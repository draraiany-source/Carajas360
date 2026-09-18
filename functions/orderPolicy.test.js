'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const policy = require('./orderPolicy');

describe('máquina de estados', () => {
  it('aceita apenas transições explícitas', () => {
    assert.equal(policy.isAllowedTransition('pending', 'accepted'), true);
    assert.equal(policy.isAllowedTransition('pending', 'completed'), false);
    assert.equal(policy.isAllowedTransition('accepted', 'inProgress'), true);
    assert.equal(policy.isAllowedTransition('inProgress', 'completed'), true);
    assert.equal(policy.isAllowedTransition('completed', 'pending'), false);
    assert.equal(policy.isAllowedTransition('cancelled', 'accepted'), false);
  });

  it('aliases created/in_progress/awaiting_payment', () => {
    assert.equal(policy.normalizeStatus('created'), 'pending');
    assert.equal(policy.normalizeStatus('in_progress'), 'inProgress');
    assert.equal(policy.normalizeStatus('awaiting_payment'), 'awaitingPayment');
    assert.equal(policy.isAllowedTransition('created', 'accepted'), true);
    assert.equal(policy.isAllowedTransition('in_progress', 'completed'), true);
  });

  it('não deixa cliente/prestador pular para completed a partir de pending', () => {
    assert.equal(policy.isAllowedTransition('pending', 'completed'), false);
    assert.equal(policy.isAllowedTransition('accepted', 'completed'), false);
  });

  it('refunded só a partir de estados finais válidos', () => {
    assert.equal(policy.isAllowedTransition('completed', 'refunded'), true);
    assert.equal(policy.isAllowedTransition('pending', 'refunded'), false);
    assert.equal(policy.actorMayPerform('refund', 'c1', 'c1', 'p1', false), false);
    assert.equal(policy.actorMayPerform('refund', 'admin', 'c1', 'p1', true), true);
  });
});

describe('ações por ator', () => {
  it('accept só pelo prestador designado (ou se ainda vazio)', () => {
    assert.equal(policy.actorMayPerform('accept', 'p1', 'c1', null), true);
    assert.equal(policy.actorMayPerform('accept', 'p1', 'c1', 'p1'), true);
    assert.equal(policy.actorMayPerform('accept', 'p2', 'c1', 'p1'), false);
  });

  it('start só pelo prestador', () => {
    assert.equal(policy.actorMayPerform('start', 'p1', 'c1', 'p1'), true);
    assert.equal(policy.actorMayPerform('start', 'c1', 'c1', 'p1'), false);
  });

  it('markPaid nunca pelo client SDK', () => {
    assert.equal(policy.actorMayPerform('markPaid', 'c1', 'c1', 'p1'), false);
    assert.equal(policy.actorMayPerform('markPaid', 'p1', 'c1', 'p1'), false);
  });
});

describe('concluir sem pagamento deve falhar', () => {
  it('bloqueia complete se paymentStatus != paid', () => {
    assert.equal(
      policy.completeBlockReason('inProgress', 'unpaid'),
      'payment_not_confirmed',
    );
    assert.equal(
      policy.completeBlockReason('inProgress', 'pending'),
      'payment_not_confirmed',
    );
    assert.equal(policy.completeBlockReason('inProgress', 'paid'), null);
    assert.equal(policy.completeBlockReason('pending', 'paid'), 'invalid_transition');
  });
});

describe('payout', () => {
  const base = {
    status: 'completed',
    paymentStatus: 'paid',
    payoutProcessed: false,
    providerId: 'p1',
    price: 100,
    orderId: 'o1',
    paymentOrderId: 'o1',
    gatewayStatus: 'approved',
    paidAmount: 100,
  };

  it('payout válido calcula comissão 15%', () => {
    const r = policy.canPayout(base);
    assert.equal(r.ok, true);
    assert.equal(r.commission, 15);
    assert.equal(r.providerAmount, 85);
  });

  it('segunda execução é idempotente (already_processed)', () => {
    const r = policy.canPayout({ ...base, payoutProcessed: true });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'already_processed');
  });

  it('sem pagamento confirmado falha', () => {
    const r = policy.canPayout({
      ...base,
      paymentStatus: 'unpaid',
      gatewayStatus: 'pending',
    });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'payment_not_confirmed');
  });

  it('price diferente do valor pago falha', () => {
    const r = policy.canPayout({ ...base, paidAmount: 1 });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'amount_mismatch');
  });

  it('payment de outro pedido falha', () => {
    const r = policy.canPayout({ ...base, paymentOrderId: 'other' });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'payment_order_mismatch');
  });

  it('providerId vazio falha', () => {
    const r = policy.canPayout({ ...base, providerId: '' });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'missing_provider');
  });

  it('trocar providerId no payload vs oficial falha', () => {
    const r = policy.canPayout({ ...base, providerId: 'hacker', officialProviderId: 'p1' });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'provider_mismatch');
  });
});

describe('campos sensíveis', () => {
  it('inclui price, providerId, status, amount e payoutProcessed', () => {
    for (const f of [
      'price', 'providerId', 'status', 'payoutProcessed', 'clientId',
      'amount', 'gatewayTransactionId', 'walletId',
    ]) {
      assert.ok(policy.SENSITIVE_FIELDS.includes(f), f);
    }
  });
});

describe('auditoria financeira', () => {
  it('registra bruto, taxa, comissão, líquido e ids', () => {
    const decision = policy.canPayout({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: false,
      providerId: 'p1',
      price: 200,
      orderId: 'o9',
      paymentOrderId: 'o9',
      gatewayStatus: 'approved',
      paidAmount: 200,
    });
    const audit = policy.buildFinancialAudit({
      orderId: 'o9',
      userId: 'c1',
      providerId: 'p1',
      clientId: 'c1',
      decision,
      gatewayTransactionId: 'mp_1',
      payoutTransactionId: 'payout_o9',
      status: 'payout_done',
    });
    assert.equal(audit.gross, 200);
    assert.equal(audit.commission, 30);
    assert.equal(audit.providerAmount, 170);
    assert.equal(audit.payoutProcessed, true);
    assert.equal(audit.gatewayTransactionId, 'mp_1');
    assert.equal(audit.payoutTransactionId, 'payout_o9');
  });
});
