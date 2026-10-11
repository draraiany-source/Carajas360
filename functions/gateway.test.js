'use strict';
// Testes do adaptador com payloads no formato da API Payments (mock; sem rede).
const test = require('node:test');
const assert = require('node:assert');
const { normalizeMp } = require('./payments/gateway');

test('normaliza Pix pendente com QR e vencimento', () => {
  const n = normalizeMp({
    id: 123, status: 'pending', status_detail: 'pending_waiting_transfer', transaction_amount: 59.9,
    currency_id: 'BRL', external_reference: 'att_1', collector_id: 77,
    date_created: '2026-10-10T10:00:00.000-03:00', date_last_updated: '2026-10-10T10:00:01.000-03:00',
    date_of_expiration: '2026-10-10T10:30:00.000-03:00',
    point_of_interaction: { transaction_data: { qr_code: '000201...', qr_code_base64: 'iVBOR' } },
  });
  assert.deepStrictEqual([n.id, n.status, n.amountCents, n.externalReference, n.collectorId], ['123', 'pending', 5990, 'att_1', '77']);
  assert.strictEqual(n.pix.qrCode, '000201...');
  assert.ok(n.gatewayUpdatedAt > 0);
});

test('cartão com desafio 3DS e reembolso parcial', () => {
  const c = normalizeMp({ id: 1, status: 'pending', status_detail: 'pending_challenge', transaction_amount: 10, three_ds_info: { external_resource_url: 'https://3ds', creq: 'x' } });
  assert.strictEqual(c.status, 'challenge');
  assert.strictEqual(c.challenge.url, 'https://3ds');
  const r = normalizeMp({ id: 2, status: 'approved', transaction_amount: 100, refunds: [{ amount: 30, status: 'approved' }, { amount: 5, status: 'in_process' }] });
  assert.strictEqual(r.status, 'partially_refunded');
  assert.strictEqual(r.refundedCents, 3000, 'só reembolsos aprovados contam');
  assert.strictEqual(normalizeMp({ id: 3, status: 'refunded', transaction_amount: 100, refunds: [{ amount: 100, status: 'approved' }] }).status, 'refunded');
});
