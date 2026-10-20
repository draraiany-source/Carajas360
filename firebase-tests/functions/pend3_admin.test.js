'use strict';
/** Pend. 3 (admin): indicadores e relatório financeiro por agregação no servidor. */
const { test, before } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const { Timestamp } = admin.firestore;
const DAY = 24 * 3600 * 1000;

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken };
}
async function call(name, user, data) {
  const r = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${user.token}` },
    body: JSON.stringify({ data: data || {} }),
  });
  const j = await r.json();
  if (j.error) throw new Error(`${j.error.status} ${j.error.message}`);
  return j.result;
}
const near = (a, b, msg) => assert.ok(Math.abs(a - b) < 0.005, `${msg}: ${a} ≠ ${b}`);

const K = `p3a${Date.now().toString(36)}`;
let master; let support; let financial; let plain;
let base; let base30; let baseDash;

before(async () => {
  [master, support, financial, plain] = await Promise.all(['mst', 'sup', 'fin', 'pla'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', name: 'Master', createdAt: Timestamp.now() });
  b.set(db.doc(`users/${support.uid}`), { type: 'admin', adminRole: 'support', name: 'Sup', createdAt: Timestamp.now() });
  b.set(db.doc(`users/${financial.uid}`), { type: 'admin', adminRole: 'financial', name: 'Fin', createdAt: Timestamp.now() });
  b.set(db.doc(`users/${plain.uid}`), { type: 'client', name: 'Cliente', createdAt: Timestamp.now() });
  await b.commit();
  // Agregados são da base inteira: compara a variação após semear.
  [base, base30, baseDash] = await Promise.all([
    call('adminFinancialReport', master), call('adminFinancialReport', master, { periodDays: 30 }), call('adminDashboardStats', master),
  ]);
  const now = Timestamp.now();
  const old = Timestamp.fromMillis(Date.now() - 60 * DAY);
  const s = db.batch();
  // Concluídos com repasse registrado (comissão e líquido gravados no servidor).
  [[100, 15, 85], [200, 30, 170], [50.5, 7.58, 42.92]].forEach(([price, commission, providerAmount], i) =>
    s.set(db.doc(`orders/${K}_ok${i}`), { status: 'completed', price, commission, providerAmount, payoutProcessed: true, completedAt: now, createdAt: now }));
  // Concluído antigo, sem repasse registrado (fora da janela de 30 dias).
  s.set(db.doc(`orders/${K}_legacy`), { status: 'completed', price: 40, completedAt: old, createdAt: old });
  s.set(db.doc(`orders/${K}_pend`), { status: 'pending', price: 999, createdAt: now });
  s.set(db.doc(`refunds/${K}_r1`), { status: 'approved', amountCents: 1500, confirmedAt: now, createdAt: now });
  s.set(db.doc(`refunds/${K}_r2`), { status: 'approved', amountCents: 250, confirmedAt: old, createdAt: old });
  s.set(db.doc(`refunds/${K}_r3`), { status: 'requested', amountCents: 9999, createdAt: now });
  s.set(db.doc(`transactions/${K}_t1`), { type: 'recharge', amount: 20, amountCents: 2000, createdAt: now });
  s.set(db.doc(`transactions/${K}_t2`), { type: 'payment', amount: 500, amountCents: 50000, createdAt: now });
  s.set(db.doc(`providers/${K}_pv1`), { userId: `${K}_pv1`, name: 'P1', verified: true, active: true });
  s.set(db.doc(`providers/${K}_pv2`), { userId: `${K}_pv2`, name: 'P2', verified: false, active: false });
  for (let i = 0; i < 5; i++) s.set(db.doc(`users/${K}_u${i}`), { type: 'client', name: `U${i}`, createdAt: now });
  s.set(db.doc(`users/${K}_uold`), { type: 'client', name: 'Antigo', createdAt: old });
  await s.commit();
});

test('indicadores do painel batem com os dados semeados (qualquer admin)', async () => {
  const k = await call('adminDashboardStats', support);
  assert.deepStrictEqual(k.unavailable, []);
  assert.strictEqual(k.totalUsers - baseDash.totalUsers, 6);
  assert.strictEqual(k.newUsersThisWeek - baseDash.newUsersThisWeek, 5);
  assert.strictEqual(k.totalProviders - baseDash.totalProviders, 1, 'só verificados');
  assert.strictEqual(k.completedOrders - baseDash.completedOrders, 4);
  near(k.revenue - baseDash.revenue, 390.5, 'GMV dos concluídos');
});

test('relatório financeiro: GMV, comissão, repasses, recargas e reembolsos aprovados', async () => {
  const r = await call('adminFinancialReport', financial);
  assert.deepStrictEqual(r.unavailable, []);
  assert.strictEqual(r.periodDays, null);
  near(r.grossRevenue - base.grossRevenue, 390.5, 'GMV');
  assert.strictEqual(r.completedCount - base.completedCount, 4);
  near(r.commission - base.commission, 52.58, 'comissão registrada');
  near(r.netToProviders - base.netToProviders, 297.92, 'repasses');
  assert.strictEqual(r.ordersWithoutCommission - base.ordersWithoutCommission, 1, 'pedido antigo sem repasse');
  near(r.pixProcessed - base.pixProcessed, 20, 'recargas');
  near(r.refunds - base.refunds, 17.5, 'só reembolsos aprovados');
  assert.strictEqual(r.refundsCount - base.refundsCount, 2);
});

test('relatório por período (30 dias) exclui eventos antigos', async () => {
  const r = await call('adminFinancialReport', master, { periodDays: 30 });
  assert.strictEqual(r.periodDays, 30);
  assert.deepStrictEqual(r.unavailable, []);
  near(r.grossRevenue - base30.grossRevenue, 350.5, 'GMV 30d');
  assert.strictEqual(r.completedCount - base30.completedCount, 3);
  assert.strictEqual(r.ordersWithoutCommission - base30.ordersWithoutCommission, 0);
  near(r.refunds - base30.refunds, 15, 'reembolsos 30d');
  await assert.rejects(call('adminFinancialReport', master, { periodDays: 0.5 }), /INVALID_ARGUMENT/);
  await assert.rejects(call('adminFinancialReport', master, { periodDays: 400 }), /INVALID_ARGUMENT/);
});

test('acesso: não-admin negado; admin sem perfil financeiro não vê o relatório', async () => {
  await assert.rejects(call('adminDashboardStats', plain), /PERMISSION_DENIED/);
  await assert.rejects(call('adminFinancialReport', plain), /PERMISSION_DENIED/);
  await assert.rejects(call('adminFinancialReport', support), /PERMISSION_DENIED.*financeiro/);
  const r = await fetch(`${FN}/adminDashboardStats`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"data":{}}' });
  assert.strictEqual((await r.json()).error.status, 'UNAUTHENTICATED');
});
