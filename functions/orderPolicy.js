'use strict';

const COMMISSION_RATE = 0.15;

const SENSITIVE_FIELDS = [
  'price', 'total', 'amount', 'providerId', 'clientId', 'status',
  'paymentStatus', 'payoutStatus', 'payoutProcessed', 'payoutProcessedAt',
  'payoutTransactionId', 'commission', 'platformFee', 'providerAmount',
  'transactionId', 'gatewayTransactionId', 'walletId', 'cashbackGranted',
  'paidAt', 'payoutAt', 'refunded', 'refundAmount',
];

const STATUS_ALIASES = {
  created: 'pending',
  in_progress: 'inProgress',
  inprogress: 'inProgress',
  awaiting_payment: 'awaitingPayment',
  awaitingpayment: 'awaitingPayment',
};

const TRANSITIONS = {
  pending: ['accepted', 'cancelled'],
  accepted: ['inProgress', 'cancelled'],
  inProgress: ['awaitingPayment', 'completed', 'cancelled', 'disputed'],
  awaitingPayment: ['paid', 'completed', 'cancelled', 'disputed'],
  paid: ['completed', 'refunded', 'disputed'],
  completed: ['refunded'],
  cancelled: ['refunded'],
  disputed: ['cancelled', 'refunded'],
  refunded: [],
};

const ACTIONS = {
  accept: 'accepted',
  start: 'inProgress',
  requestPayment: 'awaitingPayment',
  markPaid: 'paid',
  complete: 'completed',
  cancel: 'cancelled',
  decline: 'cancelled',
  dispute: 'disputed',
  refund: 'refunded',
};

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function normalizeStatus(status) {
  const raw = String(status || 'pending');
  const lower = raw.toLowerCase();
  return STATUS_ALIASES[raw] || STATUS_ALIASES[lower] || raw;
}

function isAllowedTransition(from, to) {
  const a = normalizeStatus(from);
  const b = normalizeStatus(to);
  return (TRANSITIONS[a] || []).includes(b);
}

function targetStatus(action) {
  return ACTIONS[action] || null;
}

function actorMayPerform(action, uid, clientId, providerId, isAdmin) {
  if (isAdmin && (action === 'refund' || action === 'cancel' || action === 'dispute')) {
    return true;
  }
  const isClient = uid === clientId;
  const isProvider = Boolean(providerId) && uid === providerId;
  switch (action) {
    case 'accept':
      return !providerId || uid === providerId;
    case 'start':
    case 'decline':
    case 'requestPayment':
      return isProvider;
    case 'markPaid':
      return false;
    case 'refund':
      return false;
    case 'complete':
    case 'dispute':
    case 'cancel':
      return isClient || isProvider;
    default:
      return false;
  }
}

function completeBlockReason(currentStatus, paymentStatus) {
  const from = normalizeStatus(currentStatus);
  if (!['inProgress', 'awaitingPayment', 'paid'].includes(from)) {
    return 'invalid_transition';
  }
  if (from !== 'paid' && paymentStatus !== 'paid') {
    return 'payment_not_confirmed';
  }
  if (!isAllowedTransition(from, 'completed')) {
    return 'invalid_transition';
  }
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
  officialProviderId,
}) {
  if (payoutProcessed) return { ok: false, reason: 'already_processed' };
  const st = normalizeStatus(status);
  if (st !== 'completed') return { ok: false, reason: 'order_not_completed' };
  const paid = paymentStatus === 'paid' || gatewayStatus === 'approved';
  if (!paid) return { ok: false, reason: 'payment_not_confirmed' };
  if (!providerId) return { ok: false, reason: 'missing_provider' };
  if (officialProviderId && officialProviderId !== providerId) {
    return { ok: false, reason: 'provider_mismatch' };
  }
  const gross = Number(price);
  if (!(gross > 0)) return { ok: false, reason: 'invalid_price' };
  if (paymentOrderId && paymentOrderId !== orderId) {
    return { ok: false, reason: 'payment_order_mismatch' };
  }
  if (paidAmount != null && Math.abs(Number(paidAmount) - gross) > 0.009) {
    return { ok: false, reason: 'amount_mismatch' };
  }
  const commission = round2(gross * COMMISSION_RATE);
  const providerAmount = round2(gross - commission);
  return {
    ok: true,
    gross,
    gatewayFee: 0,
    commission,
    platformFee: commission,
    netAmount: providerAmount,
    providerAmount,
  };
}

function rejectDoubleCharge(order) {
  if (!order) return { ok: false, reason: 'order_missing' };
  const ps = order.paymentStatus || 'unpaid';
  if (ps === 'paid') return { ok: false, reason: 'already_paid' };
  return { ok: true };
}

function buildFinancialAudit({
  orderId,
  userId,
  providerId,
  clientId,
  decision,
  gatewayTransactionId,
  payoutTransactionId,
  status,
}) {
  return {
    orderId: String(orderId),
    userId: userId || null,
    providerId: providerId || null,
    clientId: clientId || null,
    gross: decision.gross,
    gatewayFee: decision.gatewayFee || 0,
    commission: decision.commission,
    platformFee: decision.platformFee || decision.commission,
    netAmount: decision.netAmount != null
      ? decision.netAmount
      : decision.providerAmount,
    providerAmount: decision.providerAmount,
    gatewayTransactionId: gatewayTransactionId ? String(gatewayTransactionId) : null,
    payoutTransactionId: payoutTransactionId ? String(payoutTransactionId) : null,
    status: status || 'payout_done',
    payoutProcessed: true,
  };
}

module.exports = {
  COMMISSION_RATE,
  SENSITIVE_FIELDS,
  STATUS_ALIASES,
  TRANSITIONS,
  ACTIONS,
  round2,
  normalizeStatus,
  isAllowedTransition,
  targetStatus,
  actorMayPerform,
  completeBlockReason,
  canPayout,
  rejectDoubleCharge,
  buildFinancialAudit,
};
