'use strict';

/**
 * Pedidos do Mercado, pagamentos, reembolsos, carteira e conciliação
 * (Fase 3 — homologação/sandbox).
 *
 * Fluxo: carrinho → endereço/entrega → createMarketOrder (servidor calcula
 * preços, frete, desconto e reserva estoque) → startPayment (tentativa
 * persistida + chave de idempotência) → gateway → webhook/conciliação →
 * pedido pago → acompanhamento.
 *
 * Status do PEDIDO (marketOrders.status):
 *   pending_payment → paid → preparing → shipped|ready → delivered
 *   pending_payment → cancelled | expired
 *   paid/preparing  → cancellation_requested → cancelled (após reembolso)
 * Status do PAGAMENTO (marketOrders.paymentStatus):
 *   unpaid → pending → approved → refund_requested → partially_refunded|refunded
 *   approved_late (aprovado depois de cancelado/expirado → reembolso automático)
 */
const crypto = require('crypto');
const fin = require('../financeCore');
const { readWallet, postLedger, signedOf } = require('./wallet');
const gw = require('./gateway');

module.exports = function paymentFunctions(deps) {
  const { functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit } = deps;
  const { Timestamp } = require('firebase-admin/firestore');
  const C = {
    orders: db.collection('marketOrders'),
    attempts: db.collection('paymentAttempts'),
    refunds: db.collection('refunds'),
    issues: db.collection('financialIssues'),
    earnings: db.collection('earnings'),
    recharges: db.collection('walletRecharges'),
    webhooks: db.collection('webhookEvents'),
    runs: db.collection('reconciliationRuns'),
    products: db.collection('products'),
    stores: db.collection('stores'),
  };
  const FINANCE_CFG = db.collection('config').doc('finance');
  const now = () => Date.now();
  const ts = (msValue) => Timestamp.fromMillis(msValue);
  const millis = (v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : Number(v || 0));
  const sid = (...parts) => crypto.createHash('sha256').update(parts.join('|')).digest('hex').slice(0, 28);

  // ── Configuração e gateway ────────────────────────────────────────
  async function financeConfig(tx) {
    const s = tx ? await tx.get(FINANCE_CFG) : await FINANCE_CFG.get();
    const d = s.exists ? s.data() : {};
    const v = fin.validateFinanceConfig(d);
    return { cfg: v.ok ? v.value : { ...fin.DEFAULT_FINANCE_CONFIG }, version: Number(d.version || 0) };
  }

  let gatewayCache = null;
  function gateway() {
    const m = fin.gatewayMode(process.env);
    if (m.mode === 'disabled') return { mode: m, gateway: null };
    if (!gatewayCache || gatewayCache.mode !== m.mode) {
      gatewayCache = {
        mode: m.mode,
        impl: m.mode === 'fake' ? gw.fakeGateway(db) : gw.mercadoPagoGateway({
          accessToken: process.env.MERCADOPAGO_ACCESS_TOKEN,
          notificationUrl: process.env.PAYMENTS_WEBHOOK_URL || null,
        }),
      };
    }
    return { mode: m, gateway: gatewayCache.impl };
  }

  async function requireFinanceAdmin(context) {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente administradores');
    const u = await db.collection('users').doc(auth.uid).get();
    const role = u.exists ? u.data().adminRole : null;
    if (role && !['master', 'financial'].includes(role) && auth.token.admin !== true) {
      throw httpsError('permission-denied', 'Perfil sem acesso financeiro');
    }
    return auth;
  }

  function event(ref, type, data) {
    return [ref.collection('events').doc(), { type, ...data, at: FieldValue.serverTimestamp() }];
  }

  function issue(tx, data) {
    const ref = C.issues.doc();
    const payload = { status: 'open', ...data, createdAt: FieldValue.serverTimestamp() };
    if (tx) tx.set(ref, payload); else return ref.set(payload);
    return null;
  }

  // ── Alvos pagáveis ────────────────────────────────────────────────
  function targetRef(kind, id) {
    if (kind === 'market') return C.orders.doc(id);
    if (kind === 'service') return db.collection('orders').doc(id);
    if (kind === 'recharge') return C.recharges.doc(id);
    throw httpsError('invalid-argument', 'Tipo de cobrança inválido');
  }

  /** Valida dono, situação e valor (sempre do servidor). */
  function payability(kind, t, uid, nowMs) {
    if (!t) return { error: ['not-found', 'Pedido não encontrado'] };
    const owner = kind === 'recharge' ? t.userId : t.clientId;
    if (owner !== uid) return { error: ['permission-denied', 'Este pedido pertence a outra pessoa'] };
    if (['approved', 'paid', 'approved_late'].includes(t.paymentStatus)) return { paid: true };
    if (kind === 'market') {
      if (t.status !== 'pending_payment') return { error: ['failed-precondition', `Pedido ${t.status === 'expired' ? 'expirado' : 'não está aguardando pagamento'}`] };
      if (millis(t.reservedUntil) <= nowMs) return { error: ['failed-precondition', 'Reserva expirada. Refaça o pedido.'] };
      return { amountCents: t.totalCents, description: `Pedido ${t.storeName || ''}`.trim() };
    }
    if (kind === 'recharge') {
      if (t.status !== 'pending_payment' || millis(t.expiresAt) <= nowMs) return { error: ['failed-precondition', 'Recarga expirada'] };
      return { amountCents: t.amountCents, description: 'Recarga de carteira Carajás 360' };
    }
    // service (orders legado)
    if (['cancelled', 'completed'].includes(t.status)) return { error: ['failed-precondition', 'Pedido cancelado ou concluído'] };
    const cents = fin.toCents(t.price);
    if (!(cents > 0)) return { error: ['failed-precondition', 'Pedido sem preço definido'] };
    return { amountCents: cents, description: String(t.title || 'Serviço Carajás 360') };
  }

  // ── Estoque ────────────────────────────────────────────────────────
  async function readProducts(tx, items) {
    const refs = items.map((i) => C.products.doc(i.productId));
    const snaps = refs.length ? await tx.getAll(...refs) : [];
    return snaps;
  }
  function releaseStock(tx, order, snaps) {
    if (order.stockReleased) return;
    order.items.forEach((it, i) => {
      if (snaps[i] && snaps[i].exists) tx.update(snaps[i].ref, { stock: FieldValue.increment(it.qty) });
    });
  }

  // ── Pedido do Mercado ──────────────────────────────────────────────
  async function loadCoupon(code) {
    if (!code) return null;
    const q = await db.collection('coupons').where('code', '==', String(code).toUpperCase().trim()).limit(1).get();
    return q.empty ? { invalid: true } : { id: q.docs[0].id, ...q.docs[0].data() };
  }

  async function quote(data, tx) {
    const storeId = String(data?.storeId || '');
    const items = Array.isArray(data?.items) ? data.items.map((i) => ({ productId: String(i?.productId || ''), qty: Number(i?.qty) })) : [];
    const storeSnap = storeId ? (tx ? await tx.get(C.stores.doc(storeId)) : await C.stores.doc(storeId).get()) : null;
    const productSnaps = items.length ? (tx ? await tx.getAll(...items.map((i) => C.products.doc(i.productId || '_'))) : await db.getAll(...items.map((i) => C.products.doc(i.productId || '_')))) : [];
    const products = {};
    productSnaps.forEach((s) => { if (s.exists) products[s.id] = s.data(); });
    const couponRaw = await loadCoupon(data?.couponCode);
    const coupon = couponRaw && couponRaw.invalid ? { active: false } : couponRaw;
    const { cfg, version } = await financeConfig(tx);
    const store = storeSnap && storeSnap.exists ? { id: storeSnap.id, ...storeSnap.data() } : null;
    const q = fin.quoteMarketOrder({ items, products, store, coupon, deliveryMode: data?.deliveryMode, config: cfg, now: now() });
    return { q, store, items, productSnaps, coupon: couponRaw, cfg, version };
  }

  function publicQuote(q) {
    return {
      ok: q.ok, errors: q.errors, lines: q.lines, deliveryMode: q.deliveryMode,
      subtotalCents: q.subtotalCents, discountCents: q.discountCents,
      deliveryFeeCents: q.deliveryFeeCents, totalCents: q.totalCents,
    };
  }

  function validAddress(a, mode) {
    if (mode === 'pickup') return null;
    const s = (k, max) => String((a && a[k]) || '').trim().slice(0, max);
    const out = { street: s('street', 120), number: s('number', 20), district: s('district', 80), city: s('city', 80), reference: s('reference', 160) };
    if (!out.street || !out.city) return { error: 'Informe rua e cidade para entrega' };
    return { value: out };
  }

  const ex = {};

  ex.quoteMarketOrder = functions.region(REGION).https.onCall(async (data, context) => {
    requireAuth(context);
    const { q } = await quote(data);
    return publicQuote(q);
  });

  /**
   * Cria o pedido ANTES de qualquer cobrança: preço, desconto, frete e
   * total do servidor; snapshot de itens e condições; reserva de estoque
   * transacional (impede venda acima do estoque). Idempotente por
   * requestId (clique duplo/repetição devolvem o mesmo pedido).
   */
  ex.createMarketOrder = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'market_order', 30, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    const orderId = `mo_${sid(auth.uid, requestId)}`;
    const ref = C.orders.doc(orderId);
    const existing = await ref.get();
    if (existing.exists) return { orderId, reused: true, ...publicOrder(existing.data()) };
    const mode = data?.deliveryMode === 'pickup' ? 'pickup' : 'delivery';
    const addr = validAddress(data?.address, mode);
    if (addr && addr.error) throw httpsError('invalid-argument', addr.error);

    const result = await db.runTransaction(async (tx) => {
      const again = await tx.get(ref);
      if (again.exists) return { reused: true, order: again.data() };
      const { q, store, productSnaps, coupon, cfg, version } = await quote({ ...data, deliveryMode: mode }, tx);
      if (!q.ok) throw httpsError('failed-precondition', q.errors.join('; '));
      const terms = fin.financeTerms(q, cfg, version);
      const t = now();
      const order = {
        clientId: auth.uid,
        storeId: store.id,
        storeName: store.name || '',
        storeOwnerId: store.ownerId || null,
        items: q.lines,
        subtotalCents: q.subtotalCents,
        discountCents: q.discountCents,
        couponId: coupon && !coupon.invalid ? coupon.id : null,
        deliveryFeeCents: q.deliveryFeeCents,
        totalCents: q.totalCents,
        currency: 'BRL',
        deliveryMode: q.deliveryMode,
        address: addr && addr.value ? addr.value : null,
        financeTerms: terms,
        status: 'pending_payment',
        paymentStatus: 'unpaid',
        activeAttemptId: null,
        refundedCents: 0,
        refundPendingCents: 0,
        stockReleased: false,
        reservedUntil: ts(t + cfg.reservationMinutes * 60000),
        requestId,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };
      // Reserva: baixa o estoque agora; devolve em cancelamento/expiração.
      q.lines.forEach((l, i) => tx.update(productSnaps[i].ref, { stock: FieldValue.increment(-l.qty) }));
      tx.set(ref, order);
      tx.set(...event(ref, 'created', { by: auth.uid, totalCents: q.totalCents }));
      return { reused: false, order };
    });
    return { orderId, reused: result.reused, ...publicOrder(result.order) };
  });

  function publicOrder(o) {
    return {
      status: o.status, paymentStatus: o.paymentStatus, totalCents: o.totalCents,
      subtotalCents: o.subtotalCents, discountCents: o.discountCents, deliveryFeeCents: o.deliveryFeeCents,
      reservedUntilMs: millis(o.reservedUntil),
    };
  }

  // ── Recarga de carteira ────────────────────────────────────────────
  ex.createWalletRecharge = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'recharge', 10, 60 * 60 * 1000);
    const { cfg } = await financeConfig();
    const amountCents = Number(data?.amountCents);
    if (!Number.isInteger(amountCents) || amountCents < cfg.rechargeMinCents || amountCents > cfg.rechargeMaxCents) {
      throw httpsError('invalid-argument', `Valor de recarga entre ${cfg.rechargeMinCents / 100} e ${cfg.rechargeMaxCents / 100} reais`);
    }
    const requestId = String(data?.requestId || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    const id = `rc_${sid(auth.uid, requestId)}`;
    const ref = C.recharges.doc(id);
    await db.runTransaction(async (tx) => {
      const s = await tx.get(ref);
      if (s.exists) return;
      tx.set(ref, {
        userId: auth.uid, amountCents, status: 'pending_payment', paymentStatus: 'unpaid',
        activeAttemptId: null, expiresAt: ts(now() + 2 * 60 * 60000), createdAt: FieldValue.serverTimestamp(),
      });
    });
    return { rechargeId: id, amountCents };
  });

  // ── Tentativas de pagamento ────────────────────────────────────────
  function attemptView(id, a) {
    return {
      attemptId: id, status: a.status, method: a.method, amountCents: a.amountCents,
      statusDetail: a.statusDetail || null, pix: a.pix || null, challenge: a.challenge || null,
      targetKind: a.targetKind, targetId: a.targetId,
    };
  }

  /**
   * Inicia (ou retoma) o pagamento. Garantias:
   *  - uma tentativa ativa por pedido (dois cliques/duas abas → mesma);
   *  - mesma chave de idempotência no gateway (= id da tentativa), então
   *    repetir após timeout/resposta perdida NÃO gera nova cobrança;
   *  - resultado incerto é reconciliado antes de permitir outra cobrança.
   */
  ex.startPayment = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'start_payment', 40, 60 * 60 * 1000);
    const kind = String(data?.targetKind || '');
    const targetId = String(data?.targetId || '');
    const method = String(data?.method || '');
    const requestId = String(data?.requestId || '');
    if (!targetId || !['pix', 'card', 'wallet'].includes(method)) throw httpsError('invalid-argument', 'Dados de pagamento inválidos');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    if (kind === 'recharge' && method === 'wallet') throw httpsError('invalid-argument', 'Recarga não pode ser paga com a própria carteira');
    const g = gateway();
    if (method !== 'wallet' && !g.gateway) throw httpsError('failed-precondition', `Pagamento indisponível: ${g.mode.reason}`);
    const card = data?.card || {};
    const tRef = targetRef(kind, targetId);
    const attemptId = `pa_${sid(auth.uid, kind, targetId, requestId)}`;
    const aRef = C.attempts.doc(attemptId);

    const outcome = await db.runTransaction(async (tx) => {
      const [tSnap, aSnap] = await Promise.all([tx.get(tRef), tx.get(aRef)]);
      const t = tSnap.exists ? tSnap.data() : null;
      const p = payability(kind, t, auth.uid, now());
      if (p.error) throw httpsError(p.error[0], p.error[1]);
      if (aSnap.exists) return { reuse: true, attempt: aSnap.data() }; // mesmo clique repetido
      let active = null;
      if (t.activeAttemptId) {
        const s = await tx.get(C.attempts.doc(t.activeAttemptId));
        active = s.exists ? { id: s.id, ...s.data() } : null;
      }
      if (p.paid || (active && active.status === 'approved')) return { paid: true, attempt: active };
      if (active && fin.ACTIVE_ATTEMPT.includes(active.status)) {
        if (active.method === method) return { reuse: true, attempt: active, attemptIdOverride: active.id };
        throw httpsError('failed-precondition', 'Já existe um pagamento em andamento para este pedido. Conclua ou cancele antes de trocar a forma de pagamento.');
      }
      const { cfg } = await financeConfig(tx);
      let installments = 1;
      if (method === 'card') {
        installments = Number(card.installments || 1);
        const err = fin.validateInstallments(installments, p.amountCents, cfg);
        if (err) throw httpsError('invalid-argument', err);
        if (!card.token) throw httpsError('invalid-argument', 'Cartão não tokenizado');
      }
      const t0 = now();
      let pixExpires = null;
      if (method === 'pix') {
        // Pix exige no mínimo 30 min; a reserva acompanha o vencimento.
        pixExpires = Math.max(t0 + 30 * 60000, kind === 'market' ? millis(t.reservedUntil) : 0);
        pixExpires = Math.min(pixExpires, t0 + 120 * 60000);
      }
      const attempt = {
        userId: auth.uid, targetKind: kind, targetId, method, requestId,
        amountCents: p.amountCents, currency: 'BRL', description: p.description,
        installments, status: 'creating', statusDetail: null, gatewayPaymentId: null,
        gatewayUpdatedAt: 0, gateway: method === 'wallet' ? 'wallet' : g.gateway.name,
        pixExpiresAt: pixExpires ? ts(pixExpires) : null,
        seq: Number(t.attemptSeq || 0) + 1,
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      };
      tx.set(aRef, attempt);
      const tUpd = { activeAttemptId: attemptId, attemptSeq: attempt.seq, paymentStatus: 'pending', updatedAt: FieldValue.serverTimestamp() };
      if (kind === 'market' && pixExpires && pixExpires > millis(t.reservedUntil)) tUpd.reservedUntil = ts(pixExpires);
      tx.update(tRef, tUpd);
      if (kind === 'market') tx.set(...event(tRef, 'payment_started', { attemptId, method }));
      return { created: true, attempt };
    });

    const id = outcome.attemptIdOverride || attemptId;
    if (outcome.paid) return { already: true, status: 'approved', attemptId: outcome.attempt ? outcome.attempt.id || id : null };
    let a = outcome.attempt;
    if (a.status === 'creating' || a.status === 'uncertain') {
      a = await performCreate(id, card, auth);
    }
    return attemptView(id, a);
  });

  async function payerEmail(uid, auth) {
    if (auth && auth.token && auth.token.email) return auth.token.email;
    const u = await db.collection('users').doc(uid).get();
    return (u.exists && u.data().email) || `${uid}@users.carajas360.invalid`;
  }

  /** Cria (ou recupera, pela mesma chave) a cobrança no gateway. */
  async function performCreate(attemptId, card, auth) {
    const aRef = C.attempts.doc(attemptId);
    const a = (await aRef.get()).data();
    if (a.method === 'wallet') return payWithWallet(attemptId);
    const { gateway: g } = gateway();
    if (!g) return a;
    try {
      let norm;
      if (a.method === 'pix') {
        norm = await g.createPix({ attemptId, amountCents: a.amountCents, description: a.description, payerEmail: await payerEmail(a.userId, auth), expiresAt: millis(a.pixExpiresAt) });
      } else {
        if (!card || !card.token) {
          // Sem token (repetição sem cartão): só podemos reconciliar.
          return reconcileAttempt(attemptId);
        }
        const doc = card.docNumber ? String(card.docNumber).replace(/\D/g, '') : null;
        norm = await g.createCard({
          attemptId, amountCents: a.amountCents, description: a.description, token: String(card.token),
          installments: a.installments, paymentMethodId: card.paymentMethodId || null, issuerId: card.issuerId || null,
          payer: { email: await payerEmail(a.userId, auth), ...(doc ? { identification: { type: doc.length > 11 ? 'CNPJ' : 'CPF', number: doc } } : {}) },
        });
      }
      await applyUpdate(attemptId, norm, 'create');
    } catch (e) {
      if (e instanceof gw.GatewayUncertain) {
        await aRef.update({ status: 'uncertain', statusDetail: 'resultado incerto; conciliando', lastError: fin.redact(e.message), updatedAt: FieldValue.serverTimestamp() });
      } else if (e instanceof gw.GatewayRejected) {
        await failAttempt(attemptId, fin.redact(e.message));
      } else {
        await aRef.update({ status: 'uncertain', lastError: fin.redact(e && e.message), updatedAt: FieldValue.serverTimestamp() });
      }
    }
    return (await aRef.get()).data();
  }

  async function failAttempt(attemptId, detail, status = 'failed') {
    const aRef = C.attempts.doc(attemptId);
    await db.runTransaction(async (tx) => {
      const a = (await tx.get(aRef)).data();
      if (!fin.ACTIVE_ATTEMPT.includes(a.status)) return;
      const tRef = targetRef(a.targetKind, a.targetId);
      const t = (await tx.get(tRef)).data();
      tx.update(aRef, { status, statusDetail: detail, updatedAt: FieldValue.serverTimestamp() });
      if (t && t.activeAttemptId === attemptId) tx.update(tRef, { activeAttemptId: null, paymentStatus: 'unpaid', updatedAt: FieldValue.serverTimestamp() });
    });
  }

  /** Pagamento com a carteira interna: débito atômico, sem saldo negativo. */
  async function payWithWallet(attemptId) {
    const aRef = C.attempts.doc(attemptId);
    await db.runTransaction(async (tx) => {
      const aSnap = await tx.get(aRef);
      const a = aSnap.data();
      if (a.status !== 'creating') return;
      const tRef = targetRef(a.targetKind, a.targetId);
      const tSnap = await tx.get(tRef);
      const w = await readWallet(tx, db, a.userId, `pay_${attemptId}`);
      const t = tSnap.data();
      const p = payability(a.targetKind, t, a.userId, now());
      if (p.error || p.paid) {
        tx.update(aRef, { status: 'failed', statusDetail: p.paid ? 'pedido já pago' : p.error[1], updatedAt: FieldValue.serverTimestamp() });
        if (t && t.activeAttemptId === attemptId) tx.update(tRef, { activeAttemptId: null });
        return;
      }
      const r = postLedger(tx, w, { type: 'payment', amountCents: a.amountCents, description: a.description, refKind: a.targetKind, refId: a.targetId, extra: { attemptId } });
      if (!r.ok) {
        tx.update(aRef, { status: 'failed', statusDetail: 'Saldo insuficiente na carteira', updatedAt: FieldValue.serverTimestamp() });
        tx.update(tRef, { activeAttemptId: null, paymentStatus: 'unpaid', updatedAt: FieldValue.serverTimestamp() });
        return;
      }
      const t1 = now();
      tx.update(aRef, { status: 'approved', statusDetail: 'debitado da carteira', gatewayPaymentId: `wallet_${attemptId}`, gatewayUpdatedAt: t1, updatedAt: FieldValue.serverTimestamp() });
      approvalEffects(tx, { ...a, id: attemptId }, tRef, t, null);
    });
    return (await aRef.get()).data();
  }

  /** Efeitos da aprovação (executados uma única vez, dentro da transação). */
  function approvalEffects(tx, a, tRef, t, walletForRecharge) {
    if (a.targetKind === 'market') {
      if (t.status === 'pending_payment') {
        tx.update(tRef, { status: 'paid', paymentStatus: 'approved', paidAt: FieldValue.serverTimestamp(), paidAttemptId: a.id, paymentMethod: a.method, updatedAt: FieldValue.serverTimestamp() });
        tx.set(...event(tRef, 'paid', { attemptId: a.id, method: a.method, amountCents: a.amountCents }));
        tx.set(C.earnings.doc(tRef.id), {
          orderId: tRef.id, sellerId: t.storeOwnerId, storeId: t.storeId,
          grossCents: t.totalCents, commissionCents: t.financeTerms.commissionCents,
          netCents: t.financeTerms.sellerNetCents, commissionBps: t.financeTerms.commissionBps,
          status: 'pending_release', createdAt: FieldValue.serverTimestamp(),
        });
      } else {
        // Aprovado após cancelamento/expiração: nunca silencioso.
        const refundRef = C.refunds.doc(`rf_late_${a.id}`);
        tx.update(tRef, { paymentStatus: 'approved_late', lateApproval: true, paidAttemptId: a.id, paymentMethod: a.method, refundPendingCents: FieldValue.increment(a.amountCents), updatedAt: FieldValue.serverTimestamp() });
        tx.set(...event(tRef, 'late_approval', { attemptId: a.id, orderStatus: t.status }));
        tx.set(refundRef, refundDoc({ kind: 'market', targetId: tRef.id, attempt: a, amountCents: a.amountCents, reason: 'late_approval', by: 'system' }));
        issue(tx, { type: 'late_approval', targetKind: 'market', targetId: tRef.id, attemptId: a.id, amountCents: a.amountCents, detail: `Pagamento aprovado com pedido ${t.status}; reembolso automático solicitado.` });
      }
    } else if (a.targetKind === 'service') {
      tx.update(tRef, { paymentStatus: 'paid', transactionId: a.id, paidAt: FieldValue.serverTimestamp() });
      // Espelho legado usado pelo repasse (canPayout).
      tx.set(db.collection('payments').doc(a.id), { orderId: a.targetId, userId: a.userId, purpose: 'order', amount: fin.fromCents(a.amountCents), amountCents: a.amountCents, method: a.method, status: 'approved', walletCredited: false, externalId: a.gatewayPaymentId || a.id, createdAt: FieldValue.serverTimestamp(), paidAt: FieldValue.serverTimestamp() });
    } else if (a.targetKind === 'recharge') {
      tx.update(tRef, { status: 'paid', paymentStatus: 'approved', paidAt: FieldValue.serverTimestamp() });
      if (walletForRecharge) {
        postLedger(tx, walletForRecharge, { type: 'recharge', amountCents: a.amountCents, description: 'Recarga via Pix/cartão', refKind: 'recharge', refId: a.targetId, extra: { attemptId: a.id } });
      }
    }
  }

  function refundDoc({ kind, targetId, attempt, amountCents, reason, by }) {
    return {
      targetKind: kind, targetId, attemptId: attempt.id, method: attempt.method,
      gatewayPaymentId: attempt.gatewayPaymentId || null, amountCents, reason: String(reason || '').slice(0, 200),
      requestedBy: by, status: 'requested', gatewayRefundId: null,
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
    };
  }

  /**
   * Aplica um estado do gateway à tentativa (criação, webhook,
   * conciliação). Valida referência, valor e moeda; ignora repetidos e
   * fora de ordem; efeitos de aprovação ocorrem uma única vez.
   */
  async function applyUpdate(attemptId, norm, source) {
    const aRef = C.attempts.doc(attemptId);
    const res = await db.runTransaction(async (tx) => {
      const aSnap = await tx.get(aRef);
      if (!aSnap.exists) return { ignored: 'attempt_not_found' };
      const a = { id: attemptId, ...aSnap.data() };
      const tRef = targetRef(a.targetKind, a.targetId);
      const tSnap = await tx.get(tRef);
      const t = tSnap.data();
      const becomingApproved = norm.status === 'approved' && a.status !== 'approved';
      const wallet = becomingApproved && a.targetKind === 'recharge'
        ? await readWallet(tx, db, a.userId, `recharge_${a.targetId}`) : null;
      // Validações de autenticidade do pagamento.
      const problems = [];
      if (norm.externalReference && norm.externalReference !== attemptId) problems.push('referência externa diferente');
      if (norm.amountCents !== a.amountCents) problems.push(`valor diferente (${norm.amountCents} ≠ ${a.amountCents})`);
      if (norm.currency && norm.currency !== 'BRL') problems.push('moeda diferente');
      if (process.env.MP_COLLECTOR_ID && norm.collectorId && norm.collectorId !== process.env.MP_COLLECTOR_ID) problems.push('conta recebedora diferente');
      if (a.gatewayPaymentId && norm.id && a.gatewayPaymentId !== norm.id && !String(a.gatewayPaymentId).startsWith('wallet_')) problems.push('id de pagamento diferente');
      if (problems.length) {
        issue(tx, { type: 'payment_divergence', attemptId, gatewayPaymentId: norm.id, detail: problems.join('; '), source });
        tx.update(aRef, { divergent: true, updatedAt: FieldValue.serverTimestamp() });
        return { divergent: problems };
      }
      if (!fin.shouldApply(a, norm)) return { ignored: 'stale_or_duplicate' };
      const upd = {
        status: norm.status, statusDetail: norm.statusDetail || null, gatewayPaymentId: norm.id,
        gatewayUpdatedAt: norm.gatewayUpdatedAt || now(), refundedCents: norm.refundedCents || 0,
        updatedAt: FieldValue.serverTimestamp(), lastSource: source,
      };
      if (norm.pix) upd.pix = norm.pix;
      if (norm.challenge) upd.challenge = norm.challenge;
      tx.update(aRef, upd);
      tx.set(aRef.collection('events').doc(), { status: norm.status, detail: norm.statusDetail || null, source, at: FieldValue.serverTimestamp() });
      if (becomingApproved) {
        approvalEffects(tx, { ...a, gatewayPaymentId: norm.id }, tRef, t, wallet);
      } else if (fin.TERMINAL_FAIL.includes(norm.status) && a.status !== 'approved') {
        if (t && t.activeAttemptId === attemptId) {
          tx.update(tRef, { activeAttemptId: null, paymentStatus: 'unpaid', updatedAt: FieldValue.serverTimestamp() });
        }
        if (a.targetKind === 'market') tx.set(...event(tRef, 'payment_failed', { attemptId, status: norm.status }));
      } else if (['charged_back', 'in_dispute'].includes(norm.status)) {
        issue(tx, { type: norm.status, targetKind: a.targetKind, targetId: a.targetId, attemptId, detail: 'Contestação no gateway' });
      }
      return { applied: norm.status, refundedCents: norm.refundedCents || 0, kind: a.targetKind, targetId: a.targetId };
    });
    if (res.applied || res.ignored) await confirmRefundsFromGateway(attemptId, norm);
    if (res.applied === 'approved') await processPendingRefunds({ attemptId });
    return res;
  }

  /** Reconciliação de uma tentativa (consulta o gateway antes de decidir). */
  async function reconcileAttempt(attemptId) {
    const aRef = C.attempts.doc(attemptId);
    const a = (await aRef.get()).data();
    if (!a) return null;
    if (a.method === 'wallet') {
      if (a.status === 'creating') await payWithWallet(attemptId);
      return (await aRef.get()).data();
    }
    const { gateway: g } = gateway();
    if (!g) return a;
    try {
      const norm = a.gatewayPaymentId ? await g.get(a.gatewayPaymentId) : await g.searchByExternalReference(attemptId);
      if (norm) {
        await applyUpdate(attemptId, norm, 'reconcile');
      } else if (['creating', 'uncertain'].includes(a.status) && now() - millis(a.createdAt) > 10 * 60000) {
        // Nada no gateway após 10 min: não houve cobrança.
        await failAttempt(attemptId, 'não encontrado no gateway (sem cobrança)');
      }
    } catch (e) {
      await aRef.update({ lastError: fin.redact(e && e.message), lastReconcileAt: FieldValue.serverTimestamp() });
    }
    return (await aRef.get()).data();
  }

  async function ownedAttempt(context, attemptId) {
    const auth = requireAuth(context);
    const s = await C.attempts.doc(String(attemptId || '')).get();
    if (!s.exists) throw httpsError('not-found', 'Tentativa não encontrada');
    if (s.data().userId !== auth.uid && !(await isAdmin(auth))) throw httpsError('permission-denied', 'Sem permissão');
    return { auth, attempt: s.data() };
  }

  ex.refreshPayment = functions.region(REGION).https.onCall(async (data, context) => {
    const { auth } = await ownedAttempt(context, data?.attemptId);
    await enforceRateLimit(auth.uid, 'refresh_payment', 240, 60 * 60 * 1000);
    const a = await reconcileAttempt(String(data.attemptId));
    return attemptView(String(data.attemptId), a);
  });

  ex.cancelPaymentAttempt = functions.region(REGION).https.onCall(async (data, context) => {
    const { attempt: a } = await ownedAttempt(context, data?.attemptId);
    const id = String(data.attemptId);
    if (!fin.ACTIVE_ATTEMPT.includes(a.status)) return attemptView(id, a);
    const { gateway: g } = gateway();
    if (a.gatewayPaymentId && g && a.method !== 'wallet') {
      try {
        await applyUpdate(id, await g.cancel(a.gatewayPaymentId), 'cancel');
      } catch (e) {
        // Não cancelável: pode ter sido aprovado — reconcilia e informa.
        const after = await reconcileAttempt(id);
        if (after.status === 'approved') throw httpsError('failed-precondition', 'Pagamento já confirmado; não é possível cancelar a cobrança.');
        throw httpsError('failed-precondition', `Não foi possível cancelar agora: ${fin.redact(e.message)}`);
      }
    } else if (!a.gatewayPaymentId) {
      const after = await reconcileAttempt(id);
      if (fin.ACTIVE_ATTEMPT.includes(after.status)) await failAttempt(id, 'cancelado pelo cliente', 'cancelled');
    }
    return attemptView(id, (await C.attempts.doc(id).get()).data());
  });

  // ── Webhook (mecanismo oficial do Mercado Pago) ────────────────────
  ex.paymentsWebhook = functions.region(REGION).https.onRequest(async (req, res) => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    const g = gateway();
    if (!g.gateway) return res.status(503).send('payments disabled');
    const dataId = String((req.query && (req.query['data.id'] || req.query.id)) || (req.body && req.body.data && req.body.data.id) || '').trim();
    const type = String((req.query && (req.query.type || req.query.topic)) || (req.body && (req.body.type || req.body.topic)) || '');
    const xSignature = req.get('x-signature');
    const xRequestId = req.get('x-request-id');
    try {
      const { WebhookSignatureValidator } = require('mercadopago');
      WebhookSignatureValidator.validate({
        xSignature, xRequestId, dataId: dataId.toLowerCase(), secret: process.env.MP_WEBHOOK_SECRET,
        toleranceSeconds: Number(process.env.MP_WEBHOOK_TOLERANCE_SECONDS || 900),
      });
    } catch (e) {
      console.warn('webhook assinatura inválida', e.reason || e.message);
      return res.status(401).send('invalid signature');
    }
    if (type !== 'payment' || !dataId) return res.status(200).send('ignored');
    const evId = sid('mp', xRequestId || '', dataId, String(req.body && req.body.action || ''));
    const evRef = C.webhooks.doc(evId);
    const first = await db.runTransaction(async (tx) => {
      const s = await tx.get(evRef);
      if (s.exists && s.data().status === 'processed') return false;
      tx.set(evRef, { provider: 'mercadopago', type, dataId, requestId: xRequestId || null, action: (req.body && req.body.action) || null, status: 'received', receivedAt: FieldValue.serverTimestamp(), attempts: FieldValue.increment(1) }, { merge: true });
      return true;
    });
    if (!first) return res.status(200).send('duplicate');
    try {
      const norm = await g.gateway.get(dataId); // confirma no gateway
      const attemptId = norm.externalReference;
      const result = attemptId ? await applyUpdate(attemptId, norm, 'webhook') : { ignored: 'sem referência' };
      await evRef.update({ status: 'processed', result: JSON.stringify(result).slice(0, 300), processedAt: FieldValue.serverTimestamp() });
      return res.status(200).send('ok');
    } catch (e) {
      await evRef.update({ status: 'failed', error: fin.redact(e && e.message), failedAt: FieldValue.serverTimestamp() });
      return res.status(500).send('retry'); // o gateway reenvia
    }
  });

  // ── Reembolsos ─────────────────────────────────────────────────────
  async function requestRefundInternal({ kind, targetId, amountCents, reason, by }) {
    const tRef = targetRef(kind, targetId);
    const refundId = `rf_${crypto.randomUUID().replace(/-/g, '').slice(0, 24)}`;
    await db.runTransaction(async (tx) => {
      const t = (await tx.get(tRef)).data();
      if (!t) throw httpsError('not-found', 'Pedido não encontrado');
      if (!t.paidAttemptId) throw httpsError('failed-precondition', 'Pedido sem pagamento confirmado');
      const a = { id: t.paidAttemptId, ...(await tx.get(C.attempts.doc(t.paidAttemptId))).data() };
      const amount = amountCents == null ? t.totalCents - (t.refundedCents || 0) - (t.refundPendingCents || 0) : Number(amountCents);
      const err = fin.refundError(t.totalCents, t.refundedCents || 0, t.refundPendingCents || 0, amount);
      if (err) throw httpsError('failed-precondition', err);
      tx.set(C.refunds.doc(refundId), refundDoc({ kind, targetId, attempt: a, amountCents: amount, reason, by }));
      tx.update(tRef, { refundPendingCents: FieldValue.increment(amount), paymentStatus: 'refund_requested', updatedAt: FieldValue.serverTimestamp() });
      if (kind === 'market') tx.set(...event(tRef, 'refund_requested', { refundId, amountCents: amount, by }));
    });
    await processRefund(refundId);
    return refundId;
  }

  /** Envia o reembolso ao gateway (idempotente pela chave = refundId). */
  async function processRefund(refundId) {
    const ref = C.refunds.doc(refundId);
    const r = (await ref.get()).data();
    if (!r || r.status !== 'requested') return;
    if (r.method === 'wallet') {
      // Pagamento com carteira: estorno interno, confirmado na própria transação.
      await db.runTransaction(async (tx) => {
        const cur = (await tx.get(ref)).data();
        if (cur.status !== 'requested') return;
        const a = (await tx.get(C.attempts.doc(cur.attemptId))).data();
        const w = await readWallet(tx, db, a.userId, `refund_${refundId}`);
        postLedger(tx, w, { type: 'refund', amountCents: cur.amountCents, description: 'Estorno de pedido', refKind: cur.targetKind, refId: cur.targetId, extra: { refundId } });
        tx.update(ref, { status: 'pending_confirmation', confirmedInternally: true, updatedAt: FieldValue.serverTimestamp() });
      });
      await confirmRefund(refundId);
      return;
    }
    const { gateway: g } = gateway();
    if (!g || !r.gatewayPaymentId) return;
    try {
      const out = await g.refund(r.gatewayPaymentId, r.amountCents, refundId);
      await ref.update({ status: 'pending_confirmation', gatewayRefundId: out.refundId, gatewayRefundStatus: out.status, updatedAt: FieldValue.serverTimestamp() });
      // Confirmação SÓ com o estado do pagamento no gateway.
      await confirmRefundsFromGateway(r.attemptId, await g.get(r.gatewayPaymentId));
    } catch (e) {
      if (e instanceof gw.GatewayRejected) {
        await db.runTransaction(async (tx) => {
          const cur = (await tx.get(ref)).data();
          if (cur.status !== 'requested') return;
          const tRef = targetRef(cur.targetKind, cur.targetId);
          tx.update(ref, { status: 'failed', error: fin.redact(e.message), updatedAt: FieldValue.serverTimestamp() });
          tx.update(tRef, { refundPendingCents: FieldValue.increment(-cur.amountCents), updatedAt: FieldValue.serverTimestamp() });
          issue(tx, { type: 'refund_failed', refundId, targetId: cur.targetId, detail: fin.redact(e.message) });
        });
      } else {
        await ref.update({ lastError: fin.redact(e && e.message), updatedAt: FieldValue.serverTimestamp() }); // tenta de novo na conciliação
      }
    }
  }

  /**
   * Confirma reembolsos pendentes quando o gateway mostra o valor
   * reembolsado (ordem de criação). Nunca marca "reembolsado" antes disso.
   */
  async function confirmRefundsFromGateway(attemptId, norm) {
    if (!norm || !(norm.refundedCents > 0)) return;
    const pend = await C.refunds.where('attemptId', '==', attemptId).where('status', '==', 'pending_confirmation').get();
    if (pend.empty) return;
    const done = await C.refunds.where('attemptId', '==', attemptId).where('status', '==', 'approved').get();
    let confirmed = done.docs.reduce((s, d) => s + d.data().amountCents, 0);
    const ordered = pend.docs.sort((x, y) => millis(x.data().createdAt) - millis(y.data().createdAt));
    for (const d of ordered) {
      if (confirmed + d.data().amountCents > norm.refundedCents) break;
      confirmed += d.data().amountCents;
      await confirmRefund(d.id);
    }
  }

  /** Efeitos de um reembolso confirmado (uma única vez). */
  async function confirmRefund(refundId) {
    const ref = C.refunds.doc(refundId);
    await db.runTransaction(async (tx) => {
      const r = (await tx.get(ref)).data();
      if (!r || r.status !== 'pending_confirmation') return;
      const tRef = targetRef(r.targetKind, r.targetId);
      const t = (await tx.get(tRef)).data();
      const refundedAfter = (t.refundedCents || 0) + r.amountCents;
      const full = refundedAfter >= t.totalCents;
      // Leituras antes das escritas.
      let productSnaps = null;
      let earningsSnap = null;
      let sellerW = null;
      let clientW = null;
      const effects = r.targetKind === 'market' ? fin.refundEffects(t.financeTerms, t.totalCents, r.amountCents) : null;
      if (r.targetKind === 'market') {
        if (full && !t.stockReleased && !['delivered', 'shipped'].includes(t.status)) productSnaps = await readProducts(tx, t.items);
        earningsSnap = await tx.get(C.earnings.doc(r.targetId));
        if (earningsSnap.exists && earningsSnap.data().status === 'released' && effects.sellerNetCents > 0) {
          sellerW = await readWallet(tx, db, earningsSnap.data().sellerId, `sale_reversal_${refundId}`);
        }
        if (t.cashbackCredited && effects.cashbackCents > 0) clientW = await readWallet(tx, db, t.clientId, `cashback_reversal_${refundId}`);
      }
      tx.update(ref, { status: 'approved', confirmedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      const tUpd = {
        refundedCents: refundedAfter,
        refundPendingCents: FieldValue.increment(-r.amountCents),
        paymentStatus: full ? 'refunded' : 'partially_refunded',
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (r.targetKind === 'market') {
        // Expirado/cancelado mantêm o status (aprovação tardia reembolsada).
        if (full && ['paid', 'preparing', 'cancellation_requested'].includes(t.status)) {
          tUpd.status = 'cancelled';
        }
        if (productSnaps) { releaseStock(tx, t, productSnaps); tUpd.stockReleased = true; }
        tx.set(...event(tRef, 'refund_confirmed', { refundId, amountCents: r.amountCents, full }));
        if (earningsSnap && earningsSnap.exists) {
          const e = earningsSnap.data();
          if (e.status === 'pending_release') {
            tx.update(earningsSnap.ref, {
              netCents: Math.max(0, e.netCents - effects.sellerNetCents),
              commissionCents: Math.max(0, e.commissionCents - effects.commissionCents),
              status: full ? 'cancelled' : 'pending_release', updatedAt: FieldValue.serverTimestamp(),
            });
          } else if (e.status === 'released' && sellerW) {
            const out = postLedger(tx, sellerW, { type: 'sale_reversal', amountCents: effects.sellerNetCents, description: 'Estorno de venda (reembolso)', refKind: 'market', refId: r.targetId, extra: { refundId } });
            if (!out.ok) issue(tx, { type: 'seller_negative_balance', sellerId: e.sellerId, refundId, amountCents: effects.sellerNetCents, detail: 'Saldo do vendedor insuficiente para estorno; ajuste manual necessário.' });
            tx.update(earningsSnap.ref, { reversedCents: FieldValue.increment(effects.sellerNetCents), updatedAt: FieldValue.serverTimestamp() });
          }
        }
        if (clientW) {
          const out = postLedger(tx, clientW, { type: 'cashback_reversal', amountCents: effects.cashbackCents, description: 'Estorno de cashback', refKind: 'market', refId: r.targetId, extra: { refundId } });
          if (!out.ok) issue(tx, { type: 'cashback_reversal_failed', userId: t.clientId, refundId, amountCents: effects.cashbackCents, detail: 'Saldo insuficiente para estornar cashback.' });
        }
      }
      tx.update(tRef, tUpd);
    });
  }

  async function processPendingRefunds({ attemptId } = {}) {
    let q = C.refunds.where('status', '==', 'requested');
    if (attemptId) q = q.where('attemptId', '==', attemptId);
    const s = await q.limit(50).get();
    for (const d of s.docs) await processRefund(d.id);
    return s.size;
  }

  // ── Cancelamento ───────────────────────────────────────────────────
  ex.cancelMarketOrder = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const orderId = String(data?.orderId || '');
    const reason = String(data?.reason || 'Cancelado').slice(0, 200);
    const ref = C.orders.doc(orderId);
    const o = (await ref.get()).data();
    if (!o) throw httpsError('not-found', 'Pedido não encontrado');
    const adm = await isAdmin(auth);
    const isClient = o.clientId === auth.uid;
    const isSeller = o.storeOwnerId === auth.uid;
    if (!isClient && !isSeller && !adm) throw httpsError('permission-denied', 'Sem permissão');

    if (o.status === 'pending_payment') {
      // Cancela a cobrança pendente (se houver) antes de liberar o estoque.
      if (o.activeAttemptId) {
        const a = (await C.attempts.doc(o.activeAttemptId).get()).data();
        if (a && fin.ACTIVE_ATTEMPT.includes(a.status)) {
          const { gateway: g } = gateway();
          if (a.gatewayPaymentId && g && a.method !== 'wallet') {
            try { await applyUpdate(o.activeAttemptId, await g.cancel(a.gatewayPaymentId), 'order_cancel'); } catch (e) { await reconcileAttempt(o.activeAttemptId); }
          } else {
            await reconcileAttempt(o.activeAttemptId);
          }
          const after = (await C.attempts.doc(o.activeAttemptId).get()).data();
          if (after.status === 'approved') throw httpsError('failed-precondition', 'O pagamento acabou de ser confirmado. Solicite o cancelamento com reembolso.');
          if (fin.ACTIVE_ATTEMPT.includes(after.status)) await failAttempt(o.activeAttemptId, 'pedido cancelado', 'cancelled');
        }
      }
      await db.runTransaction(async (tx) => {
        const cur = (await tx.get(ref)).data();
        if (cur.status !== 'pending_payment') throw httpsError('failed-precondition', 'O pedido mudou de situação; atualize a tela.');
        const snaps = await readProducts(tx, cur.items);
        releaseStock(tx, cur, snaps);
        tx.update(ref, { status: 'cancelled', paymentStatus: cur.paymentStatus === 'pending' ? 'cancelled' : cur.paymentStatus, stockReleased: true, cancelReason: reason, cancelledBy: auth.uid, activeAttemptId: null, updatedAt: FieldValue.serverTimestamp() });
        tx.set(...event(ref, 'cancelled', { by: auth.uid, reason }));
      });
      return { ok: true, status: 'cancelled' };
    }
    if (['paid', 'preparing'].includes(o.status) || (adm && ['shipped', 'ready', 'delivered'].includes(o.status))) {
      await ref.update({ status: 'cancellation_requested', cancelReason: reason, cancelledBy: auth.uid, updatedAt: FieldValue.serverTimestamp() });
      await ref.collection('events').add({ type: 'cancellation_requested', by: auth.uid, reason, at: FieldValue.serverTimestamp() });
      const refundId = await requestRefundInternal({ kind: 'market', targetId: orderId, amountCents: null, reason, by: auth.uid });
      return { ok: true, status: 'cancellation_requested', refundId };
    }
    throw httpsError('failed-precondition', 'Este pedido não pode mais ser cancelado pelo app. Fale com o suporte.');
  });

  /** Admin: reembolso total ou parcial (confirmado só pelo gateway). */
  ex.refundMarketOrder = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireFinanceAdmin(context);
    const amount = data?.amountCents == null ? null : Number(data.amountCents);
    const refundId = await requestRefundInternal({ kind: 'market', targetId: String(data?.orderId || ''), amountCents: amount, reason: data?.reason || 'Reembolso administrativo', by: auth.uid });
    await db.collection('auditLogs').add({ adminId: auth.uid, adminName: 'Admin', action: 'Solicitou reembolso', target: String(data?.orderId || ''), details: { refundId, amountCents: amount }, timestamp: FieldValue.serverTimestamp() });
    return { ok: true, refundId };
  });

  // ── Acompanhamento pela loja + liberação de repasse interno ───────
  const FLOW = { paid: ['preparing'], preparing: ['shipped', 'ready'], shipped: ['delivered'], ready: ['delivered'] };
  ex.marketOrderUpdateStatus = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const orderId = String(data?.orderId || '');
    const to = String(data?.status || '');
    const ref = C.orders.doc(orderId);
    const adm = await isAdmin(auth);
    await db.runTransaction(async (tx) => {
      const o = (await tx.get(ref)).data();
      if (!o) throw httpsError('not-found', 'Pedido não encontrado');
      if (o.storeOwnerId !== auth.uid && !adm) throw httpsError('permission-denied', 'Somente a loja');
      if (!(FLOW[o.status] || []).includes(to)) throw httpsError('failed-precondition', `Transição inválida (${o.status} → ${to})`);
      if (to === 'ready' && o.deliveryMode !== 'pickup') throw httpsError('failed-precondition', 'Pedido com entrega: use "enviado"');
      let earnSnap = null;
      let sellerW = null;
      let clientW = null;
      if (to === 'delivered') {
        earnSnap = await tx.get(C.earnings.doc(orderId));
        if (earnSnap.exists && earnSnap.data().status === 'pending_release') sellerW = await readWallet(tx, db, earnSnap.data().sellerId, `sale_${orderId}`);
        if (!o.cashbackCredited && o.financeTerms.cashbackCents > 0 && o.paymentStatus === 'approved') clientW = await readWallet(tx, db, o.clientId, `cashback_${orderId}`);
      }
      const upd = { status: to, updatedAt: FieldValue.serverTimestamp(), [`${to}At`]: FieldValue.serverTimestamp() };
      if (sellerW) {
        // Saldo INTERNO disponível do vendedor — não é transferência bancária.
        const e = earnSnap.data();
        if (e.netCents > 0) postLedger(tx, sellerW, { type: 'sale_release', amountCents: e.netCents, description: `Venda liberada (pedido ${orderId.slice(-6)})`, refKind: 'market', refId: orderId });
        tx.update(earnSnap.ref, { status: 'released', releasedAt: FieldValue.serverTimestamp() });
      }
      if (clientW) {
        postLedger(tx, clientW, { type: 'cashback', amountCents: o.financeTerms.cashbackCents, description: 'Cashback de compra', refKind: 'market', refId: orderId });
        upd.cashbackCredited = true;
      }
      tx.update(ref, upd);
      tx.set(...event(ref, to, { by: auth.uid }));
    });
    return { ok: true, status: to };
  });

  // ── Manutenção: expiração, conciliação e reembolsos pendentes ─────
  async function expireOrders(limit = 100) {
    const s = await C.orders.where('status', '==', 'pending_payment').where('reservedUntil', '<=', ts(now())).limit(limit).get();
    let expired = 0;
    for (const d of s.docs) {
      const o = d.data();
      if (o.activeAttemptId) {
        const a = await reconcileAttempt(o.activeAttemptId);
        if (a && a.status === 'approved') continue; // virou pago
        if (a && fin.ACTIVE_ATTEMPT.includes(a.status)) {
          const { gateway: g } = gateway();
          if (a.gatewayPaymentId && g && a.method !== 'wallet') {
            try { await applyUpdate(o.activeAttemptId, await g.cancel(a.gatewayPaymentId), 'expire'); } catch (e) { /* aprovação tardia será tratada */ }
          }
          const after = (await C.attempts.doc(o.activeAttemptId).get()).data();
          if (after.status === 'approved') continue;
          if (fin.ACTIVE_ATTEMPT.includes(after.status)) await failAttempt(o.activeAttemptId, 'reserva expirada', 'expired');
        }
      }
      const ok = await db.runTransaction(async (tx) => {
        const cur = (await tx.get(d.ref)).data();
        if (cur.status !== 'pending_payment' || millis(cur.reservedUntil) > now()) return false;
        const snaps = await readProducts(tx, cur.items);
        releaseStock(tx, cur, snaps);
        tx.update(d.ref, { status: 'expired', paymentStatus: cur.paymentStatus === 'pending' ? 'expired' : cur.paymentStatus, stockReleased: true, activeAttemptId: null, updatedAt: FieldValue.serverTimestamp() });
        tx.set(...event(d.ref, 'expired', {}));
        return true;
      });
      if (ok) expired += 1;
    }
    return expired;
  }

  async function reconcileStale(limit = 50) {
    let n = 0;
    for (const st of fin.ACTIVE_ATTEMPT) {
      const s = await C.attempts.where('status', '==', st).where('updatedAt', '<=', ts(now() - 2 * 60000)).limit(limit).get();
      for (const d of s.docs) { await reconcileAttempt(d.id); n += 1; }
    }
    // Reembolsos aguardando confirmação.
    const pend = await C.refunds.where('status', '==', 'pending_confirmation').limit(limit).get();
    const { gateway: g } = gateway();
    for (const d of pend.docs) {
      const r = d.data();
      if (r.method === 'wallet') { await confirmRefund(d.id); continue; }
      if (g && r.gatewayPaymentId) {
        try { await confirmRefundsFromGateway(r.attemptId, await g.get(r.gatewayPaymentId)); } catch (e) { /* próxima rodada */ }
      }
    }
    return n;
  }

  async function maintenance(source) {
    const started = now();
    const out = { expired: await expireOrders(), reconciled: await reconcileStale(), refundsSent: await processPendingRefunds() };
    await C.runs.add({ ...out, source, durationMs: now() - started, at: FieldValue.serverTimestamp() });
    return out;
  }

  ex.paymentsMaintenance = functions.pubsub.schedule('every 10 minutes').onRun(() => maintenance('schedule'));
  ex.runPaymentsMaintenance = functions.region(REGION).https.onCall(async (data, context) => {
    await requireFinanceAdmin(context);
    return maintenance('admin');
  });

  // ── Configuração financeira (fonte única no servidor) ──────────────
  ex.updateFinanceConfig = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireFinanceAdmin(context);
    const res = await db.runTransaction(async (tx) => {
      const s = await tx.get(FINANCE_CFG);
      const cur = s.exists ? s.data() : {};
      const v = fin.validateFinanceConfig(data || {}, fin.validateFinanceConfig(cur).value);
      if (!v.ok) throw httpsError('invalid-argument', v.errors.join('; '));
      const version = Number(cur.version || 0) + 1;
      tx.set(FINANCE_CFG, { ...v.value, version, updatedAt: FieldValue.serverTimestamp(), updatedBy: auth.uid });
      tx.set(FINANCE_CFG.collection('history').doc(String(version)), { ...v.value, version, by: auth.uid, at: FieldValue.serverTimestamp() });
      return { ...v.value, version };
    });
    await db.collection('auditLogs').add({ adminId: auth.uid, adminName: 'Admin', action: 'Alterou configuração financeira', target: 'config/finance', details: res, timestamp: FieldValue.serverTimestamp() });
    return res;
  });

  /** Condições financeiras gravadas em pedidos de serviço (legado). */
  ex.onServiceOrderTerms = functions.firestore.document('orders/{id}').onCreate(async (snap) => {
    const d = snap.data() || {};
    if (d.financeTerms || d.type === 'marketplace') return null;
    const { cfg, version } = await financeConfig();
    await snap.ref.update({ financeTerms: { commissionBps: cfg.commissionBps, cashbackBps: cfg.cashbackBps, configVersion: version } });
    return null;
  });

  // ── Carteira: conciliação saldo × razão ───────────────────────────
  ex.walletReconcile = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireFinanceAdmin(context);
    const uid = String(data?.userId || '');
    if (!uid) throw httpsError('invalid-argument', 'userId obrigatório');
    const [w, txs] = await Promise.all([db.collection('wallets').doc(uid).get(), db.collection('transactions').where('userId', '==', uid).get()]);
    const ledger = txs.docs.reduce((s, d) => s + signedOf(d.data()), 0);
    const wd = w.exists ? w.data() : {};
    const balance = Number.isInteger(wd.balanceCents) ? wd.balanceCents : (fin.toCents(wd.balance || 0) || 0);
    const result = { userId: uid, balanceCents: balance, ledgerCents: ledger, diffCents: balance - ledger, entries: txs.size, ok: balance === ledger };
    await C.runs.add({ type: 'wallet', ...result, by: auth.uid, at: FieldValue.serverTimestamp() });
    if (!result.ok) await issue(null, { type: 'wallet_divergence', userId: uid, detail: `saldo ${balance} × razão ${ledger}` });
    return result;
  });

  // Exposto para reaproveitar nos fluxos legados (index.js).
  ex.__internals = { applyUpdate, reconcileAttempt, payability };
  return ex;
};
