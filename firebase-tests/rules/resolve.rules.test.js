'use strict';
/** Regras da Fase 4: atendimento do prestador, agenda, privados e anexos do Resolve. */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, serverTimestamp } = require('firebase/firestore');
const { ref, uploadString, getBytes } = require('firebase/storage');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-carajas360',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'), host: '127.0.0.1', port: 9199 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'providers/r4pro'), { userId: 'r4pro', name: 'Pro', categories: ['eletricista'], verified: true, active: true, rating: 0, totalReviews: 0 });
    await setDoc(doc(db, 'scheduleEntries/rs_x'), { orderId: 'rs_x', clientId: 'r4cli', providerId: 'r4pro', date: '2026-10-20', status: 'to_confirm' });
    await setDoc(doc(db, 'resolveRequests/r4req'), { clientId: 'r4cli', status: 'open', category: 'eletricista' });
    await setDoc(doc(db, 'resolveRequests/r4req/private/details'), { address: 'Rua A', attachments: [{ path: 'resolveUploads/r4cli/u/a.jpg' }] });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();
const st = (uid) => env.authenticatedContext(uid).storage();

test('prestador configura atendimento (raio, localização, disponibilidade, pausa) com formato válido', async () => {
  const db = as('r4pro');
  await assertSucceeds(updateDoc(doc(db, 'providers/r4pro'), {
    radiusKm: 25, geo: { lat: -5.37, lng: -49.12 },
    availability: { weekdays: [1, 2, 3], periods: ['morning'] }, acceptingRequests: true, unavailableUntil: '2026-12-31',
  }));
  await assertFails(updateDoc(doc(db, 'providers/r4pro'), { radiusKm: 999 }));
  await assertFails(updateDoc(doc(db, 'providers/r4pro'), { geo: { lat: 200, lng: 0 } }));
  await assertFails(updateDoc(doc(db, 'providers/r4pro'), { availability: { weekdays: [9] } }));
  await assertFails(updateDoc(doc(db, 'providers/r4pro'), { availability: { periods: ['madrugada'] } }));
  await assertFails(updateDoc(doc(db, 'providers/r4pro'), { unavailableUntil: 'amanhã' }));
  await assertFails(updateDoc(doc(as('outro'), 'providers/r4pro'), { radiusKm: 10 }));
});

test('agenda do pedido: só participantes leem; ninguém grava pelo app', async () => {
  await assertSucceeds(getDoc(doc(as('r4cli'), 'scheduleEntries/rs_x')));
  await assertSucceeds(getDoc(doc(as('r4pro'), 'scheduleEntries/rs_x')));
  await assertFails(getDoc(doc(as('outro'), 'scheduleEntries/rs_x')));
  await assertFails(updateDoc(doc(as('r4pro'), 'scheduleEntries/rs_x'), { status: 'confirmed' }));
});

test('dados privados: cliente ajusta endereço, mas não injeta anexos', async () => {
  await assertSucceeds(updateDoc(doc(as('r4cli'), 'resolveRequests/r4req/private/details'), { address: 'Rua B', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(as('r4cli'), 'resolveRequests/r4req/private/details'), { attachments: [{ path: 'providers/x/document/rg.jpg' }] }));
  await assertFails(setDoc(doc(as('r4cli'), 'resolveRequests/novo/private/details'), { address: 'x' }));
});

test('anexos do Resolve: só na própria pasta, imagem/PDF até 10 MB; terceiros não leem', async () => {
  await assertSucceeds(uploadString(ref(st('r4cli'), 'resolveUploads/r4cli/u1/foto.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertSucceeds(uploadString(ref(st('r4cli'), 'resolveUploads/r4cli/u1/laudo.pdf'), 'x', 'raw', { contentType: 'application/pdf' }));
  await assertFails(uploadString(ref(st('r4cli'), 'resolveUploads/outro/u1/foto.jpg'), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertFails(uploadString(ref(st('r4cli'), 'resolveUploads/r4cli/u1/script.html'), 'x', 'raw', { contentType: 'text/html' }));
  await assertFails(uploadString(ref(st('r4cli'), 'resolveUploads/r4cli/u1/foto.jpg'), 'y', 'raw', { contentType: 'image/jpeg' }), 'sem sobrescrever');
  await assertSucceeds(getBytes(ref(st('r4cli'), 'resolveUploads/r4cli/u1/foto.jpg')));
  await assertFails(getBytes(ref(st('r4pro'), 'resolveUploads/r4cli/u1/foto.jpg')), 'prestador recebe só por URL temporária');
});
