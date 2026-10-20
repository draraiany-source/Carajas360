'use strict';

/**
 * Núcleo financeiro (Fase 3) — regras puras, sem Firebase.
 * Toda operação interna usa CENTAVOS (inteiros). Valores em reais só na
 * fronteira (gateway e documentos legados).
 */

const DEFAULT_FINANCE_CONFIG = Object.freeze({
  commissionBps: 1500, // 15,00% (valor histórico do app)
  cashbackBps: 200, // 2,00% (valor histórico do walletOp)
  maxInstallments: 12,
  minInstallmentCents: 500,
  reservationMinutes: 30, // Pix: mínimo de 30 min no gateway
  defaultDeliveryFeeCents: 0,
  rechargeMinCents: 1000,
  rechargeMaxCents: 500000,
});

const LIMITS = {
  commissionBps: [0, 3000],
  cashbackBps: [0, 1000],
  maxInstallments: [1, 12],
  minInstallmentCents: [100, 100000],
  reservationMinutes: [30, 120],
  defaultDeliveryFeeCents: [0, 100000],
  rechargeMinCents: [100, 100000],
  rechargeMaxCents: [1000, 1000000],
};

function isInt(n) { return Number.isInteger(n); }

/** Reais (número legado) → centavos, sem erro de ponto flutuante. */
function toCents(reais) {
  const n = Number(reais);
  if (!Number.isFinite(n)) return null;
  return Math.round(n * 100);
}

function fromCents(cents) { return Math.round(Number(cents)) / 100; }

/** basis points: 1500 bps = 15%. Arredonda meio para cima. */
function bpsOf(cents, bps) { return Math.round((Number(cents) * Number(bps)) / 10000); }

function validateFinanceConfig(input, current = DEFAULT_FINANCE_CONFIG) {
  const out = { ...DEFAULT_FINANCE_CONFIG, ...current };
  const errors = [];
  for (const [k, [min, max]] of Object.entries(LIMITS)) {
    if (input[k] === undefined) continue;
    const v = Number(input[k]);
    if (!isInt(v) || v < min || v > max) errors.push(`${k} deve ser inteiro entre ${min} e ${max}`);
    else out[k] = v;
  }
  if (out.rechargeMinCents > out.rechargeMaxCents) errors.push('recarga mínima maior que a máxima');
  return { ok: errors.length === 0, errors, value: out };
}

/** Preço efetivo do produto em centavos (promoção só se menor). */
function productPriceCents(p) {
  const price = toCents(p.price);
  const promo = p.promoPrice == null ? null : toCents(p.promoPrice);
  if (price == null || price <= 0) return null;
  return promo != null && promo > 0 && promo < price ? promo : price;
}

/** Desconto do cupom (servidor). Retorna { cents, error }. */
function couponDiscount(coupon, goodsCents, now) {
  if (!coupon) return { cents: 0, error: null };
  const exp = coupon.expiresAt && typeof coupon.expiresAt.toMillis === 'function'
    ? coupon.expiresAt.toMillis()
    : (coupon.expiresAt instanceof Date ? coupon.expiresAt.getTime() : Number(coupon.expiresAt || 0));
  if (coupon.active !== true || !(exp > now)) return { cents: 0, error: 'cupom inválido ou expirado' };
  const min = coupon.minValue == null ? 0 : toCents(coupon.minValue);
  if (goodsCents < min) return { cents: 0, error: 'valor mínimo do cupom não atingido' };
  let cents;
  if (coupon.isPercentage) {
    const pct = Number(coupon.discount);
    if (!(pct > 0 && pct <= 100)) return { cents: 0, error: 'cupom mal configurado' };
    cents = Math.round(goodsCents * pct / 100);
  } else {
    cents = toCents(coupon.discount) || 0;
  }
  return { cents: Math.max(0, Math.min(cents, goodsCents)), error: null };
}

/**
 * Cotação do pedido do Mercado — SOMENTE com dados do servidor.
 * items: [{productId, qty}] do app (preço/total do app são ignorados).
 */
