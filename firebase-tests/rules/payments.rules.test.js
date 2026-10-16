'use strict';
/**
 * Regras da Fase 3: pedidos do Mercado, tentativas de pagamento, carteira,
 * reembolsos e configuração financeira são gravados só pelo servidor;
 * leitura restrita ao dono / loja / admin financeiro.
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-payments-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/fin'), { type: 'admin', adminRole: 'financial' });
    await setDoc(doc(db, 'providers/pro'), { userId: 'pro', verified: true, active: true }); // pedido só para prestador verificado
    await setDoc(doc(db, 'users/mod'), { type: 'admin', adminRole: 'moderator' });
    await setDoc(doc(db, 'marketOrders/mo1'), { clientId: 'cli', storeOwnerId: 'loja', totalCents: 5500, status: 'pending_payment' });
    await setDoc(doc(db, 'marketOrders/mo1/events/e1'), { type: 'created' });
    await setDoc(doc(db, 'paymentAttempts/pa1'), { userId: 'cli', targetId: 'mo1', status: 'pending' });
    await setDoc(doc(db, 'walletRecharges/rc1'), { userId: 'cli', amountCents: 1000 });
    await setDoc(doc(db, 'earnings/mo1'), { sellerId: 'loja', netCents: 4000 });
    await setDoc(doc(db, 'refunds/rf1'), { targetId: 'mo1', amountCents: 100 });
    await setDoc(doc(db, 'financialIssues/i1'), { type: 'x' });
    await setDoc(doc(db, 'webhookEvents/w1'), { dataId: '1' });
    await setDoc(doc(db, 'config/finance'), { commissionBps: 1500, version: 1 });
    await setDoc(doc(db, 'wallets/cli'), { balanceCents: 100, balance: 1 });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();

test('pedido do Mercado: cliente e loja leem; terceiros não; ninguém grava', async () => {
  await assertSucceeds(getDoc(doc(as('cli'), 'marketOrders/mo1')));
  await assertSucceeds(getDoc(doc(as('loja'), 'marketOrders/mo1')));
  await assertSucceeds(getDoc(doc(as('cli'), 'marketOrders/mo1/events/e1')));
  await assertSucceeds(getDoc(doc(as('fin'), 'marketOrders/mo1')));
  await assertFails(getDoc(doc(as('outro'), 'marketOrders/mo1')));
  await assertFails(getDoc(doc(as('outro'), 'marketOrders/mo1/events/e1')));
  await assertFails(getDoc(doc(as('mod'), 'marketOrders/mo1')), 'admin sem perfil financeiro');
  await assertFails(updateDoc(doc(as('cli'), 'marketOrders/mo1'), { totalCents: 1 }), 'total adulterado');
  await assertFails(updateDoc(doc(as('cli'), 'marketOrders/mo1'), { status: 'paid' }), 'aprovação local');
  await assertFails(setDoc(doc(as('cli'), 'marketOrders/mo2'), { clientId: 'cli', totalCents: 1 }));
  await assertFails(updateDoc(doc(as('fin'), 'marketOrders/mo1'), { status: 'paid' }));
});

test('tentativas, recargas e repasses: só o dono lê; ninguém grava', async () => {
  await assertSucceeds(getDoc(doc(as('cli'), 'paymentAttempts/pa1')));
  await assertFails(getDoc(doc(as('outro'), 'paymentAttempts/pa1')));
  await assertFails(updateDoc(doc(as('cli'), 'paymentAttempts/pa1'), { status: 'approved' }));
  await assertSucceeds(getDoc(doc(as('cli'), 'walletRecharges/rc1')));
  await assertFails(getDoc(doc(as('outro'), 'walletRecharges/rc1')));
  await assertSucceeds(getDoc(doc(as('loja'), 'earnings/mo1')));
  await assertFails(getDoc(doc(as('cli'), 'earnings/mo1')));
  await assertFails(setDoc(doc(as('loja'), 'earnings/mo1'), { sellerId: 'loja', netCents: 999999 }));
});

test('reembolsos, divergências e webhooks: só admin financeiro lê', async () => {
  for (const p of ['refunds/rf1', 'financialIssues/i1', 'webhookEvents/w1']) {
    await assertSucceeds(getDoc(doc(as('fin'), p)));
    await assertFails(getDoc(doc(as('cli'), p)));
    await assertFails(getDoc(doc(as('mod'), p)));
    await assertFails(setDoc(doc(as('fin'), p), { x: 1 }));
  }
});

test('carteira: saldo não é alterável pelo cliente', async () => {
  await assertSucceeds(getDoc(doc(as('cli'), 'wallets/cli')));
  await assertFails(updateDoc(doc(as('cli'), 'wallets/cli'), { balanceCents: 999999 }));
  await assertFails(setDoc(doc(as('cli'), 'transactions/t1'), { userId: 'cli', type: 'credit', amountCents: 100 }));
});

test('config/finance: leitura autenticada; gravação só pela callable (nem admin)', async () => {
  await assertSucceeds(getDoc(doc(as('cli'), 'config/finance')));
  await assertFails(updateDoc(doc(as('fin'), 'config/finance'), { commissionBps: 0 }));
  // Homologação: config/platform (manutenção, contatos) só admin master; config/booking só callable.
  await assertFails(setDoc(doc(as('fin'), 'config/platform'), { appName: 'X' }), 'admin não master');
  await assertFails(setDoc(doc(as('fin'), 'config/booking'), { holdMinutes: 1 }));
  await assertSucceeds(setDoc(doc(as('fin'), 'config/banners'), { appName: 'X' }), 'outras configs seguem como antes');
});

test('carrinho: só o dono, formato restrito', async () => {
  await assertSucceeds(setDoc(doc(as('cli'), 'carts/cli'), { items: [{ productId: 'p1', qty: 2 }], updatedAt: 1 }));
  await assertSucceeds(getDoc(doc(as('cli'), 'carts/cli')));
  await assertFails(getDoc(doc(as('outro'), 'carts/cli')));
  await assertFails(setDoc(doc(as('outro'), 'carts/cli'), { items: [] }));
  await assertFails(setDoc(doc(as('cli'), 'carts/cli'), { items: [], totalCents: 1 }));
  await assertSucceeds(deleteDoc(doc(as('cli'), 'carts/cli')));
});

test('simulador do gateway nunca acessível pelo app', async () => {
  await assertFails(getDocs(collection(as('cli'), '_fakeGateway')));
  await assertFails(setDoc(doc(as('cli'), '_fakeGatewayControl/config'), { nextCreate: 'reject' }));
});

test('pedido de serviço: cliente não grava condições financeiras', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'catalogNodes/eletricista'), { level: 'group', active: true, effectiveActive: true });
  });
  const base = { clientId: 'cli', providerId: 'pro', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, category: 'eletricista' };
  await assertSucceeds(setDoc(doc(as('cli'), 'orders/s1'), base));
  await assertFails(setDoc(doc(as('cli'), 'orders/s2'), { ...base, financeTerms: { commissionBps: 0 } }));
});
