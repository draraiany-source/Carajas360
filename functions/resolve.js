'use strict';

/**
 * Resolve Carajás (Fase 4): solicitação com questionário e anexos,
 * matching no servidor, propostas e ACEITE TRANSACIONAL que cria o pedido
 * operacional e vincula chat, agenda e financeiro.
 *
 * Toda escrita em resolveRequests/resolveProposals/orders(origem Resolve)
 * passa por aqui; as regras negam escrita direta do app.
 */
const crypto = require('crypto');
const core = require('./resolveCore');
const fin = require('./financeCore');

module.exports = function resolveFunctions(deps) {
  const { functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit, notifySafe } = deps;
  const sid = (...p) => crypto.createHash('sha256').update(p.join('|')).digest('hex').slice(0, 24);
  const REQ = db.collection('resolveRequests');
  const PROP = db.collection('resolveProposals');
  const ex = {};

  // Catálogo em cache, invalidado quando catalogMeta/current muda
  // (toda alteração pelo admin incrementa a versão).
  let cache = null;
  async function nodes() {
    const meta = await db.collection('catalogMeta').doc('current').get();
    const v = meta.exists ? `${meta.data().version || 0}` : '0';
    if (cache && cache.v === v && Date.now() - cache.at < 10 * 60000) return cache.nodes;
    const s = await db.collection('catalogNodes').get();
    const out = {};
    s.docs.forEach((d) => { out[d.id] = { id: d.id, ...d.data() }; });
    cache = { at: Date.now(), v, nodes: out };
    return out;
  }

  async function userActive(uid) {
    const u = await db.collection('users').doc(uid).get();
    if (!u.exists) return true;
    const d = u.data();
    return d.active !== false && d.status !== 'blocked' && d.status !== 'suspended';
  }

  async function matchFor(uid, request, opts = {}) {
    const p = await db.collection('providers').doc(uid).get();
    const provider = p.exists ? { id: p.id, ...p.data() } : null;
    return {
      provider,
      match: core.providerMatch(provider, request, {
        uid, nodes: await nodes(), userActive: await userActive(uid), nowMs: Date.now(), ...opts,
      }),
    };
  }

  // ── Criação da solicitação ────────────────────────────────────────
  async function loadQuestionnaire(category) {
    const n = core.questionnaireNodeFor(category, await nodes());
    if (!n) return null;
    const q = await db.collection('serviceQuestionnaires').doc(n.questionnaireId).get();
    if (!q.exists || q.data().status !== 'published') return null;
    return { id: q.id, ...q.data() };
  }

  /** Confere existência, tipo e tamanho dos anexos no Storage. */
  async function checkAttachments(list) {
    const bucket = admin.storage().bucket();
    const out = [];
    for (const a of list) {
      const f = bucket.file(a.path);
      const [exists] = await f.exists();
      if (!exists) throw httpsError('failed-precondition', 'Anexo não encontrado. Envie o arquivo novamente.');
      const [meta] = await f.getMetadata();
      const size = Number(meta.size || 0);
      if (!core.ATTACHMENT_TYPES.test(String(meta.contentType || '')) || size > core.ATTACHMENT_MAX_BYTES) {
        throw httpsError('invalid-argument', 'Anexo deve ser imagem ou PDF de até 10 MB');
      }
      out.push({ ...a, contentType: meta.contentType, size });
    }
    return out;
  }

  /**
   * Cria a solicitação. Idempotente por requestId. O questionário
   * publicado do serviço é validado no servidor (condicionais, tipos,
   * obrigatórias); anexos precisam estar na pasta do próprio usuário.
   * Endereço, telefone e anexos ficam no subdocumento privado.
   */
  ex.createResolveRequest = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'resolve_create', 20, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    const id = `rr_${sid(auth.uid, requestId)}`;
    const ref = REQ.doc(id);
    if ((await ref.get()).exists) return { id, reused: true };

    const v = core.validateRequestInput(data || {}, Date.now());
    if (!v.ok) throw httpsError('invalid-argument', v.errors.join('; '));
    const req = v.value;
    const ns = await nodes();
    const node = ns[req.category];
    const catalogCore = require('./catalogCore');
    if (!node || !catalogCore.effectiveActive(req.category, ns)) {
      throw httpsError('failed-precondition', 'Este serviço não está disponível para novas solicitações');
    }
    if (node.level === 'category') throw httpsError('invalid-argument', 'Escolha o grupo ou o serviço');
    // Saúde é vertical especializada: dados de saúde não entram em
    // oportunidades públicas de serviços (Fase 5).
    const root = catalogCore.rootOf(req.category, ns);
    if (root && root.vertical === 'health') {
      throw httpsError('failed-precondition', 'Para saúde, use o agendamento em Saúde (dados de saúde não são publicados como oportunidade).');
    }
    if (!(await userActive(auth.uid))) throw httpsError('permission-denied', 'Conta bloqueada');
    const questionnaire = await loadQuestionnaire(req.category);
    const ans = core.validateAnswers(questionnaire, data?.answers, { attachmentPrefix: `resolveUploads/${auth.uid}/` });
    if (!ans.ok) throw httpsError('invalid-argument', ans.errors.join('; '));
    const attachments = await checkAttachments(ans.attachments);
    const user = await db.collection('users').doc(auth.uid).get();

    await db.runTransaction(async (tx) => {
      if ((await tx.get(ref)).exists) return;
      tx.set(ref, {
        clientId: auth.uid,
        clientName: String((user.exists && user.data().name) || '').slice(0, 80),
        description: req.description,
        category: req.category,
        city: req.city,
        neighborhood: req.neighborhood,
        modality: req.modality,
        preferredDate: req.preferredDate,
        preferredPeriod: req.preferredPeriod,
        geo: req.geo,
        questionnaireId: questionnaire ? questionnaire.id : null,
        questionnaireVersion: questionnaire ? questionnaire.version || null : null,
        answers: ans.answers,
        publicAnswers: core.publicAnswers(questionnaire, ans.answers),
        attachmentCount: attachments.length,
        status: 'open',
        proposalCount: 0,
        leadMonetizationReady: true,
        leadFee: null,
        requestId,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('private').doc('details'), {
        address: req.address, reference: req.reference, phone: req.phone,
        attachments, updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { id, reused: false };
  });

  ex.cancelResolveRequest = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const ref = REQ.doc(String(data?.requestId || ''));
    await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (!s.exists) throw httpsError('not-found', 'Solicitação não encontrada');
      if (s.data().clientId !== auth.uid) throw httpsError('permission-denied', 'Sem permissão');
      if (s.data().status !== 'open') throw httpsError('failed-precondition', 'Só solicitações abertas podem ser canceladas');
      tx.update(ref, { status: 'cancelled', cancelledAt: FieldValue.serverTimestamp() });
    });
    return { ok: true };
  });

  // ── Oportunidades e propostas ─────────────────────────────────────
  ex.listResolveOpportunities = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'resolve_list', 120, 60 * 60 * 1000);
    const p = await db.collection('providers').doc(auth.uid).get();
    const provider = p.exists ? { id: p.id, ...p.data() } : null;
    if (!provider) return { eligible: false, reason: 'not_provider', items: [] };
    if (provider.verified !== true) return { eligible: false, reason: 'not_verified', items: [] };
    if (provider.active !== true) return { eligible: false, reason: 'inactive', items: [] };
    if (!(await userActive(auth.uid))) return { eligible: false, reason: 'account_blocked', items: [] };
    const ns = await nodes();
    const keys = core.matchKeys(provider.categories, ns);
    if (keys.length === 0) return { eligible: false, reason: 'no_services', items: [] };
    const results = [];
    for (let i = 0; i < keys.length; i += 10) {
      const snap = await REQ.where('status', '==', 'open').where('category', 'in', keys.slice(i, i + 10))
        .orderBy('createdAt', 'desc').limit(40).get();
      for (const d of snap.docs) {
        const m = core.providerMatch(provider, d.data(), { uid: auth.uid, nodes: ns, nowMs: Date.now() });
        if (m.ok) results.push(core.opportunityView(d.id, d.data(), m.distanceKm));
      }
    }
    results.sort((a, b) => (b.createdAtMs || 0) - (a.createdAtMs || 0));
    const items = results.slice(0, 40);
    if (items.length) {
      const got = await db.getAll(...items.map((i) => PROP.doc(`${i.id}_${auth.uid}`)));
      got.forEach((s, idx) => { items[idx].alreadyProposed = s.exists; });
    }
    return { eligible: true, reason: null, items };
  });

  ex.submitResolveProposal = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'resolve_propose', 60, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    if (!requestId) throw httpsError('invalid-argument', 'requestId obrigatório');
    const input = require('./security').validateProposalInput(data || {});
    if (!input.ok) throw httpsError('invalid-argument', 'Proposta inválida: ' + input.reason);
    const proposalId = `${requestId}_${auth.uid}`;
    const ns = await nodes();
    const active = await userActive(auth.uid);
    const result = await db.runTransaction(async (tx) => {
      const reqRef = REQ.doc(requestId);
      const [reqSnap, provSnap, propSnap] = await Promise.all([
        tx.get(reqRef), tx.get(db.collection('providers').doc(auth.uid)), tx.get(PROP.doc(proposalId)),
      ]);
      if (!reqSnap.exists) throw httpsError('not-found', 'Solicitação não encontrada');
      const req = reqSnap.data();
      if (req.status !== 'open') throw httpsError('failed-precondition', 'Solicitação não está mais aberta');
      const provider = provSnap.exists ? { id: provSnap.id, ...provSnap.data() } : null;
      const m = core.providerMatch(provider, req, { uid: auth.uid, nodes: ns, userActive: active, nowMs: Date.now() });
      if (!m.ok) throw httpsError('permission-denied', 'Prestador não elegível: ' + m.reason);
      if (propSnap.exists) throw httpsError('already-exists', 'Você já enviou proposta para esta solicitação');
      tx.set(PROP.doc(proposalId), {
        requestId, clientId: req.clientId, providerId: auth.uid,
        providerName: provider.name || 'Profissional', providerPhoto: provider.photoUrl || null,
        rating: Number(provider.rating || 0), totalServices: Number(provider.totalReviews || 0),
        category: req.category, price: input.value.price, priceCents: fin.toCents(input.value.price),
        deadlineDays: input.value.deadlineDays, message: input.value.message,
        distanceKm: m.distanceKm, available: true, accepted: false, status: 'sent',
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(reqRef, { proposalCount: FieldValue.increment(1) });
      return { clientId: req.clientId, providerName: provider.name || 'Profissional' };
    });
    await notifySafe(result.clientId, '💬 Nova proposta Resolve',
      `${result.providerName} enviou uma proposta para seu pedido.`, 'resolve');
    return { ok: true, id: proposalId };
  });

  // ── Aceite transacional ───────────────────────────────────────────
  /**
   * 1. pedido aberto; 2. proposta vinculada e disponível; 3. prestador
   * ainda elegível; 4. uma única proposta; 5. preço/condições gravados;
   * 6. pedido operacional; 7. chat, agenda e financeiro vinculados.
   * Repetir o aceite da MESMA proposta devolve o mesmo pedido; aceitar
   * outra depois (ou em paralelo) é recusado.
   */
  ex.acceptResolveProposal = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'resolve_accept', 30, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    const proposalId = String(data?.proposalId || '');
    if (!requestId || !proposalId) throw httpsError('invalid-argument', 'requestId e proposalId obrigatórios');
    const ns = await nodes();
    const orderId = `rs_${requestId}`;
    const reqRef = REQ.doc(requestId);
    const propRef = PROP.doc(proposalId);
    const orderRef = db.collection('orders').doc(orderId);

    const out = await db.runTransaction(async (tx) => {
      const [reqSnap, propSnap, orderSnap, cfgSnap] = await Promise.all([
        tx.get(reqRef), tx.get(propRef), tx.get(orderRef), tx.get(db.collection('config').doc('finance')),
      ]);
      if (!reqSnap.exists) throw httpsError('not-found', 'Solicitação não encontrada');
      const req = reqSnap.data();
      if (req.clientId !== auth.uid) throw httpsError('permission-denied', 'Só o cliente pode aceitar propostas');
      if (req.status === 'matched') {
        if (req.matchedProposalId === proposalId && orderSnap.exists) return { already: true, orderId, roomId: req.chatRoomId || null };
        throw httpsError('failed-precondition', 'Outra proposta já foi aceita para esta solicitação');
      }
      if (req.status !== 'open') throw httpsError('failed-precondition', 'Solicitação não está aberta');
      if (!propSnap.exists) throw httpsError('not-found', 'Proposta não encontrada');
      const prop = propSnap.data();
      if (prop.requestId !== requestId) throw httpsError('invalid-argument', 'Proposta não pertence a esta solicitação');
      if (prop.available === false || prop.status === 'withdrawn') throw httpsError('failed-precondition', 'O profissional retirou esta proposta');
      const providerId = prop.providerId;
      const [provSnap, userSnap] = await Promise.all([
        tx.get(db.collection('providers').doc(providerId)), tx.get(db.collection('users').doc(providerId)),
      ]);
      const provider = provSnap.exists ? { id: provSnap.id, ...provSnap.data() } : null;
      const ud = userSnap.exists ? userSnap.data() : {};
      const active = ud.active !== false && ud.status !== 'blocked' && ud.status !== 'suspended';
      // Disponibilidade foi avaliada ao propor; aqui revalidamos aprovação,
      // conta, serviço, modalidade e região.
      const m = core.providerMatch(provider, req, { uid: providerId, nodes: ns, userActive: active, skipAvailability: true });
      if (!m.ok) throw httpsError('failed-precondition', 'Profissional não está mais elegível: ' + m.reason);

      const [a, b] = [auth.uid, providerId].sort();
      const roomId = `${a}_${b}`;
      const roomRef = db.collection('chatRooms').doc(roomId);
      const room = await tx.get(roomRef);
      const cfgV = fin.validateFinanceConfig(cfgSnap.exists ? cfgSnap.data() : {});
      const cfg = cfgV.ok ? cfgV.value : fin.DEFAULT_FINANCE_CONFIG;
      const priceCents = Number.isInteger(prop.priceCents) ? prop.priceCents : fin.toCents(prop.price);
      const terms = {
        priceCents, price: fin.fromCents(priceCents), deadlineDays: prop.deadlineDays,
        message: prop.message || null, proposalId, acceptedBy: auth.uid,
      };

      // 4–5. Seleção única + condições aceitas.
      tx.update(propRef, { accepted: true, status: 'accepted', acceptedAt: FieldValue.serverTimestamp() });
      tx.update(reqRef, {
        status: 'matched', matchedProviderId: providerId, matchedProposalId: proposalId,
        matchedAt: FieldValue.serverTimestamp(), orderId, chatRoomId: roomId, acceptedTerms: terms,
      });
      // 6. Pedido operacional (pagamento pelo fluxo da Fase 3: startPayment 'service').
      tx.set(orderRef, {
        clientId: auth.uid, clientName: req.clientName || '', providerId, providerName: provider.name || '',
        category: req.category, title: String(req.description).slice(0, 80),
        description: req.description, address: null, city: req.city || null, modality: req.modality || 'presential',
        price: terms.price, priceCents, status: 'accepted', paymentStatus: 'unpaid', payoutProcessed: false,
        source: 'resolve', resolveRequestId: requestId, proposalId, acceptedTerms: terms,
        financeTerms: { commissionBps: cfg.commissionBps, cashbackBps: cfg.cashbackBps, configVersion: Number((cfgSnap.exists && cfgSnap.data().version) || 0) },
        scheduledDate: req.preferredDate || null, scheduledPeriod: req.preferredPeriod || 'any',
        chatRoomId: roomId, createdAt: FieldValue.serverTimestamp(), acceptedAt: FieldValue.serverTimestamp(),
      });
      // 7. Chat (sala canônica; vínculos só se ainda não existirem).
      if (!room.exists) {
        tx.set(roomRef, { participants: [a, b], createdAt: FieldValue.serverTimestamp(), orderId, requestId });
      } else if (!room.data().orderId) {
        tx.update(roomRef, { orderId, requestId });
      }
      // 7. Agenda (a confirmar com o profissional).
      tx.set(db.collection('scheduleEntries').doc(orderId), {
        orderId, clientId: auth.uid, providerId, date: req.preferredDate || null,
        period: req.preferredPeriod || 'any', timezone: core.TZ, status: 'to_confirm',
        createdAt: FieldValue.serverTimestamp(),
      });
      return { already: false, orderId, roomId, providerId };
    });
    return { ok: true, ...out };
  });

  /** Depois do aceite: avisa o escolhido e encerra as demais propostas. */
  ex.onResolveRequestMatched = functions.firestore.document('resolveRequests/{id}').onUpdate(async (change, ctx) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === 'matched' || after.status !== 'matched' || !after.matchedProviderId) return null;
    const others = await PROP.where('requestId', '==', ctx.params.id).get();
    const batch = db.batch();
    let n = 0;
    others.docs.forEach((d) => {
      if (d.id !== after.matchedProposalId && d.data().status !== 'not_selected') {
        batch.update(d.ref, { status: 'not_selected', available: false }); n += 1;
      }
    });
    if (n) await batch.commit();
    await notifySafe(after.matchedProviderId, '✅ Proposta aceita!',
      'Sua proposta Resolve foi aceita. O pedido e o chat já estão disponíveis.', 'resolve');
    for (const d of others.docs) {
      if (d.id !== after.matchedProposalId) {
        await notifySafe(d.data().providerId, 'Resolve', 'O cliente escolheu outra proposta para o pedido.', 'resolve');
      }
    }
    return null;
  });

  /** Notifica prestadores compatíveis (serviço, aprovação, região/raio, modalidade, disponibilidade). */
  ex.onResolveRequestCreated = functions.firestore.document('resolveRequests/{id}').onCreate(async (snap) => {
    const r = snap.data() || {};
    if (!r.category || r.status !== 'open') return null;
    const ns = await nodes();
    // Prestadores que declaram o serviço OU algo abaixo dele.
    const catalogCore = require('./catalogCore');
    const node = ns[r.category];
    const targets = [r.category, ...(node && node.level !== 'service' ? catalogCore.descendants(r.category, ns) : [])];
    const seen = new Set();
    let sent = 0;
    for (let i = 0; i < targets.length && sent < 50; i += 10) {
      const q = await db.collection('providers').where('verified', '==', true).where('active', '==', true)
        .where('categories', 'array-contains-any', targets.slice(i, i + 10)).limit(100).get();
      for (const p of q.docs) {
        if (seen.has(p.id)) continue;
        seen.add(p.id);
        const prov = { id: p.id, ...p.data() };
        const uid = prov.userId || p.id;
        if (!core.providerMatch(prov, r, { uid, nodes: ns, userActive: await userActive(uid), nowMs: Date.now() }).ok) continue;
        await notifySafe(uid, '⚡ Nova oportunidade Resolve', String(r.description || '').slice(0, 80), 'resolve');
        sent += 1;
        if (sent >= 50) break;
      }
    }
    return null;
  });

  // ── Anexos (acesso controlado) ────────────────────────────────────
  ex.getResolveAttachmentUrl = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const requestId = String(data?.requestId || '');
    const idx = Number(data?.index);
    const r = await REQ.doc(requestId).get();
    if (!r.exists) throw httpsError('not-found', 'Solicitação não encontrada');
    const req = r.data();
    const allowed = req.clientId === auth.uid || req.matchedProviderId === auth.uid || (await isAdmin(auth));
    if (!allowed) throw httpsError('permission-denied', 'Anexos visíveis só ao cliente e ao profissional escolhido');
    const det = await REQ.doc(requestId).collection('private').doc('details').get();
    const list = (det.exists && det.data().attachments) || [];
    const a = list[idx];
    if (!a) throw httpsError('not-found', 'Anexo não encontrado');
    const file = admin.storage().bucket().file(a.path);
    if (process.env.FUNCTIONS_EMULATOR === 'true') {
      const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
      return { url: `http://${host}/v0/b/${admin.storage().bucket().name}/o/${encodeURIComponent(a.path)}?alt=media`, contentType: a.contentType };
    }
    const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 10 * 60 * 1000 });
    return { url, contentType: a.contentType };
  });

  ex.__internals = { matchFor };
  return ex;
};
