'use strict';

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { stripSecrets } = require('./security');

const ACTIONS = Object.freeze({
  ADMIN_LOGIN: 'admin_login',
  PERMISSION_CHANGE: 'permission_change',
  PROVIDER_APPROVED: 'provider_approved',
  PAYMENT: 'payment',
  ORDER_CANCELLED: 'order_cancelled',
  ORDER_DECLINED: 'order_declined',
  REFUND: 'refund',
  PAYOUT: 'payout',
  WALLET: 'wallet_change',
  ACCOUNT_DELETED: 'lgpd_account_anonymized',
});

function sanitizeDetails(details) {
  return stripSecrets(details && typeof details === 'object' ? details : {});
}

function structuredLog(level, event, payload) {
  const safe = sanitizeDetails(payload);
  const line = { event, ...safe };
  if (level === 'error') functions.logger.error(event, line);
  else if (level === 'warn') functions.logger.warn(event, line);
  else functions.logger.info(event, line);
}

/**
 * Grava auditLogs sem secrets. Falha de escrita não derruba a callable.
 */
async function writeAudit(db, {
  actorId,
  actorType = 'system',
  action,
  target,
  details,
}) {
  const safe = sanitizeDetails(details);
  structuredLog('info', 'audit', {
    action,
    actorId: actorId || 'unknown',
    actorType,
    target: String(target || ''),
  });
  try {
    await db.collection('auditLogs').add({
      adminId: actorId || 'system',
      adminName: actorType,
      action,
      target: String(target || ''),
      details: safe,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (e) {
    structuredLog('error', 'audit_write_failed', {
      action,
      message: e && e.message,
    });
  }
}

module.exports = {
  ACTIONS,
  sanitizeDetails,
  structuredLog,
  writeAudit,
};
