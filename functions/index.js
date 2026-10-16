/**
 * Carajás 360 — Cloud Functions (staging-safe)
 *
 * Pagamentos (Fase 3): somente homologação/sandbox. O gateway só liga com
 * PAYMENTS_GATEWAY=mercadopago + PAYMENTS_ENV=sandbox + credencial de TESTE
 * + segredo do webhook, fora do projeto de produção (ver financeCore
 * gatewayMode). No emulador, PAYMENTS_GATEWAY=fake usa o simulador.
 */
// v1 explícito: firebase-functions 7 exporta v2 por padrão; os gatilhos
// continuam 1ª geração (sem migração para v2 nesta etapa).
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const axios = require('axios');
const crypto = require('crypto');
const policy = require('./orderPolicy');
const sec = require('./security');
const fin = require('./financeCore');
const { readWallet, postLedger } = require('./payments/wallet');

admin.initializeApp();
const db = admin.firestore();

const REGION = 'us-central1';
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';
const ALLOWED_PROFILE_TYPES = ['client', 'provider', 'deliverer', 'company'];

function getMpToken() {
  return process.env.MERCADOPAGO_ACCESS_TOKEN || '';
}

function getAnthropicKey() {
  return process.env.ANTHROPIC_API_KEY || '';
}

function httpsError(code, message) {
  return new functions.https.HttpsError(code, message);
}

function requireAuth(context) {
  if (ENFORCE_APP_CHECK && !context.app) {
    throw httpsError('failed-precondition', 'App Check obrigatório');
  }
  if (!context.auth || !context.auth.uid) {
    throw httpsError('unauthenticated', 'Login obrigatório');
  }
  return context.auth;
}

async function isAdmin(auth) {
  const t = auth.token || {};
  if (t.admin === true || t.role === 'admin') return true;
  const snap = await db.collection('users').doc(auth.uid).get();
  return snap.exists && snap.data().type === 'admin';
}

async function enforceRateLimit(uid, key, max, windowMs) {
  const ref = db.collection('rateLimits').doc(`${uid}_${key}`);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    const data = snap.data() || {};
    let windowStart = Number(data.windowStart || 0);
    let count = Number(data.count || 0);
    if (now - windowStart > windowMs) {
      windowStart = now;
      count = 0;
    }
    if (count >= max) {
      throw httpsError('resource-exhausted', 'Muitas tentativas. Aguarde um pouco.');
    }
    tx.set(ref, { uid, key, windowStart, count: count + 1, updatedAt: now }, { merge: true });
  });
}

/**
 * Notificação no app. `link` (opcional) leva a tela certa ao tocar:
 * { route: 'resolveDetail' | 'resolveOpportunities' | 'appointments' |
 *   'bookings' | 'marketOrder' | 'myOrders', id?: string }.
 */
