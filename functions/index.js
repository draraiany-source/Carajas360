/**
 * Carajás 360 — Cloud Functions (staging-safe)
 *
 * Runtime: Node.js 20 (1ª geração; nodejs22 não é suportado em GCF Gen1).
 * Secrets via process.env / Secret Manager — NÃO usamos functions.config().
 *
 * Pagamentos reais (Mercado Pago) só rodam se:
 *   PAYMENTS_ENABLED=true  E  MERCADOPAGO_ACCESS_TOKEN no env/Secret Manager.
 * Por padrão o gateway real permanece DESLIGADO.
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const policy = require('./orderPolicy');
const security = require('./security');
const deletion = require('./accountDeletion');
const planChange = require('./planChange');
const audit = require('./auditLog');
const { directionsDecision } = require('./directionsProxy');

admin.initializeApp();
const db = admin.firestore();

const REGION = 'us-central1';
const PAYMENTS_ENABLED = process.env.PAYMENTS_ENABLED === 'true';
const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';
const ALLOWED_PROFILE_TYPES = security.ALLOWED_PROFILE_TYPES;

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
  const result = security.assertCallableAuth(context, {
    enforceAppCheck: ENFORCE_APP_CHECK,
  });
  if (!result.ok) {
    throw httpsError(result.code, result.message);
  }
  return context.auth;
}

async function isAdmin(auth) {
  if (security.tokenIsAdmin(auth.token || {})) return true;
  const snap = await db.collection('users').doc(auth.uid).get();
  return security.userDocIsAdmin(snap.exists ? snap.data() : null);
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function grantXp(uid, reason, key) {
  const amount = security.xpAmountFor(reason);
  if (!uid || !(amount > 0)) return { ok: false, skipped: true };
  const eventId = security.xpEventId(reason, key);
  return db.runTransaction(async (tx) => {
    const evRef = db.collection('xpEvents').doc(eventId);
    const ev = await tx.get(evRef);
    if (ev.exists) return { ok: true, already: true, amount: 0 };
    const userRef = db.collection('users').doc(uid);
    const user = await tx.get(userRef);
    if (!user.exists) return { ok: false, skipped: true };
    const data = user.data() || {};
    if (data.status === 'deleted' || data.anonymized === true) {
      return { ok: false, skipped: true };
    }
    tx.set(evRef, {
      uid,
      reason,
      amount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(userRef, { xp: admin.firestore.FieldValue.increment(amount) });
    return { ok: true, already: false, amount };
  });
}

async function deleteByQuery(query) {
  let snap = await query.limit(400).get();
  while (!snap.empty) {
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    snap = await query.limit(400).get();
  }
}

async function adjustWalletTx(tx, uid, type, amount, description, icon, extra, docId) {
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
  const txRef = docId
    ? db.collection('transactions').doc(String(docId))
    : db.collection('transactions').doc();
  tx.set(txRef, {
    userId: uid,
    type,
    amount,
    description: description || '',
    icon: icon || '💰',
    status: type === 'withdraw' ? 'pending' : 'done',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(extra || {}),
  });
  return txRef.id;
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

function wrapGateway(err) {
  audit.structuredLog('error', 'gateway_error', {
    status: err && err.response && err.response.status,
    message: err && err.message,
  });
  throw httpsError('unavailable', security.safeGatewayMessage());
}

async function applyOfficialPayout(tx, {
  order,
  orderId,
  payment,
  paymentId,
  actorUid,
}) {
  if (order.payoutProcessed) {
    return { ok: true, already: true, payoutProcessed: true, orderUpdates: {} };
  }
  const decision = policy.canPayout({
    status: 'completed',
    paymentStatus: order.paymentStatus || 'unpaid',
    payoutProcessed: false,
    providerId: order.providerId,
    officialProviderId: order.providerId,
    price: order.price,
    orderId,
    paymentOrderId: payment && payment.orderId,
    gatewayStatus: payment && payment.status,
    paidAmount: payment && payment.amount,
  });
  if (!decision.ok) {
    throw httpsError('failed-precondition', 'Repasse recusado: ' + decision.reason);
  }
  const payoutTransactionId = `payout_${orderId}`;
  const payoutDoc = await tx.get(db.collection('transactions').doc(payoutTransactionId));
  const orderUpdates = {
    payoutProcessed: true,
    payoutStatus: 'done',
    payoutProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
    payoutAt: admin.firestore.FieldValue.serverTimestamp(),
    payoutTransactionId,
    commission: decision.commission,
    platformFee: decision.commission,
    providerAmount: decision.providerAmount,
  };
  if (payoutDoc.exists) {
    return { ok: true, already: true, payoutProcessed: true, orderUpdates };
  }

  await adjustWalletTx(
    tx, order.providerId, 'credit', decision.providerAmount,
    'Pagamento por serviço concluído', '💰', { orderId, payoutTransactionId },
    payoutTransactionId,
  );
  tx.set(db.collection('financialAudits').doc(), {
    ...policy.buildFinancialAudit({
      orderId,
      userId: actorUid,
      providerId: order.providerId,
      clientId: order.clientId,
      decision,
      gatewayTransactionId: paymentId,
      payoutTransactionId,
      status: 'payout_done',
    }),
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    payoutProcessed: true,
  });
  return {
    ok: true,
    already: false,
    payoutProcessed: true,
    providerAmount: decision.providerAmount,
    payoutTransactionId,
    orderUpdates,
  };
}

async function loadConfirmedPayment(tx, order, orderId) {
  const paymentId = order.transactionId || order.gatewayTransactionId;
  if (!paymentId) {
    throw httpsError('failed-precondition', 'Pagamento não confirmado');
  }
  const paySnap = await tx.get(db.collection('payments').doc(String(paymentId)));
  if (!paySnap.exists) {
    throw httpsError('failed-precondition', 'Pagamento não confirmado');
  }
  return { paymentId: String(paymentId), payment: paySnap.data() };
}

exports.transitionOrder = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data && data.orderId || '');
  const action = String(data && data.action || '');
  if (!orderId || !policy.targetStatus(action)) {
    throw httpsError('invalid-argument', 'orderId e action obrigatórios');
  }
  const adminUser = await isAdmin(auth);

  const result = await db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    const from = policy.normalizeStatus(order.status || 'pending');
    const to = policy.targetStatus(action);
    const paymentStatus = order.paymentStatus || 'unpaid';

    if (!policy.actorMayPerform(
      action, auth.uid, order.clientId, order.providerId || null, adminUser,
    )) {
      throw httpsError('permission-denied', 'Sem permissão para esta ação');
    }
    if (!policy.isAllowedTransition(from, to)) {
      throw httpsError('failed-precondition', 'Transição de status inválida');
    }

    const updates = {
      status: to,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (action === 'accept') {
      updates.providerId = order.providerId || auth.uid;
      updates.acceptedAt = admin.firestore.FieldValue.serverTimestamp();
      const quoted = Number(data && data.price);
      if (quoted > 0) {
        updates.price = policy.round2(quoted);
      }
    }
    if (action === 'start') {
      updates.startedAt = admin.firestore.FieldValue.serverTimestamp();
    }
    if (action === 'cancel' || action === 'decline') {
      updates.cancelReason = action === 'decline'
        ? 'Recusado pelo profissional'
        : ((data && data.reason) || 'Cancelado');
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
      updates.completedAt = admin.firestore.FieldValue.serverTimestamp();
    }

    let payoutProcessed = order.payoutProcessed || false;
    if (action === 'complete' && !order.payoutProcessed) {
      const { paymentId, payment } = await loadConfirmedPayment(tx, order, orderId);
      const payout = await applyOfficialPayout(tx, {
        order: { ...order, ...updates, payoutProcessed: false },
        orderId,
        payment,
        paymentId,
        actorUid: auth.uid,
      });
      payoutProcessed = payout.payoutProcessed || false;
      Object.assign(updates, payout.orderUpdates || {});
    }
    tx.update(orderRef, updates);

    return {
      ok: true,
      status: to,
      payoutProcessed,
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
    audit.structuredLog('error', 'notify_after_transition', { message: e && e.message });
  }
  if (action === 'cancel' || action === 'decline') {
    await audit.writeAudit(db, {
      actorId: auth.uid,
      actorType: adminUser ? 'admin' : 'user',
      action: action === 'cancel' ? audit.ACTIONS.ORDER_CANCELLED : audit.ACTIONS.ORDER_DECLINED,
      target: orderId,
      details: { action },
    });
  }
  if (action === 'complete' && result.payoutProcessed) {
    await audit.writeAudit(db, {
      actorId: auth.uid,
      actorType: adminUser ? 'admin' : 'user',
      action: audit.ACTIONS.PAYOUT,
      target: orderId,
      details: { via: 'complete' },
    });
  }
  return result;
});

exports.processPayout = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data && data.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');

  const adminUser = await isAdmin(auth);
  const payout = await db.runTransaction(async (tx) => {
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
    const { paymentId, payment } = await loadConfirmedPayment(tx, order, orderId);
    const result = await applyOfficialPayout(tx, {
      order,
      orderId,
      payment,
      paymentId,
      actorUid: auth.uid,
    });
    if (result.orderUpdates && Object.keys(result.orderUpdates).length) {
      tx.update(orderRef, result.orderUpdates);
    }
    return result;
  });
  await audit.writeAudit(db, {
    actorId: auth.uid,
    actorType: adminUser ? 'admin' : 'user',
    action: audit.ACTIONS.PAYOUT,
    target: orderId,
    details: { already: Boolean(payout.already) },
  });
  return payout;
});

exports.payOrderWithWallet = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const orderId = String(data && data.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');

  const paid = await db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Só o cliente pode pagar');
    const double = policy.rejectDoubleCharge(order);
    if (!double.ok) {
      return { ok: true, already: true, paymentStatus: 'paid' };
    }
    const amount = Number(order.price);
    if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');
    const paymentId = `wallet_${orderId}`;
    const existingPay = await tx.get(db.collection('payments').doc(paymentId));
    if (existingPay.exists && existingPay.data().status === 'approved') {
      tx.update(orderRef, {
        paymentStatus: 'paid',
        transactionId: paymentId,
        gatewayTransactionId: paymentId,
      });
      return { ok: true, already: true, paymentStatus: 'paid', id: paymentId };
    }
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
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(orderRef, {
      paymentStatus: 'paid',
      transactionId: paymentId,
      gatewayTransactionId: paymentId,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { ok: true, already: false, paymentStatus: 'paid', id: paymentId };
  });
  await audit.writeAudit(db, {
    actorId: auth.uid,
    actorType: 'user',
    action: audit.ACTIONS.PAYMENT,
    target: orderId,
    details: { method: 'wallet', already: Boolean(paid.already) },
  });
  return paid;
});

exports.generatePix = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'pix', 8, 60 * 60 * 1000);
  const token = requirePaymentsGateway();

  const purpose = String(data && data.purpose || 'order');
  if (!['order', 'wallet_recharge'].includes(purpose)) {
    throw httpsError('invalid-argument', 'purpose inválido');
  }

  let amount;
  let orderId = data && data.orderId ? String(data.orderId) : null;
  let description = String(data && data.description || 'Pagamento Carajás 360').slice(0, 200);
  const email = String(data && data.email || '').trim();

  if (purpose === 'order') {
    if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
    const orderSnap = await db.collection('orders').doc(orderId).get();
    if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = orderSnap.data();
    if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Pedido de outro usuário');
    const double = policy.rejectDoubleCharge(order);
    if (!double.ok) throw httpsError('already-exists', 'Pedido já pago');
    amount = Number(order.price);
    if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');
    description = description || order.title || 'Pedido Carajás 360';
  } else {
    amount = Number(data && data.amount);
    if (!(amount >= 10) || amount > 5000) {
      throw httpsError('invalid-argument', 'Valor de recarga inválido (R$ 10 a R$ 5.000)');
    }
    orderId = null;
  }

  const platformFee = policy.round2(amount * policy.COMMISSION_RATE);
  const netAmount = policy.round2(amount - platformFee);
  const idempotency = `${auth.uid}:${purpose}:${orderId || 'wallet'}:${Math.floor(Date.now() / 60000)}`;

  let response;
  try {
    response = await axios.post('https://api.mercadopago.com/v1/payments', {
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
  } catch (err) {
    wrapGateway(err);
  }

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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  if (orderId) {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'pending',
      transactionId: String(id),
      gatewayTransactionId: String(id),
    });
  }
  await audit.writeAudit(db, {
    actorId: auth.uid,
    actorType: 'user',
    action: audit.ACTIONS.PAYMENT,
    target: orderId || String(id),
    details: { method: 'pix', purpose, amount, paymentId: String(id) },
  });

  const qr = point_of_interaction && point_of_interaction.transaction_data || {};
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
  const id = String(data && data.id || '');
  if (!id) throw httpsError('invalid-argument', 'id obrigatório');

  const payRef = db.collection('payments').doc(id);
  const local = await payRef.get();
  if (!local.exists) throw httpsError('not-found', 'Pagamento não encontrado');
  const localData = local.data();
  if (!security.paymentReadableBy(auth.uid, localData, await isAdmin(auth))) {
    throw httpsError('permission-denied', 'Pagamento de outro usuário');
  }

  if (localData.method === 'wallet' || !PAYMENTS_ENABLED || !getMpToken()) {
    return security.publicPaymentView(localData, id);
  }

  let response;
  try {
    response = await axios.get(`https://api.mercadopago.com/v1/payments/${id}`, {
      headers: { Authorization: `Bearer ${getMpToken()}` },
    });
  } catch (err) {
    wrapGateway(err);
  }
  const status = response.data.status;

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(payRef);
    if (!snap.exists) return;
    const p = snap.data();
    if (status === 'approved' && p.status !== 'approved') {
      tx.update(payRef, {
        status: 'approved',
        paidAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      if (p.orderId) {
        tx.update(db.collection('orders').doc(p.orderId), {
          paymentStatus: 'paid',
          transactionId: String(id),
          gatewayTransactionId: String(id),
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
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
  return security.publicPaymentView(after, id);
});

exports.processCardPayment = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  await enforceRateLimit(auth.uid, 'card', 8, 60 * 60 * 1000);
  const token = requirePaymentsGateway();
  const cardToken = String(data && data.cardToken || '');
  if (!cardToken) throw httpsError('invalid-argument', 'Token do cartão ausente');

  const orderId = String(data && data.orderId || '');
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
  const orderSnap = await db.collection('orders').doc(orderId).get();
  if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
  const order = orderSnap.data();
  if (order.clientId !== auth.uid) throw httpsError('permission-denied', 'Pedido de outro usuário');
  const double = policy.rejectDoubleCharge(order);
  if (!double.ok) throw httpsError('already-exists', 'Pedido já pago');
  const amount = Number(order.price);
  if (!(amount > 0)) throw httpsError('failed-precondition', 'Pedido sem preço definido');

  const platformFee = policy.round2(amount * policy.COMMISSION_RATE);
  const netAmount = policy.round2(amount - platformFee);
  const email = String(data && data.email || '').trim();
  const installments = Number(data && data.installments || 1);
  const payerDocNumber = data && data.payerDocNumber
    ? security.digitsOnly(data.payerDocNumber)
    : undefined;
  if (payerDocNumber && !security.isValidCpf(payerDocNumber)) {
    throw httpsError('invalid-argument', 'CPF inválido');
  }

  let response;
  try {
    response = await axios.post('https://api.mercadopago.com/v1/payments', {
      transaction_amount: amount,
      description: String(data && data.description || order.title || 'Pagamento Carajás 360').slice(0, 200),
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
  } catch (err) {
    wrapGateway(err);
  }

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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    ...(status === 'approved' ? { paidAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
  });
  if (status === 'approved') {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'paid',
      transactionId: String(id),
      gatewayTransactionId: String(id),
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    await db.collection('orders').doc(orderId).update({
      paymentStatus: 'pending',
      transactionId: String(id),
      gatewayTransactionId: String(id),
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
  const message = String(data && data.message || '').slice(0, 2000);
  if (!message.trim()) throw httpsError('invalid-argument', 'Mensagem vazia');
  const history = Array.isArray(data && data.history) ? data.history.slice(-8) : [];

  const systemPrompt = 'Você é o assistente virtual do Carajás 360, plataforma regional de serviços. '
    + 'Responda sempre em português do Brasil, de forma breve (máx. 3 parágrafos curtos). '
    + 'Não invente confirmações de pagamento nem dados pessoais.';

  const messages = [
    ...history.map((h) => ({
      role: h && h.isAi ? 'assistant' : 'user',
      content: String(h && h.text || '').slice(0, 1000),
    })),
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
    });
  } catch (err) {
    console.error('aiAssistant error', err && err.message);
    throw httpsError('unavailable', 'Assistente indisponível no momento.');
  }
  const reply = response.data.content && response.data.content[0]
    && response.data.content[0].text
    ? response.data.content[0].text
    : 'Não consegui processar sua pergunta agora.';
  return { reply };
});

exports.walletOp = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const op = String(data && data.op || '');
  const value = Number(data && data.amount);
  if (!security.walletOpAllowed(op)) {
    throw httpsError('invalid-argument', 'Operação não permitida');
  }
  if (op !== 'cashback' && !(value > 0)) {
    throw httpsError('invalid-argument', 'Valor inválido');
  }

  if (op === 'cashback') {
    const orderId = String(data && data.orderId || '');
    if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');
    return db.runTransaction(async (tx) => {
      const orderRef = db.collection('orders').doc(orderId);
      const orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) throw httpsError('not-found', 'Pedido não encontrado');
      const order = orderSnap.data();
      if (policy.normalizeStatus(order.status) !== 'completed') {
        throw httpsError('failed-precondition', 'Pedido não concluído');
      }
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
    }).then(async (out) => {
      await audit.writeAudit(db, {
        actorId: auth.uid,
        actorType: 'user',
        action: audit.ACTIONS.WALLET,
        target: orderId,
        details: { op: 'cashback', already: Boolean(out.already) },
      });
      return out;
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
      (data && data.description) || (op === 'withdraw' ? `Saque para ${(data && data.pixKey) || ''}` : ''),
      (data && data.icon) || (op === 'withdraw' ? '📤' : '👜'),
      op === 'withdraw' ? { pixKey: (data && data.pixKey) || null } : {},
    );
  });
  await audit.writeAudit(db, {
    actorId: auth.uid,
    actorType: 'user',
    action: audit.ACTIONS.WALLET,
    target: auth.uid,
    details: { op, amount: value },
  });
  return { ok: true };
});

exports.createNotification = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  if (!(await isAdmin(auth))) {
    throw httpsError('permission-denied', 'Notificações só pelo backend ou admin');
  }
  await enforceRateLimit(auth.uid, 'notif', 40, 60 * 60 * 1000);
  const userId = String(data && data.userId || '');
  const title = String(data && data.title || '');
  const body = String(data && data.body || '');
  if (!userId || !title || !body) {
    throw httpsError('invalid-argument', 'Campos obrigatórios ausentes');
  }
  await notify(userId, title, body, (data && data.type) || 'info');
  return { ok: true };
});

exports.processRefund = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  if (!(await isAdmin(auth))) {
    throw httpsError('permission-denied', 'Apenas admin');
  }
  const orderId = String(data && data.orderId || '');
  const amount = Number(data && data.amount);
  if (!orderId) throw httpsError('invalid-argument', 'orderId obrigatório');

  return db.runTransaction(async (tx) => {
    const orderRef = db.collection('orders').doc(orderId);
    const snap = await tx.get(orderRef);
    if (!snap.exists) throw httpsError('not-found', 'Pedido não encontrado');
    const order = snap.data();
    if (order.refunded === true || policy.normalizeStatus(order.status) === 'refunded') {
      return { ok: true, already: true, status: 'refunded' };
    }
    const from = policy.normalizeStatus(order.status || 'pending');
    if (!policy.isAllowedTransition(from, 'refunded') && from !== 'completed' && from !== 'cancelled' && from !== 'paid') {
      throw httpsError('failed-precondition', 'Pedido não pode ser estornado neste estado');
    }
    tx.update(orderRef, {
      status: 'refunded',
      refunded: true,
      refundAmount: amount > 0 ? policy.round2(amount) : Number(order.price || 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(db.collection('financialAudits').doc(), {
      orderId,
      userId: auth.uid,
      providerId: order.providerId || null,
      clientId: order.clientId || null,
      gross: Number(order.price || 0),
      gatewayFee: 0,
      commission: Number(order.commission || 0),
      platformFee: Number(order.platformFee || 0),
      netAmount: Number(order.providerAmount || 0),
      providerAmount: Number(order.providerAmount || 0),
      gatewayTransactionId: order.transactionId || null,
      status: 'refund_marked',
      payoutProcessed: Boolean(order.payoutProcessed),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      note: 'Estorno marcado. Reversão de saldo/gateway depende de operação manual em staging.',
    });
    return { ok: true, already: false, status: 'refunded' };
  }).then(async (out) => {
    await audit.writeAudit(db, {
      actorId: auth.uid,
      actorType: 'admin',
      action: audit.ACTIONS.REFUND,
      target: orderId,
      details: { already: Boolean(out.already), amount: amount > 0 ? amount : null },
    });
    return out;
  });
});

exports.requestPlanChange = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const uid = auth.uid;
  await enforceRateLimit(uid, 'plan_change', 8, 60 * 60 * 1000);

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  const existing = snap.exists ? snap.data() || {} : {};
  if (existing.status === 'deleted' || existing.anonymized === true) {
    throw httpsError('failed-precondition', 'Conta indisponível');
  }
  const currentPlan = existing.plan || 'free';
  const decision = planChange.buildPlanChangeDecision({
    requestedPlan: data && data.plan,
    currentPlan,
    paymentsEnabled: PAYMENTS_ENABLED,
  });
  if (!decision.ok) {
    throw httpsError(decision.code, decision.message);
  }

  const docRef = db.collection('planChangeRequests').doc();
  await docRef.set({
    userId: uid,
    currentPlan: decision.currentPlan,
    requestedPlan: decision.requestedPlan,
    status: decision.status,
    charged: false,
    applied: false,
    paymentsEnabled: PAYMENTS_ENABLED,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    await notify(
      uid,
      'Pedido de plano registrado',
      decision.message,
      'plan',
    );
  } catch (e) {
    console.error('notify plan change', e);
  }

  return {
    ok: true,
    charged: false,
    applied: false,
    status: decision.status,
    message: decision.message,
    requestId: docRef.id,
    requestedPlan: decision.requestedPlan,
  };
});

exports.deleteMyAccount = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const uid = auth.uid;
  await enforceRateLimit(uid, 'delete_account', 3, 24 * 60 * 60 * 1000);

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  const existing = snap.exists ? snap.data() || {} : {};
  if (existing.type === 'admin') {
    throw httpsError(
      'failed-precondition',
      'Conta admin não pode ser excluída por este fluxo. Peça a outro admin.',
    );
  }

  let pii = {};
  try {
    const piiSnap = await userRef.collection('private').doc('pii').get();
    if (piiSnap.exists) pii = piiSnap.data() || {};
  } catch (e) {
    console.error('deleteMyAccount pii', e);
  }

  const now = admin.firestore.FieldValue.serverTimestamp();
  const retentionUntil = deletion.retentionUntil(new Date());

  await db.collection('legalRetention').doc(uid).set({
    uid,
    createdAtOriginal: existing.createdAt || null,
    deletedAt: now,
    retentionUntil: admin.firestore.Timestamp.fromDate(retentionUntil),
    cpfHash: security.hashPii(pii.cpf || existing.cpf),
    phoneHash: security.hashPii(pii.phone || existing.phone),
    hadWallet: true,
    status: 'anonymized',
    reason: 'user_request_lgpd',
  }, { merge: true });

  await userRef.set({
    ...deletion.userAnonymizedProfile(),
    deletedAt: now,
    updatedAt: now,
  }, { merge: true });

  try {
    const priv = await userRef.collection('private').get();
    const batch = db.batch();
    priv.docs.forEach((d) => batch.delete(d.ref));
    if (!priv.empty) await batch.commit();
  } catch (e) {
    console.error('deleteMyAccount private', e);
  }

  await db.collection('providers').doc(uid).set(
    { ...deletion.providerAnonymizedProfile(), updatedAt: now },
    { merge: true },
  );

  const companies = await db.collection('companies').where('ownerId', '==', uid).limit(20).get();
  if (!companies.empty) {
    const batch = db.batch();
    companies.docs.forEach((d) => {
      batch.set(d.ref, { ...deletion.companyAnonymizedProfile(), updatedAt: now }, { merge: true });
    });
    await batch.commit();
  }

  const reviews = await db.collection('reviews').where('clientId', '==', uid).limit(100).get();
  if (!reviews.empty) {
    const batch = db.batch();
    reviews.docs.forEach((d) => {
      batch.update(d.ref, {
        clientName: deletion.ANONYMOUS_NAME,
        clientPhoto: null,
      });
    });
    await batch.commit();
  }

  const tickets = await db.collection('support').where('userId', '==', uid).limit(100).get();
  if (!tickets.empty) {
    const batch = db.batch();
    tickets.docs.forEach((d) => {
      batch.update(d.ref, { userName: deletion.ANONYMOUS_NAME });
    });
    await batch.commit();
  }

  const resolveReqs = await db.collection('resolveRequests').where('clientId', '==', uid).limit(50).get();
  if (!resolveReqs.empty) {
    const batch = db.batch();
    resolveReqs.docs.forEach((d) => {
      batch.update(d.ref, {
        clientName: deletion.ANONYMOUS_NAME,
        address: null,
      });
    });
    await batch.commit();
  }

  try {
    await deleteByQuery(db.collection('favorites').where('userId', '==', uid));
  } catch (e) {
    console.error('deleteMyAccount favorites', e);
  }
  try {
    await deleteByQuery(db.collection('notifications').where('userId', '==', uid));
  } catch (e) {
    console.error('deleteMyAccount notifications', e);
  }

  await db.collection('wallets').doc(uid).set({
    userId: uid,
    status: 'closed',
    closedAt: now,
  }, { merge: true });

  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `users/${uid}/` });
    await bucket.deleteFiles({ prefix: `providers/${uid}/` });
  } catch (e) {
    console.error('deleteMyAccount storage', e && e.message);
  }

  let authDeleted = false;
  try {
    await admin.auth().deleteUser(uid);
    authDeleted = true;
  } catch (e) {
    if (e && e.code === 'auth/user-not-found') {
      authDeleted = true;
    } else {
      console.error('deleteMyAccount auth', e);
    }
  }

  await audit.writeAudit(db, {
    actorId: uid,
    actorType: 'self',
    action: audit.ACTIONS.ACCOUNT_DELETED,
    target: uid,
    details: {
      authDeleted,
      retained: deletion.RETAIN_COLLECTIONS,
      deleted: deletion.DELETE_ON_REQUEST,
    },
  });

  await db.collection('legalRetention').doc(uid).set({
    authDeleted,
    updatedAt: now,
  }, { merge: true });

  return {
    ok: true,
    anonymized: true,
    authDeleted,
    already: existing.status === 'deleted',
  };
});

exports.switchProfileType = functions.region(REGION).https.onCall(async (data, context) => {
  const auth = requireAuth(context);
  const next = String(data && data.type || '');
  if (!ALLOWED_PROFILE_TYPES.includes(next)) {
    throw httpsError('invalid-argument', 'Tipo de perfil inválido');
  }
  const ref = db.collection('users').doc(auth.uid);
  const snap = await ref.get();
  if (snap.exists && snap.data().type === 'admin') {
    throw httpsError('permission-denied', 'Perfil admin não pode ser alterado por esta operação');
  }
  const previous = snap.exists ? snap.data().type : null;
  await ref.set({ type: next, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  await audit.writeAudit(db, {
    actorId: auth.uid,
    actorType: 'user',
    action: audit.ACTIONS.PERMISSION_CHANGE,
    target: auth.uid,
    details: { from: previous || null, to: next },
  });
  return { ok: true, type: next };
});

exports.sendPushNotification = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap) => {
    const { userId, title, body } = snap.data();
    const userDoc = await db.collection('users').doc(userId).get();
    const pii = await db.collection('users').doc(userId).collection('private').doc('pii').get();
    const fcmToken = (pii.exists && pii.data().fcmToken) || userDoc.data() && userDoc.data().fcmToken;
    if (!fcmToken) return null;
    return admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: { notification: { icon: 'ic_launcher', color: '#0B3D91' } },
      apns: { payload: { aps: { badge: 1, sound: 'default' } } },
    });
  });

exports.updateProviderRating = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap) => {
    const { providerId, clientId, orderId } = snap.data();
    if (!providerId) return null;
    if (orderId) {
      const order = await db.collection('orders').doc(String(orderId)).get();
      if (!order.exists || order.data().providerId !== providerId) {
        console.warn('review provider mismatch', snap.id);
        await snap.ref.delete();
        return null;
      }
    }
    const reviews = await db.collection('reviews').where('providerId', '==', providerId).get();
    const total = reviews.docs.reduce((sum, d) => sum + (d.data().stars || 0), 0);
    const avg = reviews.size ? total / reviews.size : 0;
    await db.collection('providers').doc(providerId).update({
      rating: parseFloat(avg.toFixed(1)),
      totalReviews: reviews.size,
    });
    if (clientId) {
      await grantXp(clientId, 'review', snap.id);
    }
    return null;
  });

exports.onUserCreateGrantXp = functions.firestore
  .document('users/{uid}')
  .onCreate(async (snap) => {
    await grantXp(snap.id, 'signup', snap.id);
    return null;
  });

exports.sanitizeUserPii = functions.firestore
  .document('users/{uid}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;
    const data = change.after.data() || {};
    const pii = security.piiFromUser(data);
    if (!Object.keys(pii).length) return null;
    const cleaned = security.sanitizePiiWrite(pii);
    await change.after.ref.collection('private').doc('pii').set(
      { ...cleaned, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );
    const del = {};
    Object.keys(pii).forEach((k) => {
      del[k] = admin.firestore.FieldValue.delete();
    });
    await change.after.ref.update(del);
    return null;
  });

exports.sanitizePrivatePii = functions.firestore
  .document('users/{uid}/private/{docId}')
  .onWrite(async (change) => {
    if (!change.after.exists) return null;
    const after = change.after.data() || {};
    if (!Object.prototype.hasOwnProperty.call(after, 'cpf')) return null;
    if (after.cpf == null || after.cpf === '') return null;
    if (security.isValidCpf(after.cpf)) {
      const digits = security.digitsOnly(after.cpf);
      if (digits === after.cpf && !after.cpfRejected) return null;
      await change.after.ref.update({
        cpf: digits,
        cpfRejected: admin.firestore.FieldValue.delete(),
      });
      return null;
    }
    await change.after.ref.update({
      cpf: admin.firestore.FieldValue.delete(),
      cpfRejected: true,
    });
    return null;
  });

exports.onBookingCreatedNotify = functions.firestore
  .document('bookings/{id}')
  .onCreate(async (snap) => {
    const b = snap.data() || {};
    if (!b.ownerId) return null;
    await notify(
      b.ownerId,
      'Nova solicitação de reserva',
      `${b.clientName || 'Cliente'} quer alugar ${b.rentalTitle || 'seu anúncio'}`,
      'booking',
    );
    return null;
  });

exports.onResolveRequestCreatedNotify = functions.firestore
  .document('resolveRequests/{id}')
  .onCreate(async (snap) => {
    const req = snap.data() || {};
    if (!req.category) return null;
    const providers = await db.collection('providers')
      .where('active', '==', true)
      .where('verified', '==', true)
      .where('categories', 'array-contains', req.category)
      .limit(20)
      .get();
    const description = String(req.description || 'Novo pedido Resolve');
    const body = description.length > 80 ? `${description.slice(0, 80)}…` : description;
    await Promise.all(providers.docs.map((p) => {
      const pid = p.data().userId || p.id;
      return notify(pid, '⚡ Nova oportunidade Resolve', body, 'resolve');
    }));
    return null;
  });

exports.onResolveProposalCreatedNotify = functions.firestore
  .document('resolveProposals/{id}')
  .onCreate(async (snap) => {
    const p = snap.data() || {};
    if (!p.requestId) return null;
    const req = await db.collection('resolveRequests').doc(String(p.requestId)).get();
    const clientId = req.exists ? req.data().clientId : null;
    if (!clientId) return null;
    await notify(
      clientId,
      '💬 Nova proposta Resolve',
      `${p.providerName || 'Um profissional'} enviou uma proposta para seu pedido.`,
      'resolve',
    );
    return null;
  });

exports.onResolveRequestMatchedNotify = functions.firestore
  .document('resolveRequests/{id}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.status === 'matched' || after.status !== 'matched') return null;
    const providerId = after.matchedProviderId;
    if (!providerId) return null;
    await notify(
      providerId,
      '✅ Proposta aceita!',
      'Sua proposta Resolve foi aceita. Fale com o cliente no chat.',
      'resolve',
    );
    return null;
  });

exports.cleanupOldOrders = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = Date.now() - 7 * 24 * 60 * 60 * 1000;
  const oldOrders = await db.collection('orders')
    .where('status', '==', 'pending')
    .where('createdAt', '<', new Date(cutoff))
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

/**
 * Webhook sandbox Mercado Pago.
 * Sem secret: 501. Com secret inválido: 401. Válido: 202.
 * NUNCA cobra nem altera pedido/carteira (charged/applied sempre false).
 */
