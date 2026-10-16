'use strict';
/**
 * Fluxos de homologação no emulador (contas separadas de cliente,
 * prestador, loja e admin), com o gateway simulado e o RELÓGIO
 * CONTROLADO (`_testClock/current.offsetMs`, só com TEST_CLOCK=true no
 * emulador). Os prazos reais (15 min, 72 h, 7 dias) não mudam: o teste
 * adianta o relógio do servidor e executa as tarefas agendadas pela
 * callable admin `adminRunMaintenance`.
 */
const { test, describe, before, after } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const hc = require('../../functions/healthCore');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
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
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
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
let gwClock = Date.now() + 10 * H;
async function gatewaySet(paymentId, patch) {
  gwClock += 5000;
  await db.doc(`_fakeGateway/${paymentId}`).update({ ...patch, date_last_updated: new Date(gwClock).toISOString() });
}
/** Relógio do servidor (só emulador): desloca o "agora" das functions. */
async function setClock(offsetMs) {
  await db.doc('_testClock/current').set({ offsetMs });
  await sleep(1300); // cache de 1 s em functions/clock.js
}
const doc = (p) => db.doc(p).get().then((s) => s.data());
const balance = async (uid) => ((await doc(`wallets/${uid}`)) || {}).balanceCents || 0;
const attempt = (id) => doc(`paymentAttempts/${id}`);
const notifs = async (uid, type) => (await db.collection('notifications').where('userId', '==', uid).where('type', '==', type).get()).docs.map((d) => d.data());

const K = `hml${Date.now().toString(36)}`;
const SAUDE = `${K}_saude`; const CARDIO = `${K}_cardio`;
const TOMORROW = hc.localDateOf(Date.now() + 30 * H);
const at = (hhmm, date = TOMORROW) => hc.localToUtc(date, hc.hm(hhmm));
const STORE = `${K}_loja`; const PROD = `${K}_arroz`;

let adm; let master; let doctor; let owner; let seller; let pro;
const clients = [];
async function client(tag) { const u = await signUp(tag); await db.doc(`users/${u.uid}`).set({ type: 'client', name: `Cliente ${tag} Silva` }); clients.push(u); return u; }

before(async () => {
  [adm, master, doctor, owner, seller, pro] = await Promise.all(['adm', 'master', 'doc', 'own', 'sel', 'pro'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${adm.uid}`), { type: 'admin', adminRole: 'support', name: 'Suporte' });
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', adminRole: 'master', name: 'Master' });
  b.set(db.doc(`users/${doctor.uid}`), { type: 'provider', name: 'Dra. Ana Lima' });
  b.set(db.doc(`users/${pro.uid}`), { type: 'provider', name: 'João Eletricista' });
  b.set(db.doc(`catalogNodes/${SAUDE}`), { level: 'category', name: 'Saúde H', vertical: 'health', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${CARDIO}`), { level: 'group', name: 'Cardiologia H', parentId: SAUDE, active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  b.set(db.doc(`providers/${doctor.uid}`), { userId: doctor.uid, name: 'Dra. Ana', verified: true, active: true, categories: [CARDIO], modalities: ['online'] });
  const weekly = {};
  for (let d = 0; d < 7; d++) weekly[d] = [{ start: '08:00', end: '18:00' }];
  b.set(db.doc(`healthSchedules/${doctor.uid}`), { slotMinutes: 30, minLeadHours: 2, weekly, blockedDates: [], services: [{ catalogId: CARDIO, durationMin: 30, priceCents: 15000, modalities: ['online'] }] });
  b.set(db.doc(`rentals/${K}_car`), { ownerId: owner.uid, title: 'Hilux H', category: 'pickup', kind: 'vehicle', pricePerDay: 300, active: true, available: true, createdAt: new Date() });
  b.set(db.doc(`stores/${STORE}`), { ownerId: seller.uid, name: 'Mercado H', active: true, deliveryFeeCents: 500, pickupEnabled: true, deliveryEnabled: true });
  b.set(db.doc(`products/${PROD}`), { storeId: STORE, name: 'Arroz', price: 50, stock: 1000, active: true });
  b.set(db.doc('config/booking'), { holdMinutes: 15, maxPendingPerClient: 3 });
  await b.commit();
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  await setClock(0);
});
after(async () => { await setClock(0); await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true }); });

