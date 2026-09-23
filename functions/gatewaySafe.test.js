'use strict';
const { describe, it } = require('node:test');
const assert = require('node:assert/strict');

function assertGatewaySafe(token, productionPaymentsEnabled) {
  if (!token) return { ok: false, reason: 'missing_token' };
  const looksProd = token.startsWith('APP_USR-') && !token.includes('TEST');
  const looksTest = token.startsWith('TEST-') || token.includes('TEST');
  if (looksProd && !productionPaymentsEnabled) {
    return { ok: false, reason: 'production_token_blocked' };
  }
  if (productionPaymentsEnabled && looksTest) {
    return { ok: false, reason: 'test_token_in_production_mode' };
  }
  return { ok: true, looksProd, looksTest };
}

describe('FASE6 gateway fail-safe', () => {
  it('bloqueia APP_USR sem PRODUCTION_PAYMENTS_ENABLED', () => {
    const r = assertGatewaySafe('APP_USR-xxxx', false);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'production_token_blocked');
  });
  it('aceita TEST- com producao off', () => {
    const r = assertGatewaySafe('TEST-xxxx', false);
    assert.equal(r.ok, true);
    assert.equal(r.looksTest, true);
  });
  it('bloqueia TEST- com PRODUCTION_PAYMENTS_ENABLED', () => {
    const r = assertGatewaySafe('TEST-xxxx', true);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'test_token_in_production_mode');
  });
  it('aceita APP_USR com PRODUCTION_PAYMENTS_ENABLED', () => {
    const r = assertGatewaySafe('APP_USR-xxxx', true);
    assert.equal(r.ok, true);
    assert.equal(r.looksProd, true);
  });
});