'use strict';

const COMMISSION_RATE = 0.08;
const ESCROW_HOLD_DAYS = 3;

const SENSITIVE_FIELDS = [
  'price', 'total', 'amount', 'providerId', 'clientId', 'status',
  'paymentStatus', 'payoutStatus', 'payoutProcessed', 'payoutProcessedAt',
  'payoutTransactionId', 'commission', 'platformFee', 'providerAmount',
  'transactionId', 'gatewayTransactionId', 'walletId', 'cashbackGranted',
  'paidAt', 'payoutAt', 'refunded', 'refundAmount',
  'escrowStatus', 'heldAmount', 'releaseAt', 'releasedAt', 'clientConfirmedAt',
];

const STATUS_ALIASES = {
  created: 'pending',
  in_progress: 'inProgress',
  inprogress: 'inProgress',
  awaiting_payment: 'awaitingPayment',
  awaitingpayment: 'awaitingPayment',
};

const ESCROW_STATUS_ALIASES = {
  service_in_progress: 'serviceInProgress',
  serviceinprogress: 'serviceInProgress',
  release_pending: 'releasePending',
  releasepending: 'releasePending',
};

const TRANSITIONS = {
  pending: ['accepted', 'cancelled'],
  accepted: ['inProgress', 'cancelled'],
  inProgress: ['awaitingPayment', 'completed', 'cancelled', 'disputed'],
  awaitingPayment: ['paid', 'completed', 'cancelled', 'disputed'],
  paid: ['completed', 'refunded', 'disputed', 'cancelled'],
  completed: ['refunded', 'cancelled'],
  cancelled: ['refunded', 'pending', 'accepted'],
  disputed: ['cancelled', 'refunded'],
  refunded: [],
};

/** Escrow staging — Flutter client MUST NOT release funds. */
const ESCROW_TRANSITIONS = {
  held: ['serviceInProgress', 'disputed', 'refunded', 'cancelled'],
  serviceInProgress: ['releasePending', 'disputed', 'refunded'],
  releasePending: ['released', 'disputed', 'refunded'],
  released: [],
  disputed: ['refunded', 'cancelled'],
  refunded: [],
  cancelled: [],
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
  reopen: null,
  cancelDefinitive: 'cancelled',
  hold: null,
  releaseEscrow: null,
};

const ESCROW_ACTIONS = new Set(['hold', 'releaseEscrow']);
const ADMIN_ONLY_ACTIONS = new Set(['reopen', 'cancelDefinitive']);

function round2(n) {
  return Math.round(Number(n) * 100) / 100;
}

function normalizeStatus(status) {
  const raw = String(status || 'pending');
  const lower = raw.toLowerCase();
  return STATUS_ALIASES[raw] || STATUS_ALIASES[lower] || raw;
}

function normalizeEscrowStatus(status) {
  const raw = String(status || 'held');
  const lower = raw.toLowerCase();
  return ESCROW_STATUS_ALIASES[raw] || ESCROW_STATUS_ALIASES[lower] || raw;
}

function isAllowedTransition(from, to) {
  const a = normalizeStatus(from);
  const b = normalizeStatus(to);
  return (TRANSITIONS[a] || []).includes(b);
}

function isAllowedEscrowTransition(from, to) {
  const a = normalizeEscrowStatus(from);
  const b = normalizeEscrowStatus(to);
  return (ESCROW_TRANSITIONS[a] || []).includes(b);
}

function targetStatus(action) {
  return ACTIONS[action] || null;
}

function isKnownAction(action) {
  return Object.prototype.hasOwnProperty.call(ACTIONS, action);
}

function adminReopenAllowed(fromStatus) {
  return normalizeStatus(fromStatus) === 'cancelled';
}

function adminReopenTarget(order) {
  const providerId = order && order.providerId;
  if (providerId) return 'accepted';
  return 'pending';
}

function adminCancelDefinitiveAllowed(fromStatus, escrowStatus) {
  const st = normalizeStatus(fromStatus);
  if (st === 'cancelled' || st === 'refunded') return false;
  if (escrowStatus && normalizeEscrowStatus(escrowStatus) === 'released') {
    return false;
  }
  return true;
}