const NOTIF_ROUTES = ['resolveDetail', 'resolveOpportunities', 'appointments', 'bookings', 'marketOrder', 'myOrders', 'storeOrders'];
async function notify(userId, title, body, type, link) {
  if (!userId) return;
  const safeLink = link && NOTIF_ROUTES.includes(link.route)
    ? { route: link.route, ...(link.id ? { id: String(link.id).slice(0, 120) } : {}) } : null;
  await db.collection('notifications').add({
    userId,
    title: String(title).slice(0, 120),
    body: String(body).slice(0, 500),
    type: type || 'info',
    ...(safeLink ? { link: safeLink } : {}),
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function canNotifyTarget(callerUid, targetUid) {
  if (callerUid === targetUid) return true;
  const caller = await db.collection('users').doc(callerUid).get();
  if (caller.exists && caller.data().type === 'admin') return true;

  const asClient = await db.collection('orders')
    .where('clientId', '==', callerUid)
    .where('providerId', '==', targetUid)
    .limit(1)
    .get();
  if (!asClient.empty) return true;

  const asProvider = await db.collection('orders')
    .where('clientId', '==', targetUid)
    .where('providerId', '==', callerUid)
    .limit(1)
    .get();
  if (!asProvider.empty) return true;

  // Vínculo Resolve: proposta entre prestador e cliente da solicitação.
  for (const [providerId, clientId] of [[callerUid, targetUid], [targetUid, callerUid]]) {
    const link = await db.collection('resolveProposals')
      .where('providerId', '==', providerId)
      .where('clientId', '==', clientId)
      .limit(1)
      .get();
    if (!link.empty) return true;
  }

  // Auditoria: sala de chat NÃO é vínculo (qualquer usuário pode criar uma
  // com qualquer outro e, com isso, mandar push arbitrário).
  return false;
}

/** Notificação nunca derruba a operação principal já persistida. */
async function notifySafe(userId, title, body, type, link) {
  try {
    await notify(userId, title, body, type, link);
  } catch (e) {
    console.error('notifySafe', userId, e);
  }
}

/** Taxa de comissão do snapshot do pedido de serviço (bps → fração). */
function orderCommissionRate(order) {
  const bps = order && order.financeTerms && order.financeTerms.commissionBps;
  return Number.isInteger(bps) ? bps / 10000 : undefined;
}

/**
 * Crédito do repasse do prestador como SALDO INTERNO (não é transferência
 * bancária). Idempotente pela chave do razão. Usar em duas fases:
 * `const w = await readProviderWallet(...)` antes de qualquer escrita.
 */
function readProviderWallet(tx, providerId, orderId) {
  return readWallet(tx, db, providerId, `payout_service_${orderId}`);
}
function postProviderPayout(tx, w, orderId, providerAmount) {
  const out = postLedger(tx, w, {
    type: 'sale_release',
    amountCents: fin.toCents(providerAmount),
    description: 'Serviço concluído (saldo interno)',
    refKind: 'service',
    refId: orderId,
  });
  if (!out.ok) throw httpsError('failed-precondition', 'Falha ao lançar repasse interno');
}

function publicPaymentView(pay, id) {
  return {
    id: String(id),
    status: pay.status || null,
    method: pay.method || null,
    purpose: pay.purpose || null,
    orderId: pay.orderId || null,
    pending: pay.status === 'pending' || pay.status === 'in_process',
  };
}

/** Id de documento vindo do cliente (sem '/', tamanho limitado). */
function cleanId(v, field = 'id') {
  const id = String(v || '');
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(id)) throw httpsError('invalid-argument', `${field} inválido`);
  return id;
}

/** Janela para o cliente confirmar a conclusão antes da confirmação automática. */
const CLIENT_CONFIRM_MS = 72 * 60 * 60 * 1000;

/**
 * Conclusão + repasse interno ao prestador, dentro de uma transação já
 * aberta (leituras de pagamento e carteira antes das escritas).
 */
async function completeInTx(tx, orderRef, order, orderId, actorUid, updates) {
  const block = policy.completeBlockReason(order.status || 'pending', order.paymentStatus || 'unpaid');
  if (block) {
    throw httpsError('failed-precondition', block === 'payment_not_confirmed'
      ? 'Não é possível concluir sem pagamento confirmado' : 'Transição de status inválida');
  }
  updates.status = 'completed';
  updates.completedAt = FieldValue.serverTimestamp();
  updates.awaitingClientConfirmation = false;
  if (order.payoutProcessed) return;
  const paymentId = order.transactionId;
  if (!paymentId) throw httpsError('failed-precondition', 'Pagamento não confirmado');
  const paySnap = await tx.get(db.collection('payments').doc(String(paymentId)));
  if (!paySnap.exists) throw httpsError('failed-precondition', 'Pagamento não confirmado');
  const pay = paySnap.data();
  const decision = policy.canPayout({
    status: 'completed',
    paymentStatus: order.paymentStatus,
    payoutProcessed: false,
    providerId: order.providerId,
    price: order.price,
    orderId,
    paymentOrderId: pay.orderId,
    gatewayStatus: pay.status,
    paidAmount: pay.amount,
    commissionRate: orderCommissionRate(order),
  });
  if (!decision.ok) throw httpsError('failed-precondition', 'Repasse recusado: ' + decision.reason);
  const providerWallet = await readProviderWallet(tx, order.providerId, orderId);
  Object.assign(updates, {
    payoutProcessed: true,
    payoutStatus: 'done',
    payoutAt: FieldValue.serverTimestamp(),
    commission: decision.commission,
    platformFee: decision.commission,
    providerAmount: decision.providerAmount,
  });
  postProviderPayout(tx, providerWallet, orderId, decision.providerAmount);
  tx.set(db.collection('financialAudits').doc(), {
    orderId,
    userId: actorUid,
    providerId: order.providerId,
    clientId: order.clientId,
    gross: decision.gross,
    fees: decision.commission,
    commission: decision.commission,
    providerAmount: decision.providerAmount,
    gatewayTransactionId: String(paymentId),
    status: 'payout_done',
    payoutProcessed: true,
    createdAt: FieldValue.serverTimestamp(),
  });
}

exports.transitionOrder = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = cleanId(data?.orderId, 'orderId');
  const action = String(data?.action || '');
  if (!policy.targetStatus(action)) {
    throw httpsError('invalid-argument', 'orderId e action obrigatórios');
  }
  // Auditoria: aceitar exige perfil de prestador aprovado e ativo.
  let providerOk = false;
  if (action === 'accept') {
    const prov = await db.collection('providers').doc(auth.uid).get();
    providerOk = prov.exists && prov.data().verified === true && prov.data().active !== false;
  }

  let needsRefund = false;
  const result = await db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    const from = order.status || 'pending';
    let to = policy.targetStatus(action);
    const paymentStatus = order.paymentStatus || 'unpaid';
    const isClient = auth.uid === order.clientId;
    const isProvider = Boolean(order.providerId) && auth.uid === order.providerId;

    if (!policy.actorMayPerform(action, auth.uid, order.clientId, order.providerId || null)) {
      throw httpsError('permission-denied', 'Sem permissão para esta ação');
    }
    if (action === 'accept') {
      if (isClient) throw httpsError('permission-denied', 'O cliente não pode aceitar o próprio pedido');
      if (!providerOk) throw httpsError('permission-denied', 'Somente profissional aprovado pode aceitar pedidos');
    }
    // Prestador "conclui" = marca como feito; quem conclui é o cliente
    // (ou a confirmação automática após 72 h).
    const providerMarksDone = action === 'complete' && isProvider && !isClient;
    if (providerMarksDone) to = from;
    if (!providerMarksDone && !policy.isAllowedTransition(from, to)) {
      throw httpsError('failed-precondition', 'Transição de status inválida');
    }

    const updates = { updatedAt: FieldValue.serverTimestamp() };
    if (!providerMarksDone) updates.status = to;

    if (action === 'accept') {
      updates.providerId = order.providerId || auth.uid;
      updates.acceptedAt = FieldValue.serverTimestamp();
      if (!(Number(order.price) > 0)) {
        const quoted = Number(data?.price);
        if (!Number.isFinite(quoted) || quoted < 1 || quoted > 1000000) {
          throw httpsError('invalid-argument', 'Informe o valor do orçamento (R$ 1 a R$ 1.000.000)');
        }
        updates.price = policy.round2(quoted);
      }
    }
    if (action === 'start') {
      updates.startedAt = FieldValue.serverTimestamp();
    }
    if (action === 'cancel' || action === 'decline') {
      if (paymentStatus === 'pending') {
        throw httpsError('failed-precondition', 'Há um pagamento em andamento. Cancele a cobrança antes de cancelar o pedido.');
      }
      updates.cancelReason = action === 'decline'
        ? 'Recusado pelo profissional'
        : String(data?.reason || 'Cancelado').slice(0, 300);
      updates.cancelledBy = auth.uid;
      // Auditoria: pedido pago cancelado gera reembolso (antes o dinheiro ficava retido).
      if (paymentStatus === 'paid' && !order.payoutProcessed) {
        needsRefund = true;
        updates.paymentStatus = 'refund_requested';
      }
    }
    if (providerMarksDone) {
      const block = policy.completeBlockReason(from, paymentStatus);
      if (block) {
        throw httpsError('failed-precondition', block === 'payment_not_confirmed'
          ? 'Não é possível concluir sem pagamento confirmado' : 'Transição de status inválida');
      }
      updates.awaitingClientConfirmation = true;
      updates.providerDoneAt = FieldValue.serverTimestamp();
      updates.autoConfirmAfter = Timestamp.fromMillis(Date.now() + CLIENT_CONFIRM_MS);
    } else if (action === 'complete') {
      await completeInTx(tx, orderRef, order, orderId, auth.uid, updates);
    }

    tx.update(orderRef, updates);
    return {
      ok: true,
      status: providerMarksDone ? from : to,
      awaitingClientConfirmation: providerMarksDone,
      payoutProcessed: updates.payoutProcessed || order.payoutProcessed || false,
    };
  });

  if (needsRefund) {
    try {
      await paymentsInternals.refundService(orderId, 'Pedido cancelado', auth.uid);
    } catch (e) {
      console.error('refundService', orderId, e && e.message);
      await db.collection('financialIssues').add({
        type: 'service_refund_failed', targetKind: 'service', targetId: orderId,
        detail: String(e && e.message || e).slice(0, 300), status: 'open', createdAt: FieldValue.serverTimestamp(),
      });
    }
  }

  try {
    const after = await db.collection('orders').doc(orderId).get();
    const o = after.data() || {};
    const link = { route: 'myOrders' };
    if (action === 'accept' && o.clientId) {
      await notify(o.clientId, '✅ Pedido aceito!', 'Um profissional aceitou seu pedido.', 'order', link);
    }
    if (action === 'start' && o.clientId) {
      await notify(o.clientId, '🔧 Serviço iniciado', 'Seu serviço está em andamento.', 'order', link);
    }
    if (action === 'complete' && result.awaitingClientConfirmation && o.clientId) {
      await notify(o.clientId, '✔️ Serviço finalizado pelo profissional',
        'Confirme a conclusão em Meus pedidos. Sem resposta em 72 h, a conclusão é confirmada automaticamente.', 'order', link);
    }
    if ((action === 'cancel' || action === 'decline') && o.clientId && o.clientId !== auth.uid) {
      await notify(o.clientId, '❌ Pedido cancelado', o.cancelReason || 'Pedido cancelado', 'order', link);
    }
    if (action === 'cancel' && o.providerId && o.providerId !== auth.uid) {
      await notify(o.providerId, '❌ Pedido cancelado', 'O cliente cancelou a solicitação.', 'order', link);
    }
  } catch (e) {
    console.error('notify after transition', e);
  }
  return result;
});

