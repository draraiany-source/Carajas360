'use strict';
/**
 * Testes das regras Firestore (Fase 1) contra o emulador.
 * Rode com: npm run emu   (ou firebase emulators:exec ... 'npm run test:rules')
 */
const { test, before, after, beforeEach, describe } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment, assertFails, assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc, getDoc, setDoc, updateDoc, writeBatch, collection, query, where,
  getDocs, orderBy, serverTimestamp, deleteField,
} = require('firebase/firestore');

const PROJECT = 'demo-carajas360-rules';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/admin'), { type: 'admin', name: 'Admin' });
    await setDoc(doc(db, 'users/cli'), { type: 'client', name: 'Cliente' });
    await setDoc(doc(db, 'providers/pro'), {
      userId: 'pro', name: 'Eletricista Aprovado', categories: ['eletricista'],
      verified: true, active: true, rating: 4.5, totalReviews: 2, city: 'Parauapebas',
    });
    await setDoc(doc(db, 'providers/pend'), {
      userId: 'pend', name: 'Pendente', categories: ['eletricista'],
      verified: false, active: false, rating: 0, totalReviews: 0,
    });
    // Fase 2: contratação exige item ativo no catálogo.
    await setDoc(doc(db, 'catalogNodes/eletricista'), { level: 'group', name: 'Eletricista', active: true, effectiveActive: true });
    await setDoc(doc(db, 'providers/adv'), {
      userId: 'adv', name: 'Advogada', categories: ['advogado'],
      verified: true, active: true, rating: 5, totalReviews: 1,
    });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

describe('users', () => {
  test('cadastro não pode se autoverificar, ganhar XP nem virar admin', async () => {
    await assertFails(setDoc(doc(as('u1'), 'users/u1'), { type: 'client', name: 'X', verified: true }));
    await assertFails(setDoc(doc(as('u1'), 'users/u1'), { type: 'client', name: 'X', xp: 9999 }));
    await assertFails(setDoc(doc(as('u1'), 'users/u1'), { type: 'admin', name: 'X' }));
    await assertFails(setDoc(doc(as('u1'), 'users/u1'), { type: 'client', permissions: ['all'] }));
    await assertSucceeds(setDoc(doc(as('u1'), 'users/u1'), {
      type: 'client', name: 'X', xp: 0, verified: false, status: 'active', plan: 'free',
    }));
  });
  test('usuário não altera campos protegidos nem lê perfil alheio', async () => {
    await assertFails(updateDoc(doc(as('cli'), 'users/cli'), { xp: 5000 }));
    await assertFails(updateDoc(doc(as('cli'), 'users/cli'), { balance: 100 }));
    await assertFails(updateDoc(doc(as('cli'), 'users/cli'), { type: 'admin' }));
    await assertSucceeds(updateDoc(doc(as('cli'), 'users/cli'), { name: 'Novo' }));
    await assertFails(getDoc(doc(as('pro'), 'users/cli')));
  });
});

