/**
 * Carajás 360 — Cloud Functions (staging-safe)
 *
 * Pagamentos reais (Mercado Pago) só rodam se:
 *   PAYMENTS_ENABLED=true  E  MERCADOPAGO_ACCESS_TOKEN no env/Secret Manager.
 * Por padrão o gateway real permanece DESLIGADO.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const axios = require('axios');
const crypto = require('crypto');
const policy = require('./orderPolicy');
const sec = require('./security');

admin.initializeApp();
const db = admin.firestore();

const REGION = 'us-central1';
const PAYMENTS_ENABLED = process.env.PAYMENTS_ENABLED === 'true';
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

async function notify(userId, title, body, type) {
  if (!userId) return;
  await db.collection('notifications').add({
    userId,
    title: String(title).slice(0, 120),
    body: String(body).slice(0, 500),
    type: type || 'info',
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

  const ids = [callerUid, targetUid].sort();
  const room = await db.collection('chatRooms').doc(ids.join('_')).get();
  return room.exists;
}

/** Notificação nunca derruba a operação principal já persistida. */
async function notifySafe(userId, title, body, type) {
  try {
    await notify(userId, title, body, type);
  } catch (e) {
    console.error('notifySafe', userId, e);
  }
}

async function adjustWalletTx(tx, uid, type, amount, description, icon, extra) {
  if (!uid || !(amount > 0)) {
    throw httpsError('invalid-argument', 'Parâmetros de carteira inválidos');
  }
  const walletRef = db.collection('wallets').doc(uid);
  const snap = await tx.get(walletRef);
  const bal = snap.exists ? Number(snap.data().balance || 0) : 0;
  if (type === 'debit' || type === 'withdraw') {
    if (bal < amount) throw httpsError('failed-precondition', 'Saldo insuficiente');
    tx.set(walletRef, { userId: uid, balance: policy.round2(bal - amount) }, { merge: true });
  } else {
    tx.set(walletRef, { userId: uid, balance: policy.round2(bal + amount) }, { merge: true });
  }
  tx.set(db.collection('transactions').doc(), {
    userId: uid,
    type,
    amount,
    description: description || '',
    icon: icon || '💰',
    status: type === 'withdraw' ? 'pending' : 'done',
    createdAt: FieldValue.serverTimestamp(),
    ...(extra || {}),
  });
}

