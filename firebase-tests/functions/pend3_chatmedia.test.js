'use strict';
/** pend3 (LGPD): anexos do chat por URL temporária, migração e remoção. */
const { test, before } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const ST = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const BUCKET = `${PROJECT}.appspot.com`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: BUCKET });
const db = admin.firestore();
const bucket = admin.storage().bucket(BUCKET);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
/** Download como o app faria no emulador (login no cabeçalho, se houver). */
async function download(url, user) {
  const r = await fetch(url, { headers: user ? { Authorization: `Firebase ${user.token}` } : {} });
  return { status: r.status, body: r.ok ? await r.text() : null };
}
/** Envio pelo cliente (REST do emulador, passa pelas storage.rules). */
async function clientUpload(user, path, content) {
  // multipart como o SDK (o emulador só vê o contentType assim).
  const bd = 'pend3bnd';
  const body = `--${bd}\r\nContent-Type: application/json; charset=utf-8\r\n\r\n${JSON.stringify({ name: path, contentType: 'image/jpeg' })}` +
    `\r\n--${bd}\r\nContent-Type: image/jpeg\r\n\r\n${content}\r\n--${bd}--`;
  const r = await fetch(`http://${ST}/v0/b/${BUCKET}/o?name=${encodeURIComponent(path)}`, {
    method: 'POST',
    headers: { Authorization: `Firebase ${user.token}`, 'Content-Type': `multipart/related; boundary=${bd}`, 'X-Goog-Upload-Protocol': 'multipart' },
    body,
  });
  return { status: r.status, json: r.ok ? await r.json() : null };
}
const tokensOf = async (path) => ((await bucket.file(path).getMetadata())[0].metadata || {}).firebaseStorageDownloadTokens;

let a; let b; let intruso; let adm; let room; let path; let msgId;

before(async () => {
  [a, b, intruso, adm] = await Promise.all(['cma', 'cmb', 'cmi', 'cmadm'].map(signUp));
  room = [a.uid, b.uid].sort().join('_');
  await db.doc(`chatRooms/${room}`).set({ participants: [a.uid, b.uid].sort() });
  await db.doc(`users/${adm.uid}`).set({ type: 'admin', adminRole: 'master', name: 'Adm' });
  await db.doc(`users/${a.uid}`).set({ type: 'client', name: 'A' });
});

test('envio do participante: o token criado pelo Storage é removido pelo servidor', async () => {
  path = `chat_media/${room}/${a.uid}_1.jpg`;
  const up = await clientUpload(a, path, 'FOTO-SECRETA');
  assert.strictEqual(up.status, 200);
  const created = up.json.downloadTokens;
  assert.ok(await waitFor(async () => !(await tokensOf(path))), 'token removido após o envio');
  assert.ok(created, 'o emulador cria token no envio (como produção)');
  const old = await download(`http://${ST}/v0/b/${BUCKET}/o/${encodeURIComponent(path)}?alt=media&token=${created}`);
  assert.notStrictEqual(old.status, 200, 'link com o token do envio não abre');
  // Envio com nome sem o próprio uid é recusado pelas regras.
  assert.notStrictEqual((await clientUpload(a, `chat_media/${room}/2.jpg`, 'x')).status, 200);
  assert.notStrictEqual((await clientUpload(intruso, `chat_media/${room}/${intruso.uid}_3.jpg`, 'x')).status, 200);
  const m = await db.collection(`chatRooms/${room}/messages`).add({
    senderId: a.uid, senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(), mediaPath: path, mediaType: 'image',
  });
  msgId = m.id;
});

test('participantes recebem URL temporária e baixam; outros são negados', async () => {
  const r = await call('getChatMediaUrl', a, { roomId: room, messageId: msgId });
  assert.ok(r.url && r.expiresAt > Date.now() && r.expiresAt <= Date.now() + 15 * 60 * 1000);
  assert.ok(!/token=/.test(r.url), 'URL sem token permanente');
  assert.deepStrictEqual(await download(r.url, a), { status: 200, body: 'FOTO-SECRETA' });
  const rb = await call('getChatMediaUrl', b, { roomId: room, messageId: msgId });
  assert.strictEqual((await download(rb.url, b)).status, 200);
  await assert.rejects(call('getChatMediaUrl', intruso, { roomId: room, messageId: msgId }), /PERMISSION_DENIED/);
  await assert.rejects(call('getChatMediaUrl', null, { roomId: room, messageId: msgId }), /UNAUTHENTICATED/);
  // Leitura direta no Storage (com a URL ou o SDK): só participante.
  assert.strictEqual((await download(r.url, intruso)).status, 403);
  assert.strictEqual((await download(r.url, null)).status, 403);
  await assert.rejects(call('getChatMediaUrl', a, { roomId: room, messageId: 'nao-existe' }), /NOT_FOUND/);
  await assert.rejects(call('getChatMediaUrl', a, { roomId: '../x', messageId: msgId }), /INVALID_ARGUMENT/);
});

test('quem é removido da conversa perde o acesso na hora', async () => {
  await db.doc(`chatRooms/${room}`).update({ participants: [a.uid] });
  try {
    await assert.rejects(call('getChatMediaUrl', b, { roomId: room, messageId: msgId }), /PERMISSION_DENIED/);
    const r = await call('getChatMediaUrl', a, { roomId: room, messageId: msgId });
    assert.strictEqual((await download(r.url, b)).status, 403, 'leitura direta também');
  } finally {
    await db.doc(`chatRooms/${room}`).update({ participants: [a.uid, b.uid].sort() });
  }
});

