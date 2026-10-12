'use strict';
const test = require('node:test');
const assert = require('node:assert');
const r = require('./resolveCore');

const nodes = {
  casa: { id: 'casa', level: 'category' },
  eletricista: { id: 'eletricista', level: 'group', parentId: 'casa' },
  svc_tomada: { id: 'svc_tomada', level: 'service', parentId: 'eletricista', questionnaireId: 'q_tomada' },
  svc_chuveiro: { id: 'svc_chuveiro', level: 'service', parentId: 'eletricista' },
  juridico: { id: 'juridico', level: 'category' },
};
const NOW = Date.UTC(2026, 9, 12, 15); // segunda-feira 12/10/2026 12h local
const base = {
  userId: 'p1', verified: true, active: true, categories: ['svc_tomada'],
  modalities: ['presential'], city: 'Marabá', geo: { lat: -5.37, lng: -49.12 }, radiusKm: 20,
};
const req = { clientId: 'c1', category: 'eletricista', city: 'Marabá', modality: 'presential' };

test('serviço: declarar o serviço cobre grupo e categoria; declarar o grupo não cobre serviço não declarado', () => {
  assert.ok(r.serviceCompatible(['svc_tomada'], 'svc_tomada', nodes));
  assert.ok(r.serviceCompatible(['svc_tomada'], 'eletricista', nodes));
  assert.ok(r.serviceCompatible(['svc_tomada'], 'casa', nodes));
  assert.ok(!r.serviceCompatible(['eletricista'], 'svc_chuveiro', nodes));
  assert.ok(!r.serviceCompatible(['svc_tomada'], 'juridico', nodes));
  assert.deepStrictEqual(r.matchKeys(['svc_tomada'], nodes).sort(), ['casa', 'eletricista', 'svc_tomada']);
});

test('matching: aprovação, conta, serviço, modalidade, próprio pedido', () => {
  const ctx = { uid: 'p1', nodes, nowMs: NOW };
  assert.deepStrictEqual(r.providerMatch(base, req, ctx).ok, true);
  assert.strictEqual(r.providerMatch({ ...base, verified: false }, req, ctx).reason, 'not_verified');
  assert.strictEqual(r.providerMatch({ ...base, active: false }, req, ctx).reason, 'inactive');
  assert.strictEqual(r.providerMatch(base, req, { ...ctx, userActive: false }).reason, 'account_blocked');
  assert.strictEqual(r.providerMatch(base, { ...req, category: 'juridico' }, ctx).reason, 'service_mismatch');
  assert.strictEqual(r.providerMatch(base, { ...req, modality: 'online' }, ctx).reason, 'modality_mismatch');
  assert.strictEqual(r.providerMatch(base, { ...req, clientId: 'p1' }, ctx).reason, 'own_request');
  assert.strictEqual(r.providerMatch({ ...base, userId: 'x' }, req, ctx).reason, 'not_owner');
});

test('região: raio quando há localização dos dois lados; cidade caso contrário; online ignora região', () => {
  const ctx = { uid: 'p1', nodes, nowMs: NOW };
  const near = { ...req, geo: { lat: -5.40, lng: -49.10 } };
  const m = r.providerMatch(base, near, ctx);
  assert.ok(m.ok && m.distanceKm < 5);
  const far = { ...req, geo: { lat: -6.07, lng: -49.90 } }; // ~115 km (Parauapebas)
  assert.strictEqual(r.providerMatch(base, far, ctx).reason, 'out_of_radius');
  assert.ok(r.providerMatch({ ...base, radiusKm: 150 }, far, ctx).ok);
  // Belém fica a ~430 km: raio declarado de 5000 km é limitado a 200 km.
  assert.strictEqual(r.providerMatch({ ...base, radiusKm: 5000 }, { ...req, geo: { lat: -1.45, lng: -48.5 } }, ctx).reason, 'out_of_radius');
  assert.strictEqual(r.providerMatch({ ...base, geo: null }, { ...req, city: 'Belém' }, ctx).reason, 'region_mismatch');
  const online = { ...base, modalities: ['online'] };
  assert.ok(r.providerMatch(online, { ...req, modality: 'online', city: 'Belém' }, ctx).ok);
});

test('disponibilidade: dia da semana, período, pausa e férias; perfis antigos sem restrição', () => {
  const ctx = { uid: 'p1', nodes, nowMs: NOW };
  const av = { ...base, availability: { weekdays: [1, 2, 3, 4, 5], periods: ['morning'] } };
  assert.strictEqual(r.weekdayOf('2026-10-17'), 6);
  assert.ok(r.providerMatch(av, { ...req, preferredDate: '2026-10-13', preferredPeriod: 'morning' }, ctx).ok);
  assert.strictEqual(r.providerMatch(av, { ...req, preferredDate: '2026-10-17' }, ctx).reason, 'weekday_unavailable');
  assert.strictEqual(r.providerMatch(av, { ...req, preferredDate: '2026-10-13', preferredPeriod: 'evening' }, ctx).reason, 'period_unavailable');
  assert.ok(r.providerMatch(av, { ...req, preferredDate: '2026-10-13', preferredPeriod: 'any' }, ctx).ok);
  assert.strictEqual(r.providerMatch({ ...base, acceptingRequests: false }, req, ctx).reason, 'paused');
  const vac = { ...base, unavailableUntil: '2026-10-20' };
  assert.strictEqual(r.providerMatch(vac, req, ctx).reason, 'unavailable_period');
  assert.ok(r.providerMatch(vac, { ...req, preferredDate: '2026-10-25' }, ctx).ok, 'depois das férias');
  assert.ok(r.providerMatch(av, req, ctx).ok, 'sem data preferida não restringe');
  assert.ok(r.validAvailability({ weekdays: [0, 6], periods: ['morning'] }));
  assert.ok(!r.validAvailability({ weekdays: [7] }));
  assert.ok(!r.validAvailability({ periods: ['madrugada'] }));
});