const book = (u, hhmm, extra = {}) => call('bookHealthAppointment', u, {
  requestId: rid('ap'), providerId: doctor.uid, catalogId: CARDIO, startMs: at(hhmm), modality: 'online', consentVersion: '2026-10', ...extra,
});
const payCard = (u, kind, id, token = 'tok_approved') => call('startPayment', u, { targetKind: kind, targetId: id, method: 'card', requestId: rid('pay'), card: { token, installments: 1 } });
const payPix = (u, kind, id) => call('startPayment', u, { targetKind: kind, targetId: id, method: 'pix', requestId: rid('pix') });
const runJobs = (...jobs) => call('adminRunMaintenance', adm, { jobs });
const statusOf = async (col, id) => (await doc(`${col}/${id}`)).status;
const waitStatus = (col, id, st) => waitFor(async () => (await statusOf(col, id)) === st || null);

describe('B15 — reservas aguardando pagamento (Saúde e Locação)', () => {
  test('limite de 3 pendentes por cliente é atômico (4 pedidos simultâneos → 3)', async () => {
    const c = await client('lim');
    const res = await Promise.allSettled(['08:00', '08:30', '09:00', '09:30'].map((h) => book(c, h)));
    const ok = res.filter((r) => r.status === 'fulfilled');
    assert.strictEqual(ok.length, 3, JSON.stringify(res.map((r) => r.reason && r.reason.message)));
    assert.match(res.find((r) => r.status === 'rejected').reason.message, /3 reserva\(s\) aguardando pagamento/);
    // Locação conta no mesmo limite.
    await assert.rejects(call('createRentalBooking', c, { requestId: rid('bk'), rentalId: `${K}_car`, period: 'day', quantity: 1, startMs: at('09:00', hc.localDateOf(Date.now() + 40 * 24 * H)) }), /aguardando pagamento/);
    // Desistir libera o lugar no limite.
    await call('healthAppointmentAction', c, { appointmentId: ok[0].value.id, action: 'cancel' });
    assert.ok(await waitFor(async () => !((await doc(`bookingHolds/${c.uid}`)).holds || {})[ok[0].value.id] || null), 'retenção liberada');
    assert.ok((await book(c, '10:00')).id);
  });

  test('mesmo horário pedido por dois clientes ao mesmo tempo → só um segura', async () => {
    const [a, b] = await Promise.all([client('sa'), client('sb')]);
    const res = await Promise.allSettled([book(a, '11:00'), book(b, '11:00')]);
    assert.strictEqual(res.filter((r) => r.status === 'fulfilled').length, 1);
  });

  test('expiração em 15 min (relógio controlado) libera o horário e recusa pagamento atrasado', async () => {
    const [a, b] = await Promise.all([client('ea'), client('eb')]);
    const r = await book(a, '12:00');
    assert.strictEqual(r.status, 'pending_payment');
    const slots = async () => (await call('listHealthSlots', b, { providerId: doctor.uid, catalogId: CARDIO, date: TOMORROW })).slots.map((s) => s.label);
    assert.ok(!(await slots()).includes('12:00'), 'retido enquanto vale');
    await setClock(14 * MIN);
    assert.ok(!(await slots()).includes('12:00'), 'ainda retido aos 14 min');
    await setClock(16 * MIN);
    assert.ok((await slots()).includes('12:00'), 'livre ao vencer, antes mesmo da tarefa');
    await assert.rejects(payCard(a, 'health', r.id), /prazo para pagar/);
    await runJobs('expireBookingHolds');
    assert.strictEqual(await statusOf('appointments', r.id), 'expired');
    assert.ok(await waitFor(async () => (await notifs(a.uid, 'health')).some((n) => n.title === 'Reserva expirada')));
    await setClock(0);
  });

  test('pagamento aprovado depois da expiração: horário livre → confirma; ocupado → devolve (sem sobreposição)', async () => {
    const [a, b, c] = await Promise.all([client('la'), client('lb'), client('lc')]);
    // a) horário continua livre: confirma.
    const r1 = await book(a, '13:00');
    const p1 = await payPix(a, 'health', r1.id);
    const g1 = (await attempt(p1.attemptId)).gatewayPaymentId;
    await setClock(16 * MIN);
    await runJobs('expireBookingHolds');
    assert.strictEqual(await statusOf('appointments', r1.id), 'expired');
    assert.ok(await waitFor(async () => ['cancelled', 'expired', 'failed'].includes((await attempt(p1.attemptId)).status) || null), 'cobrança aberta cancelada');
    await gatewaySet(g1, { status: 'approved', status_detail: 'accredited' }); // pagador pagou mesmo assim
    assert.strictEqual(await webhook(g1), 200);
    assert.ok(await waitStatus('appointments', r1.id, 'scheduled'), 'confirmado: horário ainda livre');
    // b) horário foi ocupado por outra pessoa: devolve e não sobrepõe.
    await setClock(0);
    const r2 = await book(b, '14:00');
    const p2 = await payPix(b, 'health', r2.id);
    const g2 = (await attempt(p2.attemptId)).gatewayPaymentId;
    await setClock(16 * MIN);
    await runJobs('expireBookingHolds');
    const r3 = await book(c, '14:00'); // horário liberado, outra pessoa reserva e paga
    await payCard(c, 'health', r3.id);
    assert.ok(await waitStatus('appointments', r3.id, 'scheduled'));
    await gatewaySet(g2, { status: 'approved', status_detail: 'accredited' });
    assert.strictEqual(await webhook(g2), 200);
    const late = await waitFor(async () => { const d = await doc(`appointments/${r2.id}`); return d.lateRefund ? d : null; });
    assert.ok(late, 'pagamento tardio marcado para devolução');
    assert.strictEqual(late.status, 'expired');
    const refunds = await waitFor(async () => { const s = await db.collection('refunds').where('targetId', '==', r2.id).get(); return s.empty ? null : s.docs.map((d) => d.data()); });
    assert.ok(refunds && refunds.length === 1 && refunds[0].amountCents === 15000, 'um reembolso do valor total');
    const sameSlot = (await db.collection('appointments').where('providerId', '==', doctor.uid).where('startMs', '==', at('14:00')).where('status', '==', 'scheduled').get()).size;
    assert.strictEqual(sameSlot, 1, 'sem sobreposição');
    await setClock(0);
  });

  test('cartão recusado mantém a reserva; pendente → aprovado por webhook; webhooks duplicados/fora de ordem não duplicam', async () => {
    const a = await client('gw');
    const r = await book(a, '15:00');
    const rej = await payCard(a, 'health', r.id, 'tok_rejected');
    assert.strictEqual(rej.status, 'rejected');
    assert.strictEqual(await statusOf('appointments', r.id), 'pending_payment');
    const pend = await payCard(a, 'health', r.id, 'tok_pending');
    assert.ok(['in_process', 'pending'].includes(pend.status), pend.status);
    const gid = (await attempt(pend.attemptId)).gatewayPaymentId;
    await gatewaySet(gid, { status: 'approved', status_detail: 'accredited' });
    const approvedAt = gwClock;
    assert.strictEqual(await webhook(gid), 200);
    assert.strictEqual(await webhook(gid), 200); // duplicado
    assert.ok(await waitStatus('appointments', r.id, 'scheduled'));
    // Evento antigo chegando depois (fora de ordem) é ignorado.
    await db.doc(`_fakeGateway/${gid}`).update({ status: 'in_process', date_last_updated: new Date(approvedAt - 60000).toISOString() });
    assert.strictEqual(await webhook(gid), 200);
    await sleep(1500);
    assert.strictEqual(await statusOf('appointments', r.id), 'scheduled');
    assert.strictEqual((await attempt(pend.attemptId)).status, 'approved');
    const pays = await db.collection('paymentAttempts').where('targetId', '==', r.id).where('status', '==', 'approved').get();
    assert.strictEqual(pays.size, 1, 'uma cobrança aprovada');
    assert.strictEqual((await db.collection('refunds').where('targetId', '==', r.id).get()).size, 0, 'nenhum reembolso indevido');
  });

  test('consulta paga cancelada pelo profissional é reembolsada uma vez', async () => {
    const a = await client('rf');
    const r = await book(a, '16:00');
    await payCard(a, 'health', r.id);
    assert.ok(await waitStatus('appointments', r.id, 'scheduled'));
    await call('healthAppointmentAction', doctor, { appointmentId: r.id, action: 'cancel', reason: 'Imprevisto' });
    const rf = await waitFor(async () => { const s = await db.collection('refunds').where('targetId', '==', r.id).get(); return s.empty ? null : s; });
    assert.strictEqual(rf.size, 1);
    assert.strictEqual(rf.docs[0].data().amountCents, 15000);
  });

  test('Locação: paga → anunciante confirma ou recusa (recusa reembolsa); expira sem pagamento', async () => {
    const [a, b] = await Promise.all([client('ra'), client('rb')]);
    const day = (d) => hc.localToUtc(hc.localDateOf(Date.now() + d * 24 * H), 9 * 60);
    const r = await call('createRentalBooking', a, { requestId: rid('bk'), rentalId: `${K}_car`, period: 'day', quantity: 1, startMs: day(10) });
    assert.strictEqual(r.status, 'pending_payment');
    assert.strictEqual(r.totalCents, 30000);
    await assert.rejects(call('transitionRentalBooking', owner, { bookingId: r.id, action: 'confirm' }), /status atual/);
    await payCard(a, 'rental', r.id);
    assert.ok(await waitStatus('bookings', r.id, 'pending'));
    await call('transitionRentalBooking', owner, { bookingId: r.id, action: 'reject' });
    const rf = await waitFor(async () => { const s = await db.collection('refunds').where('targetId', '==', r.id).get(); return s.empty ? null : s; });
    assert.strictEqual(rf.docs[0].data().amountCents, 30000, 'recusa após pagamento devolve o total');
    // Expiração da retenção de locação com relógio controlado.
    const r2 = await call('createRentalBooking', b, { requestId: rid('bk'), rentalId: `${K}_car`, period: 'day', quantity: 1, startMs: day(12) });
    const busy = async () => (await call('rentalAvailability', a, { rentalId: `${K}_car` })).busy.some((x) => x.startMs === day(12));
    assert.ok(await busy(), 'período retido');
    await setClock(16 * MIN);
    assert.ok(!(await busy()), 'período liberado ao vencer');
    await runJobs('expireBookingHolds');
    assert.strictEqual(await statusOf('bookings', r2.id), 'expired');
    await setClock(0);
  });

  test('configuração no servidor: só admin, com limites validados', async () => {
    const a = await client('cfg');
    await assert.rejects(call('updateBookingConfig', a, { holdMinutes: 30, maxPendingPerClient: 3 }), /PERMISSION_DENIED/);
    await assert.rejects(call('updateBookingConfig', adm, { holdMinutes: 1, maxPendingPerClient: 3 }), /holdMinutes/);
    await call('updateBookingConfig', adm, { holdMinutes: 20, maxPendingPerClient: 1 });
    const r = await book(a, '17:00');
    assert.ok(r.holdUntilMs > Date.now() + 19 * MIN, 'novo prazo aplicado');
    await assert.rejects(book(a, '17:30'), /1 reserva\(s\)/);
    await call('updateBookingConfig', adm, { holdMinutes: 15, maxPendingPerClient: 3 });
  });
});