/** paid → held; releaseAt = paidAt + 3 dias (staging). */
function escrowHoldOnPaid({ amount, paidAt }) {
  const paid = paidAt instanceof Date ? paidAt : new Date(paidAt);
  const releaseAt = new Date(paid.getTime() + ESCROW_HOLD_DAYS * 86400000);
  return {
    escrowStatus: 'held',
    heldAmount: Number(amount) || 0,
    releaseAt,
  };
}

/** Backend/admin only — client SDK MUST NOT release funds. */
function canReleaseEscrow({
  status,
  paymentStatus,
  payoutProcessed,
  completedAt,
  clientConfirmed,
  now,
  paidAt,
  releaseAt,
  escrowStatus,
}) {
  const es = escrowStatus ? normalizeEscrowStatus(escrowStatus) : null;
  if (es === 'released' || payoutProcessed) {
    return { ok: false, reason: 'already_released' };
  }
  if (es === 'disputed' || normalizeStatus(status) === 'disputed') {
    return { ok: false, reason: 'disputed' };
  }
  if (paymentStatus !== 'paid') {
    return { ok: false, reason: 'not_paid' };
  }
  const st = normalizeStatus(status);
  if (st === 'refunded' || st === 'cancelled') {
    return { ok: false, reason: 'order_closed' };
  }

  if (clientConfirmed) return { ok: true };

  const clock = now instanceof Date ? now : (now ? new Date(now) : new Date());
  if (releaseAt) {
    const due = releaseAt instanceof Date ? releaseAt : new Date(releaseAt);
    if (clock >= due) return { ok: true };
  }

  const autoBase = completedAt || paidAt;
  if (autoBase) {
    const base = autoBase instanceof Date ? autoBase : new Date(autoBase);
    const due = new Date(base.getTime() + ESCROW_HOLD_DAYS * 86400000);
    if (clock >= due) return { ok: true };
  }

  return { ok: false, reason: 'release_not_due' };
}

function actorMayPerform(action, uid, clientId, providerId, isAdmin) {
  if (isAdmin && (
    action === 'refund' || action === 'cancel' || action === 'dispute'
    || action === 'reopen' || action === 'cancelDefinitive'
  )) {
    return true;
  }
  if (action === 'hold' || action === 'releaseEscrow') {
    return isAdmin;
  }
  if (action === 'reopen' || action === 'cancelDefinitive') {
    return isAdmin;
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
  commissionRate,
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
  // FASE 3: taxa do Admin (config) quando valida; senao fallback COMMISSION_RATE.
  let rate = COMMISSION_RATE;
  if (commissionRate != null && Number.isFinite(Number(commissionRate))) {
    const r = Number(commissionRate);
    if (r >= 0 && r <= 0.30) rate = r;
  }
  const commission = round2(gross * rate);
  const providerAmount = round2(gross - commission);
  return {
    ok: true,
    gross,
    gatewayFee: 0,
    commission,
    platformFee: commission,
    netAmount: providerAmount,
    providerAmount,
    commissionRate: rate,
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
  ESCROW_HOLD_DAYS,
  SENSITIVE_FIELDS,
  STATUS_ALIASES,
  ESCROW_STATUS_ALIASES,
  TRANSITIONS,
  ESCROW_TRANSITIONS,
  ACTIONS,
  ESCROW_ACTIONS,
  ADMIN_ONLY_ACTIONS,
  round2,
  normalizeStatus,
  normalizeEscrowStatus,
  isAllowedTransition,
  isAllowedEscrowTransition,
  targetStatus,
  isKnownAction,
  adminReopenAllowed,
  adminReopenTarget,
  adminCancelDefinitiveAllowed,
  escrowHoldOnPaid,
  canReleaseEscrow,
  actorMayPerform,
  completeBlockReason,
  canPayout,
  rejectDoubleCharge,
  buildFinancialAudit,
};
