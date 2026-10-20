'use strict';
/**
 * Integração da Fase 3 (checkout, pagamentos e financeiro) contra os
 * emuladores. O gateway é o SIMULADOR (`PAYMENTS_GATEWAY=fake`, só aceito
 * no emulador). Nenhum teste atinge o sandbox real do Mercado Pago.
 *
 * Numeração = testes obrigatórios da Fase 3 (1–13; o 14 é teste Dart do
 * carrinho; o 15 está em functions/financeCore.test.js + abaixo).
 */
const { test, before, describe } = require('node:test');
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
const { Timestamp } = require('../../functions/node_modules/firebase-admin/lib/firestore');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p = 'r') => `${p}_${crypto.randomBytes(8).toString('hex')}`;

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken };
}
async function callRaw(name, user, data) {
  const r = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ data: data || {} }),
  });
  return r.json();
}
async function call(name, user, data) {
  const j = await callRaw(name, user, data);
  if (j.error) { const e = new Error(j.error.message); e.status = j.error.status; throw e; }
  return j.result;
}
async function rejects(p, re) {
  try { await p; } catch (e) { if (re) assert.match(`${e.status} ${e.message}`, re); return e; }
  assert.fail('deveria falhar');
}

/** Webhook assinado como o Mercado Pago (x-signature ts/v1 + x-request-id). */
async function webhook(dataId, { requestId = rid('req'), secret = WEBHOOK_SECRET, action = 'payment.updated' } = {}) {
  const ts = Math.floor(Date.now() / 1000);
  const manifest = `id:${String(dataId).toLowerCase()};request-id:${requestId};ts:${ts};`;
  const v1 = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  const r = await fetch(`${FN}/paymentsWebhook?data.id=${dataId}&type=payment`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-signature': `ts=${ts},v1=${v1}`, 'x-request-id': requestId },
    body: JSON.stringify({ action, type: 'payment', data: { id: String(dataId) } }),
  });
  return { status: r.status, text: await r.text(), requestId };
}

/** Simula o pagador/gateway alterando o pagamento no simulador. */
let clock = Date.now() + 60000;
async function gatewaySet(paymentId, patch) {
  clock += 5000;
  await db.doc(`_fakeGateway/${paymentId}`).update({ ...patch, date_last_updated: new Date(clock).toISOString() });
}
async function approveRefunds(paymentId, { full }) {
  const p = (await db.doc(`_fakeGateway/${paymentId}`).get()).data();
  const refunds = p.refunds.map((r) => ({ ...r, status: 'approved' }));
  await gatewaySet(paymentId, { refunds, ...(full ? { status: 'refunded' } : {}) });
}
const gwStats = async () => (await db.doc('_fakeGatewayStats/global').get()).data() || { creates: 0, refunds: 0 };
const order = async (id) => (await db.doc(`marketOrders/${id}`).get()).data();
const attempt = async (id) => (await db.doc(`paymentAttempts/${id}`).get()).data();
const wallet = async (uid) => (await db.doc(`wallets/${uid}`).get()).data() || { balanceCents: 0 };
const stock = async (pid) => (await db.doc(`products/${pid}`).get()).data().stock;
async function setControl(nextCreate) { await db.doc('_fakeGatewayControl/config').set({ nextCreate }); }
async function ageAttempt(id) { await db.doc(`paymentAttempts/${id}`).update({ updatedAt: Timestamp.fromMillis(Date.now() - 5 * 60000) }); }

let fin; let seller; const S = `st_${Date.now()}`;
const P1 = `${S}_p1`; // R$ 25,00 (estoque alto)
const P2 = `${S}_p2`; // estoque 3 (concorrência)
const P3 = `${S}_p3`; // R$ 40,00 (promo 30,00)

