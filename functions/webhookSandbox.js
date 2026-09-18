'use strict';

/**
 * Stub sandbox Mercado Pago — sem secret, sem mutação.
 * Implementação real (assinatura + TEST-) fica no BLOCO E.
 */
function mercadoPagoWebhookDecision(method) {
  if (String(method || '').toUpperCase() !== 'POST') {
    return { status: 405, body: { ok: false, reason: 'method_not_allowed' } };
  }
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

module.exports = { mercadoPagoWebhookDecision };