/** Confirma automaticamente serviços finalizados pelo prestador há 72 h. */
exports.autoConfirmServiceOrders = functions.pubsub.schedule('every 60 minutes').onRun(async () => {
  const due = await db.collection('orders')
    .where('awaitingClientConfirmation', '==', true)
    .where('autoConfirmAfter', '<=', Timestamp.now())
    .limit(200).get();
  for (const d of due.docs) {
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(d.ref);
        const o = snap.data();
        if (!o || o.status !== 'inProgress' || o.awaitingClientConfirmation !== true) return;
        const updates = { updatedAt: FieldValue.serverTimestamp(), autoConfirmed: true };
        await completeInTx(tx, d.ref, o, d.id, 'system', updates);
        tx.update(d.ref, updates);
      });
    } catch (e) {
      console.error('autoConfirm', d.id, e && e.message);
    }
  }
  return null;
});

exports.processPayout = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data?.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');

  const adminUser = await isAdmin(auth);
  return db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    if (order.clientId !== auth.uid && order.providerId !== auth.uid && !adminUser) {
      throw httpsError('permission-denied', 'Sem permissão');
    }
    if (order.payoutProcessed) {
      return { ok: true, already: true, payoutProcessed: true };
    }
    const paymentId = order.transactionId;
    if (!paymentId) throw httpsError('failed-precondition', 'Pagamento não confirmado');
    const paySnap = await tx.get(db.collection('payments').doc(String(paymentId)));
    if (!paySnap.exists) throw httpsError('failed-precondition', 'Pagamento não confirmado');
    const pay = paySnap.data();
    const decision = policy.canPayout({
      status: order.status,
      paymentStatus: order.paymentStatus || 'unpaid',
      payoutProcessed: false,
      providerId: order.providerId,
      price: order.price,
      orderId,
      paymentOrderId: pay.orderId,
      gatewayStatus: pay.status,
      paidAmount: pay.amount,
      commissionRate: orderCommissionRate(order),
    });
    if (!decision.ok) {
      throw httpsError('failed-precondition', 'Repasse recusado: ' + decision.reason);
    }
    // Todas as leituras antes das escritas.
    const providerWallet = await readProviderWallet(tx, order.providerId, orderId);
    tx.update(orderRef, {
      payoutProcessed: true,
      payoutStatus: 'done',
      payoutAt: FieldValue.serverTimestamp(),
      commission: decision.commission,
      platformFee: decision.commission,
      providerAmount: decision.providerAmount,
    });
    postProviderPayout(tx, providerWallet, orderId, decision.providerAmount);
    tx.set(db.collection('financialAudits').doc(), {
      orderId,
      userId: auth.uid,
      providerId: order.providerId,
      clientId: order.clientId,
      gross: decision.gross,
      fees: decision.commission,
      commission: decision.commission,
      providerAmount: decision.providerAmount,
      gatewayTransactionId: String(paymentId),
      status: 'payout_done',
      payoutProcessed: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, already: false, payoutProcessed: true, providerAmount: decision.providerAmount };
  });
});