async function newOrder(user, { items = [{ productId: P1, qty: 2 }], mode = 'delivery', extra = {} } = {}) {
  return call('createMarketOrder', user, {
    requestId: rid('ord'), storeId: S, items, deliveryMode: mode,
    address: { street: 'Rua A', number: '10', city: 'Marabá' }, ...extra,
  });
}
async function payCard(user, orderId, token = 'tok_approved', extra = {}) {
  return call('startPayment', user, {
    targetKind: 'market', targetId: orderId, method: 'card', requestId: rid('pay'),
    card: { token, installments: 1, paymentMethodId: 'visa' }, ...extra,
  });
}
async function paidOrder(user) {
  const o = await newOrder(user);
  const a = await payCard(user, o.orderId);
  assert.strictEqual(a.status, 'approved');
  return { orderId: o.orderId, attemptId: a.attemptId, paymentId: (await attempt(a.attemptId)).gatewayPaymentId };
}

before(async () => {
  [fin, seller] = await Promise.all([signUp('fin'), signUp('seller')]);
  await db.doc(`users/${fin.uid}`).set({ type: 'admin', adminRole: 'financial', name: 'Financeiro' });
  await db.doc(`stores/${S}`).set({ ownerId: seller.uid, name: 'Mercado Teste', active: true, verified: true, deliveryFeeCents: 500, pickupEnabled: true, deliveryEnabled: true });
  await db.doc(`products/${P1}`).set({ storeId: S, name: 'Arroz 5kg', price: 25, stock: 1000, active: true });
  await db.doc(`products/${P2}`).set({ storeId: S, name: 'Último lote', price: 10, stock: 3, active: true });
  await db.doc(`products/${P3}`).set({ storeId: S, name: 'Café', price: 40, promoPrice: 30, stock: 1000, active: true });
  await db.doc('config/finance').delete();
  await setControl(null);
});

