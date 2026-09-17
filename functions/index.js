/**
 * ServiçoConecta — Cloud Functions (Vol.17)
 *
 * Antes de fazer deploy, configure o token do Mercado Pago:
 *   firebase functions:config:set mercadopago.token="SEU_ACCESS_TOKEN"
 *
 * Deploy: firebase deploy --only functions
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

admin.initializeApp();
const db = admin.firestore();

const COMMISSION_RATE = 0.15;

// ── Gerar cobrança PIX ──────────────────────────────────────
exports.generatePix = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') { res.set('Access-Control-Allow-Methods', 'POST'); res.set('Access-Control-Allow-Headers', 'Content-Type'); return res.status(204).send(''); }

  try {
    const { amount, description, email, orderId, userId, purpose } = req.body;
    const token = functions.config().mercadopago?.token;
    if (!token) return res.status(500).json({ error: 'Mercado Pago não configurado' });

    const platformFee = amount * COMMISSION_RATE;
    const netAmount = amount - platformFee;

    const response = await axios.post('https://api.mercadopago.com/v1/payments', {
      transaction_amount: amount,
      description: description || 'Pagamento ServiçoConecta',
      payment_method_id: 'pix',
      payer: { email: email || 'cliente@servicoconecta.com.br' },
    }, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Idempotency-Key': `${orderId || Date.now()}-${Date.now()}`,
      },
    });

    const { id, status, point_of_interaction } = response.data;

    await db.collection('payments').doc(String(id)).set({
      orderId: orderId || null,
      userId: userId || null,
      purpose: purpose || 'order',
      amount, platformFee, netAmount,
      method: 'pix', status: status === 'pending' ? 'pending' : 'processing',
      walletCredited: false,
      externalId: String(id), createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return res.status(200).json({
      id, status,
      qr_code: point_of_interaction.transaction_data.qr_code,
      qr_code_base64: point_of_interaction.transaction_data.qr_code_base64,
    });
  } catch (err) {
    console.error(err.response?.data || err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ── Verificar status do pagamento ───────────────────────────
exports.checkPayment = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  try {
    const { id } = req.query;
    const token = functions.config().mercadopago?.token;
    const response = await axios.get(`https://api.mercadopago.com/v1/payments/${id}`, {
      headers: { 'Authorization': `Bearer ${token}` },
    });
    const status = response.data.status;

    if (status === 'approved') {
      const paymentDoc = await db.collection('payments').doc(String(id)).get();
      if (paymentDoc.exists && paymentDoc.data().status !== 'approved') {
        await paymentDoc.ref.update({ status: 'approved', paidAt: admin.firestore.FieldValue.serverTimestamp() });
      }
      // Recarga de carteira: credita só via Admin SDK (nunca pelo client).
      if (paymentDoc.exists) {
        const p = paymentDoc.data();
        if (p.purpose === 'wallet_recharge' && p.userId && !p.walletCredited) {
          await adjustWalletAdmin(p.userId, 'credit', Number(p.amount), 'Recarga via PIX', '⚡');
          await paymentDoc.ref.update({ walletCredited: true });
        }
      }
    }

    return res.status(200).json({ status });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// ── Processar pagamento com cartão de crédito ────────────────
// IMPORTANTE: a tokenização do cartão (número, validade, CVV) deve
// acontecer no app Flutter via SDK do Mercado Pago (mercadopago_sdk
// ou WebView do Checkout Transparente), NUNCA enviando os dados
// brutos do cartão para este backend — isso violaria PCI-DSS. O
// client envia apenas o `cardToken` já tokenizado.
exports.processCardPayment = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') { res.set('Access-Control-Allow-Methods', 'POST'); res.set('Access-Control-Allow-Headers', 'Content-Type'); return res.status(204).send(''); }

  try {
    const { amount, description, email, orderId, cardToken, installments, payerDocNumber } = req.body;
    const token = functions.config().mercadopago?.token;
    if (!token) return res.status(500).json({ error: 'Mercado Pago não configurado' });
    if (!cardToken) return res.status(400).json({ error: 'Token do cartão ausente' });

    const platformFee = amount * COMMISSION_RATE;
    const netAmount = amount - platformFee;

    const response = await axios.post('https://api.mercadopago.com/v1/payments', {
      transaction_amount: amount,
      description: description || 'Pagamento ServiçoConecta',
      token: cardToken,
      installments: installments || 1,
      payment_method_id: undefined, // o Mercado Pago infere a partir do token
      payer: {
        email: email || 'cliente@servicoconecta.com.br',
        identification: payerDocNumber ? { type: 'CPF', number: payerDocNumber } : undefined,
      },
    }, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Idempotency-Key': `${orderId || Date.now()}-${Date.now()}`,
      },
    });

    const { id, status, status_detail } = response.data;

    await db.collection('payments').doc(String(id)).set({
      orderId: orderId || null, amount, platformFee, netAmount,
      method: 'card', status, statusDetail: status_detail, installments: installments || 1,
      externalId: String(id), createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(status === 'approved' ? { paidAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
    });

    return res.status(200).json({ id, status, statusDetail: status_detail });
  } catch (err) {
    console.error(err.response?.data || err.message);
    return res.status(500).json({ error: err.response?.data?.message || err.message });
  }
});

// ── Enviar notificação push ao criar notification doc ───────
exports.sendPushNotification = functions.firestore
  .document('notifications/{notifId}')
  .onCreate(async (snap) => {
    const { userId, title, body } = snap.data();
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return null;

    return admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      android: { notification: { icon: 'ic_launcher', color: '#0D47A1' } },
      apns: { payload: { aps: { badge: 1, sound: 'default' } } },
    });
  });

// ── Atualizar rating do prestador após review ────────────────
exports.updateProviderRating = functions.firestore
  .document('reviews/{reviewId}')
  .onCreate(async (snap) => {
    const { providerId } = snap.data();
    if (!providerId) return null;

    const reviews = await db.collection('reviews').where('providerId', '==', providerId).get();
    const total = reviews.docs.reduce((sum, d) => sum + (d.data().stars || 0), 0);
    const avg = total / reviews.size;

    return db.collection('providers').doc(providerId).update({
      rating: parseFloat(avg.toFixed(1)),
      totalReviews: reviews.size,
    });
  });

// ── Repasse automático ao concluir pedido ────────────────────
exports.processPayout = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    if (before.status !== 'completed' && after.status === 'completed' && after.providerId && after.price) {
      const netAmount = after.price * (1 - COMMISSION_RATE);
      const walletRef = db.collection('wallets').doc(after.providerId);
      const walletDoc = await walletRef.get();

      const batch = db.batch();
      if (walletDoc.exists) {
        batch.update(walletRef, { balance: admin.firestore.FieldValue.increment(netAmount) });
      } else {
        batch.set(walletRef, { userId: after.providerId, balance: netAmount, createdAt: admin.firestore.FieldValue.serverTimestamp() });
      }
      batch.set(db.collection('transactions').doc(), {
        userId: after.providerId, type: 'credit', amount: netAmount,
        description: 'Pagamento por serviço concluído', icon: '💰', status: 'done',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await batch.commit();
    }
    return null;
  });

// ── Limpeza de pedidos pendentes antigos (agendado) ───────────
exports.cleanupOldOrders = functions.pubsub.schedule('every 24 hours').onRun(async () => {
  const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
  const oldOrders = await db.collection('orders')
    .where('status', '==', 'pending')
    .where('createdAt', '<', cutoff)
    .get();

  const batch = db.batch();
  oldOrders.docs.forEach((doc) => batch.update(doc.ref, { status: 'cancelled' }));
  await batch.commit();
  console.log(`Cancelled ${oldOrders.size} old pending orders`);
  return null;
});

// ── Assistente de IA (Vol.28) — usa a Claude API ──────────────
// Antes de fazer deploy, configure a chave da API:
//   firebase functions:config:set anthropic.key="SUA_API_KEY"
exports.aiAssistant = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') { res.set('Access-Control-Allow-Methods', 'POST'); res.set('Access-Control-Allow-Headers', 'Content-Type'); return res.status(204).send(''); }

  try {
    const { message, history } = req.body;
    const apiKey = functions.config().anthropic?.key;
    if (!apiKey) return res.status(500).json({ error: 'IA não configurada' });

    const systemPrompt = `Você é o assistente virtual do ServiçoConecta, um marketplace de serviços no Brasil ` +
      `(similar ao GetNinjas) com módulos de serviços gerais, saúde, entregas, mercado e aluguel. ` +
      `Ajude o usuário a encontrar profissionais, estime preços de forma realista para o mercado brasileiro, ` +
      `explique como funciona pagamento (PIX, cartão, carteira digital com retenção até conclusão do serviço), ` +
      `e seja cordial e objetivo. Responda sempre em português do Brasil, de forma breve (máx. 3 parágrafos curtos).`;

    const messages = [
      ...(history || []).map((h) => ({ role: h.isAi ? 'assistant' : 'user', content: h.text })),
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

    const reply = response.data.content?.[0]?.text || 'Desculpe, não consegui processar sua pergunta agora.';
    return res.status(200).json({ reply });
  } catch (err) {
    console.error(err.response?.data || err.message);
    return res.status(500).json({ error: err.message });
  }
});

// ── Helpers de autenticação / carteira (Admin SDK) ───────────
function cors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

async function requireUser(req) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) {
    const e = new Error('Unauthorized');
    e.status = 401;
    throw e;
  }
  return admin.auth().verifyIdToken(h.slice(7));
}

async function adjustWalletAdmin(uid, type, amount, description, icon, extra) {
  if (!uid || !amount || amount <= 0) throw new Error('Parâmetros inválidos');
  const walletRef = db.collection('wallets').doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(walletRef);
    const bal = snap.exists ? Number(snap.data().balance || 0) : 0;
    if (type === 'debit' || type === 'withdraw') {
      if (bal < amount) throw new Error('Saldo insuficiente');
      tx.set(walletRef, { userId: uid, balance: bal - amount }, { merge: true });
    } else {
      tx.set(walletRef, { userId: uid, balance: bal + amount }, { merge: true });
    }
    tx.set(db.collection('transactions').doc(), {
      userId: uid,
      type,
      amount,
      description: description || '',
      icon: icon || '💰',
      status: type === 'withdraw' ? 'pending' : 'done',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      ...(extra || {}),
    });
  });
}

// Débito / saque / cashback autenticado (crédito livre pelo client é bloqueado).
exports.walletOp = functions.https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  try {
    const decoded = await requireUser(req);
    const { op, amount, description, icon, pixKey, orderId } = req.body || {};
    const value = Number(amount);
    if (!['debit', 'withdraw', 'cashback'].includes(op)) {
      return res.status(400).json({ error: 'Operação não permitida' });
    }
    if (op !== 'cashback' && !(value > 0)) {
      return res.status(400).json({ error: 'Valor inválido' });
    }

    if (op === 'cashback') {
      if (!orderId) return res.status(400).json({ error: 'orderId obrigatório' });
      const orderSnap = await db.collection('orders').doc(orderId).get();
      if (!orderSnap.exists) return res.status(404).json({ error: 'Pedido não encontrado' });
      const order = orderSnap.data();
      if (order.status !== 'completed') {
        return res.status(400).json({ error: 'Pedido não concluído' });
      }
      if (order.clientId !== decoded.uid && order.providerId !== decoded.uid) {
        return res.status(403).json({ error: 'Sem permissão' });
      }
      if (order.cashbackGranted) {
        return res.status(200).json({ ok: true, already: true });
      }
      const cashback = Number(order.price || 0) * 0.02;
      if (cashback > 0) {
        await adjustWalletAdmin(
          order.clientId, 'credit', cashback,
          `Cashback: ${order.title || 'Serviço'}`, '🎁',
          { orderId },
        );
      }
      await orderSnap.ref.update({ cashbackGranted: true });
      return res.status(200).json({ ok: true, cashback });
    }

    if (op === 'withdraw' && value < 10) {
      return res.status(400).json({ error: 'Saque mínimo R$ 10' });
    }
    await adjustWalletAdmin(
      decoded.uid,
      op,
      value,
      description || (op === 'withdraw' ? `Saque para ${pixKey || ''}` : ''),
      icon || (op === 'withdraw' ? '📤' : '👜'),
      op === 'withdraw' ? { pixKey: pixKey || null } : {},
    );
    return res.status(200).json({ ok: true });
  } catch (err) {
    const code = err.status || 500;
    console.error(err);
    return res.status(code).json({ error: err.message || 'Erro' });
  }
});

// Cria notificação in-app (Admin SDK) — client não escreve em notifications.
exports.createNotification = functions.https.onRequest(async (req, res) => {
  cors(res);
  if (req.method === 'OPTIONS') return res.status(204).send('');
  try {
    await requireUser(req);
    const { userId, title, body, type } = req.body || {};
    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'Campos obrigatórios ausentes' });
    }
    await db.collection('notifications').add({
      userId,
      title: String(title).slice(0, 120),
      body: String(body).slice(0, 500),
      type: type || 'info',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return res.status(200).json({ ok: true });
  } catch (err) {
    const code = err.status || 500;
    return res.status(code).json({ error: err.message || 'Erro' });
  }
});
