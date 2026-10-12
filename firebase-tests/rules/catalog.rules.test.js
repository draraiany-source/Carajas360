'use strict';
/** Regras da Fase 2: catálogo somente leitura no app; contratação exige item ativo. */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, serverTimestamp, collection, getDocs, query, where } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-catalog-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { type: 'admin' });
    await setDoc(doc(db, 'catalogNodes/cat_automoveis'), { level: 'category', name: 'Automóveis', active: false, effectiveActive: false });
    await setDoc(doc(db, 'catalogNodes/svc_freios'), { level: 'service', name: 'Freios', parentId: 'mecanico', active: true, effectiveActive: false });
    await setDoc(doc(db, 'catalogNodes/eletricista'), { level: 'group', name: 'Eletricista', active: true, effectiveActive: true });
    await setDoc(doc(db, 'serviceQuestionnaires/q1'), { serviceId: 'eletricista', status: 'published', version: 1 });
    await setDoc(doc(db, 'serviceQuestionnaires/q2'), { serviceId: 'eletricista', status: 'draft' });
    await setDoc(doc(db, 'companies/co1'), { ownerId: 'dono', name: 'Empresa', verified: true, active: true });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('catálogo: leitura pública (inclusive inativos, para históricos)', async () => {
  await assertSucceeds(getDoc(doc(anon(), 'catalogNodes/svc_freios')));
  await assertSucceeds(getDocs(collection(anon(), 'catalogNodes')));
});

test('catálogo: usuário comum e até admin não gravam direto (só via Functions)', async () => {
  await assertFails(setDoc(doc(as('u1'), 'catalogNodes/x'), { name: 'X' }));
  await assertFails(updateDoc(doc(as('u1'), 'catalogNodes/eletricista'), { active: false }));
  await assertFails(updateDoc(doc(as('admin'), 'catalogNodes/eletricista'), { name: 'Y' }));
  await assertFails(setDoc(doc(as('u1'), 'catalogMeta/current'), { version: 99 }));
  await assertFails(setDoc(doc(as('admin'), 'categories/legado'), { name: 'Legado' }));
  await assertFails(setDoc(doc(as('u1'), 'serviceQuestionnaires/q9'), { serviceId: 'eletricista', status: 'published' }));
});

test('questionários: publicados públicos; rascunhos só admin', async () => {
  await assertSucceeds(getDoc(doc(anon(), 'serviceQuestionnaires/q1')));
  await assertFails(getDoc(doc(as('u1'), 'serviceQuestionnaires/q2')));
  await assertSucceeds(getDoc(doc(as('admin'), 'serviceQuestionnaires/q2')));
  await assertSucceeds(getDocs(query(collection(anon(), 'serviceQuestionnaires'), where('status', '==', 'published'))));
});

test('nova contratação exige serviço ativo no catálogo', async () => {
  const base = { clientId: 'cli', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, title: 't' };
  await assertSucceeds(setDoc(doc(as('cli'), 'orders/o1'), { ...base, category: 'eletricista' }));
  await assertFails(setDoc(doc(as('cli'), 'orders/o2'), { ...base, category: 'svc_freios' }), 'desativado (herdado)');
  await assertFails(setDoc(doc(as('cli'), 'orders/o3'), { ...base, category: 'nao_existe' }));
  await assertFails(setDoc(doc(as('cli'), 'orders/o4'), base), 'sem serviço');
  await assertFails(setDoc(doc(as('cli'), 'orders/o5'), { ...base, category: 'eletricista', serviceSnapshot: { name: 'forjado' } }));
  // Fase 3: compra do Mercado só via createMarketOrder (valores do servidor).
  await assertFails(setDoc(doc(as('cli'), 'orders/o6'), { ...base, type: 'marketplace', category: 'marketplace' }));
  const req = { clientId: 'cli', clientName: 'C', description: 'Preciso trocar pastilhas', city: 'X', status: 'open', proposalCount: 0, leadMonetizationReady: true, leadFee: null, createdAt: serverTimestamp() };
  // Fase 4: solicitação só pela callable createResolveRequest (que também
  // exige o serviço ativo — coberto nos testes de integração).
  await assertFails(setDoc(doc(as('cli'), 'resolveRequests/r1'), { ...req, category: 'svc_freios' }));
  await assertFails(setDoc(doc(as('cli'), 'resolveRequests/r2'), { ...req, category: 'eletricista' }));
});

test('índice de busca de empresa é do servidor', async () => {
  await assertFails(updateDoc(doc(as('dono'), 'companies/co1'), { searchTokens: ['n:fake'] }));
  await assertSucceeds(updateDoc(doc(as('dono'), 'companies/co1'), { description: 'Nova' }));
});