describe('Confirmações automáticas com relógio controlado (prazos reais preservados)', () => {
  test('serviço: prestador conclui; 71 h ainda aguarda; 72 h confirma e repassa uma vez', async () => {
    const c = await client('svc');
    await db.doc(`providers/${pro.uid}`).set({ userId: pro.uid, name: 'João', verified: true, active: true, categories: ['eletricista'] });
    const id = rid('o');
    await db.doc(`payments/wallet_${id}`).set({ orderId: id, userId: c.uid, amount: 100, method: 'wallet', status: 'approved' });
    await db.doc(`orders/${id}`).set({ clientId: c.uid, providerId: pro.uid, status: 'inProgress', price: 100, paymentStatus: 'paid', transactionId: `wallet_${id}`, payoutProcessed: false, title: 'Chuveiro' });
    const before0 = await balance(pro.uid);
    await call('transitionOrder', pro, { orderId: id, action: 'complete' });
    await setClock(71 * H);
    await runJobs('autoConfirmServiceOrders');
    assert.strictEqual(await statusOf('orders', id), 'inProgress', '71 h: aguarda o cliente');
    await setClock(72 * H + MIN);
    await runJobs('autoConfirmServiceOrders');
    const o = await doc(`orders/${id}`);
    assert.deepStrictEqual([o.status, o.autoConfirmed, o.payoutProcessed], ['completed', true, true]);
    await runJobs('autoConfirmServiceOrders');
    assert.strictEqual(await balance(pro.uid) - before0, 8500, 'repasse único');
    await setClock(0);
  });

  test('Mercado: entregue; 7 dias − 1 h ainda retém; 7 dias libera a loja uma vez', async () => {
    const c = await client('mkt');
    const o = await call('createMarketOrder', c, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 2 }], deliveryMode: 'pickup' });
    await payCard(c, 'market', o.orderId);
    for (const st of ['preparing', 'ready', 'delivered']) await call('marketOrderUpdateStatus', seller, { orderId: o.orderId, status: st });
    const before0 = await balance(seller.uid);
    await setClock(7 * 24 * H - H);
    await runJobs('marketReleaseDue');
    assert.strictEqual((await doc(`earnings/${o.orderId}`)).status, 'pending_release');
    await setClock(7 * 24 * H + MIN);
    await runJobs('marketReleaseDue');
    await runJobs('marketReleaseDue');
    assert.strictEqual((await doc(`earnings/${o.orderId}`)).status, 'released');
    const net = (await doc(`marketOrders/${o.orderId}`)).financeTerms.sellerNetCents;
    assert.strictEqual(await balance(seller.uid) - before0, net, 'liberado uma vez');
    await setClock(0);
  });
});