// Auditoria: pagamento legado pela carteira convivia com uma cobrança
// Pix/cartão ativa (startPayment) e permitia pagar duas vezes. Desativado:
// carteira é um método do startPayment (tentativa única por pedido).
exports.payOrderWithWallet = functions.region(REGION).https.onCall(() => {
  throw httpsError('failed-precondition', 'Fluxo de pagamento antigo desativado. Atualize o app (use startPayment).');
});

/**
 * Callables antigas de cobrança: criavam a cobrança antes do pedido, com
 * id gerado no aparelho e idempotência por minuto. Substituídas por
 * createMarketOrder/createWalletRecharge + startPayment (payments/).
 */
function deprecatedPayment() {
  throw httpsError('failed-precondition', 'Fluxo de pagamento antigo desativado. Atualize o app (use startPayment).');
}
exports.generatePix = functions.region(REGION).https.onCall(deprecatedPayment);
exports.processCardPayment = functions.region(REGION).https.onCall(deprecatedPayment);

/**
 * Consulta de pagamentos LEGADOS (coleção `payments`). Se a recarga antiga
 * for aprovada, credita uma única vez (chave `recharge_legacy_{id}`), com
 * todas as leituras antes das escritas. Consulta o gateway só em sandbox.
 */
exports.checkPayment = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'checkpay', 30, 60 * 60 * 1000);
  const id = String(data?.id || '');
  if (!id) throw httpsError('invalid-argument', 'id obrigatório');

  const payRef = db.collection('payments').doc(id);
  const local = await payRef.get();
  if (!local.exists) throw httpsError('not-found', 'Pagamento não encontrado');
  const localData = local.data();
  if (localData.userId !== auth.uid && !(await isAdmin(auth))) {
    throw httpsError('permission-denied', 'Pagamento de outro usuário');
  }

  // Espelhos do fluxo novo (pa_*) e carteira: estado já é o do servidor.
  if (localData.method === 'wallet' || id.startsWith('pa_') || localData.externalId !== id ||
      fin.gatewayMode(process.env).mode !== 'mercadopago') {
    return publicPaymentView(localData, id);
  }

  let response;
  try {
    response = await axios.get(`https://api.mercadopago.com/v1/payments/${encodeURIComponent(id)}`, {
      headers: { Authorization: `Bearer ${getMpToken()}` },
      timeout: 15000,
    });
  } catch (e) {
    // Auditoria: o erro do axios carrega o cabeçalho com o token; nunca
    // deixar chegar ao log ("Unhandled error").
    console.warn('checkPayment gateway', e && e.response ? e.response.status : 'sem resposta');
    throw httpsError('unavailable', 'Não foi possível consultar o pagamento agora.');
  }
  const status = response.data.status;
  const gatewayCents = fin.toCents(response.data.transaction_amount);

  await db.runTransaction(async (tx) => {
    // 1) Leituras
    const snap = await tx.get(payRef);
    if (!snap.exists) return;
    const p = snap.data();
    const approving = status === 'approved' && p.status !== 'approved';
    const needsCredit = approving && p.purpose === 'wallet_recharge' && p.userId && !p.walletCredited;
    const wallet = needsCredit ? await readWallet(tx, db, p.userId, `recharge_legacy_${id}`) : null;
    // 2) Escritas
    if (approving) {
      if (gatewayCents !== fin.toCents(p.amount)) {
        tx.set(db.collection('financialIssues').doc(), {
          type: 'payment_divergence', legacyPaymentId: id, status: 'open',
          detail: `valor diferente (${gatewayCents} ≠ ${fin.toCents(p.amount)})`,
          createdAt: FieldValue.serverTimestamp(),
        });
        return;
      }
      tx.update(payRef, {
        status: 'approved',
        paidAt: FieldValue.serverTimestamp(),
        ...(needsCredit ? { walletCredited: true } : {}),
      });
      if (p.orderId) {
        tx.update(db.collection('orders').doc(p.orderId), {
          paymentStatus: 'paid',
          transactionId: String(id),
          paidAt: FieldValue.serverTimestamp(),
        });
      }
      if (wallet) {
        postLedger(tx, wallet, {
          type: 'recharge', amountCents: fin.toCents(p.amount), description: 'Recarga via PIX',
          refKind: 'legacy_payment', refId: id,
        });
      }
    } else if (status && status !== p.status) {
      tx.update(payRef, { status });
    }
  });

  const after = (await payRef.get()).data();
  return publicPaymentView(after, id);
});