function quoteMarketOrder({ items, products, store, coupon, deliveryMode, config, now }) {
  const errors = [];
  const cfg = { ...DEFAULT_FINANCE_CONFIG, ...(config || {}) };
  if (!store) errors.push('loja não encontrada');
  // Loja desativada ou ainda não aprovada pelo admin não vende.
  else if (store.active !== true) errors.push('esta loja está desativada e não aceita pedidos no momento');
  else if (store.verified !== true) errors.push('esta loja ainda não foi aprovada e não aceita pedidos');
  if (!Array.isArray(items) || items.length === 0) errors.push('carrinho vazio');
  if (Array.isArray(items) && items.length > 50) errors.push('máximo de 50 itens por pedido');
  const seen = new Set();
  const lines = [];
  for (const it of Array.isArray(items) ? items : []) {
    const id = String((it && it.productId) || '');
    const qty = Number(it && it.qty);
    if (!id || seen.has(id)) { errors.push('item inválido ou repetido'); continue; }
    seen.add(id);
    if (!isInt(qty) || qty < 1 || qty > 99) { errors.push(`quantidade inválida para ${id}`); continue; }
    const p = products[id];
    if (!p) { errors.push(`produto ${id} não encontrado`); continue; }
    if (p.active !== true) { errors.push(`"${p.name}" indisponível`); continue; }
    if (store && p.storeId !== store.id) { errors.push(`"${p.name}" é de outra loja`); continue; }
    const unit = productPriceCents(p);
    if (unit == null) { errors.push(`"${p.name}" sem preço válido`); continue; }
    const stock = Number(p.stock || 0);
    if (!(stock >= qty)) { errors.push(`estoque insuficiente para "${p.name}" (disponível: ${Math.max(0, stock)})`); continue; }
    lines.push({ productId: id, name: String(p.name || ''), unitPriceCents: unit, qty, subtotalCents: unit * qty });
  }
  const mode = deliveryMode === 'pickup' ? 'pickup' : 'delivery';
  if (store && mode === 'pickup' && store.pickupEnabled === false) errors.push('loja não aceita retirada');
  if (store && mode === 'delivery' && store.deliveryEnabled === false) errors.push('loja não faz entrega');
  const goodsCents = lines.reduce((s, l) => s + l.subtotalCents, 0);
  const disc = couponDiscount(coupon, goodsCents, now);
  if (disc.error) errors.push(disc.error);
  const deliveryFeeCents = mode === 'pickup' ? 0
    : (store && isInt(store.deliveryFeeCents) && store.deliveryFeeCents >= 0
      ? store.deliveryFeeCents : cfg.defaultDeliveryFeeCents);
  const totalCents = goodsCents - disc.cents + deliveryFeeCents;
  return {
    ok: errors.length === 0,
    errors,
    lines,
    deliveryMode: mode,
    subtotalCents: goodsCents,
    discountCents: disc.cents,
    deliveryFeeCents,
    totalCents,
  };
}

/**
 * Condições financeiras gravadas no pedido (snapshot). A comissão incide
 * sobre mercadorias menos desconto; o frete é integral da loja. Momento:
 * calculada na criação, reconhecida na liberação (entrega).
 */
function financeTerms(quote, config, configVersion) {
  const cfg = { ...DEFAULT_FINANCE_CONFIG, ...(config || {}) };
  const goodsNet = Math.max(0, quote.subtotalCents - quote.discountCents);
  const commissionCents = bpsOf(goodsNet, cfg.commissionBps);
  const cashbackCents = bpsOf(goodsNet, cfg.cashbackBps);
  return {
    commissionBps: cfg.commissionBps,
    cashbackBps: cfg.cashbackBps,
    configVersion: configVersion || 0,
    goodsNetCents: goodsNet,
    commissionCents,
    cashbackCents,
    sellerNetCents: goodsNet - commissionCents + quote.deliveryFeeCents,
  };
}

/** Parcelamento: 1..max e parcela mínima. */
function validateInstallments(n, totalCents, config) {
  const cfg = { ...DEFAULT_FINANCE_CONFIG, ...(config || {}) };
  const k = Number(n);
  if (!isInt(k) || k < 1 || k > cfg.maxInstallments) return `parcelas devem estar entre 1 e ${cfg.maxInstallments}`;
  if (k > 1 && Math.floor(totalCents / k) < cfg.minInstallmentCents) return 'valor da parcela abaixo do mínimo';
  return null;
}

// ── Estados de pagamento ──────────────────────────────────────────

/** Status do gateway (Mercado Pago) → status interno da tentativa. */
function mapGatewayStatus(s, detail) {
  switch (s) {
    case 'approved': return 'approved';
    case 'authorized':
    case 'in_process':
    case 'pending':
      return detail === 'pending_challenge' ? 'challenge' : 'pending';
    case 'rejected': return 'rejected';
    case 'cancelled': return detail === 'expired' ? 'expired' : 'cancelled';
    case 'refunded': return 'refunded';
    case 'charged_back': return 'charged_back';
    case 'in_mediation': return 'in_dispute';
    default: return 'pending';
  }
}

const RANK = {
  creating: 0, uncertain: 0, pending: 1, challenge: 1,
  rejected: 2, cancelled: 2, expired: 2, failed: 2,
  approved: 3, in_dispute: 4, partially_refunded: 4, refunded: 5, charged_back: 5,
};

/**
 * Deve aplicar a atualização? Eventos fora de ordem/repetidos são
 * ignorados: só avança por data do gateway mais nova; com a mesma data,
 * só se o status tiver rank maior. Aprovado após cancelado/expirado é
 * aceito (aprovação tardia) e tratado à parte.
 */
