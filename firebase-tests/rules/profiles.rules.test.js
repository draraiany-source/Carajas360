'use strict';
/** Regras da Fase 6: perfil público mínimo legível; perfil privado continua privado. */
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-profiles-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/ana'), { name: 'Ana Costa', email: 'ana@x.com', type: 'client' });
    await setDoc(doc(ctx.firestore(), 'publicProfiles/ana'), { name: 'Ana C.', photoUrl: null, kind: 'client' });
  });
});
after(async () => { await env.cleanup(); });
const as = (uid) => env.authenticatedContext(uid).firestore();

test('chat: outra pessoa lê só o perfil público mínimo', async () => {
  await assertFails(getDoc(doc(as('bruno'), 'users/ana')), 'perfil privado continua fechado');
  await assertSucceeds(getDoc(doc(as('bruno'), 'publicProfiles/ana')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'publicProfiles/ana')));
  await assertFails(setDoc(doc(as('ana'), 'publicProfiles/ana'), { name: 'Admin Oficial', kind: 'support' }), 'ninguém forja o próprio perfil público');
});