exports.aiAssistant = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'ai', 40, 60 * 60 * 1000);
  const apiKey = getAnthropicKey();
  if (!apiKey) {
    throw httpsError('failed-precondition', 'IA não configurada neste ambiente');
  }
  const message = String(data?.message || '').slice(0, 2000);
  if (!message.trim()) throw httpsError('invalid-argument', 'Mensagem vazia');
  // Histórico do cliente: só papéis alternados, começando pelo usuário
  // (turnos de "assistente" forjados no início são descartados).
  const raw = Array.isArray(data?.history) ? data.history.slice(-8) : [];
  const history = [];
  for (const h of raw) {
    const role = h && h.isAi === true ? 'assistant' : 'user';
    if (!history.length && role === 'assistant') continue;
    if (history.length && history[history.length - 1].role === role) continue;
    history.push({ role, text: String(h?.text || '').slice(0, 1000) });
  }
  if (history.length && history[history.length - 1].role === 'user') history.pop();

  const systemPrompt = 'Você é o assistente virtual do Carajás 360, plataforma regional de serviços. '
    + 'Responda sempre em português do Brasil, de forma breve (máx. 3 parágrafos curtos). '
    + 'Não invente confirmações de pagamento nem dados pessoais.';

  const messages = [
    ...history.map((h) => ({ role: h.role, content: h.text })),
    { role: 'user', content: message },
  ];

  let response;
  try {
    response = await axios.post('https://api.anthropic.com/v1/messages', {
      model: 'claude-sonnet-4-5',
      max_tokens: 500,
      system: systemPrompt,
      messages,
    }, {
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    });
  } catch (e) {
    // Auditoria: não registrar o erro do axios (inclui o cabeçalho x-api-key).
    console.warn('aiAssistant', e && e.response ? e.response.status : 'sem resposta');
    throw httpsError('unavailable', 'Assistente indisponível no momento.');
  }
  const reply = response.data.content?.[0]?.text || 'Não consegui processar sua pergunta agora.';
  return { reply };
});

/**
 * Operações de carteira pelo cliente. Débito livre e saque foram
 * DESATIVADOS: débito só acontece dentro de um pagamento (startPayment) e
 * não há transferência bancária integrada nesta fase. Resta o cashback de
 * pedido de serviço concluído, calculado no servidor e creditado uma vez.
 */
exports.walletOp = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const op = String(data?.op || '');
  if (op === 'withdraw') {
    throw httpsError('failed-precondition', 'Saque/transferência bancária ainda não está disponível. O saldo permanece na carteira interna.');
  }
  if (op !== 'cashback') {
    throw httpsError('invalid-argument', 'Operação não permitida');
  }
  const orderId = String(data?.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
  return db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = orderSnap.data();
    if (order.status !== 'completed') throw httpsError('failed-precondition', 'Pedido não concluído');
    if (order.clientId !== auth.uid && order.providerId !== auth.uid) {
      throw httpsError('permission-denied', 'Sem permissão');
    }
    if (order.cashbackGranted) return { ok: true, already: true };
    if ((order.paymentStatus || 'unpaid') !== 'paid') {
      throw httpsError('failed-precondition', 'Pedido sem pagamento confirmado');
    }
    const bps = Number.isInteger(order.financeTerms?.cashbackBps) ? order.financeTerms.cashbackBps : 200;
    const cashbackCents = fin.bpsOf(fin.toCents(order.price || 0) || 0, bps);
    const w = cashbackCents > 0 ? await readWallet(tx, db, order.clientId, `cashback_service_${orderId}`) : null;
    if (w) {
      postLedger(tx, w, {
        type: 'cashback', amountCents: cashbackCents, description: `Cashback: ${order.title || 'Serviço'}`,
        refKind: 'service', refId: orderId,
      });
    }
    tx.update(orderRef, { cashbackGranted: true });
    return { ok: true, cashback: fin.fromCents(cashbackCents), cashbackCents };
  });
});

