'use strict';
const test = require('node:test');
const assert = require('node:assert');
const core = require('./catalogCore');
const seed = require('./catalog/seed_v1.json');
const vectors = require('./catalog/normalization_vectors.json');

const byId = Object.fromEntries(seed.nodes.map((n) => [n.id, { ...n, active: true }]));

test('normalização compartilhada (mesmos vetores do app Dart)', () => {
  for (const [i, o] of vectors.normalize) assert.strictEqual(core.normalize(i), o, i);
  for (const [i, o] of vectors.compact) assert.strictEqual(core.compact(i), o, i);
});

test('seed: todos os IDs legados preservados e hierarquia válida', () => {
  for (const id of seed.legacyIds) assert.ok(byId[id], `legado ausente: ${id}`);
  assert.strictEqual(seed.legacyIds.length, 133);
  const ids = seed.nodes.map((n) => n.id);
  assert.strictEqual(new Set(ids).size, ids.length, 'IDs duplicados');
  for (const n of seed.nodes) {
    const existing = { ...byId };
    delete existing[n.id];
    const v = core.validateNode(n, existing, { isNew: true });
    assert.ok(v.ok, `${n.id}: ${v.errors.join('; ')}`);
  }
});

test('seed: 18 categorias regionais + 4 verticais especializadas', () => {
  const cats = seed.nodes.filter((n) => n.level === 'category');
  assert.strictEqual(cats.filter((c) => c.vertical === 'services').length, 18);
  assert.deepStrictEqual(cats.filter((c) => c.vertical !== 'services').map((c) => c.vertical).sort(),
    ['delivery', 'health', 'market', 'rental']);
});

test('validação: vínculos, níveis, duplicidade e ciclos', () => {
  const base = { icon: '🔧', name: 'Novo', modalities: ['presential'] };
  assert.ok(!core.validateNode({ ...base, id: 'svc_x', level: 'service', parentId: 'nao_existe' }, byId, { isNew: true }).ok);
  assert.ok(!core.validateNode({ ...base, id: 'svc_x', level: 'service', parentId: 'cat_agro' }, byId, { isNew: true }).ok, 'serviço sob categoria');
  assert.ok(!core.validateNode({ ...base, id: 'grp_x', level: 'group', parentId: 'grp_agro_lavoura' }, byId, { isNew: true }).ok, 'grupo sob grupo');
  assert.ok(!core.validateNode({ ...base, id: 'cat_x', level: 'category', parentId: 'cat_agro' }, byId, { isNew: true }).ok);
  assert.ok(!core.validateNode({ ...base, id: 'eletricista', level: 'group', parentId: 'cat_casa_reformas' }, byId, { isNew: true }).ok, 'id duplicado');
  assert.ok(!core.validateNode({ ...base, name: 'Freios', id: 'svc_freios2', level: 'service', parentId: 'mecanico' }, byId, { isNew: true }).ok, 'nome duplicado entre irmãos');
  assert.ok(!core.validateNode({ ...base, id: 'Bad Id', level: 'group', parentId: 'cat_agro' }, byId, { isNew: true }).ok);
  assert.ok(!core.validateNode({ ...base, id: 'svc_y', level: 'service', parentId: 'mecanico', modalities: ['teleporte'] }, byId, { isNew: true }).ok);
  assert.ok(!core.validateNode({ ...base, id: 'svc_y', level: 'service', parentId: 'mecanico', commercialModel: 'gratis' }, byId, { isNew: true }).ok);
  const ok = core.validateNode({ ...base, name: 'Embreagem', id: 'svc_embreagem', level: 'service', parentId: 'mecanico', commercialModel: 'both' }, byId, { isNew: true });
  assert.ok(ok.ok, ok.errors.join(';'));
  assert.strictEqual(ok.value.vertical, 'services');
  assert.strictEqual(ok.value.slug, 'embreagem');
  // ciclo artificial
  const cyc = { a: { id: 'a', level: 'group', parentId: 'b' }, b: { id: 'b', level: 'category', parentId: 'a' } };
  assert.ok(!core.validateNode({ ...base, id: 'a', parentId: 'b', name: 'A' }, cyc, { isNew: false }).ok);
  // nível não pode mudar
  assert.ok(!core.validateNode({ ...base, id: 'eletricista', level: 'service', name: 'Eletricista' }, byId, { isNew: false }).ok);
});

test('ativo efetivo herda desativação da categoria', () => {
  const nodes = { ...byId, cat_automoveis: { ...byId.cat_automoveis, active: false } };
  assert.strictEqual(core.effectiveActive('svc_freios', nodes), false);
  assert.strictEqual(core.effectiveActive('eletricista', nodes), true);
  assert.ok(core.descendants('cat_automoveis', nodes).includes('svc_freios'));
});