function requirePaymentsGateway() {
  if (!PAYMENTS_ENABLED) {
    throw httpsError(
      'failed-precondition',
      'Pagamentos reais desligados neste ambiente (staging).',
    );
  }
  const token = getMpToken();
  if (!token) {
    throw httpsError('failed-precondition', 'Gateway de pagamento não configurado');
  }
  return token;
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

exports.transitionOrder = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data?.orderId || '');
  const action = String(data?.action || '');
  if (!orderId || !policy.targetStatus(action)) {
    throw httpsError('invalid-argument', 'orderId e action obrigatórios');
  }

  const result = await db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    const from = order.status || 'pending';
    const to = policy.targetStatus(action);
    const paymentStatus = order.paymentStatus || 'unpaid';

    if (!policy.actorMayPerform(action, auth.uid, order.clientId, order.providerId || null)) {
      throw httpsError('permission-denied', 'Sem permissão para esta ação');
    }
    if (!policy.isAllowedTransition(from, to)) {
      throw httpsError('failed-precondition', 'Transição de status inválida');
    }

    const updates = {
      status: to,
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (action === 'accept') {
      updates.providerId = order.providerId || auth.uid;
      updates.acceptedAt = FieldValue.serverTimestamp();
      const quoted = Number(data?.price);
      if (!(Number(order.price) > 0) && quoted > 0) {
        updates.price = policy.round2(quoted);
      }
    }
    if (action === 'start') {
      updates.startedAt = FieldValue.serverTimestamp();
    }
    if (action === 'cancel' || action === 'decline') {
      updates.cancelReason = action === 'decline'
        ? 'Recusado pelo profissional'
        : (data?.reason || 'Cancelado');
    }
    if (action === 'complete') {
      const block = policy.completeBlockReason(from, paymentStatus);
      if (block) {
        throw httpsError(
          'failed-precondition',
          block === 'payment_not_confirmed'
            ? 'Não é possível concluir sem pagamento confirmado'
            : 'Transição de status inválida',
        );
      }
      updates.completedAt = FieldValue.serverTimestamp();

      if (!order.payoutProcessed) {
        const paymentId = order.transactionId;
        if (!paymentId) {
          throw httpsError('failed-precondition', 'Pagamento não confirmado');
        }
        const paySnap = await tx.get(db.collection('payments').doc(String(paymentId)));
        if (!paySnap.exists) {
          throw httpsError('failed-precondition', 'Pagamento não confirmado');
        }
        const pay = paySnap.data();
        const decision = policy.canPayout({
          status: 'completed',
          paymentStatus,
          payoutProcessed: false,
          providerId: order.providerId,
          price: order.price,
          orderId,
          paymentOrderId: pay.orderId,
          gatewayStatus: pay.status,
          paidAmount: pay.amount,
        });
        if (!decision.ok) {
          throw httpsError('failed-precondition', 'Repasse recusado: ' + decision.reason);
        }
        updates.payoutProcessed = true;
        updates.payoutStatus = 'done';
        updates.payoutAt = FieldValue.serverTimestamp();
        updates.commission = decision.commission;
        updates.platformFee = decision.commission;
        updates.providerAmount = decision.providerAmount;

        await adjustWalletTx(
          tx, order.providerId, 'credit', decision.providerAmount,
          'Pagamento por serviço concluído', '💰', { orderId },
        );
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
      }
    }

    tx.update(orderRef, updates);
    return {
      ok: true,
      status: to,
      payoutProcessed: updates.payoutProcessed || order.payoutProcessed || false,
    };
  });

  try {
    const after = await db.collection('orders').doc(orderId).get();
    const o = after.data() || {};
    if (action === 'accept' && o.clientId) {
      await notify(o.clientId, '✅ Pedido aceito!', 'Um profissional aceitou seu pedido.', 'order');
    }
    if (action === 'start' && o.clientId) {
      await notify(o.clientId, '🔧 Profissional a caminho!', 'Seu serviço está em andamento.', 'order');
    }
    if ((action === 'cancel' || action === 'decline') && o.clientId && o.clientId !== auth.uid) {
      await notify(o.clientId, '❌ Pedido cancelado', o.cancelReason || 'Pedido cancelado', 'order');
    }
    if (action === 'cancel' && o.providerId && o.providerId !== auth.uid) {
      await notify(o.providerId, '❌ Pedido cancelado', 'O cliente cancelou a solicitação.', 'order');
    }
  } catch (e) {
    console.error('notify after transition', e);
  }
  return result;
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
    });
    if (!decision.ok) {
      throw httpsError('failed-precondition', 'Repasse recusado: ' + decision.reason);
    }
    tx.update(orderRef, {
      payoutProcessed: true,
      payoutStatus: 'done',
      payoutAt: FieldValue.serverTimestamp(),
      commission: decision.commission,
      platformFee: decision.commission,
      providerAmount: decision.providerAmount,
    });
    await adjustWalletTx(
      tx, order.providerId, 'credit', decision.providerAmount,
      'Pagamento por serviço concluído', '💰', { orderId },
    );
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

exports.payOrderWithWallet = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data?.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');

  return db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Só o cliente pode pagar');
    if ((order.paymentStatus || 'unpaid') === 'paid') {
      return { ok: true, already: true, paymentStatus: 'paid' };
    }
    const amount = Number(order.price);
    if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');
    const paymentId = `wallet_${orderId}`;
    await adjustWalletTx(tx, auth.uid, 'debit', amount, `Pagamento pedido ${orderId}`, '👜', { orderId });
    tx.set(db.collection('payments').doc(paymentId), {
      orderId,
      userId: auth.uid,
      purpose: 'order',
      amount,
      method: 'wallet',
      status: 'approved',
      walletCredited: false,
      externalId: paymentId,
      createdAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      paymentStatus: 'paid',
      transactionId: paymentId,
      paidAt: FieldValue.serverTimestamp(),
    });
    return { ok: true, already: false, paymentStatus: 'paid', id: paymentId };
  });
});

