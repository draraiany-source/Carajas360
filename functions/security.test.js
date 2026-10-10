'use strict';
const test = require('node:test');
const assert = require('node:assert');
const sec = require('./security');

const provider = {
  userId: 'p1', verified: true, active: true,
  categories: ['eletricista'], city: 'Canaã dos Carajás',
};
const request = { clientId: 'c1', category: 'eletricista', city: 'canaa dos carajas' };

test('elegibilidade: prestador aprovado, ativo, serviço e cidade compatíveis', () => {
  assert.deepStrictEqual(sec.providerEligibility(provider, request, 'p1'), { ok: true, reason: null });
});

test('elegibilidade: bloqueia não verificado, inativo, outro serviço, outra cidade e próprio pedido', () => {
  assert.strictEqual(sec.providerEligibility({ ...provider, verified: false }, request, 'p1').reason, 'not_verified');
  assert.strictEqual(sec.providerEligibility({ ...provider, active: false }, request, 'p1').reason, 'inactive');
  assert.strictEqual(sec.providerEligibility(provider, { ...request, category: 'advogado' }, 'p1').reason, 'service_mismatch');
  assert.strictEqual(sec.providerEligibility(provider, { ...request, city: 'Marabá' }, 'p1').reason, 'region_mismatch');
  assert.strictEqual(sec.providerEligibility(provider, { ...request, clientId: 'p1' }, 'p1').reason, 'own_request');
  assert.strictEqual(sec.providerEligibility(provider, request, 'outro').reason, 'not_owner');
  assert.strictEqual(sec.providerEligibility(null, request, 'p1').reason, 'not_provider');
});

test('região: áreas atendidas ampliam a cobertura; sem cidade não restringe', () => {
  assert.ok(sec.providerServesCity({ city: 'Parauapebas', serviceAreas: ['Marabá'] }, 'MARABÁ'));
  assert.ok(sec.providerServesCity({}, 'Marabá'));
  assert.ok(!sec.providerServesCity({ city: 'Parauapebas' }, 'Marabá'));
});

test('oportunidade não expõe endereço nem contato', () => {
  const v = sec.opportunityView('r1', { ...request, address: 'Rua X, 10', phone: '9499', description: 'Trocar tomadas' });
  assert.strictEqual(v.address, undefined);
  assert.strictEqual(v.phone, undefined);
  assert.strictEqual(v.clientId, undefined);
  assert.strictEqual(v.description, 'Trocar tomadas');
});

test('proposta: valida preço e prazo', () => {
  assert.strictEqual(sec.validateProposalInput({ price: 0, deadlineDays: 2 }).ok, false);
  assert.strictEqual(sec.validateProposalInput({ price: 100, deadlineDays: 0 }).ok, false);
  assert.strictEqual(sec.validateProposalInput({ price: 100, deadlineDays: 1.5 }).ok, false);
  const ok = sec.validateProposalInput({ price: '150.456', deadlineDays: 3, message: '  ok ' });
  assert.deepStrictEqual(ok.value, { price: 150.46, deadlineDays: 3, message: 'ok' });
});

test('avaliação: exige cliente do pedido, pedido concluído e prestador correspondente', () => {
  const order = { clientId: 'c1', providerId: 'p1', status: 'completed' };
  const review = { orderId: 'o1', clientId: 'c1', providerId: 'p1', stars: 5 };
  assert.ok(sec.reviewValidity('o1_c1', review, order).ok);
  assert.strictEqual(sec.reviewValidity('o1_c1', { ...review, providerId: 'p2' }, order).reason, 'provider_mismatch');
  assert.strictEqual(sec.reviewValidity('o1_c1', review, { ...order, status: 'accepted' }).reason, 'not_completed');
  assert.strictEqual(sec.reviewValidity('o1_c2', { ...review, clientId: 'c2' }, order).reason, 'not_client');
  assert.strictEqual(sec.reviewValidity('x', review, order).reason, 'bad_id');
  assert.strictEqual(sec.reviewValidity('o1_c1', { ...review, stars: 9 }, order).reason, 'bad_stars');
});

test('média ignora notas inválidas', () => {
  assert.deepStrictEqual(sec.averageRating([5, 4, 99, 0, 3]), { rating: 4, totalReviews: 3 });
  assert.deepStrictEqual(sec.averageRating([]), { rating: 0, totalReviews: 0 });
});

test('storagePathFromUrl: produção, emulador e gs://', () => {
  const prod = 'https://firebasestorage.googleapis.com/v0/b/x.appspot.com/o/providers%2Fp1%2Fdocument%2F1.jpg?alt=media&token=abc';
  assert.strictEqual(sec.storagePathFromUrl(prod), 'providers/p1/document/1.jpg');
  assert.strictEqual(sec.storagePathFromUrl('http://127.0.0.1:9199/v0/b/b/o/providers%2Fp1%2Fselfie%2F2.png?alt=media'), 'providers/p1/selfie/2.png');
  assert.strictEqual(sec.storagePathFromUrl('gs://bucket/providers/p1/a.pdf'), 'providers/p1/a.pdf');
  assert.strictEqual(sec.storagePathFromUrl('CRM 1234'), null);
});

test('plano de migração separa documentos privados do perfil público', () => {
  const plan = sec.planProviderMigration({
    name: 'Ana',
    documentUrl: 'https://firebasestorage.googleapis.com/v0/b/x/o/providers%2Fp1%2Fdocument%2F1.jpg?alt=media&token=t',
    selfieUrl: null,
    certificates: ['NR-10', 'https://firebasestorage.googleapis.com/v0/b/x/o/providers%2Fp1%2Fcertificate%2Fc.pdf?token=t'],
  });
  assert.deepStrictEqual(plan.removeFields.sort(), ['certificates', 'documentUrl', 'selfieUrl']);
  assert.strictEqual(plan.privateData.documentPath, 'providers/p1/document/1.jpg');
  assert.deepStrictEqual(plan.privateData.certificates, ['NR-10']);
  assert.deepStrictEqual(plan.privateData.certificatePaths, ['providers/p1/certificate/c.pdf']);
  assert.strictEqual(plan.filesToProtect.length, 2);
  assert.strictEqual(sec.planProviderMigration({ name: 'Sem docs' }), null);
});

test('chunk respeita limite de 30 do Firestore', () => {
  const parts = sec.chunk(Array.from({ length: 31 }, (_, i) => i), sec.IN_QUERY_LIMIT);
  assert.deepStrictEqual(parts.map((p) => p.length), [30, 1]);
});
