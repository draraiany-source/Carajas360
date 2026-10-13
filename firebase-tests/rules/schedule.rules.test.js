'use strict';
/** Regras da Fase 5: agenda de saúde, dados clínicos e reservas de locação. */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, addDoc, collection, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-schedule-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/adm'), { type: 'admin' });
    await setDoc(doc(db, 'providers/medico'), { userId: 'medico', name: 'Dra', categories: ['c'], verified: true, active: true });
    await setDoc(doc(db, 'appointments/a1'), { clientId: 'pac', providerId: 'medico', status: 'scheduled', startMs: 1 });
    await setDoc(doc(db, 'appointments/a1/private/clinical'), { clientId: 'pac', providerId: 'medico', reason: 'sintoma' });
    await setDoc(doc(db, 'bookings/b1'), { clientId: 'loc', ownerId: 'dono', status: 'pending', total: 700 });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();

test('agendamento: app não cria nem altera (só callables)', async () => {
  await assertFails(addDoc(collection(as('pac'), 'appointments'), { clientId: 'pac', type: 'Consulta', time: '09:00', status: 'scheduled' }));
  await assertFails(updateDoc(doc(as('pac'), 'appointments/a1'), { status: 'cancelled' }));
  await assertFails(updateDoc(doc(as('medico'), 'appointments/a1'), { startMs: 2 }));
  await assertSucceeds(getDoc(doc(as('pac'), 'appointments/a1')));
  await assertSucceeds(getDoc(doc(as('medico'), 'appointments/a1')));
  await assertFails(getDoc(doc(as('outro'), 'appointments/a1')));
});

test('dados clínicos: só paciente e profissional (nem admin)', async () => {
  await assertSucceeds(getDoc(doc(as('pac'), 'appointments/a1/private/clinical')));
  await assertSucceeds(getDoc(doc(as('medico'), 'appointments/a1/private/clinical')));
  await assertFails(getDoc(doc(as('adm'), 'appointments/a1/private/clinical')));
  await assertFails(getDoc(doc(as('outro'), 'appointments/a1/private/clinical')));
  await assertFails(setDoc(doc(as('pac'), 'appointments/a1/private/clinical'), { reason: 'x' }));
});

test('agenda do profissional: só o próprio publica; formato validado', async () => {
  const ok = { weekly: { 1: [{ start: '08:00', end: '12:00' }] }, slotMinutes: 30, services: [], updatedAt: serverTimestamp() };
  await assertSucceeds(setDoc(doc(as('medico'), 'healthSchedules/medico'), ok));
  await assertFails(setDoc(doc(as('outro'), 'healthSchedules/medico'), ok));
  await assertFails(setDoc(doc(as('semperfil'), 'healthSchedules/semperfil'), ok), 'exige perfil de profissional');
  await assertFails(setDoc(doc(as('medico'), 'healthSchedules/medico'), { ...ok, slotMinutes: 7 }));
  await assertFails(setDoc(doc(as('medico'), 'healthSchedules/medico'), { ...ok, bookedBy: 'x' }));
  await assertSucceeds(getDoc(doc(as('pac'), 'healthSchedules/medico')));
  await assertFails(setDoc(doc(as('medico'), 'healthCalendars/medico'), { version: 1 }));
});

test('reserva de locação: app não cria, não altera status nem total', async () => {
  await assertFails(addDoc(collection(as('loc'), 'bookings'), { clientId: 'loc', ownerId: 'dono', total: 1, status: 'confirmed' }));
  await assertFails(updateDoc(doc(as('dono'), 'bookings/b1'), { status: 'confirmed' }));
  await assertFails(updateDoc(doc(as('loc'), 'bookings/b1'), { status: 'cancelled' }));
  await assertSucceeds(getDoc(doc(as('loc'), 'bookings/b1')));
  await assertFails(getDoc(doc(as('outro'), 'bookings/b1')));
  await assertFails(addDoc(collection(as('loc'), 'notifications'), { userId: 'dono', title: 'x', body: 'y' }), 'notificação só pelo servidor');
});