function shouldApply(current, incoming) {
  if (!current) return true;
  const a = current.gatewayUpdatedAt || 0;
  const b = incoming.gatewayUpdatedAt || 0;
  if (current.status === incoming.status && b <= a) return false;
  if (b < a) return false;
  if (b === a) return (RANK[incoming.status] || 0) > (RANK[current.status] || 0);
  return true;
}

const ACTIVE_ATTEMPT = ['creating', 'uncertain', 'pending', 'challenge'];
const TERMINAL_FAIL = ['rejected', 'cancelled', 'expired', 'failed'];

/** Reembolso permitido? Retorna erro ou null. */
function refundError(approvedCents, refundedCents, pendingCents, amountCents) {
  if (!isInt(amountCents) || amountCents <= 0) return 'valor de reembolso inválido';
  if (amountCents + refundedCents + pendingCents > approvedCents) return 'reembolso acima do valor pago';
  return null;
}

/** Efeitos proporcionais de um reembolso sobre comissão, repasse e cashback. */
function refundEffects(terms, totalCents, refundCents) {
  if (!terms || !(totalCents > 0)) return { commissionCents: 0, sellerNetCents: 0, cashbackCents: 0 };
  const ratio = Math.min(1, refundCents / totalCents);
  return {
    commissionCents: Math.round(terms.commissionCents * ratio),
    sellerNetCents: Math.round(terms.sellerNetCents * ratio),
    cashbackCents: Math.round(terms.cashbackCents * ratio),
  };
}

/** Lançamento na carteira: impede saldo negativo. */
function applyLedger(balanceCents, type, amountCents) {
  if (!isInt(amountCents) || amountCents <= 0) return { ok: false, error: 'valor inválido' };
  const debit = ['debit', 'payment', 'sale_reversal', 'cashback_reversal', 'withdraw'].includes(type);
  const next = debit ? balanceCents - amountCents : balanceCents + amountCents;
  if (next < 0) return { ok: false, error: 'saldo insuficiente' };
  return { ok: true, balanceCents: next, signed: debit ? -amountCents : amountCents };
}

/**
 * Guarda de ambiente do gateway (homologação). Nunca opera dinheiro real:
 *  - `fake` só existe no emulador;
 *  - `mercadopago` exige PAYMENTS_ENV=sandbox, token de teste e projeto
 *    que não seja o de produção.
 */
function gatewayMode(env) {
  const e = env || {};
  const gw = String(e.PAYMENTS_GATEWAY || '').trim();
  const emulator = e.FUNCTIONS_EMULATOR === 'true';
  const project = String(e.GCLOUD_PROJECT || e.GCP_PROJECT || '');
  const prodProjects = String(e.PROD_PROJECT_IDS || 'servicoconecta').split(',').map((s) => s.trim());
  if (!gw) return { mode: 'disabled', reason: 'Pagamentos desligados neste ambiente.' };
  if (gw === 'fake') {
    return emulator ? { mode: 'fake', reason: null }
      : { mode: 'disabled', reason: 'Gateway simulado só é permitido no emulador.' };
  }
  if (gw !== 'mercadopago') return { mode: 'disabled', reason: 'Gateway desconhecido.' };
  if (prodProjects.includes(project)) return { mode: 'disabled', reason: 'Projeto de produção: operações reais bloqueadas nesta fase.' };
  if (e.PAYMENTS_ENV !== 'sandbox') return { mode: 'disabled', reason: 'PAYMENTS_ENV deve ser "sandbox" em homologação.' };
  const token = String(e.MERCADOPAGO_ACCESS_TOKEN || '');
  if (!token) return { mode: 'disabled', reason: 'Credencial de teste ausente.' };
  const isTest = token.startsWith('TEST-') || (token.startsWith('APP_USR-') && e.MP_TEST_USER_CREDENTIALS === 'true');
  if (!isTest) return { mode: 'disabled', reason: 'Credencial não reconhecida como de teste.' };
  if (!e.MP_WEBHOOK_SECRET) return { mode: 'disabled', reason: 'Segredo do webhook ausente.' };
  return { mode: 'mercadopago', reason: null };
}

/** Remove qualquer coisa parecida com token antes de logar/gravar erro. */
function redact(text) {
  return String(text || '')
    .replace(/(TEST|APP_USR)-[A-Za-z0-9-]{8,}/g, '[redacted]')
    .replace(/Bearer\s+[A-Za-z0-9._-]+/gi, 'Bearer [redacted]')
    .slice(0, 300);
}

module.exports = {
  DEFAULT_FINANCE_CONFIG, LIMITS, ACTIVE_ATTEMPT, TERMINAL_FAIL, RANK,
  toCents, fromCents, bpsOf, validateFinanceConfig, productPriceCents, couponDiscount,
  quoteMarketOrder, financeTerms, validateInstallments, mapGatewayStatus, shouldApply,
  refundError, refundEffects, applyLedger, gatewayMode, redact,
};
