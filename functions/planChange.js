'use strict';

const ALLOWED_PLANS = ['free', 'professional', 'premium', 'corporate'];

function normalizePlan(value) {
  return String(value || 'free').trim().toLowerCase();
}

function isAllowedPlan(plan) {
  return ALLOWED_PLANS.includes(normalizePlan(plan));
}

/**
 * Pedido de troca de plano. Nunca cobra e nunca aplica o plano.
 * paymentsEnabled só muda o rótulo do status (pending_review vs sandbox).
 */
function buildPlanChangeDecision({ requestedPlan, currentPlan, paymentsEnabled }) {
  const requested = normalizePlan(requestedPlan);
  const current = normalizePlan(currentPlan);
  if (!isAllowedPlan(requested)) {
    return { ok: false, code: 'invalid-argument', message: 'Plano inválido' };
  }
  if (requested === current) {
    return {
      ok: false,
      code: 'already-exists',
      message: 'Você já está neste plano',
    };
  }
  return {
    ok: true,
    charged: false,
    applied: false,
    requestedPlan: requested,
    currentPlan: current,
    status: paymentsEnabled ? 'pending_review' : 'pending_sandbox',
    message: paymentsEnabled
      ? 'Pedido registrado. Nenhuma cobrança automática foi feita; um admin precisa revisar.'
      : 'Pedido de plano registrado em sandbox. Nenhuma cobrança foi feita e o plano atual não mudou.',
  };
}

module.exports = {
  ALLOWED_PLANS,
  normalizePlan,
  isAllowedPlan,
  buildPlanChangeDecision,
};