describe('providers: perfil público x documentação privada', () => {
  const valid = { userId: 'np', name: 'Novo', categories: ['pintor'], active: false, verified: false, rating: 0, totalReviews: 0 };
  test('perfil público não aceita documento, selfie nem certificados', async () => {
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, documentUrl: 'https://x' }));
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, selfieUrl: 'https://x' }));
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, certificates: ['a'] }));
    await assertSucceeds(setDoc(doc(as('np'), 'providers/np'), valid));
  });
  test('cadastro não pode nascer verificado, ativo ou com nota', async () => {
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, verified: true }));
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, active: true }));
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, rating: 5 }));
    await assertFails(setDoc(doc(as('np'), 'providers/np'), { ...valid, totalReviews: 9 }));
    await assertFails(setDoc(doc(as('x'), 'providers/np'), valid));
  });
  test('prestador não manipula nota, avaliações nem verificação', async () => {
    await assertFails(updateDoc(doc(as('pro'), 'providers/pro'), { rating: 5 }));
    await assertFails(updateDoc(doc(as('pro'), 'providers/pro'), { totalReviews: 999 }));
    await assertFails(updateDoc(doc(as('pend'), 'providers/pend'), { verified: true }));
    await assertFails(updateDoc(doc(as('pend'), 'providers/pend'), { active: true }));
    await assertFails(updateDoc(doc(as('pro'), 'providers/pro'), { documentUrl: 'https://x' }));
    await assertSucceeds(updateDoc(doc(as('pro'), 'providers/pro'), { bio: 'Atendo 24h', active: false }));
  });
  test('pendente não é público; aprovado é', async () => {
    await assertFails(getDoc(doc(anon(), 'providers/pend')));
    await assertFails(getDoc(doc(as('cli'), 'providers/pend')));
    await assertSucceeds(getDoc(doc(as('pend'), 'providers/pend')));
    await assertSucceeds(getDoc(doc(as('admin'), 'providers/pend')));
    await assertSucceeds(getDoc(doc(anon(), 'providers/pro')));
  });
  test('consulta pública providersStream (active+verified+categories+rating)', async () => {
    const q = query(collection(anon(), 'providers'),
      where('active', '==', true), where('verified', '==', true),
      where('categories', 'array-contains', 'eletricista'), orderBy('rating', 'desc'));
    const snap = await assertSucceeds(getDocs(q));
    if (snap.docs.map((d) => d.id).join() !== 'pro') throw new Error('filtro errado: ' + snap.docs.map((d) => d.id));
    const qAny = query(collection(anon(), 'providers'),
      where('active', '==', true), where('verified', '==', true),
      where('categories', 'array-contains-any', ['advogado', 'contador']), orderBy('rating', 'desc'));
    const s2 = await assertSucceeds(getDocs(qAny));
    if (s2.docs.map((d) => d.id).join() !== 'adv') throw new Error('grupo errado');
    // Sem filtro de verificação a consulta é negada (não vaza pendentes).
    await assertFails(getDocs(query(collection(anon(), 'providers'), where('active', '==', false))));
  });
  test('documentação privada: só dono e admin', async () => {
    const ref = (db) => doc(db, 'providers/pend/private/verification');
    await assertSucceeds(setDoc(ref(as('pend')), { documentPath: 'providers/pend/document/1.jpg', submittedAt: serverTimestamp() }));
    await assertFails(setDoc(ref(as('pend')), { reviewStatus: 'approved' }, { merge: true }));
    await assertFails(getDoc(ref(as('cli'))));
    await assertFails(getDoc(ref(anon())));
    await assertSucceeds(getDoc(ref(as('pend'))));
    await assertSucceeds(getDoc(ref(as('admin'))));
    await assertFails(setDoc(doc(as('cli'), 'providers/pend/private/verification'), { documentPath: 'x' }));
  });
});

describe('chat', () => {
  const roomId = 'cli_pro';
  test('sala só com id canônico e com o próprio usuário como participante', async () => {
    await assertFails(setDoc(doc(as('cli'), 'chatRooms/adv_pro'), { participants: ['adv', 'pro'], createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('cli'), 'chatRooms/x'), { participants: ['cli', 'pro'], createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('cli'), 'chatRooms/cli_pro'), { participants: ['cli', 'pro', 'adv'], createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('cli'), 'chatRooms/pro_cli'), { participants: ['pro', 'cli'], createdAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(as('cli'), `chatRooms/${roomId}`)));
    await assertSucceeds(setDoc(doc(as('cli'), `chatRooms/${roomId}`), { participants: ['cli', 'pro'], createdAt: serverTimestamp() }));
  });
  test('participantes e vínculos imutáveis; terceiros sem acesso', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), `chatRooms/${roomId}`), { participants: ['cli', 'pro'], orderId: 'o1' });
      await setDoc(doc(ctx.firestore(), `chatRooms/${roomId}/messages/m1`), { senderId: 'pro', text: 'oi', read: false });
    });
    await assertFails(updateDoc(doc(as('cli'), `chatRooms/${roomId}`), { participants: ['cli', 'adv'] }));
    await assertFails(updateDoc(doc(as('cli'), `chatRooms/${roomId}`), { orderId: 'outro' }));
    await assertFails(updateDoc(doc(as('cli'), `chatRooms/${roomId}`), { typing_pro: true }));
    await assertSucceeds(updateDoc(doc(as('cli'), `chatRooms/${roomId}`), { lastMsg: 'olá', lastMsgTime: serverTimestamp(), typing_cli: false }));
    await assertFails(getDoc(doc(as('adv'), `chatRooms/${roomId}`)));
    await assertFails(getDoc(doc(as('adv'), `chatRooms/${roomId}/messages/m1`)));
    await assertFails(setDoc(doc(as('adv'), `chatRooms/${roomId}/messages/m2`), { senderId: 'adv', text: 'x', read: false }));
    await assertFails(setDoc(doc(as('cli'), `chatRooms/${roomId}/messages/m3`), { senderId: 'pro', text: 'forjada', read: false }));
    await assertSucceeds(setDoc(doc(as('cli'), `chatRooms/${roomId}/messages/m4`), { senderId: 'cli', senderName: 'C', text: 'ok', read: false, createdAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(doc(as('cli'), `chatRooms/${roomId}/messages/m1`), { read: true }));
    await assertFails(updateDoc(doc(as('cli'), `chatRooms/${roomId}/messages/m1`), { text: 'adulterada' }));
    await assertFails(updateDoc(doc(as('pro'), `chatRooms/${roomId}/messages/m1`), { text: 'editada' }));
    await assertSucceeds(updateDoc(doc(as('pro'), `chatRooms/${roomId}/messages/m1`), { deleted: true, text: '' }));
    const mine = query(collection(as('cli'), 'chatRooms'), where('participants', 'array-contains', 'cli'));
    await assertSucceeds(getDocs(mine));
    await assertFails(getDocs(query(collection(as('adv'), 'chatRooms'), where('participants', 'array-contains', 'cli'))));
  });
});