describe('Checkout: pedido antes da cobrança e valores do servidor', () => {
  test('1/2: pedido persiste ANTES da cobrança e o ID real chega ao Pix e ao cartão', async () => {
    const u = await signUp('c1');
    const before = await gwStats();
    const o = await newOrder(u);
    const od = await order(o.orderId);
    assert.strictEqual(od.status, 'pending_payment');
    assert.strictEqual(od.paymentStatus, 'unpaid');
    assert.ok(od.reservedUntil.toMillis() > Date.now());
    assert.ok(od.financeTerms && od.financeTerms.commissionBps === 1500, 'snapshot financeiro');
    assert.strictEqual((await db.collection('paymentAttempts').where('targetId', '==', o.orderId).get()).size, 0);
    assert.strictEqual((await gwStats()).creates || 0, before.creates || 0, 'nenhuma cobrança ao criar o pedido');

    const pix = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') });
    assert.strictEqual(pix.status, 'pending');
    assert.strictEqual(pix.targetId, o.orderId);
    assert.ok(pix.pix && pix.pix.qrCode, 'copia-e-cola');
    assert.ok(Date.parse(pix.pix.expiresAt) > Date.now() + 29 * 60000, 'vencimento registrado (≥ 30 min)');
    const a = await attempt(pix.attemptId);
    const g = (await db.doc(`_fakeGateway/${a.gatewayPaymentId}`).get()).data();
    assert.strictEqual(g.external_reference, pix.attemptId, 'referência externa = tentativa persistida');
    assert.strictEqual(a.targetId, o.orderId);
    assert.strictEqual((await order(o.orderId)).paymentStatus, 'pending');
    assert.strictEqual((await order(o.orderId)).status, 'pending_payment', 'nunca aprovado localmente');

    // Cartão: outro pedido; número/CVV nunca persistidos (só token).
    const o2 = await newOrder(u);
    const c = await payCard(u, o2.orderId, 'tok_approved', { card: { token: 'tok_approved', installments: 2, number: '4111111111111111', cvv: '123' } });
    assert.strictEqual(c.status, 'approved');
    const ca = await attempt(c.attemptId);
    assert.strictEqual(ca.targetId, o2.orderId);
    assert.strictEqual(ca.installments, 2);
    assert.ok(!JSON.stringify(ca).includes('4111111111111111') && !JSON.stringify(ca).includes('"cvv"'));
    const paid = await order(o2.orderId);
    assert.strictEqual(paid.status, 'paid');
    assert.strictEqual(paid.paymentStatus, 'approved');
  });

  test('3: total/preço adulterados no app são ignorados (servidor recalcula em centavos)', async () => {
    const u = await signUp('c3');
    const items = [{ productId: P1, qty: 2, price: 0.01, unitPriceCents: 1 }, { productId: P3, qty: 1, price: 1 }];
    const q = await call('quoteMarketOrder', u, { storeId: S, items, deliveryMode: 'delivery', totalCents: 1 });
    assert.strictEqual(q.totalCents, 2 * 2500 + 3000 + 500, 'promo 30,00 + frete 5,00');
    const o = await newOrder(u, { items, extra: { totalCents: 1, subtotalCents: 1, deliveryFeeCents: 0, discountCents: 99999 } });
    const od = await order(o.orderId);
    assert.strictEqual(od.totalCents, 8500);
    assert.strictEqual(od.deliveryFeeCents, 500);
    assert.strictEqual(od.items[0].unitPriceCents, 2500, 'snapshot do item com preço do servidor');
    const pick = await newOrder(u, { mode: 'pickup' });
    assert.strictEqual((await order(pick.orderId)).totalCents, 5000, 'retirada sem frete');
    const a = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay'), amountCents: 1 });
    assert.strictEqual(a.amountCents, 8500);
    const g = (await db.doc(`_fakeGateway/${(await attempt(a.attemptId)).gatewayPaymentId}`).get()).data();
    assert.strictEqual(g.transaction_amount, 85);
    await rejects(newOrder(u, { items: [{ productId: P1, qty: 0 }] }), /quantidade/);
    await rejects(newOrder(u, { items: [{ productId: 'nao_existe', qty: 1 }] }), /não encontrado/);
  });

  test('4: pedido de outro usuário bloqueado (pagar, consultar, cancelar)', async () => {
    const [a, b] = await Promise.all([signUp('c4a'), signUp('c4b')]);
    const o = await newOrder(a);
    await rejects(call('startPayment', b, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') }), /PERMISSION_DENIED|outra pessoa/);
    const pa = await call('startPayment', a, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') });
    await rejects(call('refreshPayment', b, { attemptId: pa.attemptId }), /PERMISSION_DENIED/);
    await rejects(call('cancelPaymentAttempt', b, { attemptId: pa.attemptId }), /PERMISSION_DENIED/);
    await rejects(call('cancelMarketOrder', b, { orderId: o.orderId }), /PERMISSION_DENIED/);
    await rejects(call('refundMarketOrder', a, { orderId: o.orderId }), /PERMISSION_DENIED/);
  });
});

describe('Idempotência', () => {
  test('5: clique duplo e duas abas não geram duas cobranças', async () => {
    const u = await signUp('c5');
    const o = await newOrder(u);
    const before = (await gwStats()).creates || 0;
    const req = rid('pay');
    const body = { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: req };
    const [r1, r2] = await Promise.all([call('startPayment', u, body), call('startPayment', u, body)]);
    assert.strictEqual(r1.attemptId, r2.attemptId);
    // Outra aba (requestId diferente) → retoma a tentativa ativa.
    const r3 = await call('startPayment', u, { ...body, requestId: rid('tab2') });
    assert.strictEqual(r3.attemptId, r1.attemptId);
    assert.strictEqual(((await gwStats()).creates || 0) - before, 1, 'uma única cobrança no gateway');
    // Trocar de método com cobrança ativa é bloqueado.
    await rejects(payCard(u, o.orderId), /em andamento/);
    // Pedido já pago não é cobrado de novo.
    const p = await paidOrder(u);
    const again = await payCard(u, p.orderId);
    assert.strictEqual(again.already, true);
  });

  test('6: timeout/resposta perdida → repetição usa a mesma chave; incerto é conciliado antes de nova cobrança', async () => {
    const u = await signUp('c6');
    // a) gateway criou, mas a resposta se perdeu
    const o = await newOrder(u);
    const before = (await gwStats()).creates || 0;
    await setControl('timeout_after_create');
    const req = rid('pay');
    const body = { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: req };
    const r1 = await call('startPayment', u, body);
    assert.strictEqual(r1.status, 'uncertain');
    await rejects(payCard(u, o.orderId), /em andamento/, 'não permite outra cobrança com resultado incerto');
    const r2 = await call('startPayment', u, body);
    assert.strictEqual(r2.attemptId, r1.attemptId);
    assert.strictEqual(r2.status, 'pending');
    assert.strictEqual(((await gwStats()).creates || 0) - before, 1, 'mesma cobrança recuperada pela chave de idempotência');

    // b) timeout antes de criar → conciliação não encontra → nova tentativa cria uma vez
    const o2 = await newOrder(u);
    await setControl('timeout_before_create');
    const body2 = { targetKind: 'market', targetId: o2.orderId, method: 'pix', requestId: rid('pay') };
    const s1 = await call('startPayment', u, body2);
    assert.strictEqual(s1.status, 'uncertain');
    const ref = await call('refreshPayment', u, { attemptId: s1.attemptId });
    assert.strictEqual(ref.status, 'uncertain', 'sem prova de que não houve cobrança, segue incerto');
    const s2 = await call('startPayment', u, body2);
    assert.strictEqual(s2.status, 'pending');
    assert.strictEqual(((await gwStats()).creates || 0) - before, 2);

    // c) recusa → tentativa falha e o pedido volta a aceitar pagamento
    const o3 = await newOrder(u);
    const rej = await payCard(u, o3.orderId, 'tok_rejected');
    assert.strictEqual(rej.status, 'rejected');
    assert.strictEqual((await order(o3.orderId)).paymentStatus, 'unpaid');
    const ok = await payCard(u, o3.orderId, 'tok_approved');
    assert.strictEqual(ok.status, 'approved');
    // d) 3DS: fica em desafio até a confirmação do gateway
    const o4 = await newOrder(u);
    const ch = await payCard(u, o4.orderId, 'tok_challenge');
    assert.strictEqual(ch.status, 'challenge');
    assert.ok(ch.challenge && ch.challenge.url);
    assert.strictEqual((await order(o4.orderId)).status, 'pending_payment');
  });
});

describe('Webhooks e conciliação', () => {
  test('7: webhook autenticado, duplicado e fora de ordem não duplicam efeitos', async () => {
    const u = await signUp('c7');
    const o = await newOrder(u);
    const pa = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') });
    const pid = (await attempt(pa.attemptId)).gatewayPaymentId;

    const forged = await webhook(pid, { secret: 'segredo-errado' });
    assert.strictEqual(forged.status, 401, 'assinatura inválida rejeitada');
    assert.strictEqual((await order(o.orderId)).status, 'pending_payment');

    await gatewaySet(pid, { status: 'approved', status_detail: 'accredited' });
    const w1 = await webhook(pid);
    assert.strictEqual(w1.status, 200);
    assert.strictEqual((await order(o.orderId)).status, 'paid');
    const dup = await webhook(pid, { requestId: w1.requestId });
    assert.strictEqual(dup.text, 'duplicate');
    // Evento antigo chegando depois (gateway devolve estado mais velho).
    const p = (await db.doc(`_fakeGateway/${pid}`).get()).data();
    await db.doc(`_fakeGateway/${pid}`).update({ status: 'pending', date_last_updated: new Date(Date.parse(p.date_last_updated) - 60000).toISOString() });
    const old = await webhook(pid);
    assert.strictEqual(old.status, 200);
    assert.strictEqual((await attempt(pa.attemptId)).status, 'approved', 'estado antigo ignorado');
    assert.strictEqual((await order(o.orderId)).status, 'paid');
    await db.doc(`_fakeGateway/${pid}`).update({ status: 'approved', date_last_updated: p.date_last_updated });
    await webhook(pid);
    const events = await db.collection(`marketOrders/${o.orderId}/events`).where('type', '==', 'paid').get();
    assert.strictEqual(events.size, 1, 'efeito de aprovação aplicado uma vez');
    assert.ok((await db.doc(`earnings/${o.orderId}`).get()).exists);

    // Valor divergente no gateway → não aprova, registra divergência.
    const o2 = await newOrder(u);
    const pb = await call('startPayment', u, { targetKind: 'market', targetId: o2.orderId, method: 'pix', requestId: rid('pay') });
    const pid2 = (await attempt(pb.attemptId)).gatewayPaymentId;
    await gatewaySet(pid2, { status: 'approved', transaction_amount: 1 });
    await webhook(pid2);
    assert.strictEqual((await order(o2.orderId)).status, 'pending_payment');
    const iss = await db.collection('financialIssues').where('attemptId', '==', pb.attemptId).get();
    assert.ok(iss.docs.some((d) => d.data().type === 'payment_divergence'));
  });

  test('8: confirmação com o app fechado (webhook ou rotina de conciliação)', async () => {
    const u = await signUp('c8');
    const o = await newOrder(u);
    const pa = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') });
    const pid = (await attempt(pa.attemptId)).gatewayPaymentId;
    // App fechado e webhook perdido: só a rotina agendada concilia.
    await gatewaySet(pid, { status: 'approved', status_detail: 'accredited' });
    await ageAttempt(pa.attemptId);
    const run = await call('runPaymentsMaintenance', fin, {});
    assert.ok(run.reconciled >= 1);
    assert.strictEqual((await order(o.orderId)).status, 'paid');
    const runs = await db.collection('reconciliationRuns').where('source', '==', 'admin').get();
    assert.ok(runs.size >= 1, 'execução registrada');
    await rejects(call('runPaymentsMaintenance', u, {}), /PERMISSION_DENIED/);
  });
});

describe('Carteira', () => {
  let rich;
  test('9: recarga confirmada credita uma única vez', async () => {
    rich = await signUp('c9');
    const rc = await call('createWalletRecharge', rich, { amountCents: 10000, requestId: rid('rc') });
    const pa = await call('startPayment', rich, { targetKind: 'recharge', targetId: rc.rechargeId, method: 'pix', requestId: rid('pay') });
    const pid = (await attempt(pa.attemptId)).gatewayPaymentId;
    assert.strictEqual((await wallet(rich.uid)).balanceCents, 0, 'nada creditado antes da confirmação');
    await gatewaySet(pid, { status: 'approved' });
    await Promise.all([webhook(pid), webhook(pid), call('refreshPayment', rich, { attemptId: pa.attemptId })]);
    await webhook(pid);
    await ageAttempt(pa.attemptId);
    await call('runPaymentsMaintenance', fin, {});
    assert.strictEqual((await wallet(rich.uid)).balanceCents, 10000);
    const led = await db.collection('transactions').where('userId', '==', rich.uid).get();
    assert.strictEqual(led.size, 1);
    assert.strictEqual(led.docs[0].id, `recharge_${rc.rechargeId}`);
    await rejects(call('startPayment', rich, { targetKind: 'recharge', targetId: rc.rechargeId, method: 'wallet', requestId: rid('pay') }), /própria carteira/);
    await rejects(call('walletOp', rich, { op: 'debit', amount: 50 }), /não permitida/);
    await rejects(call('walletOp', rich, { op: 'withdraw', amount: 50 }), /não está disponível/);
  });

  test('10: débitos concorrentes não deixam saldo negativo', async () => {
    const orders = [];
    for (let i = 0; i < 5; i += 1) orders.push((await newOrder(rich, { items: [{ productId: P1, qty: 1 }] })).orderId); // 30,00 cada
    const res = await Promise.all(orders.map((id) => call('startPayment', rich, { targetKind: 'market', targetId: id, method: 'wallet', requestId: rid('w') })));
    const approved = res.filter((r) => r.status === 'approved').length;
    assert.strictEqual(approved, 3, '3 × 30,00 cabem em 100,00');
    assert.strictEqual(res.filter((r) => r.status === 'failed').length, 2);
    const w = await wallet(rich.uid);
    assert.strictEqual(w.balanceCents, 1000);
    assert.ok(w.balanceCents >= 0);
    const rec = await call('walletReconcile', fin, { userId: rich.uid });
    assert.strictEqual(rec.ok, true, 'saldo × razão');
    assert.strictEqual(rec.ledgerCents, 1000);
    for (const id of orders) {
      const od = await order(id);
      assert.ok(od.status === 'paid' || od.paymentStatus === 'unpaid');
    }
  });
});

describe('Estoque', () => {
  test('11: reserva concorrente sem venda acima do estoque; liberação em cancelamento e expiração', async () => {
    const users = await Promise.all([1, 2, 3, 4, 5].map((i) => signUp(`c11_${i}`)));
    const res = await Promise.allSettled(users.map((u) => newOrder(u, { items: [{ productId: P2, qty: 1 }] })));
    const ok = res.filter((r) => r.status === 'fulfilled');
    assert.strictEqual(ok.length, 3, 'só 3 unidades');
    assert.ok(res.filter((r) => r.status === 'rejected').every((r) => /estoque insuficiente/.test(r.reason.message)));
    assert.strictEqual(await stock(P2), 0);
    const owners = res.map((r, i) => (r.status === 'fulfilled' ? { u: users[i], id: r.value.orderId } : null)).filter(Boolean);

    // Abrir a tela de pagamento não libera nem baixa de novo.
    await call('startPayment', owners[0].u, { targetKind: 'market', targetId: owners[0].id, method: 'pix', requestId: rid('pay') });
    assert.strictEqual(await stock(P2), 0);
    // Cancelamento com cobrança pendente: cancela a cobrança e devolve.
    const c = await call('cancelMarketOrder', owners[0].u, { orderId: owners[0].id });
    assert.strictEqual(c.status, 'cancelled');
    assert.strictEqual(await stock(P2), 1);
    const att = await db.collection('paymentAttempts').where('targetId', '==', owners[0].id).get();
    assert.ok(att.docs.every((d) => ['cancelled', 'failed'].includes(d.data().status)));
    // Cancelar de novo não devolve duas vezes.
    await rejects(call('cancelMarketOrder', owners[0].u, { orderId: owners[0].id }));
    assert.strictEqual(await stock(P2), 1);
    // Expiração da reserva pela rotina.
    await db.doc(`marketOrders/${owners[1].id}`).update({ reservedUntil: Timestamp.fromMillis(Date.now() - 1000) });
    await rejects(call('startPayment', owners[1].u, { targetKind: 'market', targetId: owners[1].id, method: 'pix', requestId: rid('pay') }), /expirad/);
    await call('runPaymentsMaintenance', fin, {});
    assert.strictEqual((await order(owners[1].id)).status, 'expired');
    assert.strictEqual(await stock(P2), 2);
    await call('runPaymentsMaintenance', fin, {});
    assert.strictEqual(await stock(P2), 2, 'liberação idempotente');
  });
});

describe('Comissão, repasse interno e cashback', () => {
  test('12: alteração de comissão preserva pedidos anteriores; repasse interno uma vez', async () => {
    const u = await signUp('c12');
    const old = await paidOrder(u);
    await rejects(call('updateFinanceConfig', u, { commissionBps: 0 }), /PERMISSION_DENIED/);
    await rejects(call('updateFinanceConfig', fin, { commissionBps: 9000 }), /INVALID_ARGUMENT/);
    const cfg = await call('updateFinanceConfig', fin, { commissionBps: 1000 });
    assert.strictEqual(cfg.commissionBps, 1000);
    assert.ok((await db.doc(`config/finance/history/${cfg.version}`).get()).exists, 'histórico versionado');
    const neu = await paidOrder(u);
    const a = await order(old.orderId);
    const b = await order(neu.orderId);
    assert.strictEqual(a.financeTerms.commissionBps, 1500);
    assert.strictEqual(b.financeTerms.commissionBps, 1000);
    assert.strictEqual(a.financeTerms.commissionCents, 750); // 15% de 50,00
    assert.strictEqual(b.financeTerms.commissionCents, 500);

    const before = (await wallet(seller.uid)).balanceCents || 0;
    await rejects(call('marketOrderUpdateStatus', u, { orderId: old.orderId, status: 'preparing' }), /PERMISSION_DENIED/);
    await rejects(call('marketOrderUpdateStatus', seller, { orderId: old.orderId, status: 'delivered' }), /Transição inválida/);
    for (const st of ['preparing', 'shipped', 'delivered']) await call('marketOrderUpdateStatus', seller, { orderId: old.orderId, status: st });
    // Auditoria: "entregue" pela loja não libera; o cliente confirma o recebimento.
    assert.strictEqual((await wallet(seller.uid)).balanceCents || 0, before, 'sem repasse antes da confirmação');
    assert.strictEqual((await db.doc(`earnings/${old.orderId}`).get()).data().status, 'pending_release');
    await rejects(call('confirmMarketReceipt', seller, { orderId: old.orderId }), /PERMISSION_DENIED/);
    await call('confirmMarketReceipt', u, { orderId: old.orderId });
    await call('confirmMarketReceipt', u, { orderId: old.orderId }); // idempotente
    const after = (await wallet(seller.uid)).balanceCents;
    assert.strictEqual(after - before, 5000 - 750 + 500, 'líquido = mercadorias − comissão + frete');
    assert.strictEqual((await db.doc(`earnings/${old.orderId}`).get()).data().status, 'released');
    assert.strictEqual((await wallet(u.uid)).balanceCents, 100, 'cashback 2% sobre mercadorias');
    await rejects(call('marketOrderUpdateStatus', seller, { orderId: old.orderId, status: 'delivered' }));
    assert.strictEqual((await wallet(seller.uid)).balanceCents, after, 'liberado uma vez');
    await call('updateFinanceConfig', fin, { commissionBps: 1500 });
  });
});

describe('Cancelamento e reembolso', () => {
  test('13a: cancelamento de pedido pago → reembolso só confirmado pelo gateway', async () => {
    const u = await signUp('c13');
    const p = await paidOrder(u);
    const stockBefore = await stock(P1);
    const r = await call('cancelMarketOrder', u, { orderId: p.orderId, reason: 'Desisti' });
    assert.strictEqual(r.status, 'cancellation_requested');
    let od = await order(p.orderId);
    assert.strictEqual(od.paymentStatus, 'refund_requested', 'NÃO marca reembolsado antes da confirmação');
    assert.strictEqual(od.refundedCents, 0);
    const rf = (await db.doc(`refunds/${r.refundId}`).get()).data();
    assert.strictEqual(rf.status, 'pending_confirmation');
    await call('runPaymentsMaintenance', fin, {});
    assert.strictEqual((await order(p.orderId)).paymentStatus, 'refund_requested', 'gateway ainda processando');

    await approveRefunds(p.paymentId, { full: true });
    await webhook(p.paymentId);
    od = await order(p.orderId);
    assert.strictEqual(od.paymentStatus, 'refunded');
    assert.strictEqual(od.status, 'cancelled');
    assert.strictEqual(od.refundedCents, 5500);
    assert.strictEqual(await stock(P1), stockBefore + 2, 'estoque devolvido');
    assert.strictEqual((await db.doc(`earnings/${p.orderId}`).get()).data().status, 'cancelled', 'comissão/repasse cancelados');
    assert.strictEqual(((await gwStats()).refunds || 0) >= 1, true);
  });

  test('13b: reembolso parcial (admin) e limite do valor pago', async () => {
    const u = await signUp('c13b');
    const p = await paidOrder(u);
    await rejects(call('refundMarketOrder', fin, { orderId: p.orderId, amountCents: 999999 }), /acima do valor pago/);
    const r = await call('refundMarketOrder', fin, { orderId: p.orderId, amountCents: 1000, reason: 'Item avariado' });
    assert.strictEqual((await order(p.orderId)).paymentStatus, 'refund_requested');
    await approveRefunds(p.paymentId, { full: false });
    await webhook(p.paymentId);
    const od = await order(p.orderId);
    assert.strictEqual(od.paymentStatus, 'partially_refunded');
    assert.strictEqual(od.refundedCents, 1000);
    assert.strictEqual(od.status, 'paid', 'parcial não cancela o pedido');
    assert.strictEqual((await db.doc(`refunds/${r.refundId}`).get()).data().status, 'approved');
    const e = (await db.doc(`earnings/${p.orderId}`).get()).data();
    assert.ok(e.netCents < 4750 && e.commissionCents < 750, 'repasse e comissão ajustados proporcionalmente');
    const logs = await db.collection('auditLogs').where('target', '==', p.orderId).get();
    assert.ok(logs.size >= 1, 'auditoria');
  });

  test('13c: aprovação tardia (após cancelamento/expiração) gera reembolso automático e divergência', async () => {
    const u = await signUp('c13c');
    const o = await newOrder(u);
    const pa = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'pix', requestId: rid('pay') });
    const pid = (await attempt(pa.attemptId)).gatewayPaymentId;
    // Corrida: pagador paga enquanto o cliente cancela.
    await gatewaySet(pid, { status: 'approved' });
    await rejects(call('cancelMarketOrder', u, { orderId: o.orderId }), /acabou de ser confirmado/);
    assert.strictEqual((await order(o.orderId)).status, 'paid', 'pagamento confirmado prevalece');

    // Expirado sem conseguir falar com o gateway; aprovação chega depois.
    const o2 = await newOrder(u);
    const pb = await call('startPayment', u, { targetKind: 'market', targetId: o2.orderId, method: 'pix', requestId: rid('pay') });
    const pid2 = (await attempt(pb.attemptId)).gatewayPaymentId;
    await db.doc(`marketOrders/${o2.orderId}`).update({ status: 'expired', stockReleased: true });
    await gatewaySet(pid2, { status: 'approved' });
    await webhook(pid2);
    const od = await order(o2.orderId);
    assert.strictEqual(od.status, 'expired');
    assert.strictEqual(od.paymentStatus, 'approved_late');
    const rf = (await db.doc(`refunds/rf_late_${pb.attemptId}`).get()).data();
    assert.ok(['requested', 'pending_confirmation'].includes(rf.status));
    const iss = await db.collection('financialIssues').where('attemptId', '==', pb.attemptId).get();
    assert.ok(iss.docs.some((d) => d.data().type === 'late_approval'));
    await approveRefunds(pid2, { full: true });
    await webhook(pid2);
    assert.strictEqual((await order(o2.orderId)).paymentStatus, 'refunded');
  });
});

describe('Estorno na carteira', () => {
  test('13d: pedido pago com carteira → cancelamento estorna no saldo uma vez', async () => {
    const u = await signUp('c13d');
    const rc = await call('createWalletRecharge', u, { amountCents: 10000, requestId: rid('rc') });
    const pa = await call('startPayment', u, { targetKind: 'recharge', targetId: rc.rechargeId, method: 'pix', requestId: rid('pay') });
    const pid = (await attempt(pa.attemptId)).gatewayPaymentId;
    await gatewaySet(pid, { status: 'approved' });
    await webhook(pid);
    const o = await newOrder(u); // 55,00
    const w = await call('startPayment', u, { targetKind: 'market', targetId: o.orderId, method: 'wallet', requestId: rid('w') });
    assert.strictEqual(w.status, 'approved');
    assert.strictEqual((await wallet(u.uid)).balanceCents, 4500);
    const r = await call('cancelMarketOrder', u, { orderId: o.orderId });
    assert.strictEqual(r.status, 'cancellation_requested');
    const od = await order(o.orderId);
    assert.strictEqual(od.paymentStatus, 'refunded');
    assert.strictEqual(od.status, 'cancelled');
    assert.strictEqual((await wallet(u.uid)).balanceCents, 10000);
    await call('runPaymentsMaintenance', fin, {});
    assert.strictEqual((await wallet(u.uid)).balanceCents, 10000, 'estorno não duplica');
    const rec = await call('walletReconcile', fin, { userId: u.uid });
    assert.strictEqual(rec.ok, true);
  });
});

describe('Homologação', () => {
  test('15: gateway simulado só no emulador; legados de cobrança desativados', async () => {
    const u = await signUp('c15');
    await rejects(call('generatePix', u, { purpose: 'wallet_recharge', amount: 50 }), /antigo desativado/);
    await rejects(call('processCardPayment', u, { orderId: 'x', cardToken: 't' }), /antigo desativado/);
    const r = await fetch(`${FN}/paymentsWebhook`, { method: 'GET' });
    assert.strictEqual(r.status, 405);
  });
});