test('índice do prestador: não classifica em serviços não declarados', () => {
  const idx = core.providerIndex({ name: 'Carlos Mecânico', categories: ['mecanico'], modalities: ['presential'], city: 'Parauapebas' }, byId);
  assert.ok(idx.searchTokens.includes('g:mecanico'));
  assert.ok(idx.searchTokens.includes('c:cat_automoveis'));
  assert.ok(idx.searchTokens.includes('s:mecanico'));
  assert.ok(!idx.searchTokens.includes('s:svc_freios'), 'não pode virar especialista em freios');
  assert.ok(idx.searchTokens.includes('n:car') && idx.searchTokens.includes('n:mecanico'));
  assert.strictEqual(idx.cityKey, 'parauapebas');
});

test('índice do prestador: múltiplas especialidades e ID desconhecido preservado', () => {
  const idx = core.providerIndex({ name: 'Ana', categories: ['svc_freios', 'eletricista', 'id_antigo_x'] }, byId);
  for (const t of ['s:svc_freios', 'g:mecanico', 'c:cat_automoveis', 's:eletricista', 'g:eletricista', 'c:cat_casa_reformas', 's:id_antigo_x']) {
    assert.ok(idx.searchTokens.includes(t), t);
  }
  assert.deepStrictEqual(idx.unknownCategories, ['id_antigo_x']);
});

test('snapshot de serviço guarda caminho legível', () => {
  const s = core.serviceSnapshot('svc_freios', byId);
  assert.deepStrictEqual([s.name, s.groupName, s.categoryName, s.vertical], ['Freios', 'Mecânica', 'Automóveis', 'services']);
  assert.strictEqual(core.serviceSnapshot('nao_existe', byId), null);
});

test('migração: idempotente, conflito sem sobrescrever', () => {
  const p1 = core.planSeedMigration(seed.nodes, {});
  assert.strictEqual(p1.create.length, seed.nodes.length);
  const after = Object.fromEntries(seed.nodes.map((n) => [n.id, { ...n, active: true }]));
  const p2 = core.planSeedMigration(seed.nodes, after);
  assert.strictEqual(p2.create.length, 0);
  assert.strictEqual(p2.conflicts.length, 0);
  const edited = { ...after, eletricista: { ...after.eletricista, name: 'Eletricista Residencial', editedAt: 1 } };
  const p3 = core.planSeedMigration(seed.nodes, edited);
  assert.strictEqual(p3.conflicts.length, 1);
  assert.deepStrictEqual(p3.conflicts[0].fields, ['name']);
  assert.strictEqual(p3.create.length, 0);
});

test('referências desconhecidas são reportadas, não reclassificadas', () => {
  const r = core.unknownReferences([
    { collection: 'providers', id: 'eletricista' }, { collection: 'providers', id: 'xyz' },
    { collection: 'orders', id: 'xyz' }, { collection: 'orders', id: 'xyz' },
  ], new Set(seed.nodes.map((n) => n.id)));
  assert.deepStrictEqual(r, [{ id: 'xyz', collection: 'orders', count: 2 }, { id: 'xyz', collection: 'providers', count: 1 }]);
});

test('questionário: tipos, opções e condições só para perguntas anteriores', () => {
  const ok = core.validateQuestionnaire({
    serviceId: 'ar_condicionado', title: 'Instalação de ar',
    questions: [
      { id: 'tipo', type: 'single_choice', label: 'Tipo de aparelho', options: ['Split', 'Janela'], required: true },
      { id: 'btus', type: 'number', label: 'Potência (BTUs)', showIf: { questionId: 'tipo', op: 'equals', value: 'Split' } },
      { id: 'foto', type: 'attachment', label: 'Foto do local' },
    ],
  }, byId);
  assert.ok(ok.ok, ok.errors.join(';'));
  const forward = core.validateQuestionnaire({ serviceId: 'ar_condicionado', title: 'X y z', questions: [
    { id: 'a', type: 'text', label: 'A', showIf: { questionId: 'b', op: 'answered' } },
    { id: 'b', type: 'text', label: 'B' }] }, byId);
  assert.ok(!forward.ok, 'referência à frente/ciclo');
  const badOpt = core.validateQuestionnaire({ serviceId: 'ar_condicionado', title: 'X y z', questions: [
    { id: 'a', type: 'single_choice', label: 'A', options: ['1', '2'] },
    { id: 'b', type: 'text', label: 'B', showIf: { questionId: 'a', op: 'equals', value: '3' } }] }, byId);
  assert.ok(!badOpt.ok);
  assert.ok(!core.validateQuestionnaire({ serviceId: 'cat_agro', title: 'Xyz', questions: [{ id: 'a', type: 'text', label: 'A' }] }, byId).ok);
  assert.ok(!core.validateQuestionnaire({ serviceId: 'nao', title: 'Xyz', questions: [{ id: 'a', type: 'text', label: 'A' }] }, byId).ok);
  assert.ok(!core.validateQuestionnaire({ serviceId: 'ar_condicionado', title: 'Xyz', questions: [{ id: 'a', type: 'text', label: 'A' }, { id: 'a', type: 'text', label: 'B' }] }, byId).ok);
});
