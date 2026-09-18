'use strict';

const policy = require('./orderPolicy');

const USER_PROTECTED_KEYS = [
  'type', 'role', 'roles', 'adminRole', 'verified', 'active', 'plan',
  'walletId', 'financialStatus', 'permissions', 'createdAt', 'xp', 'status',
  'moderationStatus',
];

const PROVIDER_PROTECTED_KEYS = [
  'verified', 'approved', 'plan', 'status', 'rating', 'totalReviews', 'userId',
];

const COMPANY_PROTECTED_KEYS = [
  'verified', 'approved', 'plan', 'ownerId', 'active',
];

const PII_KEYS = ['cpf', 'phone', 'address', 'fcmToken'];

const ALLOWED_PROFILE_TYPES = ['client', 'provider', 'deliverer', 'company'];

function assertCallableAuth(context, { enforceAppCheck } = {}) {
  if (enforceAppCheck && !(context && context.app)) {
    return { ok: false, code: 'failed-precondition', message: 'App Check obrigatório' };
  }
  if (!context || !context.auth || !context.auth.uid) {
    return { ok: false, code: 'unauthenticated', message: 'Login obrigatório' };
  }
  return { ok: true, uid: context.auth.uid, token: context.auth.token || {} };
}

function tokenIsAdmin(token) {
  const t = token || {};
  return t.admin === true || t.role === 'admin';
}

function userDocIsAdmin(userData) {
  return Boolean(userData && userData.type === 'admin');
}

function canAccessAdmin(token, userData) {
  return tokenIsAdmin(token) || userDocIsAdmin(userData);
}

function canReadUserDoc(readerUid, targetUid, { isAdmin, sharesChat } = {}) {
  if (isAdmin) return true;
  if (readerUid && readerUid === targetUid) return true;
  if (sharesChat) return true;
  return false;
}

function canListUsers(isAdmin) {
  return Boolean(isAdmin);
}

function clientUserUpdateBlocked(affectedKeys) {
  return affectedKeys.some((k) => USER_PROTECTED_KEYS.includes(k));
}

function providerSelfUpdateBlocked(affectedKeys, { currentlyVerified } = {}) {
  if (affectedKeys.some((k) => PROVIDER_PROTECTED_KEYS.includes(k))) return true;
  if (affectedKeys.includes('active') && !currentlyVerified) return true;
  return false;
}

function companySelfUpdateBlocked(affectedKeys) {
  return affectedKeys.some((k) => COMPANY_PROTECTED_KEYS.includes(k));
}

function privilegedUserCreate(data) {
  if (!data) return true;
  if (!ALLOWED_PROFILE_TYPES.includes(data.type)) return true;
  if (data.adminRole) return true;
  if (data.verified === true) return true;
  if (data.plan && data.plan !== 'free') return true;
  if (data.moderationStatus && data.moderationStatus !== 'none') return true;
  return false;
}

function orderCreateBlocked(data, uid) {
  if (!data || data.clientId !== uid) return 'client_mismatch';
  const status = policy.normalizeStatus(data.status);
  if (status !== 'pending') return 'invalid_status';
  if (data.payoutProcessed === true) return 'payout_flag';
  const pay = data.paymentStatus || 'unpaid';
  if (!['unpaid', 'pending'].includes(pay)) return 'invalid_payment_status';
  const forbidden = [
    'commission', 'platformFee', 'providerAmount', 'payoutStatus',
    'transactionId', 'gatewayTransactionId', 'cashbackGranted',
    'payoutProcessedAt', 'payoutTransactionId', 'walletId',
  ];
  if (forbidden.some((k) => Object.prototype.hasOwnProperty.call(data, k))) {
    return 'forbidden_field';
  }
  return null;
}

function orderClientUpdateAllowed(affectedKeys, order) {
  if (!affectedKeys || affectedKeys.length !== 1 || affectedKeys[0] !== 'reviewed') {
    return false;
  }
  return order && policy.normalizeStatus(order.status) === 'completed';
}

function paymentReadableBy(uid, payment, isAdmin) {
  if (isAdmin) return true;
  return Boolean(payment && payment.userId === uid);
}

function reviewCreateBlocked({ reviewId, uid, review, order }) {
  if (!order) return 'order_missing';
  if (!review) return 'review_missing';
  if (order.clientId !== uid) return 'not_order_client';
  if (policy.normalizeStatus(order.status) !== 'completed') return 'order_not_completed';
  if (review.clientId !== uid) return 'client_mismatch';
  const orderId = review.orderId || order.id;
  if (!orderId) return 'order_missing';
  if (reviewId !== `${orderId}_${uid}`) return 'id_mismatch';
  if (order.providerId && review.providerId !== order.providerId) {
    return 'provider_mismatch';
  }
  const stars = Number(review.stars);
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) return 'invalid_stars';
  return null;
}

function clientMayCreateNotification() {
  return false;
}

function canNotifyViaBackend() {
  return true;
}

function publicPaymentView(pay, id) {
  return {
    id: String(id),
    status: pay && pay.status ? pay.status : null,
    method: pay && pay.method ? pay.method : null,
    purpose: pay && pay.purpose ? pay.purpose : null,
    orderId: pay && pay.orderId ? pay.orderId : null,
    pending: Boolean(pay && (pay.status === 'pending' || pay.status === 'in_process')),
  };
}

function stripSecrets(obj) {
  if (!obj || typeof obj !== 'object') return obj;
  const blocked = [
    'access_token', 'accessToken', 'api_key', 'apiKey', 'secret',
    'password', 'token', 'authorization', 'x-api-key', 'private_key',
    'client_secret', 'refresh_token',
  ];
  const out = Array.isArray(obj) ? [] : {};
  Object.keys(obj).forEach((k) => {
    if (blocked.includes(k) || /secret|token|password|credential|apikey/i.test(k)) {
      return;
    }
    const v = obj[k];
    out[k] = v && typeof v === 'object' ? stripSecrets(v) : v;
  });
  return out;
}

function safeGatewayMessage() {
  return 'Falha no processamento. Tente novamente.';
}

function piiFromUser(data) {
  const out = {};
  PII_KEYS.forEach((k) => {
    if (data && data[k] != null && data[k] !== '') out[k] = data[k];
  });
  return out;
}

function walletOpAllowed(op) {
  return op === 'withdraw' || op === 'cashback';
}

function corsOriginAllowed(origin, allowlist) {
  if (!origin) return false;
  if (!allowlist || allowlist.length === 0) return false;
  return allowlist.includes(origin);
}

module.exports = {
  USER_PROTECTED_KEYS,
  PROVIDER_PROTECTED_KEYS,
  COMPANY_PROTECTED_KEYS,
  PII_KEYS,
  ALLOWED_PROFILE_TYPES,
  assertCallableAuth,
  tokenIsAdmin,
  userDocIsAdmin,
  canAccessAdmin,
  canReadUserDoc,
  canListUsers,
  clientUserUpdateBlocked,
  providerSelfUpdateBlocked,
  companySelfUpdateBlocked,
  privilegedUserCreate,
  orderCreateBlocked,
  orderClientUpdateAllowed,
  paymentReadableBy,
  reviewCreateBlocked,
  clientMayCreateNotification,
  canNotifyViaBackend,
  publicPaymentView,
  stripSecrets,
  safeGatewayMessage,
  piiFromUser,
  walletOpAllowed,
  corsOriginAllowed,
};
