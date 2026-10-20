'use strict';
const test = require('node:test');
const assert = require('node:assert');
const f = require('./financeCore');

const now = Date.UTC(2026, 9, 10);
const store = { id: 's1', active: true, verified: true, deliveryFeeCents: 700 };
const products = {
  p1: { storeId: 's1', name: 'Arroz', price: 22.9, stock: 5, active: true },
  p2: { storeId: 's1', name: 'Feijão', price: 10, promoPrice: 8.5, stock: 1, active: true },
  p3: { storeId: 's2', name: 'De outra loja', price: 1, stock: 9, active: true },
  p4: { storeId: 's1', name: 'Inativo', price: 1, stock: 9, active: false },
};

test('centavos sem erro de ponto flutuante', () => {
  assert.strictEqual(f.toCents(0.1 + 0.2), 30);
  assert.strictEqual(f.toCents(22.9), 2290);
  assert.strictEqual(f.bpsOf(10000, 1500), 1500);
  assert.strictEqual(f.bpsOf(333, 1500), 50);
});

test('cotação usa só preços do servidor; total do app é ignorado', () => {
  const q = f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 2, price: 0.01, totalCents: 1 }, { productId: 'p2', qty: 1 }], products, store, deliveryMode: 'delivery', now });
  assert.ok(q.ok, q.errors.join());
  assert.strictEqual(q.subtotalCents, 2290 * 2 + 850);
  assert.strictEqual(q.deliveryFeeCents, 700);
  assert.strictEqual(q.totalCents, 4580 + 850 + 700);
  assert.deepStrictEqual(q.lines.map((l) => l.unitPriceCents), [2290, 850]);
});

test('cotação valida estoque, loja, ativo, quantidade e repetição', () => {
  const bad = f.quoteMarketOrder({ items: [{ productId: 'p2', qty: 2 }, { productId: 'p3', qty: 1 }, { productId: 'p4', qty: 1 }, { productId: 'p1', qty: 0 }, { productId: 'p1', qty: 1 }, { productId: 'p1', qty: 1 }], products, store, now });
  assert.strictEqual(bad.ok, false);
  const msg = bad.errors.join(' | ');
  for (const s of ['estoque insuficiente', 'outra loja', 'indisponível', 'quantidade inválida', 'repetido']) assert.ok(msg.includes(s), s);
  assert.ok(!f.quoteMarketOrder({ items: [], products, store, now }).ok);
  assert.ok(!f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store: { ...store, active: false }, now }).ok);
  // Loja não aprovada (ou sem o campo active) também não vende.
  assert.match(f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store: { ...store, verified: false }, now }).errors.join(), /não foi aprovada/);
  assert.match(f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store: { ...store, active: undefined }, now }).errors.join(), /desativada/);
  assert.strictEqual(f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store, deliveryMode: 'pickup', now }).deliveryFeeCents, 0);
});

test('cupom calculado no servidor com limites', () => {
  const c = { active: true, expiresAt: new Date(now + 1e6), isPercentage: true, discount: 10, minValue: 20 };
  const q = f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 2 }], products, store, coupon: c, now });
  assert.strictEqual(q.discountCents, 458);
  assert.ok(!f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store, coupon: { ...c, minValue: 100 }, now }).ok);
  assert.ok(!f.quoteMarketOrder({ items: [{ productId: 'p1', qty: 1 }], products, store, coupon: { ...c, expiresAt: new Date(now - 1) }, now }).ok);
  const fixed = f.couponDiscount({ active: true, expiresAt: new Date(now + 1e6), discount: 999 }, 1000, now);
  assert.strictEqual(fixed.cents, 1000, 'desconto nunca passa do valor');
});

test('snapshot de comissão/cashback e preservação por pedido', () => {
  const q = { subtotalCents: 10000, discountCents: 1000, deliveryFeeCents: 500, totalCents: 9500 };
  const t1 = f.financeTerms(q, { commissionBps: 1000, cashbackBps: 200 }, 3);
  assert.deepStrictEqual([t1.commissionCents, t1.cashbackCents, t1.sellerNetCents, t1.configVersion], [900, 180, 9000 - 900 + 500, 3]);
  const t2 = f.financeTerms(q, { commissionBps: 2000, cashbackBps: 200 }, 4);
  assert.notStrictEqual(t1.commissionCents, t2.commissionCents);
});

test('limites da configuração financeira', () => {
  assert.ok(!f.validateFinanceConfig({ commissionBps: 5000 }).ok);
  assert.ok(!f.validateFinanceConfig({ cashbackBps: -1 }).ok);
  assert.ok(!f.validateFinanceConfig({ commissionBps: 12.5 }).ok);
  assert.ok(!f.validateFinanceConfig({ reservationMinutes: 10 }).ok, 'Pix exige >= 30 min');
  assert.strictEqual(f.validateFinanceConfig({ commissionBps: 1200 }).value.commissionBps, 1200);
});