exports.createNotification = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'notif', 40, 60 * 60 * 1000);
  const userId = String(data?.userId || '');
  const title = String(data?.title || '').slice(0, 120);
  const body = String(data?.body || '').slice(0, 500);
  if (!userId || !title || !body) {
    throw httpsError('invalid-argument', 'Campos obrigatórios ausentes');
  }
  if (!(await canNotifyTarget(auth.uid, userId))) {
    throw httpsError('permission-denied', 'Não é permitido notificar este usuário');
  }
  const type = ['order', 'info', 'general', 'chat', 'resolve'].includes(data?.type) ? data.type : 'info';
  await notify(userId, title, body, type);
  return { ok: true };
});

exports.switchProfileType = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const next = String(data?.type || '');
  if (!ALLOWED_PROFILE_TYPES.includes(next)) {
    throw httpsError('invalid-argument', 'Tipo de perfil inválido');
  }
  const ref = db.collection('users').doc(auth.uid);
  const snap = await ref.get();
  if (snap.exists && snap.data().type === 'admin') {
    throw httpsError('permission-denied', 'Perfil admin não pode ser alterado por esta operação');
  }
  await ref.set({ type: next, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  return { ok: true, type: next };
});

exports.sendPushNotification = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap) => {
    const { userId, title, body } = snap.data();
    if (!userId) return null;
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        android: { notification: { icon: 'ic_launcher', color: '#0B3D91' } },
        apns: { payload: { aps: { badge: 1, sound: 'default' } } },
      });
    } catch (e) {
      // Push é melhor-esforço: a notificação já está salva no Firestore.
      console.warn('sendPushNotification', userId, e.code || e.message);
    }
    return null;
  });

/**
 * Avaliação: revalida no servidor (cliente participante, pedido
 * concluído, prestador do pedido, uma por contratação) e só então
 * recalcula nota/quantidade do prestador. Avaliações inválidas são
 * removidas e auditadas. Idempotente (marca processedAt).
 */
exports.onReviewCreated = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap, ctx) => {
    const review = snap.data() || {};
    const reviewId = ctx.params.reviewId;
    const orderSnap = review.orderId
      ? await db.collection('orders').doc(String(review.orderId)).get()
      : null;
    const verdict = sec.reviewValidity(reviewId, review, orderSnap && orderSnap.exists ? orderSnap.data() : null);
    if (!verdict.ok) {
      await snap.ref.delete();
      await db.collection('auditLogs').add({
        adminId: 'system',
        adminName: 'onReviewCreated',
        action: 'Avaliação inválida removida',
        target: reviewId,
        details: { reason: verdict.reason, clientId: review.clientId || null },
        timestamp: FieldValue.serverTimestamp(),
      });
      return null;
    }

    const firstRun = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(snap.ref);
      if (!fresh.exists || fresh.data().processedAt) return false;
      tx.update(snap.ref, { processedAt: FieldValue.serverTimestamp() });
      tx.update(orderSnap.ref, { reviewed: true });
      tx.set(db.collection('users').doc(review.clientId),
        { xp: FieldValue.increment(30) }, { merge: true });
      return true;
    });
    if (!firstRun) return null;

    await recomputeProviderRating(review.providerId);
    return null;
  });

async function recomputeProviderRating(providerId) {
  const reviews = await db.collection('reviews').where('providerId', '==', providerId).get();
  const { rating, totalReviews } = sec.averageRating(reviews.docs.map((d) => d.data().stars));
  await db.collection('providers').doc(providerId).set({ rating, totalReviews }, { merge: true });
  return { rating, totalReviews };
}

// ── Resolve Carajás: ver resolve.js (Fase 4: questionário, matching,
// propostas e aceite transacional). ──────────────────────────────────

// ── Migração segura (homologação primeiro) ────────────────────────

async function rotateDownloadToken(path) {
  try {
    await admin.storage().bucket().file(path).setMetadata({
      metadata: { firebaseStorageDownloadTokens: crypto.randomUUID() },
    });
    return true;
  } catch (e) {
    console.warn('rotateDownloadToken', path, e.message);
    return false;
  }
}

/**
 * Admin: move documentação privada de providers/* para
 * providers/{id}/private/verification, remove os campos do perfil
 * público, invalida as download URLs antigas e move endereços de
 * resolveRequests para resolveRequests/{id}/private/details.
 * Idempotente. Use { dryRun: true } para apenas contar.
 */
