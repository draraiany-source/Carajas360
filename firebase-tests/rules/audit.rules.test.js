'use strict';
/**
 * Regras corrigidas na auditoria completa (pós-Fase 7). Cada teste cobre
 * um achado: o fluxo legítimo passa e o abuso descrito é negado.
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, addDoc, collection, getDocs, serverTimestamp,
} = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-audit-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'catalogNodes/eletricista'), { name: 'Eletricista', effectiveActive: true });
    await setDoc(doc(db, 'providers/pro'), { userId: 'pro', verified: true, active: true }); // pedido só para prestador verificado
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'marketing' });
    await setDoc(doc(db, 'users/master'), { type: 'admin', adminRole: 'master' });
    await setDoc(doc(db, 'users/cli'), { type: 'client', name: 'Cli' });
    await setDoc(doc(db, 'stores/lojaV'), { ownerId: 'vitima', name: 'Loja Vítima' });
    await setDoc(doc(db, 'stores/lojaA'), { ownerId: 'atk', name: 'Loja Atk' });
    await setDoc(doc(db, 'companies/atk'), { ownerId: 'atk', name: 'Empresa Atk' });
    await setDoc(doc(db, 'companies/vitima'), { ownerId: 'vitima', name: 'Empresa Vítima' });
    await setDoc(doc(db, 'contracts/c1'), { companyId: 'vitima', title: 'Contrato' });
    await setDoc(doc(db, 'branches/b1'), { companyId: 'atk', name: 'Filial' });
    await setDoc(doc(db, 'coupons/cp1'), { code: 'SEGREDO100', discount: 100, isPercentage: true, active: true });
    await setDoc(doc(db, 'orders/done'), { clientId: 'cli', providerId: 'pro', status: 'completed', price: 100 });
    await setDoc(doc(db, 'chatRooms/a_b'), { participants: ['a', 'b'] });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();

test('produto: dono de qualquer empresa NÃO insere produto na loja de outra pessoa', async () => {
  const p = { companyId: 'atk', storeId: 'lojaV', name: 'Falso', price: 0.01, active: true, rating: 0, totalReviews: 0 };
  await assertFails(setDoc(doc(as('atk'), 'products/p1'), p));
  await assertSucceeds(setDoc(doc(as('atk'), 'products/p2'), { ...p, storeId: 'lojaA' }), 'na própria loja, com contadores zerados');
  await assertFails(updateDoc(doc(as('atk'), 'products/p2'), { companyId: 'vitima' }), 'empresa do produto é imutável');
});

test('loja e locação nascem com contadores zerados (o app envia 0/false)', async () => {
  await assertSucceeds(setDoc(doc(as('cli'), 'stores/s9'), { ownerId: 'cli', name: 'Nova', rating: 0, totalReviews: 0, verified: false }));
  await assertFails(setDoc(doc(as('cli'), 'stores/s8'), { ownerId: 'cli', name: 'Nova', rating: 5, totalReviews: 0, verified: false }));
  await assertFails(setDoc(doc(as('cli'), 'stores/s7'), { ownerId: 'cli', name: 'Nova', rating: 0, totalReviews: 0, verified: true }));
  await assertSucceeds(setDoc(doc(as('cli'), 'rentals/r9'), { ownerId: 'cli', title: 'Hilux', rating: 0, totalReviews: 0, verified: false }));
  await assertFails(setDoc(doc(as('cli'), 'rentals/r8'), { ownerId: 'cli', title: 'Hilux', rating: 4.9, totalReviews: 30 }));
});

test('pedido de serviço: criação do app passa; preço definido pelo cliente não', async () => {
  const o = { clientId: 'cli', providerId: 'pro', category: 'eletricista', title: 'Chuveiro', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, payoutStatus: 'none', createdAt: serverTimestamp() };
  await assertSucceeds(addDoc(collection(as('cli'), 'orders'), o), 'campos que o app sempre envia');
  await assertFails(addDoc(collection(as('cli'), 'orders'), { ...o, price: 0.01 }), 'preço vem do orçamento do prestador');
  await assertFails(addDoc(collection(as('cli'), 'orders'), { ...o, payoutStatus: 'done' }));
});

test('suspensão: usuário não apaga o próprio perfil para recriá-lo ativo', async () => {
  await assertFails(deleteDoc(doc(as('cli'), 'users/cli')));
});

test('admin comum não promove ninguém (nem a si) a master; master promove outro', async () => {
  await assertFails(updateDoc(doc(as('adm'), 'users/adm'), { adminRole: 'master' }));
  await assertFails(updateDoc(doc(as('adm'), 'users/cli'), { type: 'admin' }));
  await assertSucceeds(updateDoc(doc(as('adm'), 'users/cli'), { name: 'Cli Atualizado' }), 'edição comum continua');
  await assertSucceeds(updateDoc(doc(as('master'), 'users/adm'), { adminRole: 'support' }));
  await assertFails(updateDoc(doc(as('master'), 'users/master'), { adminRole: 'marketing' }), 'nunca o próprio papel');
});

test('empresas: contrato/filial não trocam de empresa; empresa nasce inativa e com id do dono', async () => {
  await assertFails(updateDoc(doc(as('atk'), 'contracts/c1'), { companyId: 'atk' }), 'sequestro de contrato');
  await assertFails(updateDoc(doc(as('atk'), 'branches/b1'), { companyId: 'vitima' }));
  await assertSucceeds(updateDoc(doc(as('atk'), 'branches/b1'), { name: 'Filial Centro' }));
  await assertFails(setDoc(doc(as('novo'), 'companies/outro'), { ownerId: 'novo', name: 'X' }), 'ocupar o id de outra pessoa');
  await assertFails(setDoc(doc(as('novo'), 'companies/novo'), { ownerId: 'novo', name: 'X', active: true }));
  await assertSucceeds(setDoc(doc(as('novo'), 'companies/novo'), { ownerId: 'novo', name: 'X', active: false }));
});

test('cupons não são listáveis pelo app (validação no servidor)', async () => {
  await assertFails(getDocs(collection(as('cli'), 'coupons')));
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(), 'coupons')));
  await assertSucceeds(getDocs(collection(as('adm'), 'coupons')));
});

test('"avaliado" só pelo cliente e só com a avaliação existente', async () => {
  await assertFails(updateDoc(doc(as('pro'), 'orders/done'), { reviewed: true }), 'prestador escondendo o botão de avaliar');
  await assertFails(updateDoc(doc(as('cli'), 'orders/done'), { reviewed: true }), 'sem avaliação gravada');
  await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'reviews/done_cli'), { orderId: 'done', clientId: 'cli', stars: 5 }));
  await assertSucceeds(updateDoc(doc(as('cli'), 'orders/done'), { reviewed: true }));
});

test('entregas legadas congeladas (sem fluxo no servidor)', async () => {
  await assertFails(setDoc(doc(as('cli'), 'deliveries/d1'), { clientId: 'cli', driverId: 'qualquer', lat: 1, lng: 1 }));
});

test('favoritos: consultar favorito ainda inexistente funciona; de outra pessoa não', async () => {
  await assertSucceeds(getDoc(doc(as('cli'), 'favorites/cli_pro')));
  await assertFails(getDoc(doc(as('cli'), 'favorites/outro_pro')));
  await assertSucceeds(setDoc(doc(as('cli'), 'favorites/cli_pro'), { userId: 'cli', providerId: 'pro' }));
  await assertSucceeds(getDoc(doc(as('cli'), 'favorites/cli_pro')));
});

test('chat: horário da mensagem é o do servidor', async () => {
  const m = { senderId: 'a', senderName: 'A', text: 'oi', read: false };
  await assertFails(addDoc(collection(as('a'), 'chatRooms/a_b/messages'), { ...m, createdAt: new Date(2020, 0, 1) }));
  await assertSucceeds(addDoc(collection(as('a'), 'chatRooms/a_b/messages'), { ...m, createdAt: serverTimestamp() }));
});

test('chamado de suporte nasce aberto e sem prioridade escolhida pelo cliente', async () => {
  const t = { userId: 'cli', userName: '', subject: 'Ajuda', message: 'Texto', status: 'open', priority: 'normal', createdAt: serverTimestamp() };
  await assertSucceeds(addDoc(collection(as('cli'), 'support'), t));
  await assertFails(addDoc(collection(as('cli'), 'support'), { ...t, status: 'resolved' }));
  await assertFails(addDoc(collection(as('cli'), 'support'), { ...t, priority: 'urgent' }));
});

test('log de auditoria: admin não assina por outro admin', async () => {
  await assertFails(addDoc(collection(as('adm'), 'auditLogs'), { adminId: 'master', action: 'x', timestamp: serverTimestamp() }));
  await assertSucceeds(addDoc(collection(as('adm'), 'auditLogs'), { adminId: 'adm', action: 'x', timestamp: serverTimestamp() }));
});