const qn = {
  questions: [
    { id: 'tipo', type: 'single_choice', label: 'Tipo', required: true, options: ['instalar', 'consertar'] },
    { id: 'qtd', type: 'number', label: 'Quantidade', required: true, showIf: { questionId: 'tipo', op: 'equals', value: 'instalar' } },
    { id: 'defeito', type: 'long_text', label: 'Defeito', required: true, showIf: { questionId: 'tipo', op: 'equals', value: 'consertar' } },
    { id: 'foto', type: 'attachment', label: 'Foto', required: false, showIf: { questionId: 'defeito', op: 'answered' } },
    { id: 'urgente', type: 'boolean', label: 'Urgente?', required: false },
  ],
};

test('questionário: condicionais, obrigatórias só quando visíveis, respostas ocultas descartadas', () => {
  let v = r.validateAnswers(qn, { tipo: 'instalar', qtd: 3, defeito: 'ignorado' }, { attachmentPrefix: 'resolveUploads/c1/' });
  assert.ok(v.ok, v.errors.join());
  assert.deepStrictEqual(v.answers, { tipo: 'instalar', qtd: 3 });
  v = r.validateAnswers(qn, { tipo: 'consertar' }, { attachmentPrefix: 'resolveUploads/c1/' });
  assert.ok(!v.ok && v.errors.some((e) => e.includes('Defeito')));
  assert.ok(!v.errors.some((e) => e.includes('Quantidade')), 'pergunta oculta não é obrigatória');
  v = r.validateAnswers(qn, {}, {});
  assert.ok(v.errors.some((e) => e.includes('Tipo')));
  v = r.validateAnswers(qn, { tipo: 'outro' }, {});
  assert.ok(v.errors.some((e) => e.includes('opção inválida')));
  v = r.validateAnswers(qn, { tipo: 'instalar', qtd: '3' }, {});
  assert.ok(v.errors.some((e) => e.includes('número')));
});

test('questionário: anexos só do próprio usuário, sem travessia de caminho', () => {
  const ok = r.validateAnswers(qn, { tipo: 'consertar', defeito: 'Disjuntor desarma', foto: ['resolveUploads/c1/u1/a.jpg'] }, { attachmentPrefix: 'resolveUploads/c1/' });
  assert.ok(ok.ok, ok.errors.join());
  assert.deepStrictEqual(ok.attachments, [{ questionId: 'foto', path: 'resolveUploads/c1/u1/a.jpg' }]);
  assert.strictEqual(ok.answers.foto, 1);
  for (const bad of ['resolveUploads/c2/u1/a.jpg', 'resolveUploads/c1/../c2/a.jpg', 'providers/x/document/a.jpg']) {
    const v = r.validateAnswers(qn, { tipo: 'consertar', defeito: 'xx', foto: [bad] }, { attachmentPrefix: 'resolveUploads/c1/' });
    assert.ok(!v.ok, bad);
  }
  const hidden = r.validateAnswers(qn, { tipo: 'instalar', qtd: 1, foto: ['resolveUploads/c2/x.jpg'] }, { attachmentPrefix: 'resolveUploads/c1/' });
  assert.ok(hidden.ok && hidden.attachments.length === 0, 'anexo de pergunta oculta é descartado');
});

test('questionário aplicável: o mais específico do caminho', () => {
  assert.strictEqual(r.questionnaireNodeFor('svc_tomada', nodes).id, 'svc_tomada');
  assert.strictEqual(r.questionnaireNodeFor('svc_chuveiro', nodes), null);
  const n2 = { ...nodes, eletricista: { ...nodes.eletricista, questionnaireId: 'q_ele' } };
  assert.strictEqual(r.questionnaireNodeFor('svc_chuveiro', n2).id, 'eletricista');
});

test('solicitação: validação, data no fuso local, localização aproximada', () => {
  const ok = r.validateRequestInput({ description: 'Trocar 3 tomadas na sala', category: 'svc_tomada', city: 'Marabá', preferredDate: '2026-10-13', preferredPeriod: 'morning', geo: { lat: -5.37123, lng: -49.11777 } }, NOW);
  assert.ok(ok.ok, ok.errors.join());
  assert.deepStrictEqual(ok.value.geo, { lat: -5.37, lng: -49.12 });
  assert.ok(!r.validateRequestInput({ description: 'curta', category: 'x', city: 'y' }, NOW).ok);
  assert.ok(!r.validateRequestInput({ description: 'Descrição válida aqui', category: 'x', city: 'y', preferredDate: '2026-10-01' }, NOW).ok, 'data passada');
  assert.ok(!r.validateRequestInput({ description: 'Descrição válida aqui', category: 'x', city: 'y', modality: 'teleporte' }, NOW).ok);
  assert.ok(r.validateRequestInput({ description: 'Consulta jurídica online', category: 'x', modality: 'online' }, NOW).ok, 'online dispensa cidade');
  assert.strictEqual(r.localToday(Date.UTC(2026, 9, 13, 2)), '2026-10-12', '23h em Belém ainda é dia 12');
});
