'use strict';

/**
 * Adaptador de gateway (Fase 3). Interface única usada pelo backend:
 *   createPix, createCard, get, searchByExternalReference, cancel, refund
 * Pagamentos normalizados: { id, status (interno), rawStatus, statusDetail,
 *   amountCents, refundedCents, currency, externalReference, collectorId,
 *   gatewayUpdatedAt, pix?, challenge? }
 *
 * Implementações:
 *  - mercadoPago: SDK oficial `mercadopago` (sandbox/credenciais de teste).
 *  - fake: simulador persistido no Firestore, SOMENTE no emulador.
 * Erros:
 *  - GatewayRejected: recusa definitiva (4xx) — pode tentar de novo.
 *  - GatewayUncertain: timeout/rede/5xx — resultado desconhecido; é
 *    preciso reconciliar antes de outra cobrança.
 */
const crypto = require('crypto');
const fin = require('../financeCore');

class GatewayRejected extends Error {
  constructor(message, code) { super(message); this.name = 'GatewayRejected'; this.code = code || null; }
}
class GatewayUncertain extends Error {
  constructor(message) { super(message); this.name = 'GatewayUncertain'; }
}

function ms(v) {
  if (!v) return 0;
  const t = Date.parse(v);
  return Number.isFinite(t) ? t : 0;
}

function normalizeMp(p) {
  if (!p) return null;
  const refunded = Array.isArray(p.refunds)
    ? p.refunds.filter((r) => r.status === 'approved').reduce((s, r) => s + fin.toCents(r.amount || 0), 0)
    : fin.toCents(p.transaction_amount_refunded || 0) || 0;
  const tx = (p.point_of_interaction && p.point_of_interaction.transaction_data) || {};
  const status = refunded > 0 && p.status === 'approved' ? 'partially_refunded' : fin.mapGatewayStatus(p.status, p.status_detail);
  return {
    id: String(p.id),
    status,
    rawStatus: p.status || null,
    statusDetail: p.status_detail || null,
    amountCents: fin.toCents(p.transaction_amount),
    refundedCents: refunded,
    currency: p.currency_id || 'BRL',
    externalReference: p.external_reference || null,
    collectorId: p.collector_id != null ? String(p.collector_id) : null,
    gatewayUpdatedAt: ms(p.date_last_updated) || ms(p.date_created),
    pix: tx.qr_code ? {
      qrCode: tx.qr_code,
      qrCodeBase64: tx.qr_code_base64 || null,
      ticketUrl: tx.ticket_url || null,
      expiresAt: p.date_of_expiration || null,
    } : null,
    challenge: p.three_ds_info && p.three_ds_info.external_resource_url ? {
      url: p.three_ds_info.external_resource_url,
      creq: p.three_ds_info.creq || null,
    } : null,
  };
}

function mpError(e) {
  const name = (e && e.constructor && e.constructor.name) || '';
  const status = e && (e.status || e.statusCode || (e.response && e.response.status));
  const msg = fin.redact((e && (e.message || e.cause)) || 'erro do gateway');
  if (/Connection|Timeout|Server|Idempotency|RateLimit|ResourceLocked|Dependency/.test(name) ||
      (status && status >= 500) || status === 429 || status === 409 || !status) {
    return new GatewayUncertain(msg);
  }
  return new GatewayRejected(msg, status);
}

function mercadoPagoGateway({ accessToken, notificationUrl, timeoutMs = 15000 }) {
  // Carregado sob demanda: o SDK nunca recebe/registra o token fora daqui.
  const { MercadoPagoConfig, Payment, PaymentRefund } = require('mercadopago');
  const config = new MercadoPagoConfig({ accessToken, options: { timeout: timeoutMs } });
  const payment = new Payment(config);
  const refunds = new PaymentRefund(config);
  const call = async (fn) => {
    try { return await fn(); } catch (e) { throw mpError(e); }
  };
  return {
    name: 'mercadopago',
    async createPix({ attemptId, amountCents, description, payerEmail, expiresAt }) {
      const p = await call(() => payment.create({
        body: {
          transaction_amount: fin.fromCents(amountCents),
          description: String(description).slice(0, 200),
          payment_method_id: 'pix',
          payer: { email: payerEmail },
          external_reference: attemptId,
          date_of_expiration: new Date(expiresAt).toISOString().replace('Z', '-00:00'),
          ...(notificationUrl ? { notification_url: notificationUrl } : {}),
        },
        requestOptions: { idempotencyKey: attemptId },
      }));
      return normalizeMp(p);
    },
    async createCard({ attemptId, amountCents, description, token, installments, paymentMethodId, issuerId, payer }) {
      const p = await call(() => payment.create({
        body: {
          transaction_amount: fin.fromCents(amountCents),
          description: String(description).slice(0, 200),
          token,
          installments,
          ...(paymentMethodId ? { payment_method_id: paymentMethodId } : {}),
          ...(issuerId ? { issuer_id: issuerId } : {}),
          payer,
          external_reference: attemptId,
          three_d_secure_mode: 'optional',
          ...(notificationUrl ? { notification_url: notificationUrl } : {}),
        },
        requestOptions: { idempotencyKey: attemptId },
      }));
      return normalizeMp(p);
    },
    async get(id) { return normalizeMp(await call(() => payment.get({ id }))); },
    async searchByExternalReference(ref) {
      const r = await call(() => payment.search({ options: { external_reference: ref, sort: 'date_created', criteria: 'desc' } }));
      const list = (r && r.results) || [];
      return list.length ? normalizeMp(list[0]) : null;
    },
    async cancel(id) { return normalizeMp(await call(() => payment.cancel({ id }))); },
    async refund(id, amountCents, idempotencyKey) {
      const r = await call(() => refunds.create({
        payment_id: id,
        body: amountCents ? { amount: fin.fromCents(amountCents) } : {},
        requestOptions: { idempotencyKey },
      }));
      return { refundId: r && r.id != null ? String(r.id) : null, status: (r && r.status) || 'pending' };
    },
  };
}

