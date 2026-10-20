'use strict';
/**
 * Pendência 3 — cashback: crédito único (chamadas repetidas e
 * concorrentes), estorno proporcional no reembolso e o comportamento da
 * confirmação automática.
 *
 * Regra aprovada encontrada (docs/fase3/RELATORIO_FASE3.md §8): no Mercado,
 * cashback sobre mercadorias "creditado uma vez" na liberação do pedido
 * entregue — tanto na confirmação do cliente quanto na liberação automática
 * de 7 dias (mesma função releaseMarketOrder) — e estornado
 * proporcionalmente em reembolso. Para pedidos de SERVIÇO não há regra
 * aprovada para a confirmação automática de 72 h (AUDITORIA_3 E9, decisão de
 * produto pendente; ver docs/homologacao/REGISTRO_PENDENCIAS.md): o teste
 * fixa o comportamento atual (a autoconfirmação não credita).
 */
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
// Mesmo valor de functions/.env.demo-carajas360 (segredo só de emulador).
const WEBHOOK_SECRET = 'emulator-only-webhook-secret-not-a-real-credential';
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p) => `${p}_${crypto.randomBytes(6).toString('hex')}`;
const H = 3600000;
const MIN = 60000;

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json(); return { uid: j.localId, token: j.idToken };
}
async function call(name, user, data) {
  const r = await fetch(`${FN}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${user.token}` }, body: JSON.stringify({ data: data || {} }) });
  const j = await r.json(); if (j.error) throw new Error(`${j.error.status} ${j.error.message}`); return j.result;
}
async function webhook(dataId) {
  const requestId = rid('req');
  const ts = Math.floor(Date.now() / 1000);
  const v1 = crypto.createHmac('sha256', WEBHOOK_SECRET).update(`id:${String(dataId).toLowerCase()};request-id:${requestId};ts:${ts};`).digest('hex');
  const r = await fetch(`${FN}/paymentsWebhook?data.id=${dataId}&type=payment`, {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'x-signature': `ts=${ts},v1=${v1}`, 'x-request-id': requestId },
    body: JSON.stringify({ action: 'payment.updated', type: 'payment', data: { id: String(dataId) } }),
  });
  return r.status;
}
let gwClock = Date.now() + 20 * H;
async function approveRefunds(paymentId, { full }) {
  const p = (await db.doc(`_fakeGateway/${paymentId}`).get()).data();
  gwClock += 5000;
  await db.doc(`_fakeGateway/${paymentId}`).update({
    refunds: p.refunds.map((r) => ({ ...r, status: 'approved' })), ...(full ? { status: 'refunded' } : {}),
    date_last_updated: new Date(gwClock).toISOString(),
  });
}
async function setClock(offsetMs) {
  await db.doc('_testClock/current').set({ offsetMs });
  await sleep(1300); // cache de 1 s em functions/clock.js
}
const doc = (p) => db.doc(p).get().then((s) => s.data());
const balance = async (uid) => ((await doc(`wallets/${uid}`)) || {}).balanceCents || 0;
const ledger = async (uid, type) => (await db.collection('transactions').where('userId', '==', uid).where('type', '==', type).get()).docs.map((d) => d.data());

const K = `p3cb${Date.now().toString(36)}`;
const STORE = `${K}_loja`; const PROD = `${K}_arroz`;
let master; let seller; let pro;

