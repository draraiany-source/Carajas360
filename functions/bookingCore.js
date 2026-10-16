'use strict';

/**
 * Reservas aguardando pagamento (Saúde e Locação) — regras puras.
 * A reserva nasce `pending_payment` e segura o horário até `holdUntilMs`.
 * Depois disso o horário volta a ficar livre (mesmo antes da tarefa de
 * expiração gravar `expired`), a menos que o pagamento já esteja aprovado.
 */
const DEFAULTS = Object.freeze({ holdMinutes: 15, maxPendingPerClient: 3 });
const LIMITS = Object.freeze({ holdMinutes: [5, 120], maxPendingPerClient: [1, 10] });

function clampInt(v, [min, max], dflt) {
  const n = Number(v);
  return Number.isInteger(n) && n >= min && n <= max ? n : dflt;
}

/** Configuração efetiva a partir de config/booking (valores fora do limite caem no padrão). */
function configOf(doc) {
  const d = doc || {};
  return {
    holdMinutes: clampInt(d.holdMinutes, LIMITS.holdMinutes, DEFAULTS.holdMinutes),
    maxPendingPerClient: clampInt(d.maxPendingPerClient, LIMITS.maxPendingPerClient, DEFAULTS.maxPendingPerClient),
  };
}

/** Validação da alteração feita pelo admin (rejeita em vez de corrigir). */
function validateConfig(input) {
  const errors = [];
  for (const k of Object.keys(LIMITS)) {
    const n = Number(input && input[k]);
    if (!Number.isInteger(n) || n < LIMITS[k][0] || n > LIMITS[k][1]) errors.push(`${k} deve ser inteiro entre ${LIMITS[k][0]} e ${LIMITS[k][1]}`);
  }
  return errors.length ? { ok: false, errors } : { ok: true, value: { holdMinutes: Number(input.holdMinutes), maxPendingPerClient: Number(input.maxPendingPerClient) } };
}

/** Retenções ainda válidas de um cliente ({id: holdUntilMs}). */
function activeHolds(map, nowMs) {
  const out = {};
  for (const [id, until] of Object.entries(map || {})) if (Number(until) > nowMs) out[id] = Number(until);
  return out;
}

/** A reserva ocupa o horário agora? */
function holdBlocks(b, nowMs) {
  if (!b || b.status !== 'pending_payment') return false;
  return b.paymentStatus === 'approved' || Number(b.holdUntilMs) > nowMs;
}

/** Pode expirar (prazo vencido e sem pagamento aprovado)? */
function shouldExpire(b, nowMs) {
  return Boolean(b) && b.status === 'pending_payment' && b.paymentStatus !== 'approved' && Number(b.holdUntilMs) <= nowMs;
}

module.exports = { DEFAULTS, LIMITS, configOf, validateConfig, activeHolds, holdBlocks, shouldExpire };
