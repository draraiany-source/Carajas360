'use strict';
/** Pendência 3 (Mercado): contador e visibilidade dos produtos são só do servidor. */
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, deleteDoc, getDocs, query, where, collection } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-pend3-market-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'support' });
    await setDoc(doc(db, 'stores/ok'), { ownerId: 'dono', name: 'Aprovada', active: true, verified: true, totalProducts: 1, rating: 0, totalReviews: 0 });
    await setDoc(doc(db, 'stores/off'), { ownerId: 'dono2', name: 'Desativada', active: false, verified: true, totalProducts: 1, rating: 0, totalReviews: 0 });
    await setDoc(doc(db, 'products/p_ok'), { storeId: 'ok', name: 'Arroz', price: 10, stock: 5, active: true, storeActive: true, rating: 0, totalReviews: 0 });
    await setDoc(doc(db, 'products/p_off'), { storeId: 'off', name: 'Feijão', price: 10, stock: 5, active: true, storeActive: false, rating: 0, totalReviews: 0 });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('lojista não altera totalProducts da loja (nem cria loja com contador)', async () => {
  await assertFails(updateDoc(doc(as('dono'), 'stores/ok'), { totalProducts: 99 }));
  await assertSucceeds(updateDoc(doc(as('dono'), 'stores/ok'), { name: 'Novo nome' }), 'outros campos continuam editáveis');
  await assertFails(setDoc(doc(as('novo'), 'stores/n1'), { ownerId: 'novo', name: 'Nova', rating: 0, totalReviews: 0, verified: false, totalProducts: 5 }));
  await assertSucceeds(setDoc(doc(as('novo'), 'stores/n2'), { ownerId: 'novo', name: 'Nova', rating: 0, totalReviews: 0, verified: false, totalProducts: 0, active: true }));
  await assertSucceeds(updateDoc(doc(as('adm'), 'stores/ok'), { totalProducts: 3 }), 'admin corrige');
});

test('lojista não grava storeActive no produto (criação nem edição)', async () => {
  const p = { storeId: 'off', name: 'Novo', price: 5, stock: 1, active: true, rating: 0, totalReviews: 0 };
  await assertFails(setDoc(doc(as('dono2'), 'products/n1'), { ...p, storeActive: true }), 'loja desativada não se publica sozinha');
  await assertSucceeds(setDoc(doc(as('dono2'), 'products/n2'), p));
  await assertFails(updateDoc(doc(as('dono2'), 'products/p_off'), { storeActive: true }));
  await assertSucceeds(updateDoc(doc(as('dono2'), 'products/p_off'), { price: 12 }), 'edição normal continua');
  await assertSucceeds(deleteDoc(doc(as('dono2'), 'products/n2')));
});

test('vitrine (storeActive == true) não traz produto de loja desativada', async () => {
  const s = await getDocs(query(collection(anon(), 'products'), where('active', '==', true), where('storeActive', '==', true)));
  assert.deepStrictEqual(s.docs.map((d) => d.id), ['p_ok']);
  // Perfil público e categoria usam as mesmas igualdades.
  const byStore = await getDocs(query(collection(anon(), 'products'), where('active', '==', true), where('storeId', '==', 'off'), where('storeActive', '==', true)));
  assert.strictEqual(byStore.size, 0);
  // Lista pública de lojas: só ativas e aprovadas.
  const stores = await getDocs(query(collection(anon(), 'stores'), where('active', '==', true), where('verified', '==', true)));
  assert.deepStrictEqual(stores.docs.map((d) => d.id), ['ok']);
});

test('aprovação de loja: só o admin aprova (fila "Lojas" do painel); o dono não se aprova', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'stores/nova'), { ownerId: 'dono3', name: 'Nova', active: true, verified: false, totalProducts: 0, rating: 0, totalReviews: 0 });
  });
  await assertFails(updateDoc(doc(as('dono3'), 'stores/nova'), { verified: true }));
  await assertSucceeds(getDocs(query(collection(as('adm'), 'stores'), where('verified', '==', false))), 'fila de pendentes');
  await assertSucceeds(updateDoc(doc(as('adm'), 'stores/nova'), { verified: true }));
});
