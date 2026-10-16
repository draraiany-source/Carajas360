'use strict';
/**
 * Integração das correções da auditoria completa (pós-Fase 7), no
 * emulador: pedidos de serviço, notificações, suspensão, reverificação
 * de prestador, cupom, locação e endpoints legados.
 */
const { test } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p) => `${p}_${crypto.randomBytes(6).toString('hex')}`;

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
async function waitFor(fn, ms = 12000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
const balance = async (uid) => ((await db.doc(`wallets/${uid}`).get()).data() || {}).balanceCents || 0;

async function verifiedProvider(tag) {
  const p = await signUp(tag);
  await db.doc(`users/${p.uid}`).set({ type: 'provider', name: `Pro ${tag}` });
  await db.doc(`providers/${p.uid}`).set({ userId: p.uid, name: `Pro ${tag}`, verified: true, active: true, categories: ['eletricista'] });
  return p;
}
/** Pedido já pago (espelho de pagamento aprovado, como o fluxo legado). */
async function paidOrder(client, pro, { status = 'inProgress', price = 100 } = {}) {
  const id = rid('o');
  const payId = `wallet_${id}`;
  await db.doc(`payments/${payId}`).set({ orderId: id, userId: client.uid, amount: price, method: 'wallet', status: 'approved' });
  await db.doc(`orders/${id}`).set({ clientId: client.uid, providerId: pro.uid, status, price, paymentStatus: 'paid', transactionId: payId, payoutProcessed: false, title: 'Serviço' });
  return id;
}

test('aceite: cliente não aceita o próprio pedido; prestador não aprovado não aceita; orçamento obrigatório e limitado', async () => {
  const cli = await signUp('acli');
  const pro = await verifiedProvider('apro');
  const fake = await signUp('afake');
  await db.doc(`providers/${fake.uid}`).set({ userId: fake.uid, name: 'Falso', verified: false, active: false, categories: [] });
  const id = rid('o');
  await db.doc(`orders/${id}`).set({ clientId: cli.uid, status: 'pending', paymentStatus: 'unpaid', title: 'X' });
  await assert.rejects(call('transitionOrder', cli, { orderId: id, action: 'accept', price: 1 }), /PERMISSION_DENIED/);
  await assert.rejects(call('transitionOrder', fake, { orderId: id, action: 'accept', price: 100 }), /PERMISSION_DENIED/);
  await assert.rejects(call('transitionOrder', pro, { orderId: id, action: 'accept' }), /INVALID_ARGUMENT/);
  await assert.rejects(call('transitionOrder', pro, { orderId: id, action: 'accept', price: 1e308 }), /INVALID_ARGUMENT/);
  await call('transitionOrder', pro, { orderId: id, action: 'accept', price: 150 });
  const o = (await db.doc(`orders/${id}`).get()).data();
  assert.strictEqual(o.price, 150);
  assert.strictEqual(o.providerId, pro.uid);
  await assert.rejects(call('transitionOrder', pro, { orderId: 'a/b', action: 'start' }), /INVALID_ARGUMENT/);
});

test('conclusão: prestador marca feito; repasse só quando o cliente confirma', async () => {
  const cli = await signUp('ccli');
  const pro = await verifiedProvider('cpro');
  const id = await paidOrder(cli, pro);
  const before = await balance(pro.uid);
  const r = await call('transitionOrder', pro, { orderId: id, action: 'complete' });
  assert.strictEqual(r.awaitingClientConfirmation, true);
  let o = (await db.doc(`orders/${id}`).get()).data();
  assert.strictEqual(o.status, 'inProgress');
  assert.strictEqual(o.awaitingClientConfirmation, true);
  assert.ok(o.autoConfirmAfter.toMillis() > Date.now() + 71 * 3600000);
  assert.strictEqual(await balance(pro.uid), before, 'sem repasse ainda');
  await call('transitionOrder', cli, { orderId: id, action: 'complete' });
  o = (await db.doc(`orders/${id}`).get()).data();
  assert.strictEqual(o.status, 'completed');
  assert.strictEqual(o.payoutProcessed, true);
  assert.strictEqual(await balance(pro.uid) - before, 8500);
});

test('cancelar pedido pago devolve o valor ao cliente (antes ficava retido)', async () => {
  const cli = await signUp('rcli');
  const pro = await verifiedProvider('rpro');
  const id = await paidOrder(cli, pro, { status: 'accepted', price: 80 });
  const before = await balance(cli.uid);
  await call('transitionOrder', cli, { orderId: id, action: 'cancel', reason: 'x'.repeat(5000) });
  const o = (await db.doc(`orders/${id}`).get()).data();
  assert.strictEqual(o.status, 'cancelled');
  assert.strictEqual(o.paymentStatus, 'refunded');
  assert.ok(o.cancelReason.length <= 300, 'motivo limitado');
  assert.strictEqual(await balance(cli.uid) - before, 8000);
});

test('cancelar com cobrança em andamento é recusado', async () => {
  const cli = await signUp('pcli');
  const pro = await verifiedProvider('ppro');
  const id = rid('o');
  await db.doc(`orders/${id}`).set({ clientId: cli.uid, providerId: pro.uid, status: 'accepted', price: 50, paymentStatus: 'pending', activeAttemptId: 'pa_x' });
  await assert.rejects(call('transitionOrder', cli, { orderId: id, action: 'cancel' }), /pagamento em andamento/);
});

test('pagamento legado pela carteira desativado (cobrança dupla)', async () => {
  const cli = await signUp('lcli');
  await assert.rejects(call('payOrderWithWallet', cli, { orderId: 'qualquer' }), /FAILED_PRECONDITION/);
});

test('notificação: sala de chat criada pelo próprio usuário não autoriza push', async () => {
  const a = await signUp('na');
  const v = await signUp('nv');
  const ids = [a.uid, v.uid].sort();
  await db.doc(`chatRooms/${ids.join('_')}`).set({ participants: ids });
  await assert.rejects(call('createNotification', a, { userId: v.uid, title: 'Seu banco', body: 'Clique aqui' }), /PERMISSION_DENIED/);
});

test('mensagem de chat gera aviso para o outro participante pelo servidor', async () => {
  const a = await signUp('ma');
  const b = await signUp('mb');
  const ids = [a.uid, b.uid].sort();
  await db.doc(`chatRooms/${ids.join('_')}`).set({ participants: ids });
  await db.collection(`chatRooms/${ids.join('_')}/messages`).add({ senderId: a.uid, text: 'Olá', read: false, createdAt: new Date() });
  const n = await waitFor(async () => {
    const s = await db.collection('notifications').where('userId', '==', b.uid).where('type', '==', 'chat').get();
    return s.empty ? null : s.docs[0].data();
  });
  assert.ok(n, 'destinatário avisado');
  assert.strictEqual(n.body, 'Olá');
});

test('suspensão desativa a conta no Auth e reativação desfaz (só admin)', async () => {
  const adm = await signUp('sadm');
  await db.doc(`users/${adm.uid}`).set({ type: 'admin' });
  const u = await signUp('susp');
  await db.doc(`users/${u.uid}`).set({ type: 'client', status: 'active' });
  await assert.rejects(call('setUserSuspended', u, { userId: adm.uid, suspended: true }), /PERMISSION_DENIED/);
  await call('setUserSuspended', adm, { userId: u.uid, suspended: true });
  assert.strictEqual((await admin.auth().getUser(u.uid)).disabled, true);
  assert.strictEqual((await db.doc(`users/${u.uid}`).get()).data().status, 'suspended');
  await call('setUserSuspended', adm, { userId: u.uid, suspended: false });
  assert.strictEqual((await admin.auth().getUser(u.uid)).disabled, false);
});

test('prestador aprovado que muda nome ou inclui especialidade volta para análise', async () => {
  const pro = await verifiedProvider('vpro');
  await db.doc(`providers/${pro.uid}`).update({ categories: ['eletricista', 'cardiologia'] });
  const p = await waitFor(async () => {
    const d = (await db.doc(`providers/${pro.uid}`).get()).data();
    return d.verified === false ? d : null;
  });
  assert.ok(p, 'selo removido');
  assert.strictEqual(p.verificationStatus, 'pending_review');
});

test('cupom validado no servidor', async () => {
  const u = await signUp('cup');
  const exp = new Date(Date.now() + 7 * 24 * 3600 * 1000); // validade obrigatória (mesma regra do checkout)
  await db.collection('coupons').add({ code: 'AUDIT10', discount: 10, isPercentage: true, active: true, description: '10% off', expiresAt: exp });
  await db.collection('coupons').add({ code: 'QUEBRADO', discount: 150, isPercentage: true, active: true, expiresAt: exp });
  await db.collection('coupons').add({ code: 'SEMVALIDADE', discount: 10, isPercentage: true, active: true });
  assert.strictEqual((await call('checkCoupon', u, { code: 'SEMVALIDADE' })).valid, false, 'sem validade é recusado como no checkout');
  const ok = await call('checkCoupon', u, { code: 'audit10' });
  assert.strictEqual(ok.valid, true);
  assert.strictEqual(ok.discount, 10);
  assert.strictEqual((await call('checkCoupon', u, { code: 'NAOEXISTE' })).valid, false);
  assert.strictEqual((await call('checkCoupon', u, { code: 'QUEBRADO' })).valid, false, '>100% é inválido');
});

test('locação: reserva pendente cujo início passou não pode mais ser confirmada', async () => {
  const owner = await signUp('rown');
  const cli = await signUp('rcli2');
  const rentalId = rid('r');
  await db.doc(`rentals/${rentalId}`).set({ ownerId: owner.uid, title: 'Hilux', active: true });
  const bk = rid('bk');
  await db.doc(`bookings/${bk}`).set({ rentalId, ownerId: owner.uid, clientId: cli.uid, status: 'pending', startMs: Date.now() - 3600000, endMs: Date.now() + 86400000, rentalTitle: 'Hilux' });
  await assert.rejects(call('transitionRentalBooking', owner, { bookingId: bk, action: 'confirm' }), /início da reserva já passou/);
  await assert.rejects(call('transitionRentalBooking', owner, { bookingId: '../x', action: 'confirm' }), /INVALID_ARGUMENT/);
});

test('exclusão da conta no Auth remove o perfil e os favoritos no servidor', async () => {
  const u = await signUp('del');
  await db.doc(`users/${u.uid}`).set({ type: 'client', name: 'Some Pessoa', phone: '9499' });
  await db.doc(`favorites/${u.uid}_x`).set({ userId: u.uid, providerId: 'x' });
  await admin.auth().deleteUser(u.uid);
  assert.ok(await waitFor(async () => !(await db.doc(`users/${u.uid}`).get()).exists), 'perfil removido');
  assert.ok(await waitFor(async () => !(await db.doc(`favorites/${u.uid}_x`).get()).exists), 'favoritos removidos');
});
