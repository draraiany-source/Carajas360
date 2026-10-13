'use strict';
/** Integração da Fase 5 (Saúde e Locação) contra os emuladores. */
const { test, before, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const hc = require('../../functions/healthCore');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p = 'r') => `${p}_${crypto.randomBytes(8).toString('hex')}`;
const H = 3600000;
const CONSENT = '2026-10';

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
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
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
const notifs = async (uid, type) => (await db.collection('notifications').where('userId', '==', uid).where('type', '==', type).get()).docs.map((d) => d.data());

const K = `f5${Date.now().toString(36)}`;
const SAUDE = `${K}_saude`; const CARDIO = `${K}_cardio`; const CASA = `${K}_casa`; const ELE = `${K}_ele`;
const TOMORROW = hc.localDateOf(Date.now() + 24 * H);
const at = (hhmm, date = TOMORROW) => hc.localToUtc(date, hc.hm(hhmm));
let pat; let pat2; let doc; let docPending; let owner; let renter; let renter2;

before(async () => {
  [pat, pat2, doc, docPending, owner, renter, renter2] = await Promise.all(['pat', 'pat2', 'doc', 'docp', 'own', 'ren', 'ren2'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`catalogNodes/${SAUDE}`), { level: 'category', name: 'Saúde F5', vertical: 'health', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${CARDIO}`), { level: 'group', name: 'Cardiologia F5', parentId: SAUDE, active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${CASA}`), { level: 'category', name: 'Casa F5', vertical: 'services', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${ELE}`), { level: 'group', name: 'Elétrica F5', parentId: CASA, active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  b.set(db.doc(`users/${pat.uid}`), { type: 'client', name: 'Paciente' });
  b.set(db.doc(`users/${renter.uid}`), { type: 'client', name: 'Locatário' });
  for (const [u, verified] of [[doc, true], [docPending, false]]) {
    b.set(db.doc(`providers/${u.uid}`), { userId: u.uid, name: 'Dra. Ana', verified, active: verified, categories: [CARDIO], modalities: ['online', 'presential'] });
    const weekly = {};
    for (let d = 0; d < 7; d++) weekly[d] = [{ start: '08:00', end: '12:00' }, { start: '14:00', end: '18:00' }];
    b.set(db.doc(`healthSchedules/${u.uid}`), { slotMinutes: 30, minLeadHours: 2, weekly, blockedDates: [], services: [{ catalogId: CARDIO, durationMin: 60, priceCents: 28000, modalities: ['online', 'presential'] }] });
  }
  b.set(db.doc(`rentals/${K}_car`), { ownerId: owner.uid, ownerName: 'Locadora', title: 'Hilux F5', category: 'pickup', kind: 'vehicle', pricePerDay: 350, pricePerHour: 60, active: true, available: true, createdAt: new Date() });
  await b.commit();
});

const book = (u, start, extra = {}) => call('bookHealthAppointment', u, {
  requestId: rid('ap'), providerId: doc.uid, catalogId: CARDIO, startMs: start, modality: 'online',
  consentVersion: CONSENT, reason: 'Dor no peito ao subir escadas', ...extra,
});

describe('Saúde: agenda real, conflito e privacidade', () => {
  test('horários vêm da agenda; consulta exige profissional, horário válido, modalidade e consentimento', async () => {
    const s = await call('listHealthSlots', pat, { providerId: doc.uid, catalogId: CARDIO, date: TOMORROW });
    assert.strictEqual(s.priceCents, 28000);
    assert.strictEqual(s.timezone, 'America/Belem');
    assert.ok(s.slots.some((x) => x.label === '09:00'));
    await assert.rejects(book(pat, at('09:00'), { consentVersion: undefined }), /termo/);
    await assert.rejects(book(pat, at('09:10')), /indisponível/, 'fora da grade');
    await assert.rejects(book(pat, at('12:30')), /indisponível/, 'fora do expediente');
    await assert.rejects(book(pat, at('09:00'), { modality: 'home_care' }), /Modalidade/);
    await assert.rejects(book(pat, at('09:00'), { providerId: docPending.uid }), /indisponível/);
    await assert.rejects(book(pat, at('09:00'), { catalogId: ELE }), /saúde inválida/);
    await assert.rejects(book(pat, at('09:00'), { price: 1, providerId: '' }), /obrigatórios/);
    const requestId = rid('ap');
    const r = await book(pat, at('09:00'), { requestId, priceCents: 1 });
    const again = await book(pat, at('09:00'), { requestId });
    assert.strictEqual(again.id, r.id);
    const ap = (await db.doc(`appointments/${r.id}`).get()).data();
    assert.deepStrictEqual([ap.providerId, ap.clientId, ap.date, ap.status, ap.priceCents, ap.timezone, ap.endMs - ap.startMs],
      [doc.uid, pat.uid, TOMORROW, 'scheduled', 28000, 'America/Belem', 60 * 60000]);
    assert.strictEqual(ap.consent.version, CONSENT);
    assert.strictEqual(ap.reason, undefined, 'motivo não fica no documento principal');
    const clin = (await db.doc(`appointments/${r.id}/private/clinical`).get()).data();
    assert.strictEqual(clin.reason, 'Dor no peito ao subir escadas');
    const s2 = await call('listHealthSlots', pat2, { providerId: doc.uid, catalogId: CARDIO, date: TOMORROW });
    assert.ok(!s2.slots.some((x) => ['08:30', '09:00', '09:30'].includes(x.label)), 'horários sobrepostos somem');
    await assert.rejects(book(pat2, at('09:30')), /indisponível/, 'sobreposição parcial bloqueada');
    // Notificação por evento, sem especialidade nem motivo.
    const n = await waitFor(async () => (await notifs(doc.uid, 'health')).find((x) => x.title.includes('Nova consulta')));
    assert.ok(n && !n.body.includes('Cardio') && !n.body.includes('Dor'));
  });

  test('duas reservas simultâneas do mesmo horário: exatamente uma vence', async () => {
    const res = await Promise.allSettled([book(pat, at('15:00')), book(pat2, at('15:00'))]);
    assert.strictEqual(res.filter((x) => x.status === 'fulfilled').length, 1, JSON.stringify(res.map((x) => x.reason && x.reason.message)));
    const q = await db.collection('appointments').where('providerId', '==', doc.uid).where('startMs', '==', at('15:00')).get();
    assert.strictEqual(q.size, 1);
  });

  test('cancelar e reagendar: autorização, prazos, motivo e limite', async () => {
    const r = await book(pat, at('10:30'));
    await assert.rejects(call('healthAppointmentAction', pat2, { appointmentId: r.id, action: 'cancel' }), /PERMISSION_DENIED/);
    await assert.rejects(call('healthAppointmentAction', pat, { appointmentId: r.id, action: 'reschedule', newStartMs: at('15:00') }), /indisponível/, 'horário ocupado');
    await call('healthAppointmentAction', pat, { appointmentId: r.id, action: 'reschedule', newStartMs: at('16:00') });
    let ap = (await db.doc(`appointments/${r.id}`).get()).data();
    assert.deepStrictEqual([ap.startMs, ap.rescheduleCount, ap.previousStartMs], [at('16:00'), 1, at('10:30')]);
    assert.ok((await call('listHealthSlots', pat, { providerId: doc.uid, catalogId: CARDIO, date: TOMORROW })).slots.some((x) => x.label === '10:30'), 'horário antigo liberado');
    await call('healthAppointmentAction', pat, { appointmentId: r.id, action: 'reschedule', newStartMs: at('17:00') });
    await assert.rejects(call('healthAppointmentAction', pat, { appointmentId: r.id, action: 'reschedule', newStartMs: at('11:00') }), /Limite/);
    await assert.rejects(call('healthAppointmentAction', doc, { appointmentId: r.id, action: 'complete' }), /não começou/);
    await assert.rejects(call('healthAppointmentAction', doc, { appointmentId: r.id, action: 'cancel' }), /motivo/);
    await call('healthAppointmentAction', doc, { appointmentId: r.id, action: 'cancel', reason: 'Emergência hospitalar' });
    ap = (await db.doc(`appointments/${r.id}`).get()).data();
    assert.strictEqual(ap.status, 'cancelled_by_provider');
    assert.ok(await waitFor(async () => (await notifs(pat.uid, 'health')).some((x) => x.title === 'Consulta cancelada')));
    // Paciente não cancela em cima da hora (consulta em 1 h).
    const soon = db.collection('appointments').doc();
    await soon.set({ clientId: pat.uid, providerId: doc.uid, status: 'scheduled', startMs: Date.now() + H, endMs: Date.now() + 2 * H, catalogId: CARDIO });
    await assert.rejects(call('healthAppointmentAction', pat, { appointmentId: soon.id, action: 'cancel' }), /2 h antes/);
  });

  test('Resolve não publica pedidos de saúde como oportunidade', async () => {
    await assert.rejects(call('createResolveRequest', pat, { requestId: rid('rr'), description: 'Preciso de cardiologista urgente', category: CARDIO, city: 'Marabá' }), /use o agendamento em Saúde/);
  });
});

describe('Locação: preço do servidor, disponibilidade e transições', () => {
  const start = () => hc.localToUtc(hc.localDateOf(Date.now() + 5 * 24 * H), 9 * 60);
  const reserve = (u, extra = {}) => call('createRentalBooking', u, { requestId: rid('bk'), rentalId: `${K}_car`, period: 'day', quantity: 2, startMs: start(), ...extra });

  test('reserva com total calculado no servidor; próprio anúncio e período sem preço recusados', async () => {
    const q = await call('quoteRentalBooking', renter, { rentalId: `${K}_car`, period: 'day', quantity: 2, startMs: start() });
    assert.strictEqual(q.totalCents, 70000);
    await assert.rejects(reserve(owner), /próprio anúncio/);
    await assert.rejects(reserve(renter, { period: 'week' }), /não tem preço/);
    const r = await reserve(renter, { total: 1, totalCents: 1, endMs: start() + 1 });
    const b = (await db.doc(`bookings/${r.id}`).get()).data();
    assert.deepStrictEqual([b.totalCents, b.unitCents, b.status, b.endMs - b.startMs, b.ownerId], [70000, 35000, 'pending', 48 * H, owner.uid]);
    // Notificação do anunciante por evento (antes o app tentava gravar e falhava).
    assert.ok(await waitFor(async () => (await notifs(owner.uid, 'rental')).some((x) => x.title.includes('Nova solicitação'))));
    await assert.rejects(reserve(renter2, { startMs: start() + 24 * H, quantity: 1 }), /já está reservado/, 'sobreposição');
    const adj = await reserve(renter2, { startMs: start() + 48 * H, quantity: 1 });
    assert.ok(adj.id, 'período encostado é permitido');
    const av = await call('rentalAvailability', renter2, { rentalId: `${K}_car` });
    assert.ok(av.busy.length >= 2 && av.busy.every((x) => x.clientId === undefined), 'ocupação sem dados de quem reservou');
  });

  test('reservas simultâneas do mesmo período: exatamente uma vence', async () => {
    const s = start() + 10 * 24 * H;
    const res = await Promise.allSettled([reserve(renter, { startMs: s, quantity: 1 }), reserve(renter2, { startMs: s, quantity: 1 })]);
    assert.strictEqual(res.filter((x) => x.status === 'fulfilled').length, 1, JSON.stringify(res.map((x) => x.reason && x.reason.message)));
  });

  test('transições autorizadas, prazos de cancelamento e motivo do anunciante', async () => {
    const r = await reserve(renter, { startMs: start() + 20 * 24 * H, quantity: 1 });
    await assert.rejects(call('transitionRentalBooking', renter, { bookingId: r.id, action: 'confirm' }), /Somente o anunciante/);
    await assert.rejects(call('transitionRentalBooking', renter2, { bookingId: r.id, action: 'cancel' }), /PERMISSION_DENIED/);
    await call('transitionRentalBooking', owner, { bookingId: r.id, action: 'confirm' });
    assert.ok(await waitFor(async () => (await notifs(renter.uid, 'rental')).some((x) => x.title === 'Reserva confirmada')));
    await assert.rejects(call('transitionRentalBooking', owner, { bookingId: r.id, action: 'start' }), /não começou/);
    await assert.rejects(call('transitionRentalBooking', owner, { bookingId: r.id, action: 'cancel' }), /motivo/);
    await call('transitionRentalBooking', renter, { bookingId: r.id, action: 'cancel' });
    const b = (await db.doc(`bookings/${r.id}`).get()).data();
    assert.deepStrictEqual([b.status, b.cancelledBy], ['cancelled', 'client']);
    assert.deepStrictEqual(b.history.map((h) => h.to), ['pending', 'confirmed', 'cancelled']);
    // Confirmada a menos de 24 h: locatário não cancela.
    const late = db.collection('bookings').doc();
    await late.set({ rentalId: `${K}_car`, ownerId: owner.uid, clientId: renter.uid, status: 'confirmed', startMs: Date.now() + 5 * H, endMs: Date.now() + 29 * H });
    await assert.rejects(call('transitionRentalBooking', renter, { bookingId: late.id, action: 'cancel' }), /24 h/);
    await call('transitionRentalBooking', owner, { bookingId: late.id, action: 'cancel', reason: 'Veículo em manutenção' });
  });
});