describe('resolve', () => {
  const base = {
    clientId: 'cli', clientName: 'C', description: 'Trocar 5 tomadas da sala',
    category: 'eletricista', city: 'Parauapebas', status: 'open', proposalCount: 0,
    leadMonetizationReady: true, leadFee: null,
  };
  test('solicitação não aceita endereço no documento principal', async () => {
    await assertFails(setDoc(doc(as('cli'), 'resolveRequests/r1'), { ...base, address: 'Rua A, 10', createdAt: serverTimestamp() }));
    await assertFails(setDoc(doc(as('cli'), 'resolveRequests/r1'), { ...base, proposalCount: 3, createdAt: serverTimestamp() }));
    const db = as('cli');
    const b = writeBatch(db);
    b.set(doc(db, 'resolveRequests/r1'), { ...base, createdAt: serverTimestamp() });
    b.set(doc(db, 'resolveRequests/r1/private/details'), { address: 'Rua A, 10', updatedAt: serverTimestamp() });
    await assertSucceeds(b.commit());
  });
  test('qualquer autenticado NÃO lê solicitações nem endereços', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'resolveRequests/r1'), base);
      await setDoc(doc(ctx.firestore(), 'resolveRequests/r1/private/details'), { address: 'Rua A, 10' });
    });
    await assertFails(getDoc(doc(as('adv'), 'resolveRequests/r1')));
    await assertFails(getDoc(doc(as('pro'), 'resolveRequests/r1')));
    await assertFails(getDoc(doc(as('pro'), 'resolveRequests/r1/private/details')));
    await assertFails(getDocs(query(collection(as('pro'), 'resolveRequests'), where('status', '==', 'open'))));
    await assertSucceeds(getDoc(doc(as('cli'), 'resolveRequests/r1')));
    await assertSucceeds(getDoc(doc(as('cli'), 'resolveRequests/r1/private/details')));
    await assertSucceeds(getDocs(query(collection(as('cli'), 'resolveRequests'), where('clientId', '==', 'cli'))));
  });
  test('proposta só pela callable; cliente/proposalCount não são forjáveis', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => { await setDoc(doc(ctx.firestore(), 'resolveRequests/r1'), base); });
    await assertFails(setDoc(doc(as('pro'), 'resolveProposals/r1_pro'), { requestId: 'r1', providerId: 'pro', price: 100, accepted: false }));
    await assertFails(updateDoc(doc(as('pro'), 'resolveRequests/r1'), { proposalCount: 1 }));
  });
  test('aceite atômico de uma única proposta; prestador escolhido passa a ver detalhes', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'resolveRequests/r1'), base);
      await setDoc(doc(db, 'resolveRequests/r1/private/details'), { address: 'Rua A, 10' });
      await setDoc(doc(db, 'resolveProposals/r1_pro'), { requestId: 'r1', clientId: 'cli', providerId: 'pro', price: 100, accepted: false });
      await setDoc(doc(db, 'resolveProposals/r1_adv'), { requestId: 'r1', clientId: 'cli', providerId: 'adv', price: 90, accepted: false });
    });
    // Terceiro não aceita.
    const advDb = as('adv');
    const bad = writeBatch(advDb);
    bad.update(doc(advDb, 'resolveProposals/r1_adv'), { accepted: true, acceptedAt: serverTimestamp() });
    bad.update(doc(advDb, 'resolveRequests/r1'), { status: 'matched', matchedProviderId: 'adv', matchedProposalId: 'r1_adv', matchedAt: serverTimestamp() });
    await assertFails(bad.commit());
    // Inconsistente (prestador != proposta) falha.
    const cliDb = as('cli');
    const wrong = writeBatch(cliDb);
    wrong.update(doc(cliDb, 'resolveProposals/r1_pro'), { accepted: true, acceptedAt: serverTimestamp() });
    wrong.update(doc(cliDb, 'resolveRequests/r1'), { status: 'matched', matchedProviderId: 'adv', matchedProposalId: 'r1_pro', matchedAt: serverTimestamp() });
    await assertFails(wrong.commit());
    // Cliente aceita corretamente.
    const ok = writeBatch(cliDb);
    ok.update(doc(cliDb, 'resolveProposals/r1_pro'), { accepted: true, acceptedAt: serverTimestamp() });
    ok.update(doc(cliDb, 'resolveRequests/r1'), { status: 'matched', matchedProviderId: 'pro', matchedProposalId: 'r1_pro', matchedAt: serverTimestamp() });
    await assertSucceeds(ok.commit());
    // Segundo aceite (concorrente/repetição) é recusado.
    const again = writeBatch(cliDb);
    again.update(doc(cliDb, 'resolveProposals/r1_adv'), { accepted: true, acceptedAt: serverTimestamp() });
    again.update(doc(cliDb, 'resolveRequests/r1'), { status: 'matched', matchedProviderId: 'adv', matchedProposalId: 'r1_adv', matchedAt: serverTimestamp() });
    await assertFails(again.commit());
    await assertSucceeds(getDoc(doc(as('pro'), 'resolveRequests/r1')));
    await assertSucceeds(getDoc(doc(as('pro'), 'resolveRequests/r1/private/details')));
    await assertFails(getDoc(doc(as('adv'), 'resolveRequests/r1/private/details')));
  });
  test('cliente lê propostas da própria solicitação; terceiros não', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'resolveRequests/r1'), base);
      await setDoc(doc(ctx.firestore(), 'resolveProposals/r1_pro'), { requestId: 'r1', clientId: 'cli', providerId: 'pro', price: 100, accepted: false, createdAt: new Date() });
    });
    await assertSucceeds(getDocs(query(collection(as('cli'), 'resolveProposals'), where('requestId', '==', 'r1'))));
    await assertFails(getDocs(query(collection(as('adv'), 'resolveProposals'), where('requestId', '==', 'r1'))));
    await assertFails(updateDoc(doc(as('pro'), 'resolveProposals/r1_pro'), { accepted: true }));
    await assertSucceeds(updateDoc(doc(as('pro'), 'resolveProposals/r1_pro'), { price: 120 }));
  });
});

