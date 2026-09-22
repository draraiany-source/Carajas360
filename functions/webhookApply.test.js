'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  decideWebhookApply,
  createMemoryLedger,
  simulateDuplicateWebhook,
} = require('./webhookApply');

describe('FASE4 webhookApply idempotencia', () => {
  it('PAYMENTS_ENABLED=false nao aplica', () => {
    const d = decideWebhookApply({ paymentsEnabled: false, eventId: 'e1', credits: 10 });
    assert.equal(d.apply, false);
    assert.equal(d.reason, 'payments_disabled');
    assert.equal(d.charged, false);
  });

  it('sem eventId nao aplica', () => {
    const d = decideWebhookApply({ paymentsEnabled: true, eventId: '', credits: 10 });
    assert.equal(d.apply, false);
    assert.equal(d.reason, 'missing_event_id');
  });

  it('webhook duplicado = 1 ledger', () => {
    const store = createMemoryLedger();
    const r = simulateDuplicateWebhook(store, 'pay-dup-1', {
      type: 'CREDIT_PURCHASE',
      credits: 50,
      userId: 'u1',
    });
    assert.equal(r.ok, true);
    assert.equal(r.ledgerCount, 1);
    assert.equal(r.first.ledgerWrites, 1);
    assert.equal(r.second.already, true);
  });

  it('eventos distintos = 2 ledger', () => {
    const store = createMemoryLedger();
    store.applyOnce('a', { type: 'CREDIT_PURCHASE', credits: 10 });
    store.applyOnce('b', { type: 'CREDIT_PURCHASE', credits: 20 });
    assert.equal(store.ledger.length, 2);
  });
});