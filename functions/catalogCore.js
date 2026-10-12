'use strict';

/**
 * Catálogo Carajás 360 — regras puras (sem Firebase), testáveis.
 *
 * Estrutura: categoria → grupo → serviço (3 níveis fixos).
 * Coleção: catalogNodes/{id}. IDs legados (ex.: "eletricista") são
 * preservados como IDs de nó; IDs novos usam prefixos cat_/grp_/svc_.
 */

const LEVELS = ['category', 'group', 'service'];
const PARENT_LEVEL = { category: null, group: 'category', service: 'group' };
const VERTICALS = ['services', 'health', 'market', 'rental', 'delivery'];
const MODALITIES = ['presential', 'online', 'home_care'];
const COMMERCIAL_MODELS = ['quote', 'fixed', 'both'];
const ID_RE = /^[a-z0-9_]{2,64}$/;

/** Campos que a migração/admin controla (comparados para conflito). */
const MANAGED_FIELDS = [
  'level', 'name', 'description', 'parentId', 'icon', 'color', 'vertical',
  'keywords', 'synonyms', 'modalities', 'commercialModel', 'order', 'active',
];

/**
 * Normalização compartilhada com o app (lib/core/catalog/catalog_text.dart):
 * minúsculas, sem acentos, só [a-z0-9] e espaços simples.
 */
