'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const assist = require('./serviceAssist');

describe('serviceAssist pedido', () => {
  it('sugere eletricista por texto', () => {
    const r = assist.suggestCategoryFromText(
      'preciso trocar disjuntor e instalar tomadas',
      assist.DEFAULT_CATEGORY_CATALOG,
    );
    assert.equal(r.categoryId, 'eletricista');
  });

  it('rejeita categoria invalida', () => {
    const v = assist.validateCategoryId('categoria_inventada', assist.DEFAULT_CATEGORY_CATALOG);
    assert.equal(v.ok, false);
    assert.equal(v.reason, 'invalid_category');
  });

  it('sanitize remove prontidao sem cidade/urgencia', () => {
    const d = assist.sanitizeAssistDraft({
      title: 'Troca de tomadas',
      description: 'Quero instalar quatro tomadas novas na cozinha amanha',
      categoryId: 'eletricista',
      price: 999,
      providers: [{ name: 'Fake' }],
    }, assist.DEFAULT_CATEGORY_CATALOG);
    assert.equal(d.categoryId, 'eletricista');
    assert.equal(d.readyToPublish, false);
    assert.ok(d.missingFields.includes('city'));
    assert.ok(!Object.prototype.hasOwnProperty.call(d, 'price'));
  });

  it('informacao insuficiente nao inventa categoria', () => {
    const r = assist.suggestCategoryFromText('ajuda', assist.DEFAULT_CATEGORY_CATALOG);
    assert.equal(r.categoryId, null);
  });
});

describe('serviceAssist proposta', () => {
  it('exige preco do prestador', () => {
    const r = assist.buildProposalDraftText({
      requestSummary: 'Troca de pastilhas',
      providerPrice: 0,
      deadlineDays: 2,
    });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'provider_price_required');
  });

  it('monta rascunho com valores do prestador', () => {
    const r = assist.buildProposalDraftText({
      requestSummary: 'Freios cantando',
      providerPrice: 320,
      deadlineDays: 2,
      materialsIncluded: false,
      conditions: 'Pecas a parte',
      providerServices: ['Freios'],
    });
    assert.equal(r.ok, true);
    assert.match(r.draftMessage, /320/);
    assert.match(r.draftMessage, /prestador/);
  });
});

describe('serviceAssist cotas e idempotencia', () => {
  it('quota free vs pro', () => {
    assert.equal(assist.planAiQuota('free').max, 15);
    assert.equal(assist.planAiQuota('pro').max, 60);
  });
  it('idempotency id', () => {
    assert.equal(assist.idempotencyDocId('u1', 'abc-123!'), 'u1_abc-123');
    assert.equal(assist.idempotencyDocId('u1', ''), null);
  });
});

describe('serviceAssist mergeClientCatalog e prontidao', () => {
  it('mergeClientCatalog sanitiza ids e une ao DEFAULT', () => {
    const merged = assist.mergeClientCatalog([
      { id: 'Eletricista!!!', name: 'Custom Elec', keywords: ['tomada'] },
      { id: 'nova_cat_ok', name: 'Nova Categoria', keywords: ['novo'] },
      { id: 'x', name: 'Curto demais' },
      { id: 'sem_nome', name: '' },
      { id: ';;bad!!', name: 'So simbolos' },
    ]);
    const ids = merged.map((c) => c.id);
    assert.ok(ids.includes('eletricista'));
    assert.ok(ids.includes('nova_cat_ok'));
    assert.ok(!ids.includes('x'));
    const elec = merged.find((c) => c.id === 'eletricista');
    assert.equal(elec.name, 'Eletricista');
    assert.ok(elec.keywords.includes('tomada'));
    const nova = merged.find((c) => c.id === 'nova_cat_ok');
    assert.equal(nova.name, 'Nova Categoria');
  });

  it('readyToPublish true quando campos obrigatorios ok', () => {
    const d = assist.sanitizeAssistDraft({
      title: 'Troca de tomadas',
      description: 'Quero instalar quatro tomadas novas na cozinha amanha cedo',
      categoryId: 'eletricista',
      city: 'Canaa dos Carajas',
      urgency: 'Esta semana',
    }, assist.DEFAULT_CATEGORY_CATALOG);
    assert.equal(d.readyToPublish, true);
    assert.deepEqual(d.missingFields, []);
  });

  it('rejeita deadline invalido na proposta', () => {
    const r = assist.buildProposalDraftText({
      requestSummary: 'Freios',
      providerPrice: 100,
      deadlineDays: 0,
    });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'invalid_deadline');
  });
});
