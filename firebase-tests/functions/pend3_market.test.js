'use strict';
/**
 * Pendência 3 (Mercado): loja desativada/não aprovada some da vitrine e
 * não vende; totalProducts recontado pelo servidor (idempotente);
 * reconciliação de produtos/lojas antigos.
 */
const { test, before } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const { FieldValue, FieldPath } = admin.firestore;
const marketModule = require('../../functions/market');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
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
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
const data = async (p) => (await db.doc(p).get()).data() || {};

// Módulo do Mercado num projeto ISOLADO do emulador (sem gatilhos): simula
// dados antigos e reexecução de gatilho chamando a lógica diretamente.
const iso = admin.initializeApp({ projectId: 'demo-pend3-market-iso' }, 'pend3-market-iso').firestore();
const stub = {
  firestore: { document: () => ({ onWrite: (h) => h }) },
  runWith: () => stub, region: () => stub, https: { onCall: (h) => h },
};
const isoMarket = marketModule({ functions: stub, db: iso, FieldValue, FieldPath, requireAuth: () => ({}), isAdmin: async () => true, httpsError: (c, m) => new Error(`${c} ${m}`), REGION: 'us-central1' });
const isoInt = isoMarket.__internals;
const fakeChange = (before, after, ref) => ({
  before: { exists: Boolean(before), data: () => before },
  after: { exists: Boolean(after), data: () => after, ref },
});

const K = `p3m${Date.now().toString(36)}`;
let owner; let buyer; let master;