const { mercadoPagoWebhookDecision } = require('./webhookSandbox');
exports.mercadoPagoWebhook = functions.https.onRequest((req, res) => {
  const data = req.body && req.body.data ? req.body.data : {};
  const decision = mercadoPagoWebhookDecision(req.method, {
    secret: process.env.MERCADOPAGO_WEBHOOK_SECRET || '',
    signature: req.get('x-signature'),
    requestId: req.get('x-request-id'),
    dataId: data.id,
  });
  audit.structuredLog('info', 'mp_webhook', {
    status: decision.status,
    reason: decision.body && decision.body.reason,
    charged: false,
    applied: false,
  });
  res.status(decision.status).json(decision.body);
});

/**
 * Directions proxy. Sem GOOGLE_MAPS_SERVER_KEY: recusa.
 * Com key: ainda NÃO chama a API Google (evita cobrança Maps).
 */
exports.getDirections = functions.region(REGION).https.onCall(async (data, context) => {
  requireAuth(context);
  const decision = directionsDecision({
    serverKey: process.env.GOOGLE_MAPS_SERVER_KEY || '',
    origin: data && data.origin,
    destination: data && data.destination,
  });
  if (!decision.ok) return decision;
  return {
    ok: false,
    reason: 'directions_proxy_not_enabled',
    charged: false,
    message: 'Key de servidor presente, mas o HTTP Directions está desligado para não gerar cobrança.',
  };
});
