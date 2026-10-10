'use strict';
/**
 * Integração da Fase 2 (catálogo) contra os emuladores.
 * Cobre: migração idempotente, IDs antigos, admin, desativação,
 * histórico, múltiplas especialidades, busca e paginação por cursor,
 * questionários e permissões.
 */
const { test, before, describe } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');
const { initializeApp } = require('firebase/app');
const {
  getFirestore, connectFirestoreEmulator, collection, query, where, orderBy, limit,
  startAfter, getDocs,
} = require('firebase/firestore');
const seed = require('../../functions/catalog/seed_v1.json');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken };
}
async function call(name, user, data) {
  const r = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ data: data || {} }),
  });
  const j = await r.json();
  if (j.error) throw new Error(j.error.message);
  return j.result;
}
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(300);
  }
  return null;
}
const node = async (id) => (await db.doc(`catalogNodes/${id}`).get()).data();

let adm; let user;
before(async () => {
  [adm, user] = await Promise.all([signUp('adm'), signUp('usr')]);
  await db.doc(`users/${adm.uid}`).set({ type: 'admin', name: 'Admin' });
  // Dados legados ANTES da migração.
  await db.doc('providers/legacy_mec').set({ userId: 'legacy_mec', name: 'Oficina do Zé', categories: ['mecanico'], verified: true, active: true, rating: 4, totalReviews: 3, city: 'Marabá' });
  await db.doc('providers/legacy_unknown').set({ userId: 'legacy_unknown', name: 'Antigo', categories: ['id_antigo_x'], verified: true, active: true, rating: 3 });
  await db.doc('orders/legacy_order').set({ clientId: 'c', providerId: 'legacy_mec', category: 'mecanico', status: 'completed', title: 'Revisão' });
  await db.doc('categories/admin_legado').set({ name: 'Categoria criada no admin antigo', order: 1 });
});

describe('Migração do catálogo v1', () => {
  test('simulação não grava; execução cria; segunda execução não duplica', async () => {
    const before = (await db.collection('catalogNodes').get()).size;
    const dry = await call('migrateCatalogV1', adm, { dryRun: true });
    assert.strictEqual(dry.dryRun, true);
    assert.strictEqual(dry.toCreate, seed.nodes.length - before);
    assert.strictEqual((await db.collection('catalogNodes').get()).size, before, 'dryRun não grava');
    assert.ok(dry.unknownReferences.some((u) => u.id === 'id_antigo_x' && u.collection === 'providers'));
    assert.ok(dry.legacyAdminCategories.some((c) => c.id === 'admin_legado' && c.mappedTo === null));

    const r1 = await call('migrateCatalogV1', adm, {});
    assert.strictEqual((await db.collection('catalogNodes').get()).size, seed.nodes.length);
    assert.ok(r1.providersReindexed >= 2);
    const r2 = await call('migrateCatalogV1', adm, {});
    assert.strictEqual(r2.toCreate, 0, 'idempotente');
    assert.strictEqual(r2.conflicts.length, 0);
    assert.strictEqual((await db.collection('catalogNodes').get()).size, seed.nodes.length, 'sem duplicação');
    // Nada foi apagado nem reclassificado.
    assert.ok((await db.doc('categories/admin_legado').get()).exists);
    assert.deepStrictEqual((await db.doc('providers/legacy_unknown').get()).data().categories, ['id_antigo_x']);
    const map = (await db.doc('catalogMeta/legacyIdMap').get()).data();
    assert.strictEqual(map.idsPreserved.length, 133);
  });

  test('IDs antigos preservados e prestador legado indexado sem especialidade inventada', async () => {
    for (const id of seed.legacyIds) assert.ok(await node(id), `legado ${id}`);
    const p = (await db.doc('providers/legacy_mec').get()).data();
    assert.ok(p.searchTokens.includes('g:mecanico') && p.searchTokens.includes('c:cat_automoveis'));
    assert.ok(!p.searchTokens.includes('s:svc_freios'));
    assert.strictEqual(p.cityKey, 'maraba');
    assert.deepStrictEqual(p.categories, ['mecanico'], 'categoria anterior preservada');
  });

  test('conflito: item editado pelo admin não é sobrescrito', async () => {
    await call('catalogUpsert', adm, { isNew: false, node: { ...seed.nodes.find((n) => n.id === 'pintor'), name: 'Pintor Residencial' } });
    const r = await call('migrateCatalogV1', adm, { dryRun: true });
    const c = r.conflicts.find((x) => x.id === 'pintor');
    assert.ok(c && c.fields.includes('name') && c.editedByAdmin);
    await call('migrateCatalogV1', adm, {});
    assert.strictEqual((await node('pintor')).name, 'Pintor Residencial');
  });

  test('reversão é explícita e só remove nós não editados', async () => {
    const dry = await call('rollbackCatalogV1', adm, { dryRun: true });
    assert.ok(dry.kept.includes('pintor'), 'editado é mantido');
    await assert.rejects(call('rollbackCatalogV1', adm, { dryRun: false }), /Confirme/);
    await assert.rejects(call('rollbackCatalogV1', user, { dryRun: true }), /Somente administradores/);
  });
});

