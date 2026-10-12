'use strict';

/**
 * Regras puras do Resolve Carajás (Fase 4): matching, disponibilidade,
 * questionários condicionais e validação da solicitação. Sem Firebase,
 * para teste unitário.
 */
const catalog = require('./catalogCore');
const sec = require('./security');

const MODALITIES = ['presential', 'online', 'home_care'];
const PERIODS = ['morning', 'afternoon', 'evening'];
const DEFAULT_RADIUS_KM = 30;
const MAX_RADIUS_KM = 200;
// Pará (Carajás) não tem horário de verão: UTC−3 fixo.
const TZ = 'America/Belem';
const TZ_OFFSET_MIN = -180;
const ATTACHMENT_TYPES = /^(image\/(jpeg|png|webp|heic)|application\/pdf)$/;
const ATTACHMENT_MAX_BYTES = 10 * 1024 * 1024;
const MAX_ATTACHMENTS = 10;

// ── Geografia ──────────────────────────────────────────────────────
function validGeo(g) {
  return g && Number.isFinite(g.lat) && Number.isFinite(g.lng) &&
    g.lat >= -90 && g.lat <= 90 && g.lng >= -180 && g.lng <= 180;
}

/** Arredonda para 2 casas (~1,1 km): localização aproximada, por privacidade. */
function coarseGeo(g) {
  if (!validGeo(g)) return null;
  return { lat: Math.round(g.lat * 100) / 100, lng: Math.round(g.lng * 100) / 100 };
}