describe('avaliações', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'orders/o1'), { clientId: 'cli', providerId: 'pro', status: 'completed', price: 100 });
      await setDoc(doc(db, 'orders/o2'), { clientId: 'cli', providerId: 'pro', status: 'accepted', price: 100 });
    });
  });
  const review = (o, extra = {}) => ({
    orderId: o, clientId: 'cli', providerId: 'pro', clientName: 'C', stars: 5,
    comment: 'Ótimo', tags: [], createdAt: serverTimestamp(), ...extra,
  });
  test('valida cliente, pedido concluído, prestador correspondente e nota', async () => {
    await assertFails(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1', { providerId: 'adv' })));
    await assertFails(setDoc(doc(as('cli'), 'reviews/o2_cli'), review('o2')));
    await assertFails(setDoc(doc(as('adv'), 'reviews/o1_adv'), review('o1', { clientId: 'adv' })));
    await assertFails(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1', { stars: 6 })));
    await assertFails(setDoc(doc(as('cli'), 'reviews/qualquer'), review('o1')));
    await assertFails(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1', { rating: 5 })));
    await assertSucceeds(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1')));
  });
  test('uma avaliação por contratação (sem reescrever)', async () => {
    await assertSucceeds(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1')));
    await assertFails(setDoc(doc(as('cli'), 'reviews/o1_cli'), review('o1', { stars: 1 })));
    await assertFails(updateDoc(doc(as('cli'), 'reviews/o1_cli'), { stars: 1 }));
  });
});

describe('financeiro e permissões', () => {
  test('carteira, transações e pagamentos não são graváveis pelo app', async () => {
    await assertFails(setDoc(doc(as('cli'), 'wallets/cli'), { balance: 1000 }));
    await assertFails(setDoc(doc(as('cli'), 'transactions/t1'), { userId: 'cli', amount: 1000 }));
    await assertFails(setDoc(doc(as('cli'), 'payments/p1'), { userId: 'cli', status: 'approved' }));
  });
  test('pedido não nasce com comissão, repasse ou pago', async () => {
    const o = { clientId: 'cli', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, category: 'eletricista' };
    await assertFails(setDoc(doc(as('cli'), 'orders/n1'), { ...o, commission: 0 }));
    await assertFails(setDoc(doc(as('cli'), 'orders/n1'), { ...o, paymentStatus: 'paid' }));
    await assertFails(setDoc(doc(as('cli'), 'orders/n1'), { ...o, status: 'completed' }));
    await assertSucceeds(setDoc(doc(as('cli'), 'orders/n1'), o));
  });
  test('notificações não podem ser criadas pelo app', async () => {
    await assertFails(setDoc(doc(as('cli'), 'notifications/n1'), { userId: 'pro', title: 'x', body: 'y' }));
  });
});