function normalize(text) {
  return String(text == null ? '' : text)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/** Forma compacta (sem espaços): "ar condicionado" → "arcondicionado". */
function compact(text) {
  return normalize(text).replace(/ /g, '');
}

function slugify(text) {
  return normalize(text).replace(/ /g, '-');
}

/** Prefixos de cada palavra (2..15 chars) para busca por início de nome. */
function wordPrefixes(text, { min = 2, max = 15 } = {}) {
  const out = new Set();
  for (const w of normalize(text).split(' ')) {
    if (!w) continue;
    for (let i = min; i <= Math.min(w.length, max); i += 1) out.add(w.slice(0, i));
    if (w.length < min) out.add(w);
  }
  return [...out];
}

function strList(v, { maxItems = 30, maxLen = 60 } = {}) {
  if (v == null) return [];
  if (!Array.isArray(v)) return null;
  const out = [];
  for (const x of v) {
    if (typeof x !== 'string') return null;
    const t = x.trim();
    if (!t) continue;
    if (t.length > maxLen) return null;
    if (!out.includes(t)) out.push(t);
  }
  return out.length > maxItems ? null : out;
}

/**
 * Valida e normaliza um nó vindo do admin. `existing` = mapa id→nó atual.
 * Retorna { ok, errors[], value }.
 */
function validateNode(input, existing, { isNew }) {
  const errors = [];
  const d = input || {};
  const id = String(d.id || '').trim();
  if (!ID_RE.test(id)) errors.push('id inválido (use a-z, 0-9 e _; 2 a 64 caracteres)');
  if (isNew && existing[id]) errors.push('id já existe');
  if (!isNew && !existing[id]) errors.push('nó não encontrado');

  const prev = existing[id] || {};
  const level = isNew ? d.level : prev.level;
  if (!LEVELS.includes(level)) errors.push('nível inválido');
  if (!isNew && d.level && d.level !== prev.level) errors.push('nível não pode ser alterado');

  const name = String(d.name || '').trim();
  if (name.length < 2 || name.length > 80) errors.push('nome obrigatório (2 a 80 caracteres)');

  const parentId = d.parentId == null || d.parentId === '' ? null : String(d.parentId);
  const expectedParent = PARENT_LEVEL[level];
  let root = null;
  if (LEVELS.includes(level)) {
    if (expectedParent === null) {
      if (parentId) errors.push('categoria não tem nível superior');
    } else {
      const parent = parentId ? existing[parentId] : null;
      if (!parent) errors.push(`${level === 'service' ? 'serviço' : 'grupo'} exige um ${expectedParent === 'group' ? 'grupo' : 'categoria'} existente`);
      else if (parent.level !== expectedParent) errors.push(`nível superior deve ser ${expectedParent}`);
      if (parentId === id) errors.push('hierarquia circular');
      if (parent) root = rootOf(parentId, existing);
    }
  }
  // Ciclos: impossíveis com níveis fixos, mas verificamos o caminho.
  if (parentId && hasCycle(id, parentId, existing)) errors.push('hierarquia circular');

  let vertical = d.vertical || prev.vertical || 'services';
  if (level !== 'category' && root) vertical = root.vertical || 'services';
  if (!VERTICALS.includes(vertical)) errors.push('vertical inválida');

  const description = String(d.description || '').trim();
  if (description.length > 300) errors.push('descrição muito longa (máx. 300)');
  const icon = String(d.icon || '').trim();
  if (!icon || icon.length > 16) errors.push('ícone obrigatório (emoji ou código curto)');
  const color = d.color == null || d.color === '' ? null : String(d.color);
  if (color && !/^#[0-9A-Fa-f]{6}$/.test(color)) errors.push('cor inválida (#RRGGBB)');

  const keywords = strList(d.keywords);
  const synonyms = strList(d.synonyms);
  if (keywords === null) errors.push('palavras-chave inválidas');
  if (synonyms === null) errors.push('sinônimos inválidos');
  const modalities = strList(d.modalities, { maxItems: 3 });
  if (modalities === null || modalities.some((m) => !MODALITIES.includes(m))) {
    errors.push('modalidades inválidas');
  }
  const commercialModel = d.commercialModel || 'quote';
  if (!COMMERCIAL_MODELS.includes(commercialModel)) errors.push('modalidade comercial inválida');

  const order = d.order == null ? (prev.order != null ? prev.order : 0) : Number(d.order);
  if (!Number.isFinite(order) || order < 0 || order > 100000) errors.push('ordem inválida');

  const active = d.active == null ? (prev.active != null ? prev.active : true) : d.active === true;

  // Duplicidade: mesmo slug entre irmãos.
  const slug = slugify(name);
  const dup = Object.values(existing).find((n) => n.id !== id &&
    (n.parentId || null) === parentId && slugify(n.name) === slug);
  if (dup) errors.push(`já existe "${dup.name}" neste nível`);

  return {
    ok: errors.length === 0,
    errors,
    value: {
      id, level, name, description, parentId, slug, icon, color, vertical,
      keywords: keywords || [], synonyms: synonyms || [], modalities: modalities || [],
      commercialModel, order: Math.round(order), active,
    },
  };
}

function rootOf(id, nodes) {
  let cur = nodes[id];
  let guard = 0;
  while (cur && cur.parentId && guard < 5) {
    cur = nodes[cur.parentId];
    guard += 1;
  }
  return cur || null;
}

function hasCycle(id, parentId, nodes) {
  let cur = parentId;
  const seen = new Set([id]);
  let guard = 0;
  while (cur && guard < 10) {
    if (seen.has(cur)) return true;
    seen.add(cur);
    cur = nodes[cur] ? nodes[cur].parentId : null;
    guard += 1;
  }
  return guard >= 10;
}

/** Caminho [categoria, grupo?, serviço?] de um nó. */
function pathOf(id, nodes) {
  const out = [];
  let cur = nodes[id];
  let guard = 0;
  while (cur && guard < 5) {
    out.unshift(cur);
    cur = cur.parentId ? nodes[cur.parentId] : null;
    guard += 1;
  }
  return out;
}

/** Ativo efetivo: o nó e todos os ancestrais ativos. */
function effectiveActive(id, nodes) {
  const p = pathOf(id, nodes);
  return p.length > 0 && p.every((n) => n.active !== false);
}

function descendants(id, nodes) {
  const out = [];
  const stack = [id];
  while (stack.length) {
    const cur = stack.pop();
    for (const n of Object.values(nodes)) {
      if (n.parentId === cur) {
        out.push(n.id);
        stack.push(n.id);
      }
    }
  }
  return out;
}

/** Termos pesquisáveis de um nó (nome, sinônimos, palavras-chave, slug). */
function searchTerms(node) {
  const terms = [node.name, ...(node.synonyms || []), ...(node.keywords || [])];
  const set = new Set();
  for (const t of terms) {
    const n = normalize(t);
    if (n) {
      set.add(n);
      set.add(compact(t));
    }
  }
  return [...set];
}

/** Snapshot imutável do serviço para pedidos/solicitações. */
function serviceSnapshot(id, nodes) {
  const p = pathOf(id, nodes);
  if (!p.length) return null;
  const by = (lvl) => p.find((n) => n.level === lvl) || null;
  const cat = by('category');
  const grp = by('group');
  const svc = by('service');
  return {
    id,
    name: p[p.length - 1].name || id,
    level: p[p.length - 1].level,
    categoryId: cat ? cat.id : null,
    categoryName: cat ? cat.name || null : null,
    groupId: grp ? grp.id : null,
    groupName: grp ? grp.name || null : null,
    serviceId: svc ? svc.id : null,
    // Campos ausentes viram null (Firestore recusa undefined).
    vertical: cat && cat.vertical != null ? cat.vertical : null,
  };
}

/**
 * Índice de busca de um prestador/empresa. Um único array `searchTokens`
 * (Firestore permite um array-contains por consulta):
 *   s:<serviço>  g:<grupo>  c:<categoria>  m:<modalidade>  n:<prefixo nome>
 * Prestador com um GRUPO declarado recebe g:/c: desse grupo, mas NUNCA
 * s: de serviços específicos que não declarou.
 */
function providerIndex(provider, nodes) {
  const tokens = new Set();
  const declared = Array.isArray(provider.categories) ? provider.categories : [];
  const groupIds = new Set();
  const categoryIds = new Set();
  const unknown = [];
  for (const id of declared) {
    const node = nodes[id];
    if (!node) {
      unknown.push(id);
      tokens.add(`s:${id}`); // preserva o ID legado mesmo sem catálogo
      continue;
    }
    for (const n of pathOf(id, nodes)) {
      if (n.level === 'category') categoryIds.add(n.id);
      if (n.level === 'group') groupIds.add(n.id);
    }
    if (node.level === 'service') tokens.add(`s:${node.id}`);
    if (node.level === 'group') tokens.add(`s:${node.id}`); // grupo declarado é contratável
  }
  groupIds.forEach((g) => tokens.add(`g:${g}`));
  categoryIds.forEach((c) => tokens.add(`c:${c}`));
  for (const m of Array.isArray(provider.modalities) ? provider.modalities : []) {
    if (MODALITIES.includes(m)) tokens.add(`m:${m}`);
  }
  for (const p of wordPrefixes(provider.name || '')) tokens.add(`n:${p}`);
  return {
    searchTokens: [...tokens].sort(),
    cityKey: normalize(provider.city || '') || null,
    groupIds: [...groupIds].sort(),
    categoryIds: [...categoryIds].sort(),
    unknownCategories: unknown,
  };
}

function companyIndex(company) {
  const tokens = new Set();
  for (const p of wordPrefixes(company.name || '')) tokens.add(`n:${p}`);
  for (const c of Array.isArray(company.categories) ? company.categories : []) tokens.add(`s:${c}`);
  return { searchTokens: [...tokens].sort(), cityKey: normalize(company.city || '') || null };
}

function sameArray(a, b) {
  const x = Array.isArray(a) ? a : [];
  const y = Array.isArray(b) ? b : [];
  return x.length === y.length && x.every((v, i) => v === y[i]);
}

/**
 * Plano da migração do seed: cria o que falta, ignora o idêntico e
 * reporta conflito quando o documento existente difere (nunca sobrescreve
 * nem apaga). Idempotente por construção.
 */
function planSeedMigration(seedNodes, existing) {
  const create = [];
  const unchanged = [];
  const conflicts = [];
  for (const s of seedNodes) {
    const cur = existing[s.id];
    if (!cur) {
      create.push(s);
      continue;
    }
    const diffs = MANAGED_FIELDS.filter((f) => {
      if (f === 'active') return cur.active === false && s.active !== false;
      if (f === 'order') return false; // ordem pode ser ajustada pelo admin
      const a = cur[f] == null ? null : cur[f];
      const b = s[f] == null ? null : s[f];
      return Array.isArray(a) || Array.isArray(b) ? !sameArray(a, b) : a !== b;
    });
    if (diffs.length === 0) unchanged.push(s.id);
    else conflicts.push({ id: s.id, type: 'existing_differs', fields: diffs, editedByAdmin: !!cur.editedAt });
  }
  return { create, unchanged, conflicts };
}

/**
 * IDs usados em perfis/pedidos que não existem no catálogo (nem no seed).
 * Retorna [{ id, collection, count }]. Nunca classifica automaticamente.
 */
function unknownReferences(refs, knownIds) {
  const out = {};
  for (const { collection, id } of refs) {
    if (!id || knownIds.has(id)) continue;
    const key = `${collection}:${id}`;
    out[key] = out[key] || { id, collection, count: 0 };
    out[key].count += 1;
  }
  return Object.values(out).sort((a, b) => b.count - a.count);
}

// ── Questionários (estrutura versionada) ───────────────────────────

const QUESTION_TYPES = ['text', 'long_text', 'number', 'single_choice', 'multi_choice', 'boolean', 'date', 'attachment'];
const CONDITION_OPS = ['equals', 'not_equals', 'in', 'answered'];

/**
 * Valida a definição de um questionário. Condições só podem referenciar
 * perguntas ANTERIORES (impede ciclos e referências inexistentes).
 */
function validateQuestionnaire(input, nodes) {
  const errors = [];
  const d = input || {};
  const serviceId = String(d.serviceId || '');
  const node = nodes[serviceId];
  if (!node) errors.push('serviço inexistente');
  else if (node.level === 'category') errors.push('questionário deve ser vinculado a grupo ou serviço');
  const title = String(d.title || '').trim();
  if (title.length < 3 || title.length > 120) errors.push('título obrigatório (3 a 120)');
  const qs = Array.isArray(d.questions) ? d.questions : null;
  if (!qs || qs.length === 0) errors.push('inclua ao menos uma pergunta');
  if (qs && qs.length > 40) errors.push('máximo de 40 perguntas');
  const seen = new Map();
  const clean = [];
  (qs || []).forEach((q, idx) => {
    const p = `pergunta ${idx + 1}`;
    const id = String((q && q.id) || '').trim();
    if (!/^[a-z0-9_]{1,40}$/.test(id)) errors.push(`${p}: id inválido`);
    if (seen.has(id)) errors.push(`${p}: id duplicado "${id}"`);
    const type = q && q.type;
    if (!QUESTION_TYPES.includes(type)) errors.push(`${p}: tipo inválido`);
    const label = String((q && q.label) || '').trim();
    if (label.length < 2 || label.length > 200) errors.push(`${p}: enunciado obrigatório`);
    let options = [];
    if (type === 'single_choice' || type === 'multi_choice') {
      options = strList(q.options, { maxItems: 30, maxLen: 80 }) || [];
      if (options.length < 2) errors.push(`${p}: escolha exige ao menos 2 opções`);
    }
    let showIf = null;
    if (q && q.showIf) {
      const c = q.showIf;
      const target = seen.get(c.questionId);
      if (!target) errors.push(`${p}: condição deve referenciar uma pergunta anterior`);
      if (!CONDITION_OPS.includes(c.op)) errors.push(`${p}: operador de condição inválido`);
      if (target && ['single_choice', 'multi_choice'].includes(target.type) && c.op !== 'answered') {
        const vals = Array.isArray(c.value) ? c.value : [c.value];
        if (vals.some((v) => !target.options.includes(v))) errors.push(`${p}: valor da condição não é opção de "${target.id}"`);
      }
      if (target && target.type === 'boolean' && ['equals', 'not_equals'].includes(c.op) && typeof c.value !== 'boolean') {
        errors.push(`${p}: condição booleana exige true/false`);
      }
      showIf = { questionId: c.questionId, op: c.op, value: c.value === undefined ? null : c.value };
    }
    const item = { id, type, label, required: q && q.required === true, options, showIf };
    if (id) seen.set(id, item);
    clean.push(item);
  });
  return { ok: errors.length === 0, errors, value: { serviceId, title, questions: clean } };
}

module.exports = {
  LEVELS, PARENT_LEVEL, VERTICALS, MODALITIES, COMMERCIAL_MODELS, MANAGED_FIELDS,
  QUESTION_TYPES, CONDITION_OPS,
  normalize, compact, slugify, wordPrefixes,
  validateNode, pathOf, rootOf, effectiveActive, descendants, searchTerms,
  serviceSnapshot, providerIndex, companyIndex, sameArray,
  planSeedMigration, unknownReferences, validateQuestionnaire,
};
