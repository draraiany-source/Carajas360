'use strict';

/**
 * Saúde (Fase 5): agenda do profissional, horários reais, conflito,
 * cancelamento e reagendamento. Regras puras (sem Firebase).
 *
 * Horários em fuso fixo America/Belem (UTC−3, sem horário de verão).
 * Disponibilidade semanal: { weekly: { '1': [{start:'08:00', end:'12:00'}] },
 * slotMinutes, blockedDates: ['AAAA-MM-DD'], services: [{ catalogId,
 * durationMin, priceCents, modalities }], minLeadHours }.
 */
const TZ = 'America/Belem';
const TZ_OFFSET_MIN = -180;
const MODALITIES = ['online', 'presential', 'home_care'];
const DEFAULTS = { slotMinutes: 30, minLeadHours: 2, maxDaysAhead: 90 };
const CANCEL_MIN_HOURS = 2; // cliente cancela/reagenda até 2 h antes
const MAX_RESCHEDULES = 2;
const ACTIVE = ['scheduled'];

const MIN = 60000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

function hm(s) {
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(String(s || ''));
  return m ? Number(m[1]) * 60 + Number(m[2]) : null;
}

/** Data local + minutos do dia → instante UTC (ms). */
function localToUtc(dateStr, minutes) {
  const [y, m, d] = String(dateStr).split('-').map(Number);
  return Date.UTC(y, m - 1, d, 0, minutes) - TZ_OFFSET_MIN * MIN;
}

function localDateOf(ms) {
  return new Date(ms + TZ_OFFSET_MIN * MIN).toISOString().slice(0, 10);
}

function localHmOf(ms) {
  return new Date(ms + TZ_OFFSET_MIN * MIN).toISOString().slice(11, 16);
}

function weekdayOf(dateStr) {
  const [y, m, d] = String(dateStr).split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

/** Valida e normaliza a agenda gravada pelo profissional. */
function validateSchedule(s) {
  const errors = [];
  const out = {
    slotMinutes: [15, 20, 30, 45, 60].includes(s && s.slotMinutes) ? s.slotMinutes : DEFAULTS.slotMinutes,
    minLeadHours: Number.isInteger(s && s.minLeadHours) && s.minLeadHours >= 0 && s.minLeadHours <= 72
      ? s.minLeadHours : DEFAULTS.minLeadHours,
    weekly: {},
    blockedDates: [],
    services: [],
  };
  const weekly = (s && s.weekly) || {};
  for (const [k, ranges] of Object.entries(weekly)) {
    if (!/^[0-6]$/.test(k) || !Array.isArray(ranges)) { errors.push(`dia ${k} inválido`); continue; }
    const clean = [];
    for (const r of ranges) {
      const a = hm(r && r.start);
      const b = hm(r && r.end);
      if (a == null || b == null || b <= a) { errors.push(`faixa inválida no dia ${k}`); continue; }
      clean.push({ start: a, end: b });
    }
    clean.sort((x, y) => x.start - y.start);
    for (let i = 1; i < clean.length; i += 1) {
      if (clean[i].start < clean[i - 1].end) errors.push(`faixas sobrepostas no dia ${k}`);
    }
    out.weekly[k] = clean;
  }
  out.blockedDates = (Array.isArray(s && s.blockedDates) ? s.blockedDates : [])
    .filter((d) => /^\d{4}-\d{2}-\d{2}$/.test(d)).slice(0, 366);
  for (const sv of Array.isArray(s && s.services) ? s.services : []) {
    const dur = Number(sv && sv.durationMin);
    const price = Number(sv && sv.priceCents);
    const mods = Array.isArray(sv && sv.modalities) ? sv.modalities.filter((m) => MODALITIES.includes(m)) : [];
    if (!sv || !sv.catalogId || !Number.isInteger(dur) || dur < 10 || dur > 240 ||
        !Number.isInteger(price) || price < 0 || price > 10000000 || !mods.length) {
      errors.push(`serviço ${(sv && sv.catalogId) || '?'} inválido`);
      continue;
    }
    out.services.push({ catalogId: String(sv.catalogId), durationMin: dur, priceCents: price, modalities: mods });
  }
  return { ok: errors.length === 0, errors, value: out };
}

function overlaps(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

/**
 * Horários livres num dia para um serviço: dentro das faixas semanais,
 * fora de datas bloqueadas, respeitando antecedência mínima e sem
 * sobrepor consultas existentes (busy: [{startMs, endMs}]).
 */
function freeSlots(schedule, dateStr, durationMin, busy, nowMs) {
  const s = schedule;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(dateStr))) return [];
  if (s.blockedDates.includes(dateStr)) return [];
  const today = localDateOf(nowMs);
  if (dateStr < today || dateStr > localDateOf(nowMs + DEFAULTS.maxDaysAhead * DAY)) return [];
  const ranges = s.weekly[String(weekdayOf(dateStr))] || [];
  const out = [];
  const minStart = nowMs + s.minLeadHours * HOUR;
  for (const r of ranges) {
    for (let m = r.start; m + durationMin <= r.end; m += s.slotMinutes) {
      const startMs = localToUtc(dateStr, m);
      const endMs = startMs + durationMin * MIN;
      if (startMs < minStart) continue;
      if ((busy || []).some((b) => overlaps(startMs, endMs, b.startMs, b.endMs))) continue;
      out.push({ startMs, endMs, label: localHmOf(startMs) });
    }
  }
  return out;
}

/** O início pedido é um horário válido da agenda (e livre)? */
function slotAllowed(schedule, startMs, durationMin, busy, nowMs) {
  const d = localDateOf(startMs);
  return freeSlots(schedule, d, durationMin, busy, nowMs).some((x) => x.startMs === startMs);
}

/**
 * Quem pode cancelar/reagendar e quando.
 * Cliente: até CANCEL_MIN_HOURS antes; reagendar no máximo MAX_RESCHEDULES.
 * Profissional: pode cancelar sempre (com motivo); reagenda pelo mesmo limite.
 * Concluir/faltou: só o profissional, depois do início.
 */
function actionAllowed(action, appt, uid, nowMs) {
  const isClient = uid === appt.clientId;
  const isPro = uid === appt.providerId;
  if (!isClient && !isPro) return { ok: false, reason: 'not_participant' };
  if (!ACTIVE.includes(appt.status)) return { ok: false, reason: 'not_active' };
  const startMs = Number(appt.startMs);
  const lead = startMs - nowMs;
  switch (action) {
    case 'cancel':
      if (isPro) return { ok: true, reason: null };
      return lead >= CANCEL_MIN_HOURS * HOUR ? { ok: true, reason: null } : { ok: false, reason: 'too_late' };
    case 'reschedule':
      if (lead < CANCEL_MIN_HOURS * HOUR) return { ok: false, reason: 'too_late' };
      if (Number(appt.rescheduleCount || 0) >= MAX_RESCHEDULES) return { ok: false, reason: 'limit_reached' };
      return { ok: true, reason: null };
    case 'complete':
    case 'no_show':
      if (!isPro) return { ok: false, reason: 'provider_only' };
      return nowMs >= startMs ? { ok: true, reason: null } : { ok: false, reason: 'not_started' };
    default:
      return { ok: false, reason: 'invalid_action' };
  }
}

module.exports = {
  TZ, TZ_OFFSET_MIN, MODALITIES, DEFAULTS, CANCEL_MIN_HOURS, MAX_RESCHEDULES, ACTIVE,
  hm, localToUtc, localDateOf, localHmOf, weekdayOf, validateSchedule, overlaps,
  freeSlots, slotAllowed, actionAllowed,
};