describe('Administração do catálogo', () => {
  test('usuário comum não altera o catálogo', async () => {
    await assert.rejects(call('catalogUpsert', user, { isNew: true, node: { id: 'svc_hack', level: 'service', name: 'Hack', parentId: 'mecanico', icon: 'x' } }), /Somente administradores/);
    await assert.rejects(call('catalogSetActive', user, { id: 'mecanico', active: false }), /Somente administradores/);
    await assert.rejects(call('migrateCatalogV1', user, { dryRun: true }), /Somente administradores/);
    await assert.rejects(call('catalogUpsert', null, { isNew: true, node: {} }), /Login/);
  });

  test('cadastro no admin é validado e fica disponível (com auditoria)', async () => {
    await assert.rejects(call('catalogUpsert', adm, { isNew: true, node: { id: 'svc_x', level: 'service', name: 'X X', parentId: 'nao_existe', icon: '🔧' } }), /grupo existente/);
    await assert.rejects(call('catalogUpsert', adm, { isNew: true, node: { id: 'svc_freios2', level: 'service', name: 'Freios', parentId: 'mecanico', icon: '🔧' } }), /já existe/);
    await assert.rejects(call('catalogUpsert', adm, { isNew: true, node: { id: 'svc_y', level: 'service', name: 'Y Y', parentId: 'cat_automoveis', icon: '🔧' } }), /nível superior/);
    const r = await call('catalogUpsert', adm, { isNew: true, node: {
      id: 'svc_embreagem', level: 'service', name: 'Embreagem', parentId: 'mecanico', icon: '⚙️',
      synonyms: ['kit embreagem'], modalities: ['presential'], commercialModel: 'both' } });
    assert.strictEqual(r.id, 'svc_embreagem');
    const n = await node('svc_embreagem');
    assert.strictEqual(n.effectiveActive, true);
    assert.strictEqual(n.vertical, 'services');
    assert.deepStrictEqual(n.path, ['cat_automoveis', 'mecanico', 'svc_embreagem']);
    assert.ok(n.searchTerms.includes('kit embreagem'));
    const meta = (await db.doc('catalogMeta/current').get()).data();
    assert.ok(meta.version >= 1);
    const logs = await db.collection('auditLogs').where('target', '==', 'svc_embreagem').get();
    assert.ok(!logs.empty, 'auditado');
  });

  test('reordenação exige a lista completa de irmãos', async () => {
    await assert.rejects(call('catalogReorder', adm, { parentId: 'mecanico', orderedIds: ['svc_freios'] }), /todos os itens/);
    const kids = (await db.collection('catalogNodes').where('parentId', '==', 'mecanico').get()).docs.map((d) => d.id);
    const reversed = [...kids].reverse();
    await call('catalogReorder', adm, { parentId: 'mecanico', orderedIds: reversed });
    assert.strictEqual((await node(reversed[0])).order, 10);
  });

  test('desativar categoria impede novas seleções sem apagar histórico', async () => {
    const order = db.collection('orders').doc();
    await order.set({ clientId: 'c', providerId: 'legacy_mec', category: 'svc_freios', status: 'pending', title: 'Freio' });
    const snap = await waitFor(async () => (await order.get()).data().serviceSnapshot);
    assert.deepStrictEqual([snap.name, snap.groupName, snap.categoryName], ['Freios', 'Mecânica', 'Automóveis']);

    const r = await call('catalogSetActive', adm, { id: 'cat_automoveis', active: false });
    assert.ok(r.affected > 3);
    assert.strictEqual((await node('svc_freios')).effectiveActive, false);
    assert.strictEqual((await node('svc_freios')).active, true, 'ativo próprio intacto');
    assert.strictEqual((await node('eletricista')).effectiveActive, true);
    // Histórico permanece legível (snapshot) e o nó continua existindo.
    await call('catalogUpsert', adm, { isNew: false, node: { ...(await node('svc_freios')), name: 'Freios e ABS' } });
    assert.strictEqual((await order.get()).data().serviceSnapshot.name, 'Freios');
    assert.ok((await db.doc('orders/legacy_order').get()).exists);

    await call('catalogSetActive', adm, { id: 'cat_automoveis', active: true });
    assert.strictEqual((await node('svc_freios')).effectiveActive, true);
  });
});

