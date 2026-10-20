'use strict';
/**
 * Pendências 3 — prazo de aceite de pedidos de serviço (expiresAt).
 * expiresAt gravado pelo servidor na criação (cliente não forja), aceite
 * recusado após o prazo ("Este pedido expirou"), tarefa de expiração
 * idempotente, migração de pedidos antigos e corrida aceite × expiração.
 */
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');
const { initializeApp, deleteApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInWithEmailAndPassword } = require('firebase/auth');
const {
  getFirestore, connectFirestoreEmulator, collection, addDoc, doc: cdoc, updateDoc, serverTimestamp, Timestamp: CTs,
} = require('firebase/firestore');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const MIN = 60000; const H = 60 * MIN; const D = 24 * H;

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken, email };
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
async function waitFor(fn, ms = 12000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
const clientApps = [];
/** Firestore do app (SDK cliente, regras aplicadas) autenticado como `u`. */
async function clientDb(u) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'demo' }, `pend3_${u.uid}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${AUTH}`, { disableWarnings: true });
  await signInWithEmailAndPassword(auth, u.email, 'Senha123!');
  const fdb = getFirestore(app);
  connectFirestoreEmulator(fdb, '127.0.0.1', 8080);
  clientApps.push(app);
  return fdb;
}
async function setClock(offsetMs) {
  await db.doc('_testClock/current').set({ offsetMs });
  await sleep(1300); // cache de 1 s em functions/clock.js
}
const get = async (id) => (await db.doc(`orders/${id}`).get()).data();
const runJobs = (...jobs) => call('adminRunMaintenance', master, { jobs });

const K = `p3x${Date.now().toString(36)}`;
const CAT = `${K}_eletrica`;
let cli; let pro; let master; let cdb;

