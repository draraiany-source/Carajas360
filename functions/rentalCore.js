'use strict';

/**
 * Locação (Fase 5): preço por período, fim do período, sobreposição e
 * transições autorizadas. Regras puras (sem Firebase).
 */
const { localDateOf, TZ_OFFSET_MIN } = require('./healthCore');

const MIN = 60000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

/** Período → campo de preço do anúncio e limites de quantidade. */
const PERIODS = {
  hour: { field: 'pricePerHour', max: 72, label: 'hora' },
  day: { field: 'pricePerDay', max: 90, label: 'diária' },
  week: { field: 'pricePerWeek', max: 12, label: 'semana' },
  month: { field: 'pricePerMonth', max: 12, label: 'mês' },
};
// Rótulos antigos gravados pelo app (compatibilidade).
const LEGACY = { hora: 'hour', 'diária': 'day', diaria: 'day', semana: 'week', 'mês': 'month', mes: 'month' };

const BLOCKING = ['pending', 'confirmed', 'active'];
const CLIENT_CANCEL_MIN_HOURS = 24;

function normalizePeriod(p) {
  const k = LEGACY[p] || p;
  return PERIODS[k] ? k : null;
}

function unitPriceCents(rental, period) {
  const v = rental && rental[PERIODS[period].field];
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? Math.round(n * 100) : null;
}

/** Fim do período (mês = mês de calendário, no fuso local). */
function endOf(startMs, period, qty) {
  if (period === 'hour') return startMs + qty * HOUR;
  if (period === 'day') return startMs + qty * DAY;
  if (period === 'week') return startMs + qty * 7 * DAY;
  const local = new Date(startMs + TZ_OFFSET_MIN * MIN);
  const target = new Date(Date.UTC(local.getUTCFullYear(), local.getUTCMonth() + qty, local.getUTCDate(),
    local.getUTCHours(), local.getUTCMinutes()));
  // 31/01 + 1 mês → 28/29/02 (não transborda para março).
  if (target.getUTCDate() !== local.getUTCDate()) target.setUTCDate(0);
  return target.getTime() - TZ_OFFSET_MIN * MIN;
}

/** Cotação no servidor. Retorna { ok, errors, value }. */
function quote(rental, { period, quantity, startMs }, nowMs) {
  const errors = [];
  const p = normalizePeriod(period);
  if (!rental || rental.active === false) errors.push('anúncio indisponível');
  else if (rental.available === false) errors.push('anúncio pausado pelo anunciante');
  if (!p) errors.push('período inválido');
  const qty = Number(quantity);
  if (p && (!Number.isInteger(qty) || qty < 1 || qty > PERIODS[p].max)) errors.push(`quantidade entre 1 e ${p ? PERIODS[p].max : '?'}`);
  const start = Number(startMs);
  if (!Number.isFinite(start) || start < nowMs + HOUR || start > nowMs + 365 * DAY) {
    errors.push('início deve ser de 1 hora a 365 dias a partir de agora');
  }
  const unit = p && rental ? unitPriceCents(rental, p) : null;
  if (p && rental && unit == null) errors.push('este período não tem preço definido no anúncio');
  if (errors.length) return { ok: false, errors, value: null };
  return {
    ok: true,
    errors,
    value: { period: p, quantity: qty, startMs: start, endMs: endOf(start, p, qty), unitCents: unit, totalCents: unit * qty },
  };
}

function overlaps(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

/** Reservas que bloqueiam o calendário (pendente com início vencido não bloqueia). */
function blocking(b, nowMs) {
  if (!BLOCKING.includes(b.status)) return false;
  if (b.status === 'pending' && Number(b.startMs) <= nowMs) return false;
  return true;
}

/**
 * Transições autorizadas:
 *  pending  → confirmed (anunciante) | cancelled (anunciante recusa ou cliente desiste)
 *  confirmed→ active (anunciante, a partir do início) | cancelled (anunciante com motivo;
 *             cliente até 24 h antes do início)
 *  active   → completed (anunciante)
 */
const FLOW = {
  confirm: { from: ['pending'], to: 'confirmed' },
  reject: { from: ['pending'], to: 'cancelled' },
  cancel: { from: ['pending', 'confirmed'], to: 'cancelled' },
  start: { from: ['confirmed'], to: 'active' },
  complete: { from: ['active'], to: 'completed' },
};

function transitionAllowed(action, b, uid, nowMs, reason) {
  const f = FLOW[action];
  if (!f) return { ok: false, reason: 'invalid_action' };
  const isOwner = uid === b.ownerId;
  const isClient = uid === b.clientId;
  if (!isOwner && !isClient) return { ok: false, reason: 'not_participant' };
  if (!f.from.includes(b.status)) return { ok: false, reason: 'invalid_transition' };
  const start = Number(b.startMs);
  switch (action) {
    case 'confirm':
      // Auditoria: pendente cujo início passou deixa de bloquear a agenda;
      // confirmar depois disso permitia duas reservas sobrepostas.
      if (!isOwner) return { ok: false, reason: 'owner_only' };
      return nowMs < start ? { ok: true, to: f.to } : { ok: false, reason: 'start_passed' };
    case 'reject':
    case 'complete':
      return isOwner ? { ok: true, to: f.to } : { ok: false, reason: 'owner_only' };
    case 'start':
      if (!isOwner) return { ok: false, reason: 'owner_only' };
      return nowMs >= start - HOUR ? { ok: true, to: f.to } : { ok: false, reason: 'not_started' };
    case 'cancel':
      if (isOwner) {
        if (b.status === 'confirmed' && !String(reason || '').trim()) return { ok: false, reason: 'reason_required' };
        return { ok: true, to: f.to };
      }
      if (b.status === 'pending') return { ok: true, to: f.to };
      return start - nowMs >= CLIENT_CANCEL_MIN_HOURS * HOUR ? { ok: true, to: f.to } : { ok: false, reason: 'too_late' };
    default:
      return { ok: false, reason: 'invalid_action' };
  }
}

module.exports = {
  PERIODS, BLOCKING, CLIENT_CANCEL_MIN_HOURS, FLOW,
  normalizePeriod, unitPriceCents, endOf, quote, overlaps, blocking, transitionAllowed, localDateOf,
};
