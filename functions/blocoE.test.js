'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { sanitizeDetails, ACTIONS } = require('./auditLog');
const { mercadoPagoWebhookDecision, verifyMpSignature } = require('./webhookSandbox');
const { directionsDecision } = require('./directionsProxy');

describe('AUDIT — sanitização e ações', () => {
  it('não persiste secrets em details', () => {
    const safe = sanitizeDetails({
      action: 'payment',
      access_token: 'APP_USR-secreto',
      token: 'abc',
      amount: 10,
    });
    assert.equal(safe.access_token, undefined);
    assert.equal(safe.token, undefined);
    assert.equal(safe.amount, 10);
  });

  it('lista de ações críticas está completa', () => {
    assert.equal(ACTIONS.ADMIN_LOGIN, 'admin_login');
    assert.equal(ACTIONS.PERMISSION_CHANGE, 'permission_change');
    assert.equal(ACTIONS.PROVIDER_APPROVED, 'provider_approved');
    assert.equal(ACTIONS.PAYMENT, 'payment');
    assert.equal(ACTIONS.ORDER_CANCELLED, 'order_cancelled');
    assert.equal(ACTIONS.REFUND, 'refund');
    assert.equal(ACTIONS.PAYOUT, 'payout');
    assert.equal(ACTIONS.WALLET, 'wallet_change');
    assert.equal(ACTIONS.ACCOUNT_DELETED, 'lgpd_account_anonymized');
  });
});

describe('WEBHOOK MP — assinatura sandbox sem cobrança', () => {
  const secret = 'test-only-not-for-repo-prod';

  it('sem secret continua 501 e não cobra', () => {
    const r = mercadoPagoWebhookDecision('POST', {});
    assert.equal(r.status, 501);
    assert.equal(r.body.charged, false);
    assert.equal(r.body.applied, false);
  });

  it('assinatura inválida é 401 e não aplica', () => {
    const r = mercadoPagoWebhookDecision('POST', {
      secret,
      signature: 'ts=1,v1=deadbeef',
      requestId: 'req',
      dataId: '99',
    });
    assert.equal(r.status, 401);
    assert.equal(r.body.applied, false);
    assert.equal(r.body.charged, false);
  });

  it('assinatura válida aceita mas não cobra', () => {
    const ts = '1700000000';
    const requestId = 'req-1';
    const dataId = 'pay-1';
    const manifest = `id:${dataId};request-id:${requestId};ts:${ts};`;
    const v1 = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
    assert.equal(verifyMpSignature({ secret, signature: `ts=${ts},v1=${v1}`, requestId, dataId }), true);
    const r = mercadoPagoWebhookDecision('POST', {
      secret,
      signature: `ts=${ts},v1=${v1}`,
      requestId,
      dataId,
    });
    assert.equal(r.status, 202);
    assert.equal(r.body.charged, false);
    assert.equal(r.body.applied, false);
  });
});

describe('DIRECTIONS — sem key de servidor', () => {
  it('placeholder ou vazio recusa', () => {
    assert.equal(directionsDecision({ serverKey: '', origin: '1,1', destination: '2,2' }).reason, 'maps_server_key_not_configured');
    assert.equal(directionsDecision({
      serverKey: 'COLE_SUA_GOOGLE_MAPS_API_KEY_AQUI',
      origin: '1,1',
      destination: '2,2',
    }).ok, false);
  });

  it('key presente ainda não dispara HTTP (ready apenas)', () => {
    const r = directionsDecision({
      serverKey: 'AIzaSyServerKeyFromSecretManagerNotInRepo',
      origin: '-6.0,-49.0',
      destination: '-6.1,-49.1',
    });
    assert.equal(r.ok, true);
    assert.equal(r.charged, false);
  });
});