describe('Cupons, manutenção, prestadores, chamados, avisos e autoria', () => {
  test('cupom: limite total e por cliente atômicos; pedido não pago devolve o uso', async () => {
    const exp = new Date(Date.now() + 30 * 24 * H);
    const cRef = await db.collection('coupons').add({ code: `LIM${K}`.toUpperCase(), discount: 10, isPercentage: true, active: true, expiresAt: exp, maxUses: 2, perUserLimit: 1 });
    const [a, b, c] = await Promise.all([client('ca'), client('cb'), client('cc')]);
    const order = (u) => call('createMarketOrder', u, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup', couponCode: `LIM${K}` });
    const res = await Promise.allSettled([order(a), order(b), order(c)]);
    const ok = res.filter((r) => r.status === 'fulfilled');
    assert.strictEqual(ok.length, 2, JSON.stringify(res.map((r) => r.reason && r.reason.message)));
    assert.match(res.find((r) => r.status === 'rejected').reason.message, /limite de usos/);
    assert.strictEqual((await cRef.get()).data().usedCount, 2);
    const winner = res.findIndex((r) => r.status === 'fulfilled');
    const u = [a, b, c][winner];
    await assert.rejects(order(u), /(máximo de vezes|limite de usos)/);
    await call('cancelMarketOrder', u, { orderId: ok[0].value.orderId });
    assert.strictEqual((await cRef.get()).data().usedCount, 1, 'cancelado sem pagamento devolve o uso');
    assert.strictEqual((await call('checkCoupon', u, { code: `LIM${K}` })).valid, true);
  });

  test('modo manutenção bloqueia operações de usuários; admin continua', async () => {
    const c = await client('mnt');
    await db.doc('config/platform').set({ maintenanceMode: true, maintenanceMessage: 'Manutenção programada' }, { merge: true });
    await sleep(11000); // cache de 10 s do servidor
    await assert.rejects(call('createMarketOrder', c, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup' }), /Manutenção programada/);
    await assert.rejects(book(c, '17:30'), /Manutenção/);
    const r = await call('createMarketOrder', adm, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup' });
    assert.ok(r.orderId, 'admin opera');
    await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
    await sleep(11000);
    assert.ok((await call('createMarketOrder', c, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup' })).orderId);
  });

  test('prestador: recusa com motivo, nova análise e aprovação (só admin)', async () => {
    const p = await signUp('prv');
    await db.doc(`providers/${p.uid}`).set({ userId: p.uid, name: 'Pedro Pintor', verified: false, active: false, categories: ['pintor'] });
    await assert.rejects(call('reviewProvider', p, { providerId: p.uid, decision: 'approve' }), /PERMISSION_DENIED/);
    await assert.rejects(call('reviewProvider', adm, { providerId: p.uid, decision: 'reject', reason: '' }), /motivo/);
    await call('reviewProvider', adm, { providerId: p.uid, decision: 'reject', reason: 'Documento ilegível' });
    let d = await doc(`providers/${p.uid}`);
    assert.deepStrictEqual([d.verified, d.active, d.verificationStatus, d.rejectionReason], [false, false, 'rejected', 'Documento ilegível']);
    assert.ok(await waitFor(async () => (await notifs(p.uid, 'info')).some((n) => n.body.includes('Documento ilegível'))));
    assert.strictEqual((await call('requestProviderReview', p, {})).status, 'pending_review');
    await call('reviewProvider', adm, { providerId: p.uid, decision: 'approve' });
    d = await doc(`providers/${p.uid}`);
    assert.deepStrictEqual([d.verified, d.active, d.verificationStatus, d.rejectionReason], [true, true, 'approved', undefined]);
  });

  test('chamado: resposta do suporte avisa o cliente; resposta do cliente reabre', async () => {
    const c = await client('tkt');
    const t = await db.collection('support').add({ userId: c.uid, userName: '', subject: 'Cobrança', message: 'Fui cobrado duas vezes', status: 'open', priority: 'normal', createdAt: new Date() });
    await t.collection('messages').add({ authorId: adm.uid, authorRole: 'support', text: 'Verificamos e estornamos.', createdAt: new Date() });
    assert.ok(await waitFor(async () => (await t.get()).data().status === 'answered' || null));
    assert.ok(await waitFor(async () => (await notifs(c.uid, 'info')).some((n) => n.title === '💬 Resposta do suporte')));
    await t.collection('messages').add({ authorId: c.uid, authorRole: 'user', text: 'Obrigado!', createdAt: new Date() });
    assert.ok(await waitFor(async () => (await t.get()).data().status === 'open' || null));
  });

  test('nova solicitação de serviço gera UM aviso ao prestador (sem duplicar com o chat)', async () => {
    const c = await client('dup');
    const before0 = (await notifs(pro.uid, 'order')).length;
    const chatBefore = (await notifs(pro.uid, 'chat')).length;
    const oRef = await db.collection('orders').add({ clientId: c.uid, providerId: pro.uid, status: 'pending', title: 'Trocar tomada', paymentStatus: 'unpaid', createdAt: new Date() });
    const ids = [c.uid, pro.uid].sort();
    await db.doc(`chatRooms/${ids.join('_')}`).set({ participants: ids });
    await db.collection(`chatRooms/${ids.join('_')}/messages`).add({ senderId: c.uid, text: '📋 Nova solicitação: Trocar tomada', read: false, orderId: oRef.id, createdAt: new Date() });
    assert.ok(await waitFor(async () => (await notifs(pro.uid, 'order')).length === before0 + 1 || null));
    await sleep(2500);
    assert.strictEqual((await notifs(pro.uid, 'order')).length, before0 + 1, 'um aviso de pedido');
    assert.strictEqual((await notifs(pro.uid, 'chat')).length, chatBefore, 'mensagem automática não avisa de novo');
  });

  test('R22: autor da avaliação vem do perfil público do autenticado (nome enviado é ignorado)', async () => {
    const c = await client('rev');
    assert.ok(await waitFor(async () => (await doc(`publicProfiles/${c.uid}`)) || null));
    const oid = rid('o');
    await db.doc(`orders/${oid}`).set({ clientId: c.uid, providerId: pro.uid, status: 'completed', price: 50 });
    // Gravação direta (contornando as regras) com nome forjado: o servidor sobrescreve.
    await db.doc(`reviews/${oid}_${c.uid}`).set({ orderId: oid, clientId: c.uid, providerId: pro.uid, stars: 5, clientName: 'Equipe Oficial', createdAt: new Date() });
    const r = await waitFor(async () => { const d = await doc(`reviews/${oid}_${c.uid}`); return d && d.authorFromServer ? d : null; });
    assert.ok(r, 'processada');
    assert.strictEqual(r.clientName, 'Cliente S.', 'primeiro nome + inicial do sobrenome, nunca o texto enviado');
    const dry = await call('migrateReviewAuthors', adm, { dryRun: true });
    assert.ok(dry.dryRun === true && dry.total >= 1);
  });

  test('terceiros não pagam, cancelam nem confirmam o que é de outra pessoa', async () => {
    const [a, x] = await Promise.all([client('own'), client('atk')]);
    const r = await book(a, '17:30');
    await assert.rejects(payCard(x, 'health', r.id), /PERMISSION_DENIED/);
    await assert.rejects(call('healthAppointmentAction', x, { appointmentId: r.id, action: 'cancel' }), /PERMISSION_DENIED/);
    const o = await call('createMarketOrder', a, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup' });
    await assert.rejects(call('confirmMarketReceipt', x, { orderId: o.orderId }), /PERMISSION_DENIED/);
    await assert.rejects(call('cancelMarketOrder', x, { orderId: o.orderId }), /PERMISSION_DENIED/);
    await assert.rejects(call('adminRunMaintenance', x, {}), /PERMISSION_DENIED/);
    await assert.rejects(call('updateBookingConfig', x, { holdMinutes: 15, maxPendingPerClient: 3 }), /PERMISSION_DENIED/);
  });
});
