'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const policy = require('./orderPolicy');

describe('F2 preço ao aceitar', () => {
  it('exige valor quando o pedido não tem preço', () => {
    assert.deepEqual(policy.acceptPriceDecision(null, undefined), { ok: false, reason: 'price_required' });
    assert.deepEqual(policy.acceptPriceDecision(0, ''), { ok: false, reason: 'price_required' });
  });

  it('aceita o valor informado pelo profissional', () => {
    assert.deepEqual(policy.acceptPriceDecision(null, 180.456), { ok: true, price: 180.46 });
  });

  it('mantém o preço já definido (ex.: proposta aceita)', () => {
    assert.deepEqual(policy.acceptPriceDecision(250, undefined), { ok: true, price: null });
  });

  it('recusa valores inválidos', () => {
    assert.equal(policy.acceptPriceDecision(null, -5).ok, false);
    assert.equal(policy.acceptPriceDecision(null, 'abc').ok, false);
    assert.equal(policy.acceptPriceDecision(null, policy.MAX_ORDER_PRICE + 1).ok, false);
  });
});

describe('F2 cancelamento com pagamento', () => {
  it('cliente/profissional não cancelam pedido pago', () => {
    assert.equal(policy.cancelBlockReason({ paymentStatus: 'paid' }, false), 'paid_requires_refund');
    assert.equal(policy.cancelBlockReason({ paymentStatus: 'unpaid' }, false), null);
  });

  it('admin pode cancelar (estorno é tratado à parte)', () => {
    assert.equal(policy.cancelBlockReason({ paymentStatus: 'paid' }, true), null);
  });
});

describe('F2 pagamento ligado ao pedido', () => {
  const base = { providerId: 'p1', status: 'accepted', price: 150, paymentStatus: 'unpaid' };

  it('pedido aceito com preço pode ser pago', () => {
    assert.equal(policy.paymentBlockReason(base), null);
    assert.equal(policy.paymentBlockReason({ ...base, status: 'inProgress' }), null);
  });

  it('bloqueia sem profissional, sem preço, já pago ou fora de etapa', () => {
    assert.equal(policy.paymentBlockReason({ ...base, providerId: null }), 'no_provider');
    assert.equal(policy.paymentBlockReason({ ...base, price: null }), 'no_price');
    assert.equal(policy.paymentBlockReason({ ...base, paymentStatus: 'paid' }), 'already_paid');
    assert.equal(policy.paymentBlockReason({ ...base, status: 'pending' }), 'order_not_payable');
    assert.equal(policy.paymentBlockReason({ ...base, status: 'cancelled' }), 'order_not_payable');
    assert.equal(policy.paymentBlockReason({ ...base, status: 'completed' }), 'order_not_payable');
  });
});

describe('F2 custódia', () => {
  const paidAt = new Date('2026-01-01T00:00:00Z');
  const completedAt = new Date('2026-01-02T00:00:00Z');

  it('prazo vem do Admin entre 1 e 30 dias; senão o padrão', () => {
    assert.equal(policy.escrowHoldDays(7), 7);
    assert.equal(policy.escrowHoldDays(0), policy.ESCROW_HOLD_DAYS);
    assert.equal(policy.escrowHoldDays(90), policy.ESCROW_HOLD_DAYS);
    assert.equal(policy.escrowHoldDays(undefined), policy.ESCROW_HOLD_DAYS);
  });

  it('com releaseAt definido, não libera antes do prazo', () => {
    const r = policy.canReleaseEscrow({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: false,
      completedAt,
      paidAt,
      releaseAt: new Date('2026-01-09T00:00:00Z'),
      now: new Date('2026-01-06T00:00:00Z'),
    });
    assert.deepEqual(r, { ok: false, reason: 'release_not_due' });
  });

  it('libera após o prazo ou com confirmação do cliente', () => {
    const args = {
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: false,
      completedAt,
      paidAt,
      releaseAt: new Date('2026-01-09T00:00:00Z'),
    };
    assert.equal(policy.canReleaseEscrow({ ...args, now: new Date('2026-01-09T00:00:01Z') }).ok, true);
    assert.equal(policy.canReleaseEscrow({ ...args, now: completedAt, clientConfirmed: true }).ok, true);
  });

  it('contestação bloqueia a liberação', () => {
    const r = policy.canReleaseEscrow({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: false,
      escrowStatus: 'disputed',
      clientConfirmed: true,
    });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'disputed');
  });
});

describe('F2 contestação', () => {
  it('permitida após conclusão enquanto o repasse não saiu', () => {
    assert.equal(policy.disputeBlockReason({ status: 'completed', payoutProcessed: false }), null);
    assert.equal(
      policy.disputeBlockReason({ status: 'completed', payoutProcessed: true }),
      'payout_already_done',
    );
  });
});
