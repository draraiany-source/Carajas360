'use strict';

const crypto = require('crypto');

/**
 * Stub sandbox Mercado Pago — sem secret no repo, sem mutação de pedido/carteira.
 * Se MERCADOPAGO_WEBHOOK_SECRET existir, valida x-signature (formato MP).
 * Mesmo válido: charged=false, applied=false (PAYMENTS_ENABLED continua off).
 */

function parseMpSignature(header) {
  const out = {};
  String(header || '').split(',').forEach((part) => {
    const i = part.indexOf('=');
    if (i > 0) out[part.slice(0, i).trim()] = part.slice(i + 1).trim();
  });
  return out;
}

function verifyMpSignature({ secret, signature, requestId, dataId }) {
  if (!secret) return false;
  const parsed = parseMpSignature(signature);
  const ts = parsed.ts;
  const v1 = parsed.v1;
  if (!ts || !v1) return false;
  const manifest = `id:${dataId || ''};request-id:${requestId || ''};ts:${ts};`;
  const expected = crypto.createHmac('sha256', secret).update(manifest).digest('hex');
  const a = Buffer.from(String(v1), 'utf8');
  const b = Buffer.from(expected, 'utf8');
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

function mercadoPagoWebhookDecision(method, opts) {
  if (String(method || '').toUpperCase() !== 'POST') {
    return { status: 405, body: { ok: false, reason: 'method_not_allowed' } };
  }
  const secret = opts && opts.secret;
  if (!secret) {
    return {
      status: 501,
      body: {
        ok: false,
        reason: 'webhook_sandbox_not_configured',
        charged: false,
        applied: false,
      },
    };
  }
  const valid = verifyMpSignature({
    secret,
    signature: opts.signature,
    requestId: opts.requestId,
    dataId: opts.dataId,
  });
  if (!valid) {
    return {
      status: 401,
      body: {
        ok: false,
        reason: 'invalid_signature',
        charged: false,
        applied: false,
      },
    };
  }
  return {
    status: 202,
    body: {
      ok: true,
      reason: 'sandbox_accepted_not_applied',
      charged: false,
      applied: false,
    },
  };
}

module.exports = { mercadoPagoWebhookDecision, verifyMpSignature };
