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

  it('assistedRequestPublishes é backend-only na escrita', () => {
    assert.match(rules, /match \/assistedRequestPublishes\/\{id\}/);
    assert.match(rules, /allow create, update, delete: if false;/);
  });

  it('aiConversations e aiUsage: client só lê o próprio; escrita backend', () => {
    assert.match(rules, /match \/aiConversations\/\{convId\}/);
    assert.match(rules, /match \/aiUsage\/\{id\}/);
    assert.match(rules, /resource\.data\.userId == uid\(\)/);
    assert.match(rules, /match \/messages\/\{msgId\}/);
    assert.match(rules, /allow create, update, delete: if false;/);
  });

  it('cliente não define comissão ao criar pedido', () => {
    const orders = rules.slice(rules.indexOf('match /orders/{orderId}'));
    const create = orders.slice(0, orders.indexOf('allow update'));
    for (const key of ['commissionRate', 'commissionExempt', 'billingMode']) {
      assert.ok(create.includes(`'${key}'`), `${key} deve estar bloqueado`);
    }
  });

  function block(start) {
    const from = rules.indexOf(start);
    assert.ok(from >= 0, `${start} ausente`);
    return rules.slice(from, rules.indexOf('\n    match /', from + start.length));
  }

  it('cliente não define preço de serviço nem custódia ao criar pedido', () => {
    const create = block('match /orders/{orderId}').split('allow update')[0];
    for (const key of ['price', 'escrowStatus', 'releaseAt', 'clientConfirmedAt']) {
      assert.ok(create.includes(`'${key}'`), `${key} deve estar bloqueado`);
    }
    assert.match(create, /get\('providerId', ''\) != uid\(\)/);
  });

  it('pedido aberto: só profissionais listam; contato fica em private', () => {
    const req = block('match /resolveRequests/{id}');
    assert.match(req, /resource\.data\.status == 'open' && isProvider\(\)/);
    assert.match(req, /'address', 'clientName', 'clientPhone'/);
    assert.match(req, /match \/private\/\{docId\}/);
  });

  it('proposta exige profissional, pedido aberto e valor positivo', () => {
    const create = block('match /resolveProposals/{id}').split('allow update')[0];
    assert.match(create, /isProvider\(\)/);
    assert.match(create, /\.status == 'open'/);
    assert.match(create, /price > 0/);
    assert.match(create, /data\.get\('totalReviews', 0\)/);
  });

  it('cliente não marca proposta como aceita direto', () => {
    const update = block('match /resolveProposals/{id}').split('allow update')[1];
    assert.ok(!/hasOnly\(\['accepted'\]\)/.test(update));
  });

  it('coleções novas têm regra explícita', () => {
    for (const c of ['serviceTaxonomy/{docId}', 'leadUnlocks/{id}', 'creditPurchases/{id}', 'highlightPurchases/{id}']) {
      assert.ok(rules.includes(`match /${c}`), `${c} sem regra`);
    }
  });

  it('prestador não cria perfil com nota', () => {
    const create = block('match /providers/{providerId}').split('allow update')[0];
    assert.match(create, /get\('rating', 0\) == 0/);
    assert.match(create, /get\('totalReviews', 0\) == 0/);
  });

  it('cliente da reserva só cancela enquanto pendente', () => {
    const b = block('match /bookings/{bookingId}');
    assert.match(b, /request\.resource\.data\.status == 'cancelled'/);
    assert.match(b, /get\('status', 'pending'\) == 'pending'/);
  });

  it('catch-all recusa tudo', () => {
    assert.match(rules, /match \/\{document=\*\*\}/);
    assert.match(rules, /allow read, write: if false;/);
  });
});