before(async () => {
  [master, seller, pro] = await Promise.all(['master', 'sel', 'pro'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', adminRole: 'master', name: 'Master' });
  b.set(db.doc(`users/${pro.uid}`), { type: 'provider', name: 'João Eletricista' });
  b.set(db.doc(`providers/${pro.uid}`), { userId: pro.uid, name: 'João', verified: true, active: true, categories: ['eletricista'] });
  b.set(db.doc(`stores/${STORE}`), { ownerId: seller.uid, name: 'Mercado P3', active: true, verified: true, deliveryFeeCents: 500, pickupEnabled: true, deliveryEnabled: true });
  b.set(db.doc(`products/${PROD}`), { storeId: STORE, name: 'Arroz', price: 25, stock: 1000, active: true });
  await b.commit();
  await db.doc('config/finance').delete(); // padrão: comissão 15%, cashback 2%
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  await setClock(0);
});
after(async () => { await setClock(0); });

const runJobs = (...jobs) => call('adminRunMaintenance', master, { jobs });

async function client(tag) {
  const u = await signUp(tag);
  await db.doc(`users/${u.uid}`).set({ type: 'client', name: `Cliente ${tag}` });
  return u;
}
/** Pedido de serviço em andamento, pago (carteira legada), R$ 100,00. */
async function serviceOrder(c) {
  const id = rid('o');
  await db.doc(`payments/wallet_${id}`).set({ orderId: id, userId: c.uid, amount: 100, method: 'wallet', status: 'approved' });
  await db.doc(`orders/${id}`).set({
    clientId: c.uid, providerId: pro.uid, status: 'inProgress', price: 100, paymentStatus: 'paid',
    transactionId: `wallet_${id}`, payoutProcessed: false, title: 'Chuveiro',
    financeTerms: { commissionBps: 1500, cashbackBps: 200, configVersion: 0 },
  });
  return id;
}
/** Pedido do Mercado pago no cartão (simulador), entregue: 2 × 25,00, retirada (sem frete). */
async function deliveredMarketOrder(c) {
  const o = await call('createMarketOrder', c, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 2 }], deliveryMode: 'pickup' });
  const a = await call('startPayment', c, { targetKind: 'market', targetId: o.orderId, method: 'card', requestId: rid('pay'), card: { token: 'tok_approved', installments: 1 } });
  assert.strictEqual(a.status, 'approved');
  for (const st of ['preparing', 'ready', 'delivered']) await call('marketOrderUpdateStatus', seller, { orderId: o.orderId, status: st });
  const paymentId = (await doc(`paymentAttempts/${a.attemptId}`)).gatewayPaymentId;
  return { orderId: o.orderId, paymentId };
}

describe('Serviço: cashback do walletOp', () => {
  test('confirmação pelo cliente: crédito único com chamadas repetidas e concorrentes', async () => {
    const c = await client('svc');
    const id = await serviceOrder(c);
    await call('transitionOrder', c, { orderId: id, action: 'complete' });
    const res = await Promise.allSettled([1, 2, 3, 4].map(() => call('walletOp', c, { op: 'cashback', orderId: id })));
    assert.ok(res.some((r) => r.status === 'fulfilled'), JSON.stringify(res.map((r) => r.reason && r.reason.message)));
    await call('walletOp', c, { op: 'cashback', orderId: id }); // de novo, depois
    assert.strictEqual(await balance(c.uid), 200, '2% de R$ 100,00, uma vez');
    const l = await ledger(c.uid, 'cashback');
    assert.strictEqual(l.length, 1, 'um lançamento no razão');
    assert.strictEqual(l[0].refId, id);
    assert.ok((await db.doc(`transactions/cashback_service_${id}`).get()).exists, 'chave idempotente por pedido');
    assert.strictEqual((await doc(`orders/${id}`)).cashbackGranted, true);
    // O prestador (participante) chamando também não duplica.
    assert.strictEqual((await call('walletOp', pro, { op: 'cashback', orderId: id })).already, true);
    assert.strictEqual(await balance(c.uid), 200);
    assert.strictEqual((await call('walletReconcile', master, { userId: c.uid })).ok, true);
  });

  test('pedido não concluído ou de terceiro não gera cashback', async () => {
    const [c, x] = await Promise.all([client('svc2'), client('intruso')]);
    const id = await serviceOrder(c);
    await assert.rejects(call('walletOp', c, { op: 'cashback', orderId: id }), /não concluído/);
    await call('transitionOrder', c, { orderId: id, action: 'complete' });
    await assert.rejects(call('walletOp', x, { op: 'cashback', orderId: id }), /PERMISSION_DENIED/);
    assert.strictEqual(await balance(x.uid), 0);
  });

  test('confirmação automática de 72 h: conclui e repassa, mas NÃO credita cashback (regra atual; decisão pendente)', async () => {
    const c = await client('auto');
    const id = await serviceOrder(c);
    await call('transitionOrder', pro, { orderId: id, action: 'complete' });
    await setClock(72 * H + MIN);
    await runJobs('autoConfirmServiceOrders');
    await runJobs('autoConfirmServiceOrders');
    await setClock(0);
    const o = await doc(`orders/${id}`);
    assert.deepStrictEqual([o.status, o.autoConfirmed, o.payoutProcessed], ['completed', true, true]);
    assert.notStrictEqual(o.cashbackGranted, true);
    assert.strictEqual(await balance(c.uid), 0, 'sem cashback na autoconfirmação');
    assert.strictEqual((await db.doc(`transactions/cashback_service_${id}`).get()).exists, false);
  });
});