test('parcelamento', () => {
  assert.strictEqual(f.validateInstallments(1, 300), null);
  assert.ok(f.validateInstallments(13, 100000));
  assert.ok(f.validateInstallments(12, 1000), 'parcela abaixo do mínimo');
  assert.ok(f.validateInstallments(1.5, 1000));
});

test('estados do gateway e eventos fora de ordem/duplicados', () => {
  assert.strictEqual(f.mapGatewayStatus('in_process'), 'pending');
  assert.strictEqual(f.mapGatewayStatus('pending', 'pending_challenge'), 'challenge');
  assert.strictEqual(f.mapGatewayStatus('cancelled', 'expired'), 'expired');
  const approved = { status: 'approved', gatewayUpdatedAt: 200 };
  assert.ok(!f.shouldApply(approved, { status: 'pending', gatewayUpdatedAt: 100 }), 'pendente antigo depois de aprovado');
  assert.ok(!f.shouldApply(approved, { status: 'approved', gatewayUpdatedAt: 200 }), 'duplicado');
  assert.ok(f.shouldApply(approved, { status: 'refunded', gatewayUpdatedAt: 300 }));
  assert.ok(f.shouldApply({ status: 'pending', gatewayUpdatedAt: 100 }, { status: 'approved', gatewayUpdatedAt: 100 }), 'mesmo instante, rank maior');
  assert.ok(f.shouldApply({ status: 'cancelled', gatewayUpdatedAt: 100 }, { status: 'approved', gatewayUpdatedAt: 150 }), 'aprovação tardia é aceita para tratamento');
});

test('reembolso: limites e efeitos proporcionais', () => {
  assert.ok(f.refundError(1000, 0, 0, 1001));
  assert.ok(f.refundError(1000, 600, 0, 500));
  assert.ok(f.refundError(1000, 0, 600, 500), 'considera reembolso pendente');
  assert.strictEqual(f.refundError(1000, 0, 0, 1000), null);
  const e = f.refundEffects({ commissionCents: 900, sellerNetCents: 8600, cashbackCents: 180 }, 9500, 4750);
  assert.deepStrictEqual(e, { commissionCents: 450, sellerNetCents: 4300, cashbackCents: 90 });
});

test('carteira nunca fica negativa', () => {
  assert.deepStrictEqual(f.applyLedger(1000, 'credit', 500), { ok: true, balanceCents: 1500, signed: 500 });
  assert.strictEqual(f.applyLedger(1000, 'payment', 1001).ok, false);
  assert.strictEqual(f.applyLedger(1000, 'payment', 1000).balanceCents, 0);
  assert.strictEqual(f.applyLedger(1000, 'credit', 0).ok, false);
});

test('homologação impede operação real', () => {
  const base = { PAYMENTS_GATEWAY: 'mercadopago', PAYMENTS_ENV: 'sandbox', MERCADOPAGO_ACCESS_TOKEN: 'TEST-123456789-abc', MP_WEBHOOK_SECRET: 's', GCLOUD_PROJECT: 'carajas360-hml' };
  assert.strictEqual(f.gatewayMode(base).mode, 'mercadopago');
  assert.strictEqual(f.gatewayMode({ ...base, GCLOUD_PROJECT: 'servicoconecta' }).mode, 'disabled', 'projeto de produção');
  assert.strictEqual(f.gatewayMode({ ...base, PAYMENTS_ENV: 'production' }).mode, 'disabled');
  assert.strictEqual(f.gatewayMode({ ...base, MERCADOPAGO_ACCESS_TOKEN: 'APP_USR-999999999-real' }).mode, 'disabled', 'credencial real');
  assert.strictEqual(f.gatewayMode({ ...base, MERCADOPAGO_ACCESS_TOKEN: 'APP_USR-999999999-x', MP_TEST_USER_CREDENTIALS: 'true' }).mode, 'mercadopago', 'usuário de teste explícito');
  assert.strictEqual(f.gatewayMode({ ...base, MP_WEBHOOK_SECRET: '' }).mode, 'disabled');
  assert.strictEqual(f.gatewayMode({ PAYMENTS_GATEWAY: 'fake' }).mode, 'disabled', 'fake fora do emulador');
  assert.strictEqual(f.gatewayMode({ PAYMENTS_GATEWAY: 'fake', FUNCTIONS_EMULATOR: 'true' }).mode, 'fake');
  assert.strictEqual(f.gatewayMode({}).mode, 'disabled');
});

test('redação de segredos em logs', () => {
  const s = f.redact('erro Bearer TEST-1234567890-abcdef token APP_USR-1234567890-zz');
  assert.ok(!s.includes('TEST-1234567890') && !s.includes('APP_USR-1234567890'));
});
