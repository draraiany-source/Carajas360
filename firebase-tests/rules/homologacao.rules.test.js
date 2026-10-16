'use strict';
/** Regras da etapa de homologação: "Meus chamados", modo manutenção e mensagem automática de pedido. */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, collection, getDocs, getDoc, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-hml-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'support' });
    await setDoc(doc(db, 'users/master'), { type: 'admin', adminRole: 'master' });
    await setDoc(doc(db, 'support/t1'), { userId: 'cli', subject: 'Ajuda', message: 'Texto', status: 'open', priority: 'normal' });
    await setDoc(doc(db, 'chatRooms/cli_pro'), { participants: ['cli', 'pro'] });
    await setDoc(doc(db, 'catalogNodes/eletricista'), { name: 'Eletricista', effectiveActive: true });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();
const msg = (authorId, authorRole, extra = {}) => ({ authorId, authorRole, text: 'Olá', createdAt: serverTimestamp(), ...extra });

test('chamado: só o autor e a equipe leem e respondem; papel conferido', async () => {
  await assertSucceeds(addDoc(collection(as('cli'), 'support/t1/messages'), msg('cli', 'user')));
  await assertSucceeds(addDoc(collection(as('adm'), 'support/t1/messages'), msg('adm', 'support')));
  await assertFails(addDoc(collection(as('cli'), 'support/t1/messages'), msg('cli', 'support')), 'cliente fingindo ser o suporte');
  await assertFails(addDoc(collection(as('outro'), 'support/t1/messages'), msg('outro', 'user')), 'terceiro');
  await assertFails(addDoc(collection(as('cli'), 'support/t1/messages'), msg('cli', 'user', { createdAt: new Date(2020, 0, 1) })));
  await assertSucceeds(getDocs(collection(as('cli'), 'support/t1/messages')));
  await assertFails(getDocs(collection(as('outro'), 'support/t1/messages')));
  await assertFails(getDoc(doc(as('outro'), 'support/t1')));
});

test('modo manutenção: usuário não cria pedido nem mensagem; admin cria; só master liga a chave', async () => {
  await assertFails(setDoc(doc(as('adm'), 'config/platform'), { maintenanceMode: true }), 'admin comum');
  await assertSucceeds(setDoc(doc(as('master'), 'config/platform'), { maintenanceMode: true }));
  const order = { clientId: 'cli', providerId: 'pro', category: 'eletricista', title: 'X', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, payoutStatus: 'none', createdAt: serverTimestamp() };
  await assertFails(addDoc(collection(as('cli'), 'orders'), order));
  await assertFails(addDoc(collection(as('cli'), 'chatRooms/cli_pro/messages'), { senderId: 'cli', senderName: 'C', text: 'oi', read: false, createdAt: serverTimestamp() }));
  await assertSucceeds(addDoc(collection(as('adm'), 'orders'), { ...order, clientId: 'adm' }));
  await assertSucceeds(setDoc(doc(as('master'), 'config/platform'), { maintenanceMode: false }));
  await assertSucceeds(addDoc(collection(as('cli'), 'orders'), order));
});

test('mensagem automática de pedido pode levar orderId (o servidor não avisa em dobro)', async () => {
  await assertSucceeds(addDoc(collection(as('cli'), 'chatRooms/cli_pro/messages'), { senderId: 'cli', senderName: 'C', text: '📋 Nova solicitação', read: false, orderId: 'o1', createdAt: serverTimestamp() }));
});

test('coleções internas (retenções, usos de cupom, relógio de teste) não são acessíveis pelo app', async () => {
  for (const p of ['bookingHolds/cli', 'couponRedemptions/c_cli', '_testClock/current']) {
    await assertFails(getDoc(doc(as('cli'), p)));
    await assertFails(setDoc(doc(as('cli'), p), { x: 1 }));
  }
  await assertFails(setDoc(doc(as('adm'), 'config/booking'), { holdMinutes: 1 }), 'config de reservas só pela callable');
});
