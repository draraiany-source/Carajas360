'use strict';

const COMMISSION_RATE = 0.15;

const SENSITIVE_FIELDS = [
  'price', 'total', 'providerId', 'clientId', 'status', 'expiresAt', 'expiredAt',
  'paymentStatus', 'payoutStatus', 'payoutProcessed',
  'commission', 'platformFee', 'providerAmount', 'transactionId',
  'cashbackGranted', 'paidAt', 'payoutAt',
];

const TRANSITIONS = {
  pending: ['accepted', 'cancelled'],
  accepted: ['inProgress', 'cancelled'],
  inProgress: ['completed', 'cancelled', 'disputed'],
  completed: [],
  cancelled: [],
  disputed: ['cancelled'],
};

const ACTIONS = {
  accept: 'accepted',
  start: 'inProgress',
  complete: 'completed',
  cancel: 'cancelled',
  decline: 'cancelled',
  dispute: 'disputed',
};

/**
 * Prazo para o prestador aceitar um pedido pendente (regra vigente: 7 dias,
 * a mesma da antiga limpeza `cleanupOldOrders`). O app usa o mesmo valor
 * em OrderModel.expiryOf (lib/shared/models/models.dart).
 */
const PENDING_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

/** Timestamp | Date | ms → ms (ou null se ausente/inválido). */
function toMs(v) {
  if (v == null) return null;
  if (typeof v.toMillis === 'function') return v.toMillis();
  if (v instanceof Date) return v.getTime();
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : null;
}

/**
 * Fonte única do vencimento de um pedido pendente: `expiresAt` gravado pelo
 * servidor; pedido antigo sem o campo usa createdAt + 7 dias. Sem nenhuma
 * data: null (não expira; o antigo cleanup também não o alcançava).
 */
function expiresAtMs(order) {
  const o = order || {};
  const exp = toMs(o.expiresAt);
  if (exp) return exp;
  const created = toMs(o.createdAt);
  return created ? created + PENDING_EXPIRY_MS : null;
}

/** Pedido pendente com prazo vencido em `nowMs`? */
function isExpired(order, nowMs) {
  if (((order && order.status) || 'pending') !== 'pending') return false;
  const exp = expiresAtMs(order);
  return exp != null && nowMs >= exp;
}

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function isAllowedTransition(from, to) {
  return (TRANSITIONS[from] || []).includes(to);
}

function targetStatus(action) {
  return ACTIONS[action] || null;
}

function actorMayPerform(action, uid, clientId, providerId) {
  const isClient = uid === clientId;
  const isProvider = Boolean(providerId) && uid === providerId;
  switch (action) {
    case 'accept':
      return !providerId || uid === providerId;
    case 'start':
    case 'decline':
      return isProvider;
    case 'complete':
    case 'dispute':
    case 'cancel':
      return isClient || isProvider;
    default:
      return false;
  }
}

function completeBlockReason(currentStatus, paymentStatus) {
  if (currentStatus !== 'inProgress') return 'invalid_transition';
  if (paymentStatus !== 'paid') return 'payment_not_confirmed';
  return null;
}

function canPayout({
  status,
  paymentStatus,
  payoutProcessed,
  providerId,
  price,
  orderId,
  paymentOrderId,
  gatewayStatus,
  paidAmount,
  commissionRate,
}) {
  if (payoutProcessed) return { ok: false, reason: 'already_processed' };
  if (status !== 'completed') return { ok: false, reason: 'order_not_completed' };
  const paid = paymentStatus === 'paid' || gatewayStatus === 'approved';
  if (!paid) return { ok: false, reason: 'payment_not_confirmed' };
  if (!providerId) return { ok: false, reason: 'missing_provider' };
  const gross = Number(price);
  if (!(gross > 0)) return { ok: false, reason: 'invalid_price' };
  if (paymentOrderId && paymentOrderId !== orderId) {
    return { ok: false, reason: 'payment_order_mismatch' };
  }
  if (paidAmount != null && Math.abs(Number(paidAmount) - gross) > 0.009) {
    return { ok: false, reason: 'amount_mismatch' };
  }
  // Taxa do snapshot do pedido (financeTerms); legado sem snapshot usa 15%.
  const rate = Number.isFinite(commissionRate) && commissionRate >= 0 && commissionRate <= 0.5
    ? commissionRate : COMMISSION_RATE;
  const commission = round2(gross * rate);
  const providerAmount = round2(gross - commission);
  return { ok: true, gross, commission, providerAmount };
}

module.exports = {
  COMMISSION_RATE,
  SENSITIVE_FIELDS,
  PENDING_EXPIRY_MS,
  TRANSITIONS,
  ACTIONS,
  round2,
  toMs,
  expiresAtMs,
  isExpired,
  isAllowedTransition,
  targetStatus,
  actorMayPerform,
  completeBlockReason,
  canPayout,
};
