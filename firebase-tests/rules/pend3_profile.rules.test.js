'use strict';
/**
 * Pendência 3 — Perfil › "Quero ser prestador": o cliente cria o perfil de
 * prestador PENDENTE e envia documentos, mas não se autoaprova (verified,
 * active, verificationStatus, nota) nem muda o próprio papel (type/admin).
 */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, updateDoc, getDoc, getDocs, query, where, collection, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-pend3-profile',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/cli'), { type: 'client', name: 'Ana Cliente', verified: false, status: 'active' });
    await setDoc(doc(db, 'users/outro'), { type: 'client', name: 'Outro' });
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'support' });
    await setDoc(doc(db, 'catalogNodes/eletricista'), { level: 'group', name: 'Eletricista', active: true, effectiveActive: true });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();
// Mesmo formato de FS.createProviderProfile.
const pending = (uid, extra = {}) => ({
  userId: uid, name: 'Ana Cliente', categories: ['eletricista'], city: 'Marabá', modalities: ['presential'],
  minPrice: null, photoUrl: null, serviceAreas: [], rating: 0, totalReviews: 0, active: false, verified: false,
  createdAt: serverTimestamp(), ...extra,
});

test('cliente cria o perfil de prestador só como pendente', async () => {
  const db = as('cli');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { verified: true })), 'verified');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { active: true })), 'active');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { verificationStatus: 'approved' })), 'status de análise');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { rating: 5, totalReviews: 100 })), 'nota');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { reviewedBy: 'cli' })), 'campo do admin');
  await assertFails(setDoc(doc(as('outro'), 'providers/cli'), pending('cli')), 'perfil de outra pessoa');
  await assertFails(setDoc(doc(db, 'providers/cli'), pending('cli', { categories: [] })), 'sem especialidade');
  await assertSucceeds(setDoc(doc(db, 'providers/cli'), pending('cli')));
  // Pendente não é público: só o dono (consulta do app) e a equipe.
  await assertSucceeds(getDocs(query(collection(db, 'providers'), where('userId', '==', 'cli'))));
  await assertFails(getDoc(doc(as('outro'), 'providers/cli')));
  await assertSucceeds(getDoc(doc(as('adm'), 'providers/cli')));
});

test('pendente ou recusado não se aprova, não fica online nem apaga a recusa', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'providers/cli'), { ...pending('cli'), createdAt: new Date(), verificationStatus: 'rejected', rejectionReason: 'Documento ilegível' });
  });
  const ref = doc(as('cli'), 'providers/cli');
  await assertFails(updateDoc(ref, { verified: true }));
  await assertFails(updateDoc(ref, { active: true }), 'online só depois de aprovado');
  await assertFails(updateDoc(ref, { verificationStatus: 'approved' }));
  await assertFails(updateDoc(ref, { verificationStatus: 'pending_review' }), 'nova análise só pela callable');
  await assertFails(updateDoc(ref, { rejectionReason: null }));
  await assertFails(updateDoc(ref, { totalReviews: 50 }));
  // Corrigir os dados públicos continua permitido.
  await assertSucceeds(updateDoc(ref, { bio: 'Eletricista há 10 anos', categories: ['eletricista'], updatedAt: serverTimestamp() }));
});

test('documentos privados: o dono envia caminhos; não grava aprovação por lá', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'providers/cli'), { ...pending('cli'), createdAt: new Date() });
  });
  const v = doc(as('cli'), 'providers/cli/private/verification');
  await assertSucceeds(setDoc(v, { documentPath: 'providers/cli/document/1.jpg', selfiePath: 'providers/cli/selfie/1.jpg', submittedAt: serverTimestamp() }, { merge: true }));
  await assertFails(setDoc(v, { verified: true }, { merge: true }));
  await assertFails(setDoc(v, { approvedBy: 'cli' }, { merge: true }));
  await assertFails(setDoc(doc(as('cli'), 'providers/cli/private/approval'), { documentPath: 'x' }), 'outro documento');
  await assertFails(getDoc(doc(as('outro'), 'providers/cli/private/verification')));
});

test('cliente não muda o próprio papel nem campos de verificação no users', async () => {
  const ref = doc(as('cli'), 'users/cli');
  await assertFails(updateDoc(ref, { type: 'provider' }), 'type só pela callable');
  await assertFails(updateDoc(ref, { type: 'admin' }));
  await assertFails(updateDoc(ref, { adminRole: 'master' }));
  await assertFails(updateDoc(ref, { roles: ['client', 'provider'] }));
  await assertFails(updateDoc(ref, { verified: true }));
  await assertFails(updateDoc(ref, { active: true }));
  await assertSucceeds(updateDoc(ref, { name: 'Ana C. Silva' }));
});

test('tipo "provider" no users não dá acesso de prestador aprovado', async () => {
  // Estado após switchProfileType('provider') sem aprovação do admin.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/cli'), { type: 'provider', name: 'Ana' });
    await setDoc(doc(db, 'providers/cli'), { ...pending('cli'), createdAt: new Date() });
  });
  await assertFails(updateDoc(doc(as('cli'), 'providers/cli'), { active: true }), 'não fica online');
  await assertFails(updateDoc(doc(as('cli'), 'providers/cli'), { verified: true }));
  // Não aparece para outros nem recebe pedidos (pedido exige prestador verificado).
  await assertFails(getDoc(doc(as('outro'), 'providers/cli')));
  const o = { clientId: 'outro', providerId: 'cli', status: 'pending', paymentStatus: 'unpaid', payoutProcessed: false, category: 'eletricista' };
  await assertFails(setDoc(doc(as('outro'), 'orders/n1'), o));
  // Depois da aprovação (pelo servidor/admin), o mesmo pedido é aceito.
  await env.withSecurityRulesDisabled(async (ctx) => {
    await updateDoc(doc(ctx.firestore(), 'providers/cli'), { verified: true, active: true, verificationStatus: 'approved' });
  });
  await assertSucceeds(setDoc(doc(as('outro'), 'orders/n1'), o));
  await assertSucceeds(updateDoc(doc(as('cli'), 'providers/cli'), { active: false }), 'aprovado alterna online');
});
