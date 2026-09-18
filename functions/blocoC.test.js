'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const planChange = require('./planChange');

describe('planChange — sandbox sem cobrança', () => {
  it('rejeita plano inválido', () => {
    const r = planChange.buildPlanChangeDecision({
      requestedPlan: 'diamond',
      currentPlan: 'free',
      paymentsEnabled: false,
    });
    assert.equal(r.ok, false);
    assert.equal(r.code, 'invalid-argument');
  });

  it('rejeita pedido do mesmo plano', () => {
    const r = planChange.buildPlanChangeDecision({
      requestedPlan: 'premium',
      currentPlan: 'premium',
      paymentsEnabled: false,
    });
    assert.equal(r.ok, false);
    assert.equal(r.code, 'already-exists');
  });

  it('sandbox: pending_sandbox, charged=false, applied=false', () => {
    const r = planChange.buildPlanChangeDecision({
      requestedPlan: 'professional',
      currentPlan: 'free',
      paymentsEnabled: false,
    });
    assert.equal(r.ok, true);
    assert.equal(r.charged, false);
    assert.equal(r.applied, false);
    assert.equal(r.status, 'pending_sandbox');
    assert.equal(r.requestedPlan, 'professional');
  });

  it('flag de pagamento on ainda NÃO cobra nem aplica', () => {
    const r = planChange.buildPlanChangeDecision({
      requestedPlan: 'corporate',
      currentPlan: 'free',
      paymentsEnabled: true,
    });
    assert.equal(r.ok, true);
    assert.equal(r.charged, false);
    assert.equal(r.applied, false);
    assert.equal(r.status, 'pending_review');
  });

  it('lista oficial de planos', () => {
    for (const p of ['free', 'professional', 'premium', 'corporate']) {
      assert.equal(planChange.isAllowedPlan(p), true);
    }
    assert.equal(planChange.isAllowedPlan('pro'), false);
  });
});