exports.generatePix = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'pix', 8, 60 * 60 * 1000);
  const token = requirePaymentsGateway();

  const purpose = String(data?.purpose || 'order');
  if (!['order', 'wallet_recharge'].includes(purpose)) {
    throw httpsError('invalid-argument', 'purpose inválido');
  }

  let amount;
  let orderId = data?.orderId ? String(data.orderId) : null;
  let description = String(data?.description || 'Pagamento Carajás 360').slice(0, 200);
  const email = String(data?.email || '').trim();

  if (purpose === 'order') {
    if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
    const orderSnap = await db.collection('orders').doc(orderId).get();
    if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = orderSnap.data();
    if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Pedido de outro usuário');
    amount = Number(order.price);
    if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');
    description = description || order.title || 'Pedido Carajás 360';
  } else {
    amount = Number(data?.amount);
    if (!(amount >= 10) || amount > 5000) {
      throw httpsError('invalid-argument', 'Valor de recarga inválido (R$ 10 a R$ 5.000)');
    }
    orderId = null;
  }

  const platformFee = policy.round2(amount * policy.COMMISSION_RATE);
  const netAmount = policy.round2(amount - platformFee);
  const idempotency = `${auth.uid}:${purpose}:${orderId || 'wallet'}:${Math.floor(Date.now() / 60000)}`;

  const response = await axios.post('https://api.mercadopago.com/v1/payments', {
    transaction_amount: amount,
    description,
    payment_method_id: 'pix',
    payer: { email: email || `${auth.uid}@users.carajas360.invalid` },
  }, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Idempotency-Key': idempotency,
    },
  });

  const { id, status, point_of_interaction } = response.data;
  await db.collection('payments').doc(String(id)).set({
    orderId,
    userId: auth.uid,
    purpose,
    amount,
    platformFee,
    netAmount,
    method: 'pix',
    status: status === 'pending' ? 'pending' : (status || 'processing'),
    walletCredited: false,
    externalId: String(id),
    createdAt: FieldValue.serverTimestamp(),
  });
  if (orderId) {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'pending',
      transactionId: String(id),
    });
  }

  const qr = point_of_interaction?.transaction_data || {};
  return {
    id: String(id),
    status,
    qr_code: qr.qr_code || null,
    qr_code_base64: qr.qr_code_base64 || null,
  };
});

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

  if (localData.method === 'wallet' || !PAYMENTS_ENABLED || !getMpToken()) {
    return publicPaymentView(localData, id);
  }

  const response = await axios.get(`https://api.mercadopago.com/v1/payments/${id}`, {
    headers: { Authorization: `Bearer ${getMpToken()}` },
  });
  const status = response.data.status;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(payRef);
    if (!snap.exists) return;
    const p = snap.data();
    if (status === 'approved' && p.status !== 'approved') {
      tx.update(payRef, {
        status: 'approved',
        paidAt: FieldValue.serverTimestamp(),
      });
      if (p.orderId) {
        tx.update(db.collection('orders').doc(p.orderId), {
          paymentStatus: 'paid',
          transactionId: String(id),
          paidAt: FieldValue.serverTimestamp(),
        });
      }
      if (p.purpose === 'wallet_recharge' && p.userId && !p.walletCredited) {
        await adjustWalletTx(tx, p.userId, 'credit', Number(p.amount), 'Recarga via PIX', '⚡', { paymentId: id });
        tx.update(payRef, { walletCredited: true });
      }
    } else if (status && status !== p.status) {
      tx.update(payRef, { status });
    }
  });

  const after = (await payRef.get()).data();
  return publicPaymentView(after, id);
});

exports.processCardPayment = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'card', 8, 60 * 60 * 1000);
  const token = requirePaymentsGateway();
  const cardToken = String(data?.cardToken || '');
  if (!cardToken) throw httpsError('invalid-argument', 'Token do cartão ausente');

  const orderId = String(data?.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
  const orderSnap = await db.collection('orders').doc(orderId).get();
  if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
  const order = orderSnap.data();
  if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Pedido de outro usuário');
  const amount = Number(order.price);
  if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');

  const platformFee = policy.round2(amount * policy.COMMISSION_RATE);
  const netAmount = policy.round2(amount - platformFee);
  const email = String(data?.email || '').trim();
  const installments = Number(data?.installments || 1);
  const payerDocNumber = data?.payerDocNumber ? String(data.payerDocNumber).replace(/\D/g, '') : undefined;

  const response = await axios.post('https://api.mercadopago.com/v1/payments', {
    transaction_amount: amount,
    description: String(data?.description || order.title || 'Pagamento Carajás 360').slice(0, 200),
    token: cardToken,
    installments: installments >= 1 && installments <= 12 ? installments : 1,
    payer: {
      email: email || `${auth.uid}@users.carajas360.invalid`,
      identification: payerDocNumber ? { type: 'CPF', number: payerDocNumber } : undefined,
    },
  }, {
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Idempotency-Key': `${auth.uid}:${orderId}:card`,
    },
  });

  const { id, status, status_detail } = response.data;
  await db.collection('payments').doc(String(id)).set({
    orderId,
    userId: auth.uid,
    purpose: 'order',
    amount,
    platformFee,
    netAmount,
    method: 'card',
    status,
    statusDetail: status_detail,
    installments,
    walletCredited: false,
    externalId: String(id),
    createdAt: FieldValue.serverTimestamp(),
    ...(status === 'approved' ? { paidAt: FieldValue.serverTimestamp() } : {}),
  });
  if (status === 'approved') {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'paid',
      transactionId: String(id),
      paidAt: FieldValue.serverTimestamp(),
    });
  } else {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'pending',
      transactionId: String(id),
    });
  }
  return { id: String(id), status, statusDetail: status_detail };
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
  const history = Array.isArray(data?.history) ? data.history.slice(-8) : [];

  const systemPrompt = 'Você é o assistente virtual do Carajás 360, plataforma regional de serviços. '
    + 'Responda sempre em português do Brasil, de forma breve (máx. 3 parágrafos curtos). '
    + 'Não invente confirmações de pagamento nem dados pessoais.';

  const messages = [
    ...history.map((h) => ({
      role: h && h.isAi ? 'assistant' : 'user',
      content: String(h?.text || '').slice(0, 1000),
    })),
    { role: 'user', content: message },
  ];

  const response = await axios.post('https://api.anthropic.com/v1/messages', {
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
  });
  const reply = response.data.content?.[0]?.text || 'Não consegui processar sua pergunta agora.';
  return { reply };
});

exports.walletOp = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const op = String(data?.op || '');
  const value = Number(data?.amount);
  if (!['debit', 'withdraw', 'cashback'].includes(op)) {
    throw httpsError('invalid-argument', 'Operação não permitida');
  }
  if (op !== 'cashback' && !(value > 0)) {
    throw httpsError('invalid-argument', 'Valor inválido');
  }

  if (op === 'cashback') {
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
      const cashback = policy.round2(Number(order.price || 0) * 0.02);
      if (cashback > 0) {
        await adjustWalletTx(
          tx, order.clientId, 'credit', cashback,
          `Cashback: ${order.title || 'Serviço'}`, '🎁', { orderId },
        );
      }
      tx.update(orderRef, { cashbackGranted: true });
      return { ok: true, cashback };
    });
  }

  if (op === 'withdraw' && value < 10) {
    throw httpsError('invalid-argument', 'Saque mínimo R$ 10');
  }
  await db.runTransaction(async (tx) => {
    await adjustWalletTx(
      tx,
      auth.uid,
      op,
      value,
      data?.description || (op === 'withdraw' ? `Saque para ${data?.pixKey || ''}` : ''),
      data?.icon || (op === 'withdraw' ? '📤' : '👜'),
      op === 'withdraw' ? { pixKey: data?.pixKey || null } : {},
    );
  });
  return { ok: true };
});

exports.createNotification = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'notif', 40, 60 * 60 * 1000);
  const userId = String(data?.userId || '');
  const title = String(data?.title || '');
  const body = String(data?.body || '');
  if (!userId || !title || !body) {
    throw httpsError('invalid-argument', 'Campos obrigatórios ausentes');
  }
  if (!(await canNotifyTarget(auth.uid, userId))) {
    throw httpsError('permission-denied', 'Não é permitido notificar este usuário');
  }
  await notify(userId, title, body, data?.type || 'info');
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

// ── Resolve Carajás: matching e propostas (servidor) ──────────────

async function loadProvider(uid) {
  const snap = await db.collection('providers').doc(uid).get();
  return snap.exists ? { id: snap.id, ...snap.data() } : null;
}

/**
 * Oportunidades para o prestador logado: só se aprovado e ativo, só
 * dos serviços que ele atende e da região dele. Sem endereço/contato.
 */
exports.listResolveOpportunities = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'resolve_list', 120, 60 * 60 * 1000);
  const provider = await loadProvider(auth.uid);
  if (!provider) return { eligible: false, reason: 'not_provider', items: [] };
  if (provider.verified !== true) return { eligible: false, reason: 'not_verified', items: [] };
  if (provider.active !== true) return { eligible: false, reason: 'inactive', items: [] };
  const cats = (Array.isArray(provider.categories) ? provider.categories : []).filter(Boolean);
  if (cats.length === 0) return { eligible: false, reason: 'no_services', items: [] };

  const results = [];
  for (const part of sec.chunk(cats, sec.IN_QUERY_LIMIT)) {
    const snap = await db.collection('resolveRequests')
      .where('status', '==', 'open')
      .where('category', 'in', part)
      .orderBy('createdAt', 'desc')
      .limit(40)
      .get();
    for (const d of snap.docs) {
      const r = d.data();
      if (sec.providerEligibility(provider, r, auth.uid).ok) {
        results.push(sec.opportunityView(d.id, r));
      }
    }
  }
  results.sort((a, b) => (b.createdAtMs || 0) - (a.createdAtMs || 0));
  const items = results.slice(0, 40);

  // Marca as que o prestador já respondeu (id determinístico).
  if (items.length) {
    const refs = items.map((i) => db.collection('resolveProposals').doc(`${i.id}_${auth.uid}`));
    const got = await db.getAll(...refs);
    got.forEach((s, idx) => { items[idx].alreadyProposed = s.exists; });
  }
  return { eligible: true, reason: null, items };
});

/**
 * Envio de proposta: transação valida solicitação aberta, prestador
 * aprovado/ativo/compatível e impede proposta duplicada. Dados do
 * prestador (nome, foto, nota) vêm do servidor, não do cliente.
 */
exports.submitResolveProposal = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'resolve_propose', 60, 60 * 60 * 1000);
  const requestId = String(data?.requestId || '');
  if (!requestId) throw httpsError('invalid-argument', 'requestId obrigatório');
  const input = sec.validateProposalInput(data || {});
  if (!input.ok) throw httpsError('invalid-argument', 'Proposta inválida: ' + input.reason);

  const proposalId = `${requestId}_${auth.uid}`;
  const result = await db.runTransaction(async (tx) => {
    const reqRef = db.collection('resolveRequests').doc(requestId);
    const provRef = db.collection('providers').doc(auth.uid);
    const propRef = db.collection('resolveProposals').doc(proposalId);
    const [reqSnap, provSnap, propSnap] = await Promise.all([
      tx.get(reqRef), tx.get(provRef), tx.get(propRef),
    ]);
    if (!reqSnap.exists) throw httpsError('not-found', 'Solicitação não encontrada');
    const req = reqSnap.data();
    if (req.status !== 'open') throw httpsError('failed-precondition', 'Solicitação não está mais aberta');
    const provider = provSnap.exists ? { id: provSnap.id, ...provSnap.data() } : null;
    const elig = sec.providerEligibility(provider, req, auth.uid);
    if (!elig.ok) throw httpsError('permission-denied', 'Prestador não elegível: ' + elig.reason);
    if (propSnap.exists) throw httpsError('already-exists', 'Você já enviou proposta para esta solicitação');

    tx.set(propRef, {
      requestId,
      clientId: req.clientId,
      providerId: auth.uid,
      providerName: provider.name || 'Profissional',
      providerPhoto: provider.photoUrl || null,
      rating: Number(provider.rating || 0),
      totalServices: Number(provider.totalReviews || 0),
      category: req.category,
      price: input.value.price,
      deadlineDays: input.value.deadlineDays,
      message: input.value.message,
      available: true,
      accepted: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(reqRef, { proposalCount: FieldValue.increment(1) });
    return { clientId: req.clientId, providerName: provider.name || 'Profissional' };
  });

  await notifySafe(result.clientId, '💬 Nova proposta Resolve',
    `${result.providerName} enviou uma proposta para seu pedido.`, 'resolve');
  return { ok: true, id: proposalId };
});

/**
 * Notificação por evento: ao salvar uma solicitação, avisa prestadores
 * aprovados, ativos, do serviço e da região. Falha de push não afeta
 * a solicitação (já persistida).
 */
exports.onResolveRequestCreated = functions.firestore
  .document('resolveRequests/{id}')
  .onCreate(async (snap) => {
    const r = snap.data() || {};
    if (!r.category || r.status !== 'open') return null;
    const providers = await db.collection('providers')
      .where('verified', '==', true)
      .where('active', '==', true)
      .where('categories', 'array-contains', r.category)
      .limit(100)
      .get();
    const text = String(r.description || '');
    const body = text.length > 80 ? `${text.slice(0, 80)}…` : text;
    let sent = 0;
    for (const p of providers.docs) {
      const prov = { id: p.id, ...p.data() };
      const uid = prov.userId || p.id;
      if (!sec.providerEligibility(prov, r, uid).ok) continue;
      await notifySafe(uid, '⚡ Nova oportunidade Resolve', body, 'resolve');
      sent += 1;
      if (sent >= 50) break;
    }
    return null;
  });

/** Ao aceitar uma proposta (status -> matched), avisa o prestador escolhido. */
exports.onResolveRequestMatched = functions.firestore
  .document('resolveRequests/{id}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === 'matched' || after.status !== 'matched' || !after.matchedProviderId) {
      return null;
    }
    await notifySafe(after.matchedProviderId, '✅ Proposta aceita!',
      'Sua proposta Resolve foi aceita. Fale com o cliente no chat.', 'resolve');
    return null;
  });

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

exports.cleanupOldOrders = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const oldOrders = await db.collection('orders')
    .where('status', '==', 'pending')
    .where('createdAt', '<', cutoff)
    .get();
  let i = 0;
  let batch = db.batch();
  for (const doc of oldOrders.docs) {
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