/**
 * Simulador (emulador). Estado em `_fakeGateway/*`; cenários em
 * `_fakeGatewayControl/config`: { nextCreate: 'timeout_after_create' |
 * 'timeout_before_create' | 'reject' | null }. Token de cartão define o
 * resultado: tok_approved | tok_rejected | tok_challenge | tok_pending.
 */
function fakeGateway(db) {
  const col = db.collection('_fakeGateway');
  const keys = db.collection('_fakeGatewayKeys');
  const control = db.collection('_fakeGatewayControl').doc('config');
  async function consume() {
    return db.runTransaction(async (tx) => {
      const s = await tx.get(control);
      const next = s.exists ? s.data().nextCreate || null : null;
      if (next) tx.set(control, { nextCreate: null }, { merge: true });
      return next;
    });
  }
  async function counter(field) {
    await db.collection('_fakeGatewayStats').doc('global').set({ [field]: require('firebase-admin/firestore').FieldValue.increment(1) }, { merge: true });
  }
  async function create(attemptId, base) {
    const scenario = await consume();
    if (scenario === 'timeout_before_create') throw new GatewayUncertain('timeout (simulado) antes de criar');
    if (scenario === 'reject') throw new GatewayRejected('recusado (simulado)', 400);
    // Idempotência por chave, como o gateway real.
    const existing = await keys.doc(attemptId).get();
    let id;
    if (existing.exists) {
      id = existing.data().id;
    } else {
      id = String(Date.now()) + crypto.randomInt(1000, 9999);
      await col.doc(id).set({ ...base, id, external_reference: attemptId, date_created: new Date().toISOString(), date_last_updated: new Date().toISOString(), refunds: [] });
      await keys.doc(attemptId).set({ id });
      await counter('creates');
    }
    if (scenario === 'timeout_after_create') throw new GatewayUncertain('timeout (simulado) depois de criar');
    return normalizeMp((await col.doc(id).get()).data());
  }
  return {
    name: 'fake',
    async createPix({ attemptId, amountCents, expiresAt }) {
      return create(attemptId, {
        status: 'pending', status_detail: 'pending_waiting_transfer', transaction_amount: fin.fromCents(amountCents),
        currency_id: 'BRL', payment_method_id: 'pix', collector_id: 'fake-collector',
        date_of_expiration: new Date(expiresAt).toISOString(),
        point_of_interaction: { transaction_data: { qr_code: `00020126FAKEPIX${attemptId.slice(0, 12)}5204000053039865802BR`, qr_code_base64: null } },
      });
    },
    async createCard({ attemptId, amountCents, token }) {
      const map = {
        tok_approved: ['approved', 'accredited'], tok_rejected: ['rejected', 'cc_rejected_insufficient_amount'],
        tok_challenge: ['pending', 'pending_challenge'], tok_pending: ['in_process', 'pending_review_manual'],
      };
      const [status, detail] = map[token] || ['rejected', 'cc_rejected_bad_filled_card_number'];
      return create(attemptId, {
        status, status_detail: detail, transaction_amount: fin.fromCents(amountCents), currency_id: 'BRL',
        payment_method_id: 'visa', collector_id: 'fake-collector',
        ...(detail === 'pending_challenge' ? { three_ds_info: { external_resource_url: 'https://example.invalid/3ds', creq: 'fake-creq' } } : {}),
      });
    },
    async get(id) {
      const s = await col.doc(String(id)).get();
      if (!s.exists) throw new GatewayRejected('pagamento não encontrado', 404);
      return normalizeMp(s.data());
    },
    async searchByExternalReference(ref) {
      const k = await keys.doc(ref).get();
      if (!k.exists) return null;
      return normalizeMp((await col.doc(k.data().id).get()).data());
    },
    async cancel(id) {
      const ref = col.doc(String(id));
      const s = await ref.get();
      if (!s.exists) throw new GatewayRejected('pagamento não encontrado', 404);
      const p = s.data();
      if (!['pending', 'in_process'].includes(p.status)) throw new GatewayRejected(`não cancelável (${p.status})`, 400);
      await ref.update({ status: 'cancelled', status_detail: 'by_collector', date_last_updated: new Date(Date.now() + 1).toISOString() });
      return normalizeMp((await ref.get()).data());
    },
    async refund(id, amountCents, idempotencyKey) {
      const ref = col.doc(String(id));
      const s = await ref.get();
      if (!s.exists) throw new GatewayRejected('pagamento não encontrado', 404);
      const p = s.data();
      if (p.status !== 'approved' && p.status !== 'refunded') throw new GatewayRejected('não reembolsável', 400);
      const existing = (p.refunds || []).find((r) => r.key === idempotencyKey);
      if (existing) return { refundId: existing.id, status: existing.status };
      // Reembolso fica "in_process" até o teste confirmar (simula atraso).
      const r = { id: `rf_${Date.now()}`, key: idempotencyKey, amount: amountCents ? fin.fromCents(amountCents) : p.transaction_amount, status: 'in_process' };
      await ref.update({ refunds: [...(p.refunds || []), r] });
      await counter('refunds');
      return { refundId: r.id, status: r.status };
    },
  };
}

module.exports = { GatewayRejected, GatewayUncertain, normalizeMp, mercadoPagoGateway, fakeGateway };
