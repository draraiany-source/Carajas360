'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const policy = require('./orderPolicy');
const security = require('./security');

function fakeContext(uid, extras = {}) {
  if (!uid) return {};
  return { auth: { uid, token: extras.token || {} }, app: extras.app };
}

describe('fraude financeira — deve ser bloqueada', () => {
  const order = {
    id: 'o1',
    clientId: 'c1',
    providerId: 'p1',
    price: 150,
    status: 'inProgress',
    paymentStatus: 'unpaid',
    payoutProcessed: false,
  };

  it('1) alterar price após criação é campo sensível', () => {
    assert.ok(policy.SENSITIVE_FIELDS.includes('price'));
    assert.equal(
      security.orderClientUpdateAllowed(['price'], order),
      false,
    );
  });

  it('2) trocar providerId é bloqueado', () => {
    assert.ok(policy.SENSITIVE_FIELDS.includes('providerId'));
    assert.equal(
      security.orderClientUpdateAllowed(['providerId'], { ...order, status: 'completed' }),
      false,
    );
    const payout = policy.canPayout({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: false,
      providerId: 'hacker',
      officialProviderId: 'p1',
      price: 150,
      orderId: 'o1',
      paymentOrderId: 'o1',
      gatewayStatus: 'approved',
      paidAmount: 150,
    });
    assert.equal(payout.ok, false);
    assert.equal(payout.reason, 'provider_mismatch');
  });

  it('3) concluir sem pagamento é bloqueado', () => {
    assert.equal(
      policy.completeBlockReason('inProgress', 'unpaid'),
      'payment_not_confirmed',
    );
    assert.equal(
      policy.isAllowedTransition('pending', 'completed'),
      false,
    );
  });

  it('4) pagar duas vezes é bloqueado', () => {
    assert.equal(policy.rejectDoubleCharge({ paymentStatus: 'paid' }).ok, false);
    assert.equal(policy.rejectDoubleCharge({ paymentStatus: 'unpaid' }).ok, true);
  });

  it('5) payout duas vezes é bloqueado (idempotente)', () => {
    const second = policy.canPayout({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: true,
      providerId: 'p1',
      price: 150,
      orderId: 'o1',
      paymentOrderId: 'o1',
      gatewayStatus: 'approved',
      paidAmount: 150,
    });
    assert.equal(second.ok, false);
    assert.equal(second.reason, 'already_processed');
  });

  it('6) Function sem auth é bloqueada', () => {
    const r = security.assertCallableAuth(fakeContext(null));
    assert.equal(r.ok, false);
    assert.equal(r.code, 'unauthenticated');
  });

  it('7) Function com usuário errado não lê pagamento alheio', () => {
    const payment = { userId: 'c1', orderId: 'o1', status: 'approved' };
    assert.equal(security.paymentReadableBy('hacker', payment, false), false);
    assert.equal(security.paymentReadableBy('c1', payment, false), true);
    assert.equal(security.paymentReadableBy('hacker', payment, true), true);
  });

  it('8) manipular status manualmente é bloqueado', () => {
    assert.ok(policy.SENSITIVE_FIELDS.includes('status'));
    assert.equal(
      security.orderClientUpdateAllowed(['status'], { ...order, status: 'completed' }),
      false,
    );
    assert.equal(policy.isAllowedTransition('pending', 'paid'), false);
    assert.equal(policy.actorMayPerform('markPaid', 'c1', 'c1', 'p1'), false);
  });
});

describe('auth / app check / perfil', () => {
  it('App Check obrigatório quando enforce=true', () => {
    const r = security.assertCallableAuth(fakeContext('u1'), { enforceAppCheck: true });
    assert.equal(r.ok, false);
    assert.equal(r.code, 'failed-precondition');
  });

  it('auth válido retorna uid', () => {
    const r = security.assertCallableAuth(fakeContext('u1', { app: { appId: 'x' } }));
    assert.equal(r.ok, true);
    assert.equal(r.uid, 'u1');
  });

  it('usuário comum não cria notificação arbitrária', () => {
    assert.equal(security.clientMayCreateNotification(), false);
  });

  it('usuário comum não se autoaprova', () => {
    assert.equal(security.privilegedUserCreate({ type: 'provider', verified: true }), true);
    assert.equal(security.privilegedUserCreate({ type: 'company', plan: 'premium' }), true);
    assert.equal(security.privilegedUserCreate({ type: 'admin' }), true);
    assert.equal(security.privilegedUserCreate({ type: 'client' }), false);
    assert.equal(
      security.providerSelfUpdateBlocked(['verified'], { currentlyVerified: false }),
      true,
    );
    assert.equal(security.companySelfUpdateBlocked(['plan']), true);
  });

  it('leitura global de users bloqueada; PII não na lista pública', () => {
    assert.equal(security.canListUsers(false), false);
    assert.equal(security.canListUsers(true), true);
    assert.equal(security.canReadUserDoc('a', 'b', { isAdmin: false, sharesChat: false }), false);
    assert.equal(security.canReadUserDoc('a', 'a', {}), true);
    assert.ok(security.PII_KEYS.includes('cpf'));
    assert.ok(security.PII_KEYS.includes('fcmToken'));
  });

  it('review só do cliente do pedido completed, 1x, provider oficial', () => {
    const order = {
      id: 'o1', clientId: 'c1', providerId: 'p1', status: 'completed',
    };
    assert.equal(security.reviewCreateBlocked({
      reviewId: 'o1_c1', uid: 'c1',
      review: { orderId: 'o1', clientId: 'c1', providerId: 'p1', stars: 5 },
      order,
    }), null);
    assert.equal(security.reviewCreateBlocked({
      reviewId: 'o1_hacker', uid: 'hacker',
      review: { orderId: 'o1', clientId: 'hacker', providerId: 'p1', stars: 5 },
      order,
    }), 'not_order_client');
    assert.equal(security.reviewCreateBlocked({
      reviewId: 'o1_c1', uid: 'c1',
      review: { orderId: 'o1', clientId: 'c1', providerId: 'hacker', stars: 5 },
      order,
    }), 'provider_mismatch');
    assert.equal(security.reviewCreateBlocked({
      reviewId: 'o1_c1', uid: 'c1',
      review: { orderId: 'o1', clientId: 'c1', providerId: 'p1', stars: 5 },
      order: { ...order, status: 'pending' },
    }), 'order_not_completed');
  });

  it('walletOp debit arbitrário não é permitido', () => {
    assert.equal(security.walletOpAllowed('debit'), false);
    assert.equal(security.walletOpAllowed('withdraw'), true);
    assert.equal(security.walletOpAllowed('cashback'), true);
  });

  it('resposta pública de pagamento não vaza secrets', () => {
    const view = security.publicPaymentView({
      status: 'approved',
      method: 'pix',
      purpose: 'order',
      orderId: 'o1',
      access_token: 'SECRET',
      amount: 99,
    }, 'pay1');
    assert.equal(view.id, 'pay1');
    assert.equal(view.status, 'approved');
    assert.equal(view.access_token, undefined);
    assert.equal(view.amount, undefined);
    const stripped = security.stripSecrets({ token: 'x', qr_code: 'abc', nested: { apiKey: 'z', ok: 1 } });
    assert.equal(stripped.token, undefined);
    assert.equal(stripped.qr_code, 'abc');
    assert.equal(stripped.nested.apiKey, undefined);
    assert.equal(stripped.nested.ok, 1);
  });

  it('CORS * não é considerado seguro', () => {
    assert.equal(security.corsOriginAllowed('*', ['https://app.example']), false);
    assert.equal(security.corsOriginAllowed('https://app.example', ['https://app.example']), true);
  });
});
