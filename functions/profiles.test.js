'use strict';
const test = require('node:test');
const assert = require('node:assert');
const { displayName, buildPublicProfile } = require('./profiles');

test('nome de exibição mínimo: primeiro nome + inicial', () => {
  assert.strictEqual(displayName('maria da silva souza'), 'maria S.');
  assert.strictEqual(displayName('João'), 'João');
  assert.strictEqual(displayName('   '), null);
});

test('perfil público não expõe dados privados', () => {
  const u = { name: 'Ana Paula Costa', email: 'ana@x.com', phone: '9499', cpf: '123', photoUrl: 'p.jpg', type: 'client', balance: 10 };
  const p = buildPublicProfile(u, null);
  assert.deepStrictEqual(Object.keys(p).sort(), ['kind', 'name', 'photoUrl', 'verified']);
  assert.deepStrictEqual(p, { name: 'Ana C.', photoUrl: 'p.jpg', kind: 'client', verified: false });
});

test('prestador aprovado usa o nome público de prestador; pendente não', () => {
  const u = { name: 'Carlos Alberto Lima', type: 'provider' };
  assert.strictEqual(buildPublicProfile(u, { name: 'Carlos Eletricista', verified: true, active: true }).name, 'Carlos Eletricista');
  assert.strictEqual(buildPublicProfile(u, { name: 'Carlos Eletricista', verified: false }).name, 'Carlos L.');
  assert.strictEqual(buildPublicProfile({ type: 'admin', name: 'Equipe' }, null).kind, 'support');
  assert.strictEqual(buildPublicProfile({}, null).name, 'Usuário');
});