before(async () => {
  [owner, buyer, master] = await Promise.all(['own', 'buy', 'mst'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', adminRole: 'master', name: 'Master' });
  b.set(db.doc(`publicProfiles/${buyer.uid}`), { name: 'Comprador T.' });
  for (const [id, st] of [['ok', { active: true, verified: true }], ['off', { active: false, verified: true }], ['pend', { active: true, verified: false }]]) {
    b.set(db.doc(`stores/${K}_${id}`), { ownerId: owner.uid, name: `Loja ${id}`, ...st, totalProducts: 0, rating: 0, totalReviews: 0, deliveryFeeCents: 500, pickupEnabled: true, deliveryEnabled: true });
  }
  await b.commit();
  await db.doc('config/finance').delete();
  // Produtos criados como o app (sem storeActive): o gatilho define.
  for (const id of ['ok', 'off', 'pend']) {
    await db.doc(`products/${K}_${id}_p`).set({ storeId: `${K}_${id}`, storeName: `Loja ${id}`, name: `Arroz ${id}`, price: 20, stock: 50, active: true, category: 'market', rating: 0, totalReviews: 0 });
  }
});

test('gatilho define storeActive na criação e a vitrine (storeActive == true) só traz loja ativa e aprovada', async () => {
  assert.ok(await waitFor(async () => (await data(`products/${K}_ok_p`)).storeActive === true), 'loja ok → true');
  assert.ok(await waitFor(async () => (await data(`products/${K}_off_p`)).storeActive === false), 'loja desativada → false');
  assert.ok(await waitFor(async () => (await data(`products/${K}_pend_p`)).storeActive === false), 'loja não aprovada → false');
  const vitrine = await db.collection('products').where('active', '==', true).where('storeActive', '==', true).get();
  const mine = vitrine.docs.map((d) => d.id).filter((id) => id.startsWith(K));
  assert.deepStrictEqual(mine, [`${K}_ok_p`]);
});

test('criar/excluir produto atualiza totalProducts exatamente uma vez', async () => {
  const S = `${K}_ok`;
  assert.ok(await waitFor(async () => (await data(`stores/${S}`)).totalProducts === 1), 'contador = 1');
  const extra = db.doc(`products/${K}_ok_p2`);
  await extra.set({ storeId: S, storeName: 'Loja ok', name: 'Feijão', price: 9, stock: 5, active: true, rating: 0, totalReviews: 0 });
  assert.ok(await waitFor(async () => (await data(`stores/${S}`)).totalProducts === 2), 'contador = 2');
  // Produto desativado sai da contagem; reativado volta.
  await extra.update({ active: false });
  assert.ok(await waitFor(async () => (await data(`stores/${S}`)).totalProducts === 1));
  await extra.update({ active: true });
  assert.ok(await waitFor(async () => (await data(`stores/${S}`)).totalProducts === 2));
  await extra.delete();
  assert.ok(await waitFor(async () => (await data(`stores/${S}`)).totalProducts === 1), 'excluir → 1');
  await sleep(1500);
  assert.strictEqual((await data(`stores/${S}`)).totalProducts, 1, 'sem contagem dupla depois de assentar');
});

test('gatilho reexecutado (2x) não conta em dobro: recálculo por count() é idempotente', async () => {
  const S = 'iso_store';
  await iso.doc(`stores/${S}`).set({ ownerId: 'o', name: 'Iso', active: true, verified: true, totalProducts: 0 });
  const ref = iso.doc('products/iso_p1');
  const p = { storeId: S, name: 'X', price: 1, stock: 1, active: true };
  await ref.set(p);
  const ch = fakeChange(null, p, ref);
  await isoMarket.onProductMarketSync(ch);
  await isoMarket.onProductMarketSync(ch); // reentrega do mesmo evento
  assert.strictEqual((await iso.doc(`stores/${S}`).get()).data().totalProducts, 1);
  assert.strictEqual((await ref.get()).data().storeActive, true);
  assert.strictEqual(await isoInt.recountStore(S), 1);
  assert.strictEqual(await isoInt.recountStore(S), 1);
  await ref.delete();
  const del = fakeChange(p, null, ref);
  await isoMarket.onProductMarketSync(del);
  await isoMarket.onProductMarketSync(del);
  assert.strictEqual((await iso.doc(`stores/${S}`).get()).data().totalProducts, 0);
});

test('desativar a loja oculta os produtos; reativar mostra de novo', async () => {
  const S = `${K}_ok`; const P = `products/${K}_ok_p`;
  await db.doc(`stores/${S}`).update({ active: false });
  assert.ok(await waitFor(async () => (await data(P)).storeActive === false), 'oculto');
  await db.doc(`stores/${S}`).update({ active: true });
  assert.ok(await waitFor(async () => (await data(P)).storeActive === true), 'visível');
  // Admin aprova a loja pendente: produto passa a aparecer.
  await db.doc(`stores/${K}_pend`).update({ verified: true });
  assert.ok(await waitFor(async () => (await data(`products/${K}_pend_p`)).storeActive === true), 'aprovada → visível');
  await db.doc(`stores/${K}_pend`).update({ verified: false });
  assert.ok(await waitFor(async () => (await data(`products/${K}_pend_p`)).storeActive === false), 'reprovada → oculto');
});

test('createMarketOrder e a cotação recusam loja desativada/não aprovada e aceitam a ativa', async () => {
  const order = (id) => call('createMarketOrder', buyer, {
    requestId: rid('ord'), storeId: `${K}_${id}`, items: [{ productId: `${K}_${id}_p`, qty: 1 }], deliveryMode: 'pickup',
  });
  await assert.rejects(order('off'), /FAILED_PRECONDITION.*desativada/);
  await assert.rejects(order('pend'), /FAILED_PRECONDITION.*não foi aprovada/);
  const q = await call('quoteMarketOrder', buyer, { storeId: `${K}_off`, items: [{ productId: `${K}_off_p`, qty: 1 }], deliveryMode: 'pickup' });
  assert.strictEqual(q.ok, false);
  assert.match(q.errors.join(), /desativada/);
  const stockBefore = (await data(`products/${K}_off_p`)).stock;
  assert.strictEqual(stockBefore, 50, 'recusa não reserva estoque');
  const ok = await order('ok');
  assert.strictEqual(ok.status, 'pending_payment');
  assert.strictEqual((await data(`marketOrders/${ok.orderId}`)).storeId, `${K}_ok`);
});

test('reconciliação corrige storeActive e totalProducts de dados antigos (idempotente, com relatório)', async () => {
  // Dados antigos no projeto isolado: sem storeActive e contadores errados
  // (ex.: increments duplicados do app antigo).
  const b = iso.batch();
  b.set(iso.doc('stores/old_ok'), { ownerId: 'o', name: 'Antiga ok', active: true, verified: true, totalProducts: 7 });
  b.set(iso.doc('stores/old_off'), { ownerId: 'o', name: 'Antiga off', active: false, verified: true, totalProducts: -1 });
  b.set(iso.doc('stores/old_pend'), { ownerId: 'o', name: 'Antiga pend', active: true });
  for (let i = 0; i < 3; i++) b.set(iso.doc(`products/old_ok_${i}`), { storeId: 'old_ok', name: `P${i}`, price: 1, stock: 1, active: true });
  b.set(iso.doc('products/old_ok_inativo'), { storeId: 'old_ok', name: 'Inativo', price: 1, stock: 1, active: false });
  b.set(iso.doc('products/old_off_0'), { storeId: 'old_off', name: 'Off', price: 1, stock: 1, active: true, storeActive: true });
  b.set(iso.doc('products/old_pend_0'), { storeId: 'old_pend', name: 'Pend', price: 1, stock: 1, active: true });
  b.set(iso.doc('products/sem_loja'), { name: 'Órfão', price: 1, stock: 1, active: true });
  await b.commit();

  const dry = await isoInt.reconcileMarket({ dryRun: true });
  assert.ok(dry.productsFixed >= 7 && dry.countersFixed >= 2, JSON.stringify(dry));
  assert.strictEqual((await iso.doc('stores/old_ok').get()).data().totalProducts, 7, 'dryRun não grava');

  const r1 = await isoInt.reconcileMarket();
  assert.ok(r1.products >= 7 && r1.stores >= 3, JSON.stringify(r1));
  const st = async (id) => (await iso.doc(`products/${id}`).get()).data().storeActive;
  for (let i = 0; i < 3; i++) assert.strictEqual(await st(`old_ok_${i}`), true);
  assert.strictEqual(await st('old_off_0'), false, 'loja desativada');
  assert.strictEqual(await st('old_pend_0'), false, 'loja não aprovada');
  assert.strictEqual(await st('sem_loja'), false, 'sem loja');
  assert.strictEqual((await iso.doc('stores/old_ok').get()).data().totalProducts, 3, 'só ativos');
  assert.strictEqual((await iso.doc('stores/old_off').get()).data().totalProducts, 1);
  assert.strictEqual((await iso.doc('stores/old_pend').get()).data().totalProducts, 1);
  assert.strictEqual((await iso.doc('config/market').get()).data().storeActiveReady, true);

  const r2 = await isoInt.reconcileMarket();
  assert.strictEqual(r2.productsFixed, 0, 'segunda passada não muda nada');
  assert.strictEqual(r2.countersFixed, 0);
});

test('reconciliação registrada: adminRunMaintenance(marketReconcile) e adminReconcileMarket só para admin', async () => {
  const S = `${K}_ok`;
  // Contador corrompido (o gatilho da loja não reconta quando só o contador muda).
  await db.doc(`stores/${S}`).update({ totalProducts: 42 });
  const out = await call('adminRunMaintenance', master, { jobs: ['marketReconcile'] });
  assert.ok(out.marketReconcile && !out.marketReconcile.error, JSON.stringify(out));
  assert.ok(out.marketReconcile.countersFixed >= 1);
  assert.strictEqual((await data(`stores/${S}`)).totalProducts, 1);
  assert.strictEqual((await data('config/market')).storeActiveReady, true);
  const dry = await call('adminReconcileMarket', master, { dryRun: true });
  assert.strictEqual(dry.dryRun, true);
  await assert.rejects(call('adminReconcileMarket', buyer, {}), /PERMISSION_DENIED/);
});
