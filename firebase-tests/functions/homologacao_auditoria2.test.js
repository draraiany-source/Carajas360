'use strict';
/**
 * Auditoria 2 (16/10/2026): regressões dos achados corrigidos em reservas,
 * pagamentos, prestadores, chamados, manutenção e tarefas admin. Emulador
 * com gateway simulado e relógio controlado (TEST_CLOCK, só no emulador).
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
let gwClock = Date.now() + 20 * H;
async function gatewaySet(paymentId, patch) {
  gwClock += 5000;
  await db.doc(`_fakeGateway/${paymentId}`).update({ ...patch, date_last_updated: new Date(gwClock).toISOString() });
}
async function setClock(offsetMs) {
  await db.doc('_testClock/current').set({ offsetMs });
  await sleep(1300);
}
const doc = (p) => db.doc(p).get().then((s) => s.data());

const K = `au2${Date.now().toString(36)}`;
const SAUDE = `${K}_saude`; const CARDIO = `${K}_cardio`;
// Outro dia que o dos testes de homologação, para não disputar horários.
const DAY = hc.localDateOf(Date.now() + 54 * H);
const at = (hhmm) => hc.localToUtc(DAY, hc.hm(hhmm));
const STORE = `${K}_loja`; const PROD = `${K}_arroz`;

let master; let support; let doctor; let seller;
async function client(tag) { const u = await signUp(tag); await db.doc(`users/${u.uid}`).set({ type: 'client', name: `Cliente ${tag} Souza` }); return u; }

before(async () => {
  [master, support, doctor, seller] = await Promise.all(['mst', 'sup', 'doc', 'sel'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`users/${master.uid}`), { type: 'admin', adminRole: 'master', name: 'Master' });
  b.set(db.doc(`users/${support.uid}`), { type: 'admin', adminRole: 'support', name: 'Suporte' });
  b.set(db.doc(`users/${doctor.uid}`), { type: 'provider', name: 'Dr. Paulo Reis' });
  b.set(db.doc(`catalogNodes/${SAUDE}`), { level: 'category', name: 'Saúde A2', vertical: 'health', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${CARDIO}`), { level: 'group', name: 'Cardiologia A2', parentId: SAUDE, active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true }); // invalida o cache do catálogo
  b.set(db.doc(`providers/${doctor.uid}`), { userId: doctor.uid, name: 'Dr. Paulo', verified: true, active: true, categories: [CARDIO], modalities: ['online'] });
  const weekly = {};
  for (let d = 0; d < 7; d++) weekly[d] = [{ start: '08:00', end: '18:00' }];
  b.set(db.doc(`healthSchedules/${doctor.uid}`), { slotMinutes: 30, minLeadHours: 2, weekly, blockedDates: [], services: [{ catalogId: CARDIO, durationMin: 30, priceCents: 15000, modalities: ['online'] }] });
  b.set(db.doc(`stores/${STORE}`), { ownerId: seller.uid, name: 'Mercado A2', active: true, verified: true, deliveryFeeCents: 500, pickupEnabled: true, deliveryEnabled: true });
  b.set(db.doc(`products/${PROD}`), { storeId: STORE, name: 'Arroz', price: 50, stock: 1000, active: true });
  b.set(db.doc('config/booking'), { holdMinutes: 15, maxPendingPerClient: 3 });
  await b.commit();
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  await setClock(0);
});
after(async () => {
  await setClock(0);
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  // Não deixa nós de catálogo para outras suítes (contagem do catálogo).
  await Promise.all([SAUDE, CARDIO].map((id) => db.doc(`catalogNodes/${id}`).delete()));
  await db.doc('catalogMeta/current').set({ version: admin.firestore.FieldValue.increment(1) }, { merge: true });
});

const book = (u, hhmm) => call('bookHealthAppointment', u, {
  requestId: rid('ap'), providerId: doctor.uid, catalogId: CARDIO, startMs: at(hhmm), modality: 'online', consentVersion: '2026-10',
});
const payCard = (u, id) => call('startPayment', u, { targetKind: 'health', targetId: id, method: 'card', requestId: rid('pay'), card: { token: 'tok_approved', installments: 1 } });
const payPix = (u, id) => call('startPayment', u, { targetKind: 'health', targetId: id, method: 'pix', requestId: rid('pix') });
const waitStatus = (id, st) => waitFor(async () => ((await doc(`appointments/${id}`)) || {}).status === st || null);

describe('Auditoria 2 — reservas e pagamentos', () => {
  test('reembolso recusado pelo gateway não entra em laço (um pedido de reembolso só)', async () => {
    const c = await client('loop');
    const r = await book(c, '08:00');
    const p = await payCard(c, r.id);
    assert.ok(await waitStatus(r.id, 'scheduled'), 'pago e confirmado');
    const gid = (await doc(`paymentAttempts/${p.attemptId}`)).gatewayPaymentId;
    // Gateway passa a recusar o estorno (ex.: pagamento em disputa).
    await gatewaySet(gid, { status: 'in_mediation' });
    await call('healthAppointmentAction', doctor, { appointmentId: r.id, action: 'cancel', reason: 'Imprevisto do profissional' });
    assert.ok(await waitFor(async () => (await db.collection('refunds').where('targetId', '==', r.id).where('status', '==', 'failed').get()).size >= 1 || null), 'reembolso recusado registrado');
    await sleep(5000); // antes da correção, novos pedidos de reembolso apareciam aqui sem parar
    const all = await db.collection('refunds').where('targetId', '==', r.id).get();
    assert.strictEqual(all.size, 1, `pedidos de reembolso: ${all.docs.map((d) => d.data().status)}`);
    const ap = await doc(`appointments/${r.id}`);
    assert.strictEqual(ap.paymentStatus, 'approved', 'valor continua registrado como pago, com pendência financeira');
  });

  test('Pix estende a retenção até o vencimento do Pix (com teto) e o limite do cliente acompanha', async () => {
    const c = await client('pix');
    const r = await book(c, '09:00');
    const before = (await doc(`appointments/${r.id}`)).holdUntilMs;
    await payPix(c, r.id);
    const ap = await doc(`appointments/${r.id}`);
    assert.ok(ap.holdUntilMs > before + 10 * MIN, `retenção ${ap.holdUntilMs} vs ${before}`);
    assert.ok(ap.holdUntilMs <= before + 30 * MIN, 'teto: prazo original + 30 min');
    assert.strictEqual((await doc(`bookingHolds/${c.uid}`)).holds[r.id], ap.holdUntilMs);
  });

  test('quem paga depois do prazo não tira o horário de quem está dentro da própria retenção', async () => {
    const [a, b] = await Promise.all([client('late'), client('ontime')]);
    const ra = await book(a, '10:00');
    const pa = await payPix(a, ra.id);
    const holdA = (await doc(`appointments/${ra.id}`)).holdUntilMs;
    const t0 = Date.now();
    await setClock(holdA - t0 + 2 * MIN); // retenção de A venceu (a tarefa ainda não rodou)
    const rb = await book(b, '10:00');
    // A paga o Pix atrasado: não confirma e é reembolsado.
    const gid = (await doc(`paymentAttempts/${pa.attemptId}`)).gatewayPaymentId;
    await gatewaySet(gid, { status: 'approved', status_detail: 'accredited' });
    assert.strictEqual(await webhook(gid), 200);
    assert.ok(await waitFor(async () => ((await doc(`appointments/${ra.id}`)) || {}).lateRefund === true || null), 'A devolvido');
    // B paga dentro do prazo dele e fica com o horário.
    await payCard(b, rb.id);
    assert.ok(await waitStatus(rb.id, 'scheduled'), 'B confirmado');
    assert.strictEqual((await doc(`appointments/${ra.id}`)).status, 'expired');
    await setClock(0);
  });
});

describe('Auditoria 2 — prestadores, chamados, tarefas e manutenção', () => {
  test('aprovar não reativa conta suspensa ou apagada; reanálise só para recusado', async () => {
    const p = await signUp('susp');
    await db.doc(`users/${p.uid}`).set({ type: 'provider', name: 'Prestador Suspenso', status: 'suspended' });
    await db.doc(`providers/${p.uid}`).set({ userId: p.uid, verified: false, active: false, verificationStatus: 'pending' });
    await assert.rejects(call('reviewProvider', master, { providerId: p.uid, decision: 'approve' }), /FAILED_PRECONDITION/);
    assert.strictEqual((await doc(`providers/${p.uid}`)).verified, false);
    // Reanálise: quem não foi recusado não muda de estado.
    const q = await signUp('rean');
    await db.doc(`providers/${q.uid}`).set({ userId: q.uid, verified: false, verificationStatus: 'pending' });
    assert.strictEqual((await call('requestProviderReview', q, {})).status, 'pending');
    await db.doc(`providers/${q.uid}`).update({ verificationStatus: 'rejected', rejectionReason: 'Documento ilegível' });
    assert.strictEqual((await call('requestProviderReview', q, {})).status, 'pending_review');
    // Aprovação repetida não notifica de novo.
    await call('reviewProvider', master, { providerId: q.uid, decision: 'approve' });
    const again = await call('reviewProvider', master, { providerId: q.uid, decision: 'approve' });
    assert.strictEqual(again.unchanged, true);
    const log = await db.collection('auditLogs').where('target', '==', q.uid).where('action', '==', 'Aprovou prestador').get();
    assert.strictEqual(log.size, 1);
    assert.strictEqual(log.docs[0].data().adminName, 'Master');
  });

  test('chamado: o dono limpa o aviso de não lida; terceiro não', async () => {
    const [c, x] = await Promise.all([client('tk'), client('tkx')]);
    const t = await db.collection('support').add({ userId: c.uid, subject: 'Ajuda', message: 'Texto', status: 'answered', priority: 'normal', unreadByUser: true, createdAt: new Date() });
    await assert.rejects(call('markTicketRead', x, { ticketId: t.id }), /PERMISSION_DENIED/);
    await call('markTicketRead', c, { ticketId: t.id });
    assert.strictEqual((await t.get()).data().unreadByUser, false);
  });

  test('tarefas admin: perfil de suporte não roda; nomes inválidos são recusados', async () => {
    await assert.rejects(call('adminRunMaintenance', support, { jobs: ['marketReleaseDue'] }), /PERMISSION_DENIED/);
    await assert.rejects(call('adminRunMaintenance', master, { jobs: ['hasOwnProperty'] }), /INVALID_ARGUMENT/);
    await assert.rejects(call('adminRunMaintenance', master, { jobs: ['constructor'] }), /INVALID_ARGUMENT/);
    const out = await call('adminRunMaintenance', master, { jobs: ['expireBookingHolds', 'expireBookingHolds'] });
    assert.deepStrictEqual(Object.keys(out), ['expireBookingHolds']);
  });

  test('manutenção: bloqueia liberar dinheiro e reagendar; cancelar continua liberado', async () => {
    const c = await client('mnt');
    const o = await call('createMarketOrder', c, { requestId: rid('ord'), storeId: STORE, items: [{ productId: PROD, qty: 1 }], deliveryMode: 'pickup' });
    const r = await book(c, '11:00');
    await db.doc('config/platform').set({ maintenanceMode: true }, { merge: true });
    await sleep(11000); // cache de 10 s do guarda de manutenção
    try {
      await assert.rejects(call('confirmMarketReceipt', c, { orderId: o.orderId }), /UNAVAILABLE/);
      await assert.rejects(call('healthAppointmentAction', c, { appointmentId: r.id, action: 'reschedule', newStartMs: at('12:00') }), /UNAVAILABLE/);
      await call('healthAppointmentAction', c, { appointmentId: r.id, action: 'cancel' });
      await call('cancelMarketOrder', c, { orderId: o.orderId });
    } finally {
      await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
      await sleep(11000);
    }
  });

  test('aviso de novo pedido usa texto fixo (o título do cliente não vai na notificação)', async () => {
    const [c, p] = await Promise.all([client('ntf'), signUp('ntfp')]);
    await db.doc(`orders/${rid('o')}`).set({ clientId: c.uid, providerId: p.uid, status: 'pending', title: 'PAGUE A TAXA NO PIX chave 123', createdAt: new Date() });
    const n = await waitFor(async () => {
      const s = await db.collection('notifications').where('userId', '==', p.uid).where('type', '==', 'order').get();
      return s.empty ? null : s.docs[0].data();
    }, 30000);
    assert.ok(n, 'aviso enviado');
    assert.doesNotMatch(JSON.stringify(n), /PAGUE A TAXA/);
  });

  test('migração de autores pula avaliação sem perfil público (não vira "Cliente" de vez)', async () => {
    // Avaliação antiga de conta sem perfil público (ex.: conta apagada).
    const cid = `sem_perfil_${K}`;
    const oid = rid('o');
    const id = `${oid}_${cid}`;
    await db.doc(`orders/${oid}`).set({ clientId: cid, providerId: doctor.uid, status: 'completed', price: 50 });
    await db.doc(`reviews/${id}`).set({ orderId: oid, clientId: cid, providerId: doctor.uid, stars: 5, createdAt: new Date() });
    assert.ok(await waitFor(async () => ((await doc(`reviews/${id}`)) || {}).processedAt || null), 'processada pelo gatilho');
    // Simula o formato antigo (nome digitado pelo app, sem marca do servidor).
    await db.doc(`reviews/${id}`).update({ clientName: 'Maria Antiga', authorFromServer: admin.firestore.FieldValue.delete() });
    const out = await call('migrateReviewAuthors', master, { dryRun: false });
    assert.ok(out.skippedNoProfile.includes(id) || out.skippedNoProfile.length === 50);
    const rv = await doc(`reviews/${id}`);
    assert.strictEqual(rv.clientName, 'Maria Antiga');
    assert.notStrictEqual(rv.authorFromServer, true);
  });
});
