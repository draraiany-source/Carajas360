'use strict';
/**
 * Pendência 3: push por aparelho (users/{uid}/devices). No emulador não há
 * FCM: PUSH_TRANSPORT=fake (functions/.env.demo-carajas360) simula o envio e
 * registra em _fakePush. Tokens "invalid-…" = não registrado,
 * "malformed-…" = token inválido, "fail-…" = erro temporário.
 * Entrega real em aparelho/navegador NÃO é testada aqui.
 */
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, getDoc, deleteDoc, getDocs, collection, serverTimestamp } = require('firebase/firestore');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const TS = admin.firestore.Timestamp;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p = 'u') => `${p}_${crypto.randomBytes(6).toString('hex')}`;
const devId = () => crypto.randomBytes(16).toString('hex');
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
async function device(uid, token, ageMin = 0, id = devId()) {
  await db.doc(`users/${uid}/devices/${id}`).set({ token, platform: 'android', updatedAt: TS.fromMillis(Date.now() - ageMin * 60000) });
  return id;
}
/** Cria a notificação (gatilho sendPushNotification) e espera o envio simulado. */
async function notifyAndWait(userId) {
  const ref = await db.collection('notifications').add({ userId, title: 'Teste', body: 'Corpo', type: 'order', link: { route: 'marketOrder', id: 'p1' }, read: false, createdAt: new Date() });
  const sent = await waitFor(async () => {
    const s = await db.collection('_fakePush').where('notifId', '==', ref.id).get();
    return s.empty ? null : s.docs[0].data();
  });
  assert.ok(sent, 'envio simulado registrado');
  return sent;
}

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-pend3-push',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });

test('envia para todos os aparelhos do usuário, com o destino no data', async () => {
  const uid = rid();
  await db.doc(`users/${uid}`).set({ type: 'client', name: 'A' });
  await device(uid, 'tok-celular'); await device(uid, 'tok-tablet', 5); await device(uid, 'tok-web', 10);
  const sent = await notifyAndWait(uid);
  assert.deepStrictEqual([...sent.tokens].sort(), ['tok-celular', 'tok-tablet', 'tok-web']);
  assert.deepStrictEqual(sent.delivered.length, 3);
  assert.deepStrictEqual(sent.data, { type: 'order', route: 'marketOrder', id: 'p1' });
});

test('token inválido sai, válido e erro temporário ficam', async () => {
  const uid = rid();
  await db.doc(`users/${uid}`).set({ type: 'client' });
  const ok = await device(uid, 'tok-ok');
  const gone = await device(uid, 'invalid-desinstalado', 1);
  const bad = await device(uid, 'malformed-xyz', 2);
  const tmp = await device(uid, 'fail-temporario', 3);
  await notifyAndWait(uid);
  const ids = await waitFor(async () => {
    const s = await db.collection(`users/${uid}/devices`).get();
    const v = s.docs.map((d) => d.id).sort();
    return v.length === 2 ? v : null;
  });
  assert.deepStrictEqual(ids, [ok, tmp].sort());
  assert.ok(!ids.includes(gone) && !ids.includes(bad));
});

test('limite: só os 20 aparelhos mais recentes recebem', async () => {
  const uid = rid();
  await db.doc(`users/${uid}`).set({ type: 'client' });
  await Promise.all(Array.from({ length: 23 }, (_, i) => device(uid, `tok-${String(i).padStart(2, '0')}`, i)));
  const sent = await notifyAndWait(uid);
  assert.strictEqual(sent.tokens.length, 20);
  assert.ok(!sent.tokens.includes('tok-22') && !sent.tokens.includes('tok-21') && !sent.tokens.includes('tok-20'));
});

test('compatibilidade: token legado users.fcmToken é usado; inválido é limpo', async () => {
  const a = rid(); const b = rid();
  await db.doc(`users/${a}`).set({ type: 'client', fcmToken: 'legado-ok' });
  await db.doc(`users/${b}`).set({ type: 'client', fcmToken: 'invalid-legado' });
  await device(b, 'tok-novo');
  const sa = await notifyAndWait(a);
  assert.deepStrictEqual(sa.tokens, ['legado-ok']);
  const sb = await notifyAndWait(b);
  assert.deepStrictEqual([...sb.tokens].sort(), ['invalid-legado', 'tok-novo']);
  assert.ok(await waitFor(async () => (await db.doc(`users/${b}`).get()).get('fcmToken') === undefined), 'legado inválido removido');
  assert.strictEqual((await db.doc(`users/${a}`).get()).get('fcmToken'), 'legado-ok');
  assert.strictEqual((await db.collection(`users/${b}/devices`).get()).size, 1);
});

test('regras: dono grava/lê/apaga só os próprios aparelhos; logout de um não afeta o outro', async () => {
  const me = env.authenticatedContext('dono').firestore();
  const other = env.authenticatedContext('intruso').firestore();
  const d1 = devId(); const d2 = devId();
  const ok = (token) => ({ token, platform: 'android', updatedAt: serverTimestamp() });
  await assertSucceeds(setDoc(doc(me, `users/dono/devices/${d1}`), ok('tok-1')));
  await assertSucceeds(setDoc(doc(me, `users/dono/devices/${d2}`), { ...ok('tok-2'), platform: 'web' }));
  // renovação do token: atualiza só este documento
  await assertSucceeds(setDoc(doc(me, `users/dono/devices/${d1}`), ok('tok-1b')));
  // campos validados
  await assertFails(setDoc(doc(me, `users/dono/devices/${devId()}`), { ...ok('t'), extra: 1 }));
  await assertFails(setDoc(doc(me, `users/dono/devices/${devId()}`), { ...ok('t'), platform: 'tv' }));
  await assertFails(setDoc(doc(me, `users/dono/devices/${devId()}`), { ...ok(''), }));
  await assertFails(setDoc(doc(me, `users/dono/devices/${devId()}`), { token: 't', platform: 'ios', updatedAt: new Date(2020, 0, 1) }));
  await assertFails(setDoc(doc(me, 'users/dono/devices/curto'), ok('t')));
  // outro usuário não lê, não grava, não apaga, não lista
  await assertFails(getDoc(doc(other, `users/dono/devices/${d1}`)));
  await assertFails(setDoc(doc(other, `users/dono/devices/${d1}`), ok('roubado')));
  await assertFails(deleteDoc(doc(other, `users/dono/devices/${d1}`)));
  await assertFails(getDocs(collection(other, 'users/dono/devices')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), `users/dono/devices/${d1}`)));
  // logout do aparelho 1: apaga só ele
  await assertSucceeds(getDoc(doc(me, `users/dono/devices/${d1}`)));
  await assertSucceeds(deleteDoc(doc(me, `users/dono/devices/${d1}`)));
  await env.withSecurityRulesDisabled(async (ctx) => {
    const s = await getDocs(collection(ctx.firestore(), 'users/dono/devices'));
    assert.deepStrictEqual(s.docs.map((d) => d.id), [d2]);
  });
});

test('exclusão de conta apaga os aparelhos', async () => {
  const u = await admin.auth().createUser({ email: `${rid('del')}@test.dev`, password: 'Senha123!' });
  await db.doc(`users/${u.uid}`).set({ type: 'client', name: 'Saindo' });
  await device(u.uid, 'tok-a'); await device(u.uid, 'tok-b');
  await admin.auth().deleteUser(u.uid);
  assert.ok(await waitFor(async () => (await db.collection(`users/${u.uid}/devices`).get()).empty), 'devices apagados');
  assert.ok(await waitFor(async () => !(await db.doc(`users/${u.uid}`).get()).exists));
});