exports.migratePhase1Privacy = functions.region(REGION)
  .runWith({ timeoutSeconds: 540, memory: '512MB' })
  .https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
    const dryRun = data?.dryRun === true;
    const report = {
      dryRun, providersScanned: 0, providersMigrated: 0, filesProtected: 0,
      requestsScanned: 0, requestsMigrated: 0, proposalsBackfilled: 0,
    };

    const providers = await db.collection('providers').get();
    for (const doc of providers.docs) {
      report.providersScanned += 1;
      const plan = sec.planProviderMigration(doc.data());
      if (!plan) continue;
      report.providersMigrated += 1;
      if (dryRun) continue;
      const batch = db.batch();
      batch.set(doc.ref.collection('private').doc('verification'), {
        ...plan.privateData,
        migratedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      const del = {};
      for (const f of plan.removeFields) del[f] = FieldValue.delete();
      batch.update(doc.ref, del);
      await batch.commit();
      for (const path of plan.filesToProtect) {
        if (await rotateDownloadToken(path)) report.filesProtected += 1;
      }
    }

    const requests = await db.collection('resolveRequests').get();
    for (const doc of requests.docs) {
      report.requestsScanned += 1;
      const r = doc.data();
      if (!('address' in r)) continue;
      report.requestsMigrated += 1;
      if (dryRun) continue;
      const batch = db.batch();
      if (r.address) {
        batch.set(doc.ref.collection('private').doc('details'), {
          address: r.address,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      batch.update(doc.ref, { address: FieldValue.delete() });
      await batch.commit();
    }

    const proposals = await db.collection('resolveProposals').get();
    for (const doc of proposals.docs) {
      const p = doc.data();
      if (p.clientId || !p.requestId) continue;
      const req = requests.docs.find((d) => d.id === p.requestId);
      if (!req) continue;
      report.proposalsBackfilled += 1;
      if (!dryRun) await doc.ref.update({ clientId: req.data().clientId });
    }

    if (!dryRun) {
      await db.collection('migrations').doc('phase1_privacy').set({
        ...report,
        runBy: auth.uid,
        ranAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    return report;
  });

/**
 * Admin: URL temporária (15 min) para um arquivo privado de verificação.
 * Em emulador, usa download URL padrão.
 */
exports.getVerificationFileUrl = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
  const providerId = String(data?.providerId || '');
  const path = String(data?.path || '');
  if (!providerId || !path.startsWith(`providers/${providerId}/`)) {
    throw httpsError('invalid-argument', 'Caminho inválido');
  }
  const file = admin.storage().bucket().file(path);
  const [exists] = await file.exists();
  if (!exists) throw httpsError('not-found', 'Arquivo não encontrado');
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    const bucket = admin.storage().bucket().name;
    const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
    return { url: `http://${host}/v0/b/${bucket}/o/${encodeURIComponent(path)}?alt=media` };
  }
  const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 15 * 60 * 1000 });
  await db.collection('auditLogs').add({
    adminId: auth.uid, adminName: 'Admin', action: 'Visualizou documento de verificação',
    target: providerId, details: { path },
    timestamp: FieldValue.serverTimestamp(),
  });
  return { url };
});

exports.onUserCreateGrantXp = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap) => {
    const xp = Number(snap.data().xp || 0);
    if (xp > 0) return null;
    await snap.ref.update({ xp: 50 });
    return null;
  });

/**
 * Auditoria: aviso de nova mensagem pelo servidor (o app não precisa mais
 * de createNotification para o chat). Texto curto, só para o destinatário.
 */
exports.onChatMessageCreated = functions.firestore
  .document('chatRooms/{roomId}/messages/{msgId}')
  .onCreate(async (snap, ctx) => {
    const m = snap.data() || {};
    const room = await db.collection('chatRooms').doc(ctx.params.roomId).get();
    const parts = (room.exists && room.data().participants) || [];
    const to = parts.find((p) => p !== m.senderId);
    if (!to || !parts.includes(m.senderId)) return null;
    const pub = await db.collection('publicProfiles').doc(String(m.senderId)).get();
    const name = (pub.exists && pub.data().name) || 'Nova mensagem';
    const text = m.mediaUrl && !m.text ? '📎 Anexo' : String(m.text || '').slice(0, 80);
    await notifySafe(to, `💬 ${name}`, text || 'Você recebeu uma mensagem.', 'chat');
    return null;
  });

/**
 * Auditoria: suspensão era só `users.status` (nada lia o campo). Agora
 * desativa a conta no Auth e revoga as sessões; reativar desfaz.
 */
