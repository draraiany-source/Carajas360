'use strict';
/** Integração da Fase 6: perfil público mínimo mantido pelo servidor. */
const { test } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
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
const pub = (uid) => db.doc(`publicProfiles/${uid}`).get().then((s) => s.data());

test('perfil público é criado/atualizado pelo servidor só com dados mínimos', async () => {
  const u = await signUp('pp');
  await db.doc(`users/${u.uid}`).set({ name: 'Maria das Dores Silva', email: 'maria@x.com', phone: '94999990000', photoUrl: 'foto.jpg', type: 'client', balance: 99 });
  const p = await waitFor(async () => { const d = await pub(u.uid); return d && d.name === 'Maria S.' ? d : null; });
  assert.ok(p, 'perfil público gerado');
  assert.deepStrictEqual(Object.keys(p).sort(), ['kind', 'name', 'photoUrl', 'updatedAt', 'verified']);
  await db.doc(`providers/${u.uid}`).set({ userId: u.uid, name: 'Maria Eletricista', verified: true, active: true, categories: ['x'] });
  assert.ok(await waitFor(async () => (await pub(u.uid))?.name === 'Maria Eletricista' || null), 'prestador aprovado usa nome profissional');
  await db.doc(`providers/${u.uid}`).update({ verified: false });
  assert.ok(await waitFor(async () => (await pub(u.uid))?.name === 'Maria S.' || null), 'desaprovado volta ao nome mínimo');
});

test('migração gera perfis de usuários antigos (admin)', async () => {
  const adm = await signUp('ppadm');
  await db.doc(`users/${adm.uid}`).set({ type: 'admin', name: 'Admin' });
  const dry = await call('migratePublicProfiles', adm, { dryRun: true });
  assert.ok(dry.users >= 1 && dry.updated === 0);
  const u = await signUp('pplegacy');
  await call('migratePublicProfiles', adm, {});
  assert.ok(await waitFor(async () => (await pub(adm.uid)) || null));
  await assert.rejects(call('migratePublicProfiles', u, {}), /PERMISSION_DENIED/);
});