test('apagar para todos: URL negada e arquivo apagado pelo servidor', async () => {
  const ref = db.doc(`chatRooms/${room}/messages/${msgId}`);
  await ref.update({ deleted: true, text: '', mediaPath: admin.firestore.FieldValue.delete(), mediaType: admin.firestore.FieldValue.delete() });
  await assert.rejects(call('getChatMediaUrl', a, { roomId: room, messageId: msgId }), /NOT_FOUND/);
  assert.ok(await waitFor(async () => !(await bucket.file(path).exists())[0]), 'arquivo removido do Storage');
  // Anexo da outra pessoa referenciado por engano não é apagado.
  const other = `chat_media/${room}/${b.uid}_9.jpg`;
  await bucket.file(other).save('DO-B', { contentType: 'image/jpeg' });
  const m = await db.collection(`chatRooms/${room}/messages`).add({
    senderId: a.uid, senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(), mediaPath: other, mediaType: 'image',
  });
  await m.update({ deleted: true, text: '', mediaPath: admin.firestore.FieldValue.delete(), mediaType: admin.firestore.FieldValue.delete() });
  await sleep(2500);
  assert.ok((await bucket.file(other).exists())[0], 'arquivo de outro remetente fica');
});

test('migração: converte mensagem antiga, revoga o token antigo e é idempotente', async () => {
  const legacyPath = `chat_media/${room}/171000.jpg`;
  const tok = `tok-${Date.now()}`;
  await bucket.file(legacyPath).save('ANTIGA', { contentType: 'image/jpeg' });
  await sleep(1000); // o gatilho do envio não vê token (o evento é do envio)
  await bucket.file(legacyPath).setMetadata({ metadata: { firebaseStorageDownloadTokens: tok } });
  const oldUrl = `http://${ST}/v0/b/${BUCKET}/o/${encodeURIComponent(legacyPath)}?alt=media&token=${tok}`;
  const before = await download(oldUrl);
  const col = db.collection(`chatRooms/${room}/messages`);
  const legacy = await col.add({ senderId: a.uid, senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(), mediaUrl: oldUrl });
  const ext = await col.add({ senderId: a.uid, senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(), mediaUrl: 'https://golpe.example.com/x.jpg' });
  const docLegacy = await col.add({ senderId: a.uid, senderName: 'A', text: '📄 contrato.pdf', read: false, createdAt: new Date(),
    mediaUrl: `http://${ST}/v0/b/${BUCKET}/o/${encodeURIComponent(`chat_media/${room}/sumiu.pdf`)}?alt=media&token=x` });

  // Compatibilidade: antes da migração, o app já usa a callable (nunca o link).
  const pre = await call('getChatMediaUrl', b, { roomId: room, messageId: legacy.id });
  assert.strictEqual((await download(pre.url, b)).body, 'ANTIGA');
  await assert.rejects(call('getChatMediaUrl', b, { roomId: room, messageId: ext.id }), /NOT_FOUND/);

  await assert.rejects(call('adminMigrateChatMedia', a, {}), /PERMISSION_DENIED/);
  const runAll = async () => {
    const reports = []; let cursor = null;
    do {
      const r = await call('adminMigrateChatMedia', adm, { cursor, pageSize: 100 });
      reports.push(r); cursor = r.nextCursor;
    } while (cursor);
    return reports;
  };
  const first = await runAll();
  assert.ok(first[first.length - 1].done);
  assert.ok(first.reduce((s, r) => s + r.migrated, 0) >= 2);
  assert.ok(first.some((r) => r.items.some((i) => i.message === `${room}/${ext.id}` && i.result === 'discarded')));
  assert.ok(first.some((r) => r.items.some((i) => i.message === `${room}/${docLegacy.id}` && i.result === 'missing')));

  const l = (await legacy.get()).data();
  assert.strictEqual(l.mediaPath, legacyPath);
  assert.strictEqual(l.mediaType, 'image');
  assert.strictEqual(l.mediaUrl, undefined);
  const d = (await docLegacy.get()).data();
  assert.strictEqual(d.mediaType, 'document');
  assert.strictEqual(d.mediaName, 'contrato.pdf');
  const e = (await ext.get()).data();
  assert.strictEqual(e.mediaUrl, undefined);
  assert.strictEqual(e.mediaPath, undefined);
  assert.strictEqual(e.mediaDiscarded, true);
  assert.ok(!(await tokensOf(legacyPath)), 'token antigo removido do objeto');
  assert.strictEqual(before.status, 200, 'o link antigo abria antes da migração');
  assert.notStrictEqual((await download(oldUrl)).status, 200, 'link antigo com token não abre mais');
  const post = await call('getChatMediaUrl', b, { roomId: room, messageId: legacy.id });
  assert.strictEqual((await download(post.url, b)).body, 'ANTIGA');

  const second = await runAll();
  assert.ok(!second.some((r) => r.items.some((i) => i.message.startsWith(`${room}/`))), 'nada a refazer');
  assert.deepStrictEqual((await legacy.get()).data(), l);
});