exports.setUserSuspended = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
  const userId = cleanId(data?.userId, 'userId');
  if (userId === auth.uid) throw httpsError('failed-precondition', 'Não é possível suspender a própria conta');
  const suspended = data?.suspended === true;
  const target = await db.collection('users').doc(userId).get();
  if (target.exists && target.data().type === 'admin') {
    throw httpsError('permission-denied', 'Conta de administrador não pode ser suspensa por aqui');
  }
  await admin.auth().updateUser(userId, { disabled: suspended });
  if (suspended) await admin.auth().revokeRefreshTokens(userId);
  await db.collection('users').doc(userId).set({
    status: suspended ? 'suspended' : 'active', updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  if (suspended) {
    await db.collection('providers').doc(userId).get().then((p) => p.exists && p.ref.update({ active: false }));
  }
  await db.collection('auditLogs').add({
    adminId: auth.uid, adminName: 'Admin', action: suspended ? 'Suspendeu usuário' : 'Reativou usuário',
    target: userId, details: {}, timestamp: FieldValue.serverTimestamp(),
  });
  return { ok: true, status: suspended ? 'suspended' : 'active' };
});

/**
 * Auditoria: aprovado como uma especialidade, o prestador podia trocar
 * nome ou incluir outras (inclusive de Saúde) mantendo o selo. Mudança
 * de identidade ou especialidade nova volta para análise do admin.
 */
exports.onProviderIdentityChange = functions.firestore
  .document('providers/{providerId}')
  .onUpdate(async (change) => {
    const b = change.before.data() || {};
    const a = change.after.data() || {};
    if (!(b.verified === true && a.verified === true)) return null;
    const before = new Set(b.categories || []);
    const added = (a.categories || []).filter((c) => !before.has(c));
    const renamed = String(a.name || '').trim() !== String(b.name || '').trim();
    if (!added.length && !renamed) return null;
    await change.after.ref.update({
      verified: false,
      verificationStatus: 'pending_review',
      reviewReason: renamed ? 'Nome alterado' : `Nova especialidade: ${added.join(', ')}`.slice(0, 200),
      updatedAt: FieldValue.serverTimestamp(),
    });
    await notifySafe(change.after.id, 'Perfil em nova análise',
      'Você alterou nome ou especialidades. O selo de verificado volta após a análise da equipe.', 'info');
    return null;
  });

/**
 * Auditoria: exclusão de conta. O app apaga o usuário no Auth (após login
 * recente) e o servidor remove os dados pessoais. Pedidos, pagamentos e
 * razão financeiro ficam (obrigação legal/fiscal), sem o perfil.
 */
exports.onAuthUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const del = async (q) => {
    const s = await q.limit(400).get();
    if (s.empty) return;
    const b = db.batch();
    s.docs.forEach((d) => b.delete(d.ref));
    await b.commit();
  };
  await Promise.all([
    db.collection('users').doc(uid).delete().catch(() => {}),
    db.collection('publicProfiles').doc(uid).delete().catch(() => {}),
    db.collection('carts').doc(uid).delete().catch(() => {}),
    del(db.collection('favorites').where('userId', '==', uid)),
    del(db.collection('notifications').where('userId', '==', uid)),
  ]);
  const prov = await db.collection('providers').doc(uid).get();
  if (prov.exists) {
    await prov.ref.update({ active: false, verified: false, acceptingRequests: false, deletedAt: FieldValue.serverTimestamp() });
  }
  return null;
});

exports.cleanupOldOrders = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const oldOrders = await db.collection('orders')
    .where('status', '==', 'pending')
    .where('createdAt', '<', cutoff)
    .get();
  let i = 0;
  let batch = db.batch();
  for (const doc of oldOrders.docs) {
    const ps = doc.data().paymentStatus || 'unpaid';
    if (ps !== 'unpaid') continue; // pago/pendente: tratado pelo suporte, nunca cancelado em silêncio
    batch.update(doc.ref, { status: 'cancelled', cancelReason: 'Expirado automaticamente' });
    i += 1;
    if (i >= 400) {
      await batch.commit();
      batch = db.batch();
      i = 0;
    }
  }
  if (i > 0) await batch.commit();
  return null;
});

function gone(_req, res) {
  res.status(410).json({ error: 'Endpoint público desativado. Use callable autenticado.' });
}
exports.generatePixHttp = functions.https.onRequest(gone);
exports.checkPaymentHttp = functions.https.onRequest(gone);
exports.processCardPaymentHttp = functions.https.onRequest(gone);
exports.aiAssistantHttp = functions.https.onRequest(gone);

// ── Catálogo (Fase 2): fonte única, migração, questionários e busca ──
Object.assign(exports, require('./catalog')({
  functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION,
}));

// ── Pedidos do Mercado, pagamentos e financeiro (Fase 3, sandbox) ──
const payments = require('./payments')({
  functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit,
});
const paymentsInternals = payments.__internals;
delete payments.__internals;
Object.assign(exports, payments);

// ── Resolve Carajás (Fase 4) ──
const resolve = require('./resolve')({
  functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit, notifySafe,
});
delete resolve.__internals;
Object.assign(exports, resolve);

// ── Saúde e Locação (Fase 5) ──
const schedule = require('./schedule')({
  functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit, notifySafe,
});
delete schedule.__internals;
Object.assign(exports, schedule);

// ── Perfil público mínimo (Fase 6: chat e identificação) ──
Object.assign(exports, require('./profiles')({
  functions, db, FieldValue, requireAuth, isAdmin, httpsError, REGION,
}));
