'use strict';
/** Auditoria 3: Home Care exige endereço; nome do paciente; exclusão de conta anonimiza o prestador. */
const { test, before } = require('node:test');
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
async function waitFor(fn, ms = 12000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}

const K = `a3${Date.now().toString(36)}`;
const SAUDE = `${K}_saude`; const ENF = `${K}_enf`;
const DAY = hc.localDateOf(Date.now() + 24 * H);
const at = (hhmm) => hc.localToUtc(DAY, hc.hm(hhmm));
let pat; let nurse; let gone;

before(async () => {
  [pat, nurse, gone] = await Promise.all(['pat', 'nur', 'gone'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`catalogNodes/${SAUDE}`), { level: 'category', name: 'Saúde A3', vertical: 'health', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${ENF}`), { level: 'group', name: 'Enfermagem A3', parentId: SAUDE, active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  b.set(db.doc(`publicProfiles/${pat.uid}`), { name: 'Maria Paciente' });
  b.set(db.doc(`providers/${nurse.uid}`), { userId: nurse.uid, name: 'Enf. Rita', verified: true, active: true, categories: [ENF], modalities: ['home_care'] });
  const weekly = {};
  for (let d = 0; d < 7; d++) weekly[d] = [{ start: '08:00', end: '18:00' }];
  b.set(db.doc(`healthSchedules/${nurse.uid}`), { slotMinutes: 30, minLeadHours: 2, weekly, blockedDates: [], services: [{ catalogId: ENF, durationMin: 60, priceCents: 0, modalities: ['home_care'] }] });
  b.set(db.doc(`users/${gone.uid}`), { type: 'provider', name: 'Fulano Saindo' });
  b.set(db.doc(`providers/${gone.uid}`), { userId: gone.uid, name: 'Fulano Saindo', phone: '94999990000', email: 'f@x.com', bio: 'bio', photoUrl: 'http://x/p.jpg', verified: true, active: true });
  await b.commit();
});

const book = (extra = {}) => call('bookHealthAppointment', pat, {
  requestId: rid('ap'), providerId: nurse.uid, catalogId: ENF, startMs: at('10:00'), modality: 'home_care',
  consentVersion: '2026-10', reason: 'Curativo', ...extra,
});

test('Home Care exige endereço, que fica só no documento privado; o profissional vê o nome do paciente', async () => {
  await assert.rejects(book(), /endereço/);
  await assert.rejects(book({ address: 'Rua 1' }), /endereço/);
  const r = await book({ address: 'Rua A, 123, Cidade Nova' });
  const ap = (await db.doc(`appointments/${r.id}`).get()).data();
  assert.strictEqual(ap.clientName, 'Maria Paciente');
  assert.strictEqual(ap.address, undefined, 'endereço não vai no documento principal');
  const priv = (await db.doc(`appointments/${r.id}/private/clinical`).get()).data();
  assert.strictEqual(priv.address, 'Rua A, 123, Cidade Nova');
});

test('excluir a conta anonimiza o perfil público do prestador', async () => {
  await admin.auth().deleteUser(gone.uid);
  const p = await waitFor(async () => {
    const d = (await db.doc(`providers/${gone.uid}`).get()).data();
    return d && d.name === 'Profissional removido' ? d : null;
  }, 20000);
  assert.ok(p, 'perfil anonimizado');
  for (const f of ['phone', 'email', 'bio', 'photoUrl']) assert.ok(p[f] == null, `${f} apagado`);
});
