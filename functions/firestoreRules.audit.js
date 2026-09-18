'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const rules = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

describe('firestore.rules — políticas críticas (auditoria estática)', () => {
  it('wallets não são graváveis pelo client', () => {
    assert.match(rules, /match \/wallets\/\{userId\}/);
    assert.match(rules, /allow write: if false;/);
  });

  it('transactions e payments não são criados pelo client', () => {
    assert.match(rules, /match \/transactions\/\{txId\}/);
    assert.match(rules, /match \/payments\/\{paymentId\}/);
    assert.match(rules, /allow create, update, delete: if false;/);
  });

  it('users não podem ser apagados pelo client', () => {
    assert.match(rules, /match \/users\/\{userId\}/);
    assert.match(rules, /allow delete: if false;/);
  });

  it('plan, xp e type são protegidos no perfil', () => {
    assert.match(rules, /'type', 'role', 'roles', 'adminRole', 'verified', 'active', 'plan'/);
    assert.match(rules, /'xp'/);
  });

  it('planChangeRequests só o backend escreve', () => {
    assert.match(rules, /match \/planChangeRequests\/\{id\}/);
    assert.match(rules, /allow create, update, delete: if false;/);
  });

  it('xpEvents e rateLimits são backend-only', () => {
    assert.match(rules, /match \/xpEvents\/\{id\}/);
    assert.match(rules, /match \/rateLimits\/\{id\}/);
  });

  it('catch-all recusa tudo', () => {
    assert.match(rules, /match \/\{document=\*\*\}/);
    assert.match(rules, /allow read, write: if false;/);
  });
});
