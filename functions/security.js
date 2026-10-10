'use strict';

/**
 * Regras de negócio puras (sem Firebase) usadas pelas Cloud Functions de
 * segurança da Fase 1. Mantidas isoladas para testes unitários.
 */

const ARRAY_CONTAINS_ANY_LIMIT = 30;
const IN_QUERY_LIMIT = 30;

/** Campos de verificação que NÃO podem ficar no perfil público. */
const PROVIDER_PRIVATE_FIELDS = ['documentUrl', 'selfieUrl', 'certificates', 'documents'];

function chunk(list, size) {
  const out = [];
  for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
  return out;
}

/** Normaliza nomes de cidade para comparação (sem acento, minúsculo). */
function normalizeCity(v) {
  return String(v || '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Prestador elegível para receber/aceitar uma oportunidade:
 * aprovado (verified), conta ativa, atende o serviço e, quando tem
 * cidade/áreas declaradas, atende a cidade da solicitação.
 * Retorna { ok, reason }.
 */
function providerEligibility(provider, request, uid) {
  if (!provider) return { ok: false, reason: 'not_provider' };
  if (uid && provider.userId && provider.userId !== uid) {
    return { ok: false, reason: 'not_owner' };
  }
  if (provider.verified !== true) return { ok: false, reason: 'not_verified' };
  if (provider.active !== true) return { ok: false, reason: 'inactive' };
  const cats = Array.isArray(provider.categories) ? provider.categories : [];
  if (!request || !cats.includes(request.category)) {
    return { ok: false, reason: 'service_mismatch' };
  }
  if (uid && request.clientId === uid) return { ok: false, reason: 'own_request' };
  if (!providerServesCity(provider, request.city)) {
    return { ok: false, reason: 'region_mismatch' };
  }
  return { ok: true, reason: null };
}

/** Sem cidade/áreas declaradas, o prestador não é restringido por região. */
function providerServesCity(provider, city) {
  const target = normalizeCity(city);
  if (!target) return true;
  const areas = [
    provider.city,
    ...(Array.isArray(provider.serviceAreas) ? provider.serviceAreas : []),
  ].map(normalizeCity).filter(Boolean);
  if (areas.length === 0) return true;
  return areas.some((a) => a === target || target.includes(a) || a.includes(target));
}

/** Visão de oportunidade enviada ao prestador: sem endereço/contato. */
function opportunityView(id, r) {
  const ts = r.createdAt && typeof r.createdAt.toMillis === 'function'
    ? r.createdAt.toMillis()
    : null;
  return {
    id,
    description: String(r.description || '').slice(0, 2000),
    category: r.category || '',
    city: r.city || '',
    neighborhood: r.neighborhood || null,
    modality: r.modality || null,
    proposalCount: Number(r.proposalCount || 0),
    createdAtMs: ts,
  };
}

/** Validação da proposta enviada pelo prestador. */
function validateProposalInput(data) {
  const price = Number(data && data.price);
  const days = Number(data && data.deadlineDays);
  if (!(price > 0) || price > 1000000) return { ok: false, reason: 'invalid_price' };
  if (!Number.isInteger(days) || days < 1 || days > 365) {
    return { ok: false, reason: 'invalid_deadline' };
  }
  const msg = data && data.message != null ? String(data.message) : null;
  if (msg && msg.length > 1000) return { ok: false, reason: 'message_too_long' };
  return {
    ok: true,
    value: {
      price: Math.round(price * 100) / 100,
      deadlineDays: days,
      message: msg && msg.trim() ? msg.trim() : null,
    },
  };
}

/**
 * Revalida uma avaliação contra o pedido (defesa em profundidade além
 * das regras do Firestore).
 */
function reviewValidity(reviewId, review, order) {
  if (!review || !order) return { ok: false, reason: 'missing' };
  if (reviewId !== `${review.orderId}_${review.clientId}`) return { ok: false, reason: 'bad_id' };
  if (order.clientId !== review.clientId) return { ok: false, reason: 'not_client' };
  if (order.status !== 'completed') return { ok: false, reason: 'not_completed' };
  if (!order.providerId || order.providerId !== review.providerId) {
    return { ok: false, reason: 'provider_mismatch' };
  }
  const s = review.stars;
  if (!Number.isInteger(s) || s < 1 || s > 5) return { ok: false, reason: 'bad_stars' };
  return { ok: true, reason: null };
}

function averageRating(starsList) {
  const valid = starsList.filter((s) => Number.isInteger(s) && s >= 1 && s <= 5);
  if (valid.length === 0) return { rating: 0, totalReviews: 0 };
  const sum = valid.reduce((a, b) => a + b, 0);
  return { rating: Math.round((sum / valid.length) * 10) / 10, totalReviews: valid.length };
}

/**
 * Extrai o caminho do objeto no Storage a partir de uma download URL
 * (produção ou emulador). Retorna null se não reconhecer.
 */
function storagePathFromUrl(url) {
  if (typeof url !== 'string' || !url) return null;
  if (url.startsWith('gs://')) {
    const rest = url.slice(5);
    const i = rest.indexOf('/');
    return i > 0 ? rest.slice(i + 1) : null;
  }
  const m = url.match(/\/v0\/b\/[^/]+\/o\/([^?#]+)/);
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch (_) {
    return null;
  }
}

/**
 * Plano de migração de um perfil de prestador legado: o que vai para
 * private/verification e quais campos saem do documento público.
 */
function planProviderMigration(data) {
  const d = data || {};
  const present = PROVIDER_PRIVATE_FIELDS.filter((k) => k in d);
  if (present.length === 0) return null;
  const priv = {};
  const filesToProtect = [];
  if (d.documentUrl) {
    const p = storagePathFromUrl(d.documentUrl);
    priv.documentPath = p || null;
    if (p) filesToProtect.push(p);
  }
  if (d.selfieUrl) {
    const p = storagePathFromUrl(d.selfieUrl);
    priv.selfiePath = p || null;
    if (p) filesToProtect.push(p);
  }
  const certs = [];
  const certPaths = [];
  const rawCerts = [
    ...(Array.isArray(d.certificates) ? d.certificates : []),
    ...(Array.isArray(d.documents) ? d.documents : []),
  ];
  for (const c of rawCerts) {
    const p = storagePathFromUrl(c);
    if (p) {
      certPaths.push(p);
      filesToProtect.push(p);
    } else if (typeof c === 'string' && c.trim()) {
      certs.push(c.trim().slice(0, 200));
    }
  }
  if (certs.length) priv.certificates = certs;
  if (certPaths.length) priv.certificatePaths = certPaths;
  return { removeFields: present, privateData: priv, filesToProtect };
}

module.exports = {
  ARRAY_CONTAINS_ANY_LIMIT,
  IN_QUERY_LIMIT,
  PROVIDER_PRIVATE_FIELDS,
  chunk,
  normalizeCity,
  providerEligibility,
  providerServesCity,
  opportunityView,
  validateProposalInput,
  reviewValidity,
  averageRating,
  storagePathFromUrl,
  planProviderMigration,
};