before(async () => {
  [cli, pro, master] = await Promise.all(['cli', 'pro', 'mst'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${cli.uid}`), { type: 'client', name: 'Cliente Prazo' });
  b.set(db.doc(`users/${pro.uid}`), { type: 'provider', name: 'Pedro Eletricista' });
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', adminRole: 'master', name: 'Master' });
  b.set(db.doc(`providers/${pro.uid}`), { userId: pro.uid, name: 'Pedro', verified: true, active: true, categories: [CAT] });
  b.set(db.doc(`catalogNodes/${CAT}`), { level: 'category', name: 'Elétrica P3', active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: FieldValue.increment(1) }, { merge: true });
  await b.commit();
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  await setClock(0);
  cdb = await clientDb(cli);
});
after(async () => {
  await setClock(0);
  // SDK cliente mantém conexões abertas: sem isso o processo não termina.
  await Promise.all(clientApps.map((a) => deleteApp(a)));
});

const clientOrder = (extra = {}) => addDoc(collection(cdb, 'orders'), {
  clientId: cli.uid, providerId: pro.uid, category: CAT, title: 'Trocar tomada', description: 'Sala',
  address: 'Rua 1', status: 'pending', paymentStatus: 'unpaid', createdAt: serverTimestamp(), ...extra,
});
/** Pedido gravado pelo servidor (admin), com datas no passado/futuro. */
async function adminOrder(extra = {}) {
  const ref = db.collection('orders').doc();
  await ref.set({
    clientId: cli.uid, providerId: pro.uid, category: CAT, title: 'Pedido teste', description: 'x', address: 'Rua 2',
    status: 'pending', paymentStatus: 'unpaid', price: 120, createdAt: Timestamp.now(), ...extra,
  });
  return ref.id;
}
const accept = (id) => call('transitionOrder', pro, { orderId: id, action: 'accept', price: 150 });

test('expiresAt é gravado pelo servidor na criação (createdAt + 7 dias) e o cliente não o forja', async () => {
  const ref = await clientOrder();
  const o = await waitFor(async () => { const d = await get(ref.id); return d && d.expiresAt ? d : null; });
  assert.ok(o, 'expiresAt gravado pelo gatilho');
  const delta = o.expiresAt.toMillis() - o.createdAt.toMillis();
  assert.ok(Math.abs(delta - 7 * D) < 2 * MIN, `prazo de 7 dias (delta ${delta})`);

  // Criar com expiresAt (ou flags de expiração) é negado pelas regras.
  await assert.rejects(clientOrder({ expiresAt: CTs.fromMillis(Date.now() + 365 * D) }), /permission/i);
  await assert.rejects(clientOrder({ expired: false }), /permission/i);
  // createdAt no futuro não estende o prazo: vale o relógio do servidor.
  const fut = await clientOrder({ createdAt: CTs.fromMillis(Date.now() + 30 * D) });
  const f = await waitFor(async () => { const d = await get(fut.id); return d && d.expiresAt ? d : null; });
  assert.ok(f.expiresAt.toMillis() <= Date.now() + 7 * D + 2 * MIN, 'prazo não estendido');
  // Alterar expiresAt depois também é negado.
  await assert.rejects(updateDoc(cdoc(cdb, 'orders', ref.id), { expiresAt: CTs.fromMillis(Date.now() + 365 * D) }), /permission/i);
  assert.strictEqual((await get(ref.id)).expiresAt.toMillis(), o.expiresAt.toMillis());
});

test('aceite antes do prazo funciona', async () => {
  const ref = await clientOrder();
  await waitFor(async () => (await get(ref.id) || {}).expiresAt);
  const r = await accept(ref.id);
  assert.strictEqual(r.status, 'accepted');
  assert.strictEqual((await get(ref.id)).status, 'accepted');
});

test('após o prazo o prestador não aceita nem recusa ("Este pedido expirou"); o cliente ainda cancela', async () => {
  const id = await adminOrder({ createdAt: Timestamp.fromMillis(Date.now() - 8 * D), expiresAt: Timestamp.fromMillis(Date.now() - D) });
  await assert.rejects(accept(id), /FAILED_PRECONDITION Este pedido expirou/);
  await assert.rejects(call('transitionOrder', pro, { orderId: id, action: 'decline' }), /Este pedido expirou/);
  await assert.rejects(call('transitionOrder', pro, { orderId: id, action: 'cancel' }), /Este pedido expirou/);
  assert.strictEqual((await get(id)).status, 'pending', 'recusa não muda o pedido');
  const r = await call('transitionOrder', cli, { orderId: id, action: 'cancel', reason: 'Desisti' });
  assert.strictEqual(r.status, 'cancelled');
});

test('com o relógio do servidor avançado 7 dias o aceite é recusado (expiresAt gravado na criação)', async () => {
  const ref = await clientOrder();
  await waitFor(async () => (await get(ref.id) || {}).expiresAt);
  try {
    await setClock(7 * D + MIN);
    await assert.rejects(accept(ref.id), /Este pedido expirou/);
  } finally {
    await setClock(0);
  }
  // Relógio de volta: o mesmo pedido volta a ser aceitável (o servidor decide pelo prazo gravado).
  assert.strictEqual((await accept(ref.id)).status, 'accepted');
});

test('tarefa de expiração: só o devido, pago fica para o suporte, migração de antigos e idempotência', async () => {
  const now = Date.now();
  const due = await adminOrder({ expiresAt: Timestamp.fromMillis(now - MIN) });
  const notYet = await adminOrder({ expiresAt: Timestamp.fromMillis(now + D) });
  const accepted = await adminOrder({ status: 'accepted', expiresAt: Timestamp.fromMillis(now - D) });
  const paid = await adminOrder({ paymentStatus: 'paid', expiresAt: Timestamp.fromMillis(now - MIN) });
  // Antigo sem expiresAt (o gatilho grava; removemos para simular dado legado).
  const legacy = await adminOrder({ createdAt: Timestamp.fromMillis(now - 8 * D) });
  const legacyFresh = await adminOrder({ createdAt: Timestamp.fromMillis(now - D) });
  for (const id of [legacy, legacyFresh]) {
    assert.ok(await waitFor(async () => (await get(id)).expiresAt), 'gatilho gravou expiresAt');
    await db.doc(`orders/${id}`).update({ expiresAt: FieldValue.delete() });
  }

  const mig = (await runJobs('backfillOrderExpiry')).backfillOrderExpiry;
  assert.ok(mig.done && mig.updated >= 2, JSON.stringify(mig));
  assert.strictEqual((await get(legacy)).expiresAt.toMillis(), now - 8 * D + 7 * D, 'createdAt + 7 dias');
  assert.strictEqual((await get(legacyFresh)).expiresAt.toMillis(), now - D + 7 * D);
  const mig2 = (await runJobs('backfillOrderExpiry')).backfillOrderExpiry;
  assert.ok(mig2.done, 'migração idempotente');
  assert.strictEqual((await get(legacy)).expiresAt.toMillis(), now - D);

  const r1 = (await runJobs('expireServiceOrders')).expireServiceOrders;
  assert.ok(r1.expired >= 2 && r1.paidKept >= 1, JSON.stringify(r1));
  for (const id of [due, legacy]) {
    const o = await get(id);
    assert.strictEqual(o.status, 'cancelled', id);
    assert.strictEqual(o.cancelReason, 'Expirado automaticamente');
    assert.strictEqual(o.expired, true);
    assert.strictEqual(o.cancelledBy, 'system');
    assert.ok(o.expiredAt);
  }
  assert.strictEqual((await get(notYet)).status, 'pending');
  assert.strictEqual((await get(legacyFresh)).status, 'pending');
  assert.strictEqual((await get(accepted)).status, 'accepted');
  const p = await get(paid);
  assert.strictEqual(p.status, 'pending', 'pago não é cancelado em silêncio');
  assert.strictEqual(p.paymentStatus, 'paid');
  const issue = (await db.doc(`financialIssues/order_expired_${paid}`).get()).data();
  assert.strictEqual(issue.type, 'service_order_expired_paid');
  await assert.rejects(accept(paid), /Este pedido expirou/);

  // Rodar de novo não muda nada (nem duplica o registro do suporte).
  const firstExpiredAt = (await get(due)).expiredAt.toMillis();
  await runJobs('expireServiceOrders');
  assert.strictEqual((await get(due)).expiredAt.toMillis(), firstExpiredAt);
  assert.strictEqual((await get(accepted)).status, 'accepted');
  const issues = await db.collection('financialIssues').where('targetId', '==', paid).get();
  assert.strictEqual(issues.size, 1);
  // Expirado não é aceito depois.
  await assert.rejects(accept(due), /Transição de status inválida|expirou/);
});

test('corrida aceite × expiração: o pedido termina em exatamente um dos dois estados, coerente', async () => {
  for (let i = 0; i < 4; i++) {
    const exp = Date.now() + 2500;
    const id = await adminOrder({ expiresAt: Timestamp.fromMillis(exp) });
    await sleep(Math.max(0, exp - Date.now() - 40 + i * 30));
    const [a, j] = await Promise.allSettled([accept(id), runJobs('expireServiceOrders')]);
    assert.strictEqual(j.status, 'fulfilled');
    // Se nenhum venceu (aceite após o prazo e tarefa antes dele), a próxima rodada decide.
    if ((await get(id)).status === 'pending') await runJobs('expireServiceOrders');
    const o = await get(id);
    if (a.status === 'fulfilled') {
      assert.strictEqual(o.status, 'accepted');
      assert.ok(o.acceptedAt);
      assert.strictEqual(o.expired, undefined, 'aceito não é expirado');
    } else {
      assert.match(a.reason.message, /Este pedido expirou|Transição de status inválida/);
      assert.strictEqual(o.status, 'cancelled');
      assert.strictEqual(o.expired, true);
      assert.strictEqual(o.acceptedAt, undefined, 'expirado não foi aceito');
    }
    // Rodadas seguintes não mudam o desfecho.
    await runJobs('expireServiceOrders');
    assert.strictEqual((await get(id)).status, o.status);
  }
});