function haversineKm(a, b) {
  const R = 6371;
  const rad = (d) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

function providerRadiusKm(p) {
  const r = Number(p && p.radiusKm);
  return Number.isFinite(r) && r > 0 ? Math.min(r, MAX_RADIUS_KM) : DEFAULT_RADIUS_KM;
}

// ── Catálogo ───────────────────────────────────────────────────────
/**
 * Chaves de solicitações que um prestador pode atender: o caminho de
 * cada especialidade declarada (serviço → grupo → categoria). Mesma regra
 * da busca (Fase 2): declarar um serviço atende pedidos do serviço, do
 * grupo e da categoria; declarar o grupo NÃO cobre um serviço específico
 * não declarado.
 */
function matchKeys(declared, nodes) {
  const out = new Set();
  for (const id of Array.isArray(declared) ? declared : []) {
    const path = catalog.pathOf(id, nodes || {});
    if (path.length === 0) out.add(id);
    path.forEach((n) => out.add(n.id || id));
  }
  return [...out];
}

function serviceCompatible(declared, category, nodes) {
  if (!category) return false;
  return matchKeys(declared, nodes).includes(category);
}

// ── Disponibilidade ────────────────────────────────────────────────
/** Dia da semana (0=domingo) de uma data AAAA-MM-DD no fuso local. */
function weekdayOf(dateStr) {
  const [y, m, d] = String(dateStr).split('-').map(Number);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

function localToday(nowMs) {
  const d = new Date(nowMs + TZ_OFFSET_MIN * 60000);
  return d.toISOString().slice(0, 10);
}

function validAvailability(a) {
  if (a == null) return true;
  if (typeof a !== 'object') return false;
  const wd = a.weekdays;
  const pe = a.periods;
  if (wd != null && (!Array.isArray(wd) || wd.some((x) => !Number.isInteger(x) || x < 0 || x > 6))) return false;
  if (pe != null && (!Array.isArray(pe) || pe.some((x) => !PERIODS.includes(x)))) return false;
  return true;
}

/**
 * O prestador atende na data/período pedidos? Sem disponibilidade
 * declarada (perfis antigos) = sem restrição. Pausa e férias bloqueiam.
 */
function availabilityOk(provider, request, nowMs) {
  if (provider.acceptingRequests === false) return { ok: false, reason: 'paused' };
  const until = provider.unavailableUntil;
  if (until && String(until) >= localToday(nowMs)) {
    if (!request.preferredDate || String(request.preferredDate) <= String(until)) {
      return { ok: false, reason: 'unavailable_period' };
    }
  }
  const a = provider.availability;
  if (!a || !request.preferredDate) return { ok: true, reason: null };
  if (Array.isArray(a.weekdays) && a.weekdays.length &&
      !a.weekdays.includes(weekdayOf(request.preferredDate))) {
    return { ok: false, reason: 'weekday_unavailable' };
  }
  const per = request.preferredPeriod;
  if (per && per !== 'any' && Array.isArray(a.periods) && a.periods.length && !a.periods.includes(per)) {
    return { ok: false, reason: 'period_unavailable' };
  }
  return { ok: true, reason: null };
}

// ── Matching completo ──────────────────────────────────────────────
/**
 * Prestador compatível com a solicitação? Retorna { ok, reason, distanceKm }.
 * ctx: { uid, nodes, userActive, nowMs, skipAvailability }
 */
function providerMatch(provider, request, ctx = {}) {
  if (!provider) return { ok: false, reason: 'not_provider' };
  const uid = ctx.uid;
  if (uid && provider.userId && provider.userId !== uid) return { ok: false, reason: 'not_owner' };
  if (provider.verified !== true) return { ok: false, reason: 'not_verified' };
  if (provider.active !== true) return { ok: false, reason: 'inactive' };
  if (ctx.userActive === false) return { ok: false, reason: 'account_blocked' };
  if (uid && request.clientId === uid) return { ok: false, reason: 'own_request' };
  if (!serviceCompatible(provider.categories, request.category, ctx.nodes)) {
    return { ok: false, reason: 'service_mismatch' };
  }
  const modality = request.modality || 'presential';
  const mods = Array.isArray(provider.modalities) && provider.modalities.length
    ? provider.modalities : ['presential'];
  if (!mods.includes(modality)) return { ok: false, reason: 'modality_mismatch' };

  let distanceKm = null;
  if (modality !== 'online') {
    // Raio quando os dois lados têm localização; senão, cidade/áreas.
    if (validGeo(provider.geo) && validGeo(request.geo)) {
      distanceKm = Math.round(haversineKm(provider.geo, request.geo) * 10) / 10;
      if (distanceKm > providerRadiusKm(provider)) return { ok: false, reason: 'out_of_radius', distanceKm };
    } else if (!sec.providerServesCity(provider, request.city)) {
      return { ok: false, reason: 'region_mismatch' };
    }
  }
  if (!ctx.skipAvailability) {
    const av = availabilityOk(provider, request, ctx.nowMs || Date.now());
    if (!av.ok) return { ok: false, reason: av.reason, distanceKm };
  }
  return { ok: true, reason: null, distanceKm };
}

// ── Questionário ───────────────────────────────────────────────────
function answered(v) {
  if (v === undefined || v === null) return false;
  if (typeof v === 'string') return v.trim().length > 0;
  if (Array.isArray(v)) return v.length > 0;
  return true;
}

function conditionHolds(cond, answers) {
  if (!cond) return true;
  const v = answers[cond.questionId];
  switch (cond.op) {
    case 'answered': return answered(v);
    case 'equals': return Array.isArray(v) ? v.includes(cond.value) : v === cond.value;
    case 'not_equals': return Array.isArray(v) ? !v.includes(cond.value) : answered(v) && v !== cond.value;
    case 'in': {
      const vals = Array.isArray(cond.value) ? cond.value : [cond.value];
      return Array.isArray(v) ? v.some((x) => vals.includes(x)) : vals.includes(v);
    }
    default: return false;
  }
}

/** Perguntas visíveis, na ordem (condição só olha perguntas anteriores visíveis). */
function visibleQuestions(questions, answers) {
  const vis = [];
  const visibleAnswers = {};
  for (const q of questions || []) {
    if (q.showIf && !(q.showIf.questionId in visibleAnswers)) continue;
    if (!conditionHolds(q.showIf, visibleAnswers)) continue;
    vis.push(q);
    visibleAnswers[q.id] = answers[q.id];
  }
  return vis;
}

/**
 * Valida respostas contra o questionário publicado. Respostas de
 * perguntas ocultas são descartadas. Anexos devem ser caminhos do
 * próprio usuário (`attachmentPrefix`). Retorna { ok, errors, answers, attachments }.
 */
function validateAnswers(questionnaire, rawAnswers, { attachmentPrefix } = {}) {
  const errors = [];
  const answers = rawAnswers && typeof rawAnswers === 'object' ? rawAnswers : {};
  const out = {};
  const attachments = [];
  if (!questionnaire) return { ok: true, errors, answers: out, attachments };
  for (const q of visibleQuestions(questionnaire.questions, answers)) {
    const v = answers[q.id];
    if (!answered(v)) {
      if (q.required) errors.push(`"${q.label}" é obrigatória`);
      continue;
    }
    switch (q.type) {
      case 'text':
      case 'long_text': {
        const max = q.type === 'text' ? 200 : 2000;
        if (typeof v !== 'string' || v.length > max) errors.push(`"${q.label}": texto inválido`);
        else out[q.id] = v.trim();
        break;
      }
      case 'number':
        if (typeof v !== 'number' || !Number.isFinite(v) || Math.abs(v) > 1e9) errors.push(`"${q.label}": número inválido`);
        else out[q.id] = v;
        break;
      case 'boolean':
        if (typeof v !== 'boolean') errors.push(`"${q.label}": sim/não inválido`);
        else out[q.id] = v;
        break;
      case 'date':
        if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) errors.push(`"${q.label}": data inválida`);
        else out[q.id] = v;
        break;
      case 'single_choice':
        if (!q.options.includes(v)) errors.push(`"${q.label}": opção inválida`);
        else out[q.id] = v;
        break;
      case 'multi_choice':
        if (!Array.isArray(v) || v.some((x) => !q.options.includes(x))) errors.push(`"${q.label}": opções inválidas`);
        else out[q.id] = [...new Set(v)];
        break;
      case 'attachment': {
        const list = Array.isArray(v) ? v : [v];
        const ok = list.every((p) => typeof p === 'string' && attachmentPrefix &&
          p.startsWith(attachmentPrefix) && !p.includes('..') && p.length <= 300);
        if (!ok) errors.push(`"${q.label}": anexo inválido`);
        else { out[q.id] = list.length; list.forEach((p) => attachments.push({ questionId: q.id, path: p })); }
        break;
      }
      default:
        errors.push(`"${q.label}": tipo não suportado`);
    }
  }
  if (attachments.length > MAX_ATTACHMENTS) errors.push(`máximo de ${MAX_ATTACHMENTS} anexos`);
  return { ok: errors.length === 0, errors, answers: out, attachments };
}

/** Questionário aplicável: o do item mais específico do caminho que tiver um publicado. */
function questionnaireNodeFor(category, nodes) {
  const path = catalog.pathOf(category, nodes || {});
  for (let i = path.length - 1; i >= 0; i -= 1) {
    if (path[i].questionnaireId) return path[i];
  }
  return null;
}

// ── Solicitação ────────────────────────────────────────────────────
function validateRequestInput(d, nowMs) {
  const errors = [];
  const s = (k, max) => String((d && d[k]) || '').trim().slice(0, max);
  const description = String((d && d.description) || '').trim();
  if (description.length < 10 || description.length > 2000) errors.push('descrição entre 10 e 2000 caracteres');
  const category = s('category', 80);
  if (!category) errors.push('serviço obrigatório');
  const city = s('city', 80);
  const modality = (d && d.modality) || 'presential';
  if (!MODALITIES.includes(modality)) errors.push('modalidade inválida');
  if (modality !== 'online' && !city) errors.push('cidade obrigatória');
  let preferredDate = null;
  if (d && d.preferredDate) {
    preferredDate = String(d.preferredDate);
    const today = localToday(nowMs);
    const max = localToday(nowMs + 180 * 86400000);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(preferredDate) || preferredDate < today || preferredDate > max) {
      errors.push('data preferida inválida (de hoje a 180 dias)');
    }
  }
  const preferredPeriod = (d && d.preferredPeriod) || 'any';
  if (![...PERIODS, 'any'].includes(preferredPeriod)) errors.push('período inválido');
  const geo = d && d.geo ? coarseGeo(d.geo) : null;
  if (d && d.geo && !geo) errors.push('localização inválida');
  return {
    ok: errors.length === 0,
    errors,
    value: {
      description, category, city, modality, preferredDate, preferredPeriod, geo,
      neighborhood: s('neighborhood', 80) || null,
      address: s('address', 200) || null,
      reference: s('reference', 160) || null,
      phone: s('phone', 30) || null,
    },
  };
}

