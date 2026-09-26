'use strict';

/**
 * Assistente de pedido/proposta — logica pura (testavel sem Anthropic).
 * Nao inventa profissionais, avaliacoes, precos, disponibilidade ou garantias.
 */

function normalizeText(s) {
  return String(s || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim();
}

function buildCategoryIndex(catalog) {
  const list = Array.isArray(catalog) ? catalog : [];
  return list
    .map((c) => ({
      id: String(c.id || ''),
      name: String(c.name || ''),
      groupId: c.groupId ? String(c.groupId) : null,
      keywords: Array.isArray(c.keywords)
        ? c.keywords.map((k) => normalizeText(k))
        : [normalizeText(c.name), normalizeText(c.id)],
    }))
    .filter((c) => c.id);
}

function suggestCategoryFromText(text, catalog) {
  const n = normalizeText(text);
  if (!n) return { categoryId: null, confidence: 0, reason: 'empty' };
  const index = buildCategoryIndex(catalog);
  let best = null;
  let bestScore = 0;
  for (const c of index) {
    let score = 0;
    for (const kw of c.keywords) {
      if (!kw) continue;
      if (n.includes(kw)) score += kw.length >= 5 ? 3 : 2;
    }
    if (n.includes(normalizeText(c.id))) score += 4;
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }
  if (!best || bestScore < 2) {
    return { categoryId: null, confidence: 0, reason: 'insufficient_match' };
  }
  return {
    categoryId: best.id,
    categoryName: best.name,
    groupId: best.groupId,
    confidence: Math.min(1, bestScore / 10),
    reason: 'keyword_match',
  };
}

function validateCategoryId(categoryId, catalog) {
  const id = String(categoryId || '');
  if (!id) return { ok: false, reason: 'missing_category' };
  const found = buildCategoryIndex(catalog).find((c) => c.id === id);
  if (!found) return { ok: false, reason: 'invalid_category' };
  return { ok: true, category: found };
}

function missingFieldsForRequest(draft) {
  const missing = [];
  if (!String(draft && draft.city || '').trim()) missing.push('city');
  if (!String(draft && draft.urgency || '').trim()) missing.push('urgency');
  if (!String(draft && draft.description || '').trim() ||
      String(draft.description).trim().length < 20) {
    missing.push('description_detail');
  }
  if (!String(draft && draft.categoryId || '').trim()) missing.push('categoryId');
  return missing;
}

function sanitizeAssistDraft(raw, catalog) {
  const title = String((raw && raw.title) || '').slice(0, 120).trim();
  const description = String((raw && raw.description) || '').slice(0, 2000).trim();
  const city = String((raw && raw.city) || '').slice(0, 80).trim();
  const neighborhood = String((raw && raw.neighborhood) || '').slice(0, 80).trim();
  const urgency = String((raw && raw.urgency) || '').slice(0, 40).trim();
  const clarifyingQuestions = Array.isArray(raw && raw.clarifyingQuestions)
    ? raw.clarifyingQuestions.map((q) => String(q).slice(0, 160)).filter(Boolean).slice(0, 6)
    : [];
  // Nunca aceitar precos/profissionais vindos da IA.
  const forbiddenKeys = ['price', 'budget', 'providers', 'rating', 'guarantee', 'phone', 'addressFull'];
  for (const k of forbiddenKeys) {
    if (raw && Object.prototype.hasOwnProperty.call(raw, k) && raw[k] != null) {
      // strip silently
    }
  }
  let categoryId = String((raw && raw.categoryId) || '').trim();
  const catCheck = validateCategoryId(categoryId, catalog);
  if (!catCheck.ok) {
    const guessed = suggestCategoryFromText(`${title} ${description}`, catalog);
    categoryId = guessed.categoryId || '';
  }
  const missing = missingFieldsForRequest({
    city,
    urgency,
    description,
    categoryId,
  });
  return {
    title: title || description.slice(0, 60) || 'Pedido de servico',
    description,
    categoryId: categoryId || null,
    city: city || null,
    neighborhood: neighborhood || null,
    urgency: urgency || null,
    clarifyingQuestions,
    missingFields: missing,
    readyToPublish: missing.length === 0,
  };
}

function buildProposalDraftText({
  requestSummary,
  providerPrice,
  deadlineDays,
  materialsIncluded,
  conditions,
  providerServices,
}) {
  const price = Number(providerPrice);
  const days = Number(deadlineDays);
  if (!(price > 0)) {
    return { ok: false, reason: 'provider_price_required' };
  }
  if (!(days >= 1 && days <= 365)) {
    return { ok: false, reason: 'invalid_deadline' };
  }
  const services = Array.isArray(providerServices)
    ? providerServices.map((s) => String(s).slice(0, 80)).filter(Boolean).slice(0, 8)
    : [];
  const cond = String(conditions || '').slice(0, 800).trim();
  const summary = String(requestSummary || '').slice(0, 400).trim();
  const lines = [];
  lines.push('Proposta (rascunho — valores informados pelo prestador):');
  if (summary) lines.push(`Referente a: ${summary}`);
  if (services.length) lines.push(`Servicos: ${services.join(', ')}`);
  lines.push(`Valor: R$ ${price.toFixed(2).replace('.', ',')}`);
  lines.push(`Prazo: ${days} dia(s)`);
  lines.push(`Materiais inclusos: ${materialsIncluded ? 'sim' : 'nao (a combinar)'}`);
  if (cond) lines.push(`Condicoes: ${cond}`);
  lines.push('Esta proposta nao inclui garantias inventadas pela plataforma.');
  return {
    ok: true,
    draftMessage: lines.join('\n'),
    price,
    deadlineDays: days,
    materialsIncluded: Boolean(materialsIncluded),
  };
}

function planAiQuota(plan) {
  const p = String(plan || 'free').toLowerCase();
  if (p === 'pro' || p === 'business' || p === 'empresa') return { max: 60, windowMs: 24 * 60 * 60 * 1000 };
  return { max: 15, windowMs: 24 * 60 * 60 * 1000 };
}

function idempotencyDocId(uid, key) {
  const k = String(key || '').replace(/[^a-zA-Z0-9_-]/g, '').slice(0, 64);
  if (!k) return null;
  return `${uid}_${k}`;
}

/** Catalogo minimo alinhado a taxonomia (servidor nao confia so no client). */
const DEFAULT_CATEGORY_CATALOG = [
  { id: 'eletricista', name: 'Eletricista', groupId: 'casa_geral', keywords: ['eletricista', 'tomada', 'disjuntor', 'fio', 'energia'] },
  { id: 'encanador', name: 'Encanador', groupId: 'casa_geral', keywords: ['encanador', 'vazamento', 'cano', 'torneira', 'hidraulica'] },
  { id: 'pedreiro', name: 'Pedreiro', groupId: 'casa_geral', keywords: ['pedreiro', 'alvenaria', 'reforma', 'parede'] },
  { id: 'pintor', name: 'Pintor', groupId: 'casa_geral', keywords: ['pintor', 'pintura', 'tinta'] },
  { id: 'diarista', name: 'Diarista', groupId: 'limpeza_dom', keywords: ['diarista', 'faxina', 'limpeza'] },
  { id: 'freios', name: 'Freios', groupId: 'mecanica', keywords: ['freio', 'freios', 'pastilha', 'disco'] },
  { id: 'mecanica_geral', name: 'Mecanica geral', groupId: 'mecanica', keywords: ['mecanica', 'motor', 'carro', 'oficina'] },
  { id: 'guincho', name: 'Guincho', groupId: 'emergencia_auto', keywords: ['guincho', 'reboque', 'socorro'] },
  { id: 'baterista_auto', name: 'Bateria automotiva', groupId: 'eletrica_auto', keywords: ['bateria', 'partida'] },
  { id: 'ar_condicionado', name: 'Ar-condicionado', groupId: 'casa_geral', keywords: ['ar condicionado', 'ar-condicionado', 'split'] },
  { id: 'jardineiro', name: 'Jardineiro', groupId: 'rural_jardim', keywords: ['jardim', 'jardineiro', 'poda'] },
  { id: 'soldador', name: 'Soldador', groupId: 'industria', keywords: ['solda', 'soldador'] },
];

function mergeClientCatalog(clientCatalog) {
  const byId = new Map();
  for (const c of DEFAULT_CATEGORY_CATALOG) {
    byId.set(c.id, {
      id: c.id,
      name: c.name,
      groupId: c.groupId || null,
      keywords: Array.isArray(c.keywords) ? c.keywords.slice() : [c.name, c.id],
    });
  }
  const list = Array.isArray(clientCatalog) ? clientCatalog.slice(0, 200) : [];
  for (const raw of list) {
    const id = String((raw && raw.id) || '')
      .toLowerCase()
      .replace(/[^a-z0-9_]/g, '')
      .slice(0, 64);
    if (!id || id.length < 2) continue;
    const name = String((raw && raw.name) || '').slice(0, 80).trim();
    if (!name) continue;
    const keywords = Array.isArray(raw.keywords)
      ? raw.keywords.map((k) => String(k).slice(0, 60)).filter(Boolean).slice(0, 12)
      : [name, id];
    const prev = byId.get(id);
    byId.set(id, {
      id,
      name: prev ? prev.name : name,
      groupId: (raw && raw.groupId) ? String(raw.groupId).slice(0, 64) : (prev && prev.groupId) || null,
      keywords: prev
        ? Array.from(new Set([...(prev.keywords || []), ...keywords])).slice(0, 20)
        : keywords,
    });
  }
  return Array.from(byId.values());
}

module.exports = {
  normalizeText,
  buildCategoryIndex,
  suggestCategoryFromText,
  validateCategoryId,
  missingFieldsForRequest,
  sanitizeAssistDraft,
  buildProposalDraftText,
  planAiQuota,
  idempotencyDocId,
  mergeClientCatalog,
  DEFAULT_CATEGORY_CATALOG,
};