'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const security = require('./security');
const policy = require('./orderPolicy');

describe('AUTH — login / logout / unauth', () => {
  it('callable sem auth é bloqueada', () => {
    const r = security.assertCallableAuth({});
    assert.equal(r.ok, false);
    assert.equal(r.code, 'unauthenticated');
  });

  it('callable com uid passa', () => {
    const r = security.assertCallableAuth({ auth: { uid: 'u1', token: {} } });
    assert.equal(r.ok, true);
    assert.equal(r.uid, 'u1');
  });
});

describe('USERS — próprio perfil vs outro + campos protegidos', () => {
  it('dono lê o próprio doc; terceiro sem chat não lê', () => {
    assert.equal(security.canReadUserDoc('u1', 'u1'), true);
    assert.equal(security.canReadUserDoc('u2', 'u1'), false);
    assert.equal(security.canReadUserDoc('u2', 'u1', { sharesChat: true }), true);
    assert.equal(security.canReadUserDoc('adm', 'u1', { isAdmin: true }), true);
  });

  it('lista global de users só admin', () => {
    assert.equal(security.canListUsers(false), false);
    assert.equal(security.canListUsers(true), true);
  });

  it('client não altera plan/xp/type/verified', () => {
    assert.equal(security.clientUserUpdateBlocked(['name']), false);
    assert.equal(security.clientUserUpdateBlocked(['plan']), true);
    assert.equal(security.clientUserUpdateBlocked(['xp']), true);
    assert.equal(security.clientUserUpdateBlocked(['type']), true);
    assert.equal(security.clientUserUpdateBlocked(['verified']), true);
  });
});

describe('PROVIDERS — self-verification bloqueada', () => {
  it('prestador não se autoaprova nem seta verified', () => {
    assert.equal(security.providerSelfUpdateBlocked(['verified']), true);
    assert.equal(security.providerSelfUpdateBlocked(['approved']), true);
    assert.equal(
      security.providerSelfUpdateBlocked(['active'], { currentlyVerified: false }),
      true,
    );
    assert.equal(security.providerSelfUpdateBlocked(['city']), false);
  });
});

describe('ORDERS — transições / ownership / preço', () => {
  it('cliente não muda price nem providerId', () => {
    assert.equal(policy.SENSITIVE_FIELDS.includes('price'), true);
    assert.equal(
      security.orderClientUpdateAllowed(['price'], { status: 'completed' }),
      false,
    );
    assert.equal(
      security.orderClientUpdateAllowed(['providerId'], { status: 'pending' }),
      false,
    );
  });

  it('create exige clientId do auth e status pending', () => {
    assert.equal(security.orderCreateBlocked({ clientId: 'u1', status: 'pending' }, 'u1'), null);
    assert.equal(security.orderCreateBlocked({ clientId: 'hack', status: 'pending' }, 'u1'), 'client_mismatch');
    assert.equal(security.orderCreateBlocked({ clientId: 'u1', status: 'completed' }, 'u1'), 'invalid_status');
  });

  it('terceiro não aceita pedido alheio', () => {
    assert.equal(policy.actorMayPerform('accept', 'x', 'c1', 'p1'), false);
    assert.equal(policy.actorMayPerform('accept', 'p1', 'c1', 'p1'), true);
  });
});

describe('PAYMENTS — auth / ownership / idempotência', () => {
  it('pagamento só é lido pelo dono', () => {
    assert.equal(security.paymentReadableBy('u1', { userId: 'u1' }, false), true);
    assert.equal(security.paymentReadableBy('u2', { userId: 'u1' }, false), false);
    assert.equal(security.paymentReadableBy('adm', { userId: 'u1' }, true), true);
  });

  it('segunda cobrança é bloqueada', () => {
    assert.equal(policy.rejectDoubleCharge({ paymentStatus: 'paid' }).ok, false);
    assert.equal(policy.rejectDoubleCharge({ paymentStatus: 'unpaid' }).ok, true);
  });
});

describe('WALLET — payout único / saldo', () => {
  it('payout já processado é idempotente', () => {
    const r = policy.canPayout({
      status: 'completed',
      paymentStatus: 'paid',
      payoutProcessed: true,
      providerId: 'p1',
      price: 100,
      orderId: 'o1',
      paymentOrderId: 'o1',
      gatewayStatus: 'approved',
      paidAmount: 100,
    });
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'already_processed');
  });

  it('walletOp só withdraw/cashback', () => {
    assert.equal(security.walletOpAllowed('withdraw'), true);
    assert.equal(security.walletOpAllowed('cashback'), true);
    assert.equal(security.walletOpAllowed('credit'), false);
    assert.equal(security.walletOpAllowed('debit'), false);
  });
});

describe('ADMIN — autorização', () => {
  it('claim ou type=admin', () => {
    assert.equal(security.canAccessAdmin({ admin: true }, {}), true);
    assert.equal(security.canAccessAdmin({}, { type: 'admin' }), true);
    assert.equal(security.canAccessAdmin({}, { type: 'client', adminRole: 'support' }), false);
  });
});

describe('REVIEWS — 1 por pedido', () => {
  it('review id deve ser orderId_uid e pedido completed', () => {
    const order = { clientId: 'c1', providerId: 'p1', status: 'completed', id: 'o1' };
    assert.equal(
      security.reviewCreateBlocked({
        reviewId: 'o1_c1',
        uid: 'c1',
        review: { clientId: 'c1', providerId: 'p1', orderId: 'o1', stars: 5 },
        order,
      }),
      null,
    );
    assert.equal(
      security.reviewCreateBlocked({
        reviewId: 'outro',
        uid: 'c1',
        review: { clientId: 'c1', providerId: 'p1', orderId: 'o1', stars: 5 },
        order,
      }),
      'id_mismatch',
    );
  });
});

describe('NOTIFICATIONS — só dono / só backend', () => {
  it('client não cria notificação arbitrária', () => {
    assert.equal(security.clientMayCreateNotification(), false);
    assert.equal(security.canNotifyViaBackend(), true);
  });
});