describe('Busca e paginação', () => {
  test('prestador com múltiplas especialidades aparece em cada uma', async () => {
    await db.doc('providers/multi').set({ userId: 'multi', name: 'Ana Múltipla', categories: ['svc_freios', 'eletricista', 'advogado'], verified: true, active: true, rating: 4.9, modalities: ['presential', 'online'] });
    const p = await waitFor(async () => {
      const d = (await db.doc('providers/multi').get()).data();
      return d.searchTokens ? d : null;
    });
    for (const t of ['s:svc_freios', 'g:mecanico', 'c:cat_automoveis', 's:eletricista', 'c:cat_casa_reformas', 's:advogado', 'c:cat_juridico_contabil', 'm:online', 'n:ana', 'n:multipla']) {
      assert.ok(p.searchTokens.includes(t), t);
    }
  });

  test('nome com acento: busca sem acento encontra', async () => {
    await db.doc('providers/jose').set({ userId: 'jose', name: 'José Ávila Conceição', categories: ['pintor'], verified: true, active: true, rating: 4.1 });
    const p = await waitFor(async () => (await db.doc('providers/jose').get()).data().searchTokens);
    for (const t of ['n:jose', 'n:avila', 'n:conceicao', 'n:conc']) assert.ok(p.includes(t), t);
  });

  test('paginação por cursor encontra registros fora da primeira página (consulta do app, sem login)', async () => {
    const batch = db.batch();
    for (let i = 0; i < 45; i++) {
      batch.set(db.doc(`providers/page_${String(i).padStart(2, '0')}`), {
        userId: `page_${i}`, name: `Eletricista ${i}`, categories: ['eletricista'],
        verified: true, active: true, rating: 5 - i * 0.05, totalReviews: i,
      });
    }
    await batch.commit();
    await waitFor(async () => (await db.doc('providers/page_44').get()).data().searchTokens);
    const app = initializeApp({ projectId: PROJECT, apiKey: 'demo' }, `pager_${Date.now()}`);
    const fdb = getFirestore(app);
    connectFirestoreEmulator(fdb, '127.0.0.1', 8080);
    const base = () => [collection(fdb, 'providers'), where('active', '==', true), where('verified', '==', true),
      where('searchTokens', 'array-contains', 'g:eletricista'), orderBy('rating', 'desc')];
    const seen = [];
    let cursor = null;
    let pages = 0;
    do {
      const q = cursor ? query(...base(), startAfter(cursor), limit(20)) : query(...base(), limit(20));
      const s = await getDocs(q);
      s.docs.forEach((d) => seen.push(d.id));
      cursor = s.docs.length === 20 ? s.docs[s.docs.length - 1] : null;
      pages += 1;
    } while (cursor && pages < 10);
    assert.ok(pages >= 3, `páginas: ${pages}`);
    assert.ok(seen.includes('page_44'), 'último registro (fora da 1ª página) encontrado');
    assert.strictEqual(new Set(seen).size, seen.length, 'sem duplicados entre páginas');
    assert.ok(!seen.includes('legacy_unknown'));
    // Pendentes nunca aparecem.
    await db.doc('providers/pend_x').set({ userId: 'pend_x', name: 'Pendente', categories: ['eletricista'], verified: false, active: false, rating: 5 });
    const again = await getDocs(query(...base(), limit(100)));
    assert.ok(!again.docs.some((d) => d.id === 'pend_x'));
  });
});

describe('Questionários (estrutura)', () => {
  test('rascunho, publicação versionada e validação no servidor', async () => {
    const qs = [
      { id: 'tipo', type: 'single_choice', label: 'Tipo', options: ['Split', 'Janela'], required: true },
      { id: 'btus', type: 'number', label: 'BTUs', showIf: { questionId: 'tipo', op: 'equals', value: 'Split' } },
    ];
    await assert.rejects(call('questionnaireSave', user, { serviceId: 'ar_condicionado', title: 'Ar', questions: qs }), /Somente administradores/);
    await assert.rejects(call('questionnaireSave', adm, { serviceId: 'ar_condicionado', title: 'Ar cond', questions: [qs[1], qs[0]] }), /pergunta anterior/);
    const d = await call('questionnaireSave', adm, { serviceId: 'ar_condicionado', title: 'Ar cond', questions: qs });
    assert.strictEqual(d.status, 'draft');
    const p1 = await call('questionnaireSave', adm, { id: d.id, serviceId: 'ar_condicionado', title: 'Ar cond', questions: qs, publish: true });
    assert.strictEqual(p1.version, 1);
    const p2 = await call('questionnaireSave', adm, { id: p1.id, serviceId: 'ar_condicionado', title: 'Ar cond v2', questions: qs, publish: true });
    assert.strictEqual(p2.version, 2);
    assert.notStrictEqual(p2.id, p1.id, 'publicada é imutável');
    assert.strictEqual((await db.doc(`serviceQuestionnaires/${p1.id}`).get()).data().status, 'archived');
    const n = await node('ar_condicionado');
    assert.deepStrictEqual([n.questionnaireId, n.questionnaireVersion], [p2.id, 2]);
  });
});