/** Visão de oportunidade (sem endereço, contato ou anexos). */
function opportunityView(id, r, distanceKm) {
  return {
    ...sec.opportunityView(id, r),
    preferredDate: r.preferredDate || null,
    preferredPeriod: r.preferredPeriod || 'any',
    answers: r.publicAnswers || [],
    attachmentCount: Number(r.attachmentCount || 0),
    distanceKm: distanceKm == null ? null : distanceKm,
  };
}

/** Respostas legíveis (rótulo/valor), para o prestador orçar. */
function publicAnswers(questionnaire, answers) {
  if (!questionnaire) return [];
  return questionnaire.questions
    .filter((q) => q.id in answers)
    .map((q) => ({
      label: q.label,
      value: q.type === 'attachment' ? `${answers[q.id]} anexo(s)`
        : q.type === 'boolean' ? (answers[q.id] ? 'Sim' : 'Não')
          : Array.isArray(answers[q.id]) ? answers[q.id].join(', ') : String(answers[q.id]),
    }));
}

module.exports = {
  MODALITIES, PERIODS, DEFAULT_RADIUS_KM, MAX_RADIUS_KM, TZ, TZ_OFFSET_MIN,
  ATTACHMENT_TYPES, ATTACHMENT_MAX_BYTES, MAX_ATTACHMENTS,
  validGeo, coarseGeo, haversineKm, providerRadiusKm,
  matchKeys, serviceCompatible, weekdayOf, localToday, validAvailability, availabilityOk,
  providerMatch, conditionHolds, visibleQuestions, validateAnswers, questionnaireNodeFor,
  validateRequestInput, opportunityView, publicAnswers,
};
