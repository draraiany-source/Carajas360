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
    assert.equal(policy.isAllowedTransition('cancelled', 'accepted'), true);
    assert.equal(policy.isAllowedTransition('cancelled', 'pending'), true);
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

  it('reopen/cancelDefinitive/releaseEscrow só admin', () => {
    assert.equal(policy.actorMayPerform('reopen', 'c1', 'c1', 'p1', false), false);
    assert.equal(policy.actorMayPerform('reopen', 'admin', 'c1', 'p1', true), true);
    assert.equal(policy.actorMayPerform('cancelDefinitive', 'c1', 'c1', 'p1', false), false);
    assert.equal(policy.actorMayPerform('cancelDefinitive', 'admin', 'c1', 'p1', true), true);
    assert.equal(policy.actorMayPerform('releaseEscrow', 'c1', 'c1', 'p1', false), false);
    assert.equal(policy.actorMayPerform('releaseEscrow', 'admin', 'c1', 'p1', true), true);
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

  it('payout válido calcula comissão 8% (100 → 8/92)', () => {
    const r = policy.canPayout(base);
    assert.equal(r.ok, true);
    assert.equal(r.commission, 8);
    assert.equal(r.providerAmount, 92);
  });

  it('250 → 20/230', () => {
    const r = policy.canPayout({ ...base, price: 250, paidAmount: 250 });
    assert.equal(r.commission, 20);
    assert.equal(r.providerAmount, 230);
  });

  it('1000 → 80/920', () => {
    const r = policy.canPayout({ ...base, price: 1000, paidAmount: 1000 });
    assert.equal(r.commission, 80);
    assert.equal(r.providerAmount, 920);
  });

  // FASE 3: taxa do Admin/snapshot deve prevalecer sobre o default 8%.
  it('commissionRate Admin 10% em 500 → 50/450', () => {
    const r = policy.canPayout({
      ...base,
      price: 500,
      paidAmount: 500,
      commissionRate: 0.10,
    });
    assert.equal(r.ok, true);
    assert.equal(r.commissionRate, 0.10);
    assert.equal(r.commission, 50);
    assert.equal(r.providerAmount, 450);
  });

  it('commissionRate invalida (>30%) cai no default 8%', () => {
    const r = policy.canPayout({
      ...base,
      price: 100,
      paidAmount: 100,
      commissionRate: 0.5,
    });
    assert.equal(r.ok, true);
    assert.equal(r.commissionRate, 0.08);
    assert.equal(r.commission, 8);
  });

  it('FASE4 direct_contact isenta comissao (sem cobranca dupla)', () => {
    const r = policy.canPayout({
      ...base,
      price: 500,
      paidAmount: 500,
      billingMode: 'direct_contact',
    });
    assert.equal(r.ok, true);
    assert.equal(r.commission, 0);
    assert.equal(r.providerAmount, 500);
    assert.equal(r.commissionRate, 0);
    assert.equal(r.commissionAmount, 0);
  });

  it('FASE4 commissionExempt true isenta comissao', () => {
    const r = policy.canPayout({
      ...base,
      price: 200,
      paidAmount: 200,
      commissionExempt: true,
    });
    assert.equal(r.ok, true);
    assert.equal(r.commission, 0);
    assert.equal(r.providerAmount, 200);
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

describe('escrow staging', () => {
  it('escrowHoldOnPaid retém e calcula releaseAt +3 dias', () => {
    const paidAt = new Date('2026-01-01T12:00:00Z');
    const hold = policy.escrowHoldOnPaid({ amount: 100, paidAt });
    assert.equal(hold.escrowStatus, 'held');
    assert.equal(hold.heldAmount, 100);
    assert.equal(hold.releaseAt.getTime(), paidAt.getTime() + 3 * 86400000);
  });

  it('canReleaseEscrow bloqueia estados inválidos', () => {
    assert.equal(
      policy.canReleaseEscrow({
        status: 'completed',
        paymentStatus: 'unpaid',
        payoutProcessed: false,
      }).ok,
      false,
    );
    assert.equal(
      policy.canReleaseEscrow({
        status: 'disputed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        escrowStatus: 'disputed',
      }).reason,
      'disputed',
    );
    assert.equal(
      policy.canReleaseEscrow({
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        escrowStatus: 'released',
      }).reason,
      'already_released',
    );
  });

  it('canReleaseEscrow libera com confirmação ou após prazo', () => {
    const paidAt = new Date('2026-01-01T00:00:00Z');
    assert.equal(
      policy.canReleaseEscrow({
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        clientConfirmed: true,
      }).ok,
      true,
    );
    assert.equal(
      policy.canReleaseEscrow({
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        paidAt,
        now: new Date(paidAt.getTime() + 3 * 86400000),
      }).ok,
      true,
    );
    assert.equal(
      policy.canReleaseEscrow({
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        paidAt,
        now: new Date(paidAt.getTime() + 2 * 86400000),
      }).reason,
      'release_not_due',
    );
  });

  it('adminReopen e adminCancelDefinitive', () => {
    assert.equal(policy.adminReopenAllowed('cancelled'), true);
    assert.equal(policy.adminReopenAllowed('completed'), false);
    assert.equal(policy.adminReopenTarget({ providerId: 'p1' }), 'accepted');
    assert.equal(policy.adminReopenTarget({}), 'pending');
    assert.equal(policy.adminCancelDefinitiveAllowed('paid'), true);
    assert.equal(policy.adminCancelDefinitiveAllowed('cancelled'), false);
    assert.equal(
      policy.adminCancelDefinitiveAllowed('completed', 'released'),
      false,
    );
  });

  it('transições escrow', () => {
    assert.equal(policy.isAllowedEscrowTransition('held', 'serviceInProgress'), true);
    assert.equal(policy.isAllowedEscrowTransition('releasePending', 'released'), true);
    assert.equal(policy.isAllowedEscrowTransition('released', 'held'), false);
  });
});

describe('campos sensíveis', () => {
  it('inclui price, providerId, status, amount e payoutProcessed', () => {
    for (const f of [
      'price', 'providerId', 'status', 'payoutProcessed', 'clientId',
      'amount', 'gatewayTransactionId', 'walletId',
      'escrowStatus', 'heldAmount', 'releaseAt', 'releasedAt', 'clientConfirmedAt',
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
    assert.equal(audit.commission, 16);
    assert.equal(audit.providerAmount, 184);
    assert.equal(audit.payoutProcessed, true);
    assert.equal(audit.gatewayTransactionId, 'mp_1');
    assert.equal(audit.payoutTransactionId, 'payout_o9');
  });
});

describe('ações conhecidas', () => {
  it('isKnownAction inclui escrow e admin', () => {
    assert.equal(policy.isKnownAction('accept'), true);
    assert.equal(policy.isKnownAction('reopen'), true);
    assert.equal(policy.isKnownAction('hold'), true);
    assert.equal(policy.isKnownAction('releaseEscrow'), true);
    assert.equal(policy.isKnownAction('bogus'), false);
  });
});