describe('Mercado: cashback na liberação e estorno no reembolso', () => {
  test('confirmações concorrentes + tarefa de 7 dias: crédito único', async () => {
    const c = await client('mkt');
    const { orderId } = await deliveredMarketOrder(c);
    const cb = (await doc(`marketOrders/${orderId}`)).financeTerms.cashbackCents;
    assert.strictEqual(cb, 100, '2% de R$ 50,00 em mercadorias');
    const res = await Promise.allSettled([1, 2, 3].map(() => call('confirmMarketReceipt', c, { orderId })));
    assert.ok(res.some((r) => r.status === 'fulfilled'), JSON.stringify(res.map((r) => r.reason && r.reason.message)));
    await setClock(7 * 24 * H + MIN);
    await runJobs('marketReleaseDue');
    await setClock(0);
    await call('confirmMarketReceipt', c, { orderId });
    assert.strictEqual(await balance(c.uid), 100);
    assert.strictEqual((await ledger(c.uid, 'cashback')).length, 1);
    assert.strictEqual((await doc(`marketOrders/${orderId}`)).cashbackCredited, true);
  });

  test('liberação automática de 7 dias (sem o cliente confirmar) também credita uma vez', async () => {
    const c = await client('mkt7');
    const { orderId } = await deliveredMarketOrder(c);
    await setClock(7 * 24 * H + MIN);
    await Promise.allSettled([runJobs('marketReleaseDue'), runJobs('marketReleaseDue')]);
    await runJobs('marketReleaseDue');
    await setClock(0);
    const o = await doc(`marketOrders/${orderId}`);
    assert.deepStrictEqual([o.released, o.releasedBy, o.cashbackCredited], [true, 'system', true]);
    assert.strictEqual(await balance(c.uid), 100);
    assert.strictEqual((await ledger(c.uid, 'cashback')).length, 1);
  });

  test('reembolso depois do crédito estorna o cashback proporcionalmente, sem duplicar', async () => {
    const c = await client('mktrf');
    const { orderId, paymentId } = await deliveredMarketOrder(c);
    await call('confirmMarketReceipt', c, { orderId });
    assert.strictEqual(await balance(c.uid), 100);
    // Parcial: R$ 10,00 de R$ 50,00 → 100 × 1000/5000 = 20.
    await call('refundMarketOrder', master, { orderId, amountCents: 1000, reason: 'Item avariado' });
    await approveRefunds(paymentId, { full: false });
    await webhook(paymentId);
    await webhook(paymentId); // reentrega do gateway
    assert.strictEqual(await balance(c.uid), 80);
    // Restante (R$ 40,00): estorno total do cashback (20 + 80 = 100).
    await call('refundMarketOrder', master, { orderId, reason: 'Devolução' });
    await approveRefunds(paymentId, { full: true });
    await webhook(paymentId);
    await call('runPaymentsMaintenance', master, {});
    const o = await doc(`marketOrders/${orderId}`);
    assert.strictEqual(o.paymentStatus, 'refunded');
    assert.strictEqual(await balance(c.uid), 0, 'cashback devolvido por inteiro');
    const rev = await ledger(c.uid, 'cashback_reversal');
    assert.deepStrictEqual(rev.map((r) => r.amountCents).sort((a, b) => a - b), [20, 80]);
    assert.strictEqual((await call('walletReconcile', master, { userId: c.uid })).ok, true);
  });
});
