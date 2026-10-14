'use strict';
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { ref, uploadString, getBytes, deleteObject } = require('firebase/storage');
const { doc, setDoc } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    // Regras cross-service (Storage→Firestore) usam o projeto do emulador.
    projectId: process.env.GCLOUD_PROJECT || 'demo-carajas360',
    storage: { rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'), host: '127.0.0.1', port: 9199 },
    firestore: { rules: 'rules_version = "2"; service cloud.firestore { match /databases/{d}/documents { match /{x=**} { allow read, write: if false; } } }', host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/admin'), { type: 'admin' });
    const st = ctx.storage();
    await uploadString(ref(st, 'providers/pro/document/rg.jpg'), 'x', 'raw', { contentType: 'image/jpeg' });
    await uploadString(ref(st, 'providers/pro/photo/p.jpg'), 'x', 'raw', { contentType: 'image/jpeg' });
    await uploadString(ref(st, 'users/u1/private/a.jpg'), 'x', 'raw', { contentType: 'image/jpeg' });
  });
});
after(async () => { await env.cleanup(); });

const st = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();

test('documento de verificação: só dono e admin leem', async () => {
  await assertFails(getBytes(ref(st('outro'), 'providers/pro/document/rg.jpg')));
  await assertFails(getBytes(ref(st(null), 'providers/pro/document/rg.jpg')));
  await assertSucceeds(getBytes(ref(st('pro'), 'providers/pro/document/rg.jpg')));
});

test('documento de verificação: admin lê', async () => {
  // Admin por custom claim (recomendado) e por users/{uid}.type == 'admin'.
  const claimAdmin = env.authenticatedContext('staff', { admin: true }).storage();
  await assertSucceeds(getBytes(ref(claimAdmin, 'providers/pro/document/rg.jpg')));
});

test('documento de verificação: admin via users/{uid}.type (cross-service)', async () => {
  await assertSucceeds(getBytes(ref(st('admin'), 'providers/pro/document/rg.jpg')));
});

test('foto de perfil do prestador é pública', async () => {
  await assertSucceeds(getBytes(ref(st(null), 'providers/pro/photo/p.jpg')));
});

test('prestador só envia documento na própria pasta e em tipos permitidos', async () => {
  await assertFails(uploadString(ref(st('outro'), 'providers/pro/document/x.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertFails(uploadString(ref(st('pro'), 'providers/pro/qualquer/x.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertFails(uploadString(ref(st('pro'), 'providers/pro/document/x.exe'), 'x', 'raw', { contentType: 'application/x-msdownload' }));
  await assertSucceeds(uploadString(ref(st('pro'), 'providers/pro/selfie/s.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
});

test('arquivos do usuário fora de /photo não são públicos', async () => {
  await assertFails(getBytes(ref(st('outro'), 'users/u1/private/a.jpg')));
  await assertSucceeds(getBytes(ref(st('u1'), 'users/u1/private/a.jpg')));
});

// ── Auditoria completa ──────────────────────────────────────────────
test('auditoria: SVG não entra em caminho público', async () => {
  await assertFails(uploadString(ref(st('u1'), 'users/u1/photo/x.svg'), '<svg onload="alert(1)"/>', 'raw', { contentType: 'image/svg+xml' }));
  await assertSucceeds(uploadString(ref(st('u1'), 'users/u1/photo/x.png'), 'x', 'raw', { contentType: 'image/png' }));
});

test('auditoria: dono apaga a própria foto (antes negado)', async () => {
  await assertSucceeds(deleteObject(ref(st('u1'), 'users/u1/photo/x.png')));
});

test('auditoria: documento de verificação não é substituído depois de enviado', async () => {
  await assertFails(uploadString(ref(st('pro'), 'providers/pro/document/rg.jpg'), 'y', 'raw', { contentType: 'image/jpeg' }));
  await assertSucceeds(uploadString(ref(st('pro'), 'providers/pro/document/rg2.jpg'), 'y', 'raw', { contentType: 'image/jpeg' }));
});

test('auditoria: foto de anúncio novo vai para a pasta do dono', async () => {
  await assertSucceeds(uploadString(ref(st('dono'), 'rentalPhotos/dono/1.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertFails(uploadString(ref(st('outro'), 'rentalPhotos/dono/2.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertSucceeds(getBytes(ref(st(null), 'rentalPhotos/dono/1.jpg')), 'foto de anúncio é pública');
});
