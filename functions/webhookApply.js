'use strict';

/**
 * FASE 4 - aplicacao idempotente de eventos de pagamento (Sandbox/ledger).
 * Nao inventa cobranca: so aplica ledger quando paymentsEnabled=true e eventId unico.
 */

function decideWebhookApply({
  paymentsEnabled,
  eventId,
  alreadyApplied,
  kind,
  credits,
  amount,
}) {
  if (!paymentsEnabled) {
    return {
      apply: false,
      charged: false,
      applied: false,
      reason: 'payments_disabled',
    };
  }
  if (!eventId) {
    return {
      apply: false,
      charged: false,
      applied: false,
      reason: 'missing_event_id',
    };
  }
  if (alreadyApplied) {
    return {
      apply: false,
      charged: false,
      applied: true,
      already: true,
      reason: 'idempotent_skip',
    };
  }
  const k = String(kind || 'credit_purchase');
  return {
    apply: true,
    charged: false,
    applied: false,
    reason: 'apply_ledger',
    kind: k,
    credits: Math.max(0, Number(credits) || 0),
    amount: Number(amount) || 0,
    eventId: String(eventId),
  };
}

function createMemoryLedger() {
  const events = new Map();
  const ledger = [];
  return {
    events,
    ledger,
    applyOnce(eventId, entry) {
      const id = String(eventId);
      if (events.has(id)) {
        return { already: true, applied: true, ledgerWrites: 0, entry: events.get(id) };
      }
      const row = Object.assign({}, entry, { eventId: id, status: 'done' });
      events.set(id, row);
      ledger.push(row);
      return { already: false, applied: true, ledgerWrites: 1, entry: row };
    },
  };
}

function simulateDuplicateWebhook(store, eventId, entry) {
  const a = store.applyOnce(eventId, entry);
  const b = store.applyOnce(eventId, entry);
  return {
    first: a,
    second: b,
    ledgerCount: store.ledger.length,
    ok: store.ledger.length === 1 && a.ledgerWrites === 1 && b.already === true,
  };
}

module.exports = {
  decideWebhookApply,
  createMemoryLedger,
  simulateDuplicateWebhook,
};