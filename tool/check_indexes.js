'use strict';
/**
 * Fase 7: confere consultas compostas do app (Dart) e das functions (JS)
 * contra firestore.indexes.json. O emulador NÃO exige índices compostos,
 * então uma falta só apareceria em homologação/produção.
 *   node tool/check_indexes.js
 * Heurística: lê cadeias `.collection(X)` / `.collectionGroup(X)` seguidas
 * de where/orderBy até o fim da expressão. Consultas montadas em variáveis
 * em vários passos são analisadas pelo trecho onde aparecem; o resultado
 * lista o que precisa de índice e se ele existe.
 */
const fs = require('fs'); const path = require('path');
const ROOT = path.join(__dirname, '..');
const idx = JSON.parse(fs.readFileSync(path.join(ROOT, 'firestore.indexes.json'), 'utf8')).indexes;

const colConst = {};
const consts = fs.readFileSync(path.join(ROOT, 'lib/core/constants/app_constants.dart'), 'utf8');
for (const m of consts.matchAll(/static const (\w+) = '([A-Za-z]+)';/g)) colConst[`Col.${m[1]}`] = m[2];

function files(dir, ext, out = []) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) { if (!['node_modules', '.dart_tool', 'build'].includes(f.name)) files(p, ext, out); } else if (p.endsWith(ext) && !p.endsWith('.test.js')) out.push(p);
  }
  return out;
}

const EQ = new Set(['isEqualTo', '==', 'whereIn', 'in']);
const ARR = new Set(['arrayContains', 'array-contains', 'arrayContainsAny', 'array-contains-any']);
function parseChain(src) {
  const filters = []; const orders = [];
  // Dart: .where('f', isEqualTo: x) | JS: .where('f', '==', x)
  for (const m of src.matchAll(/\.where\(\s*['"]([\w.]+)['"]\s*,\s*(?:(\w+)\s*:|['"]([^'"]+)['"])/g)) {
    const op = m[2] || m[3];
    filters.push({ field: m[1], kind: EQ.has(op) ? 'eq' : ARR.has(op) ? 'arr' : 'range' });
  }
  for (const m of src.matchAll(/\.orderBy\(\s*['"]([\w.]+)['"]\s*(?:,\s*(?:descending:\s*(true|false)|['"](asc|desc)['"]))?/g)) {
    orders.push({ field: m[1], dir: (m[2] === 'true' || m[3] === 'desc') ? 'DESCENDING' : 'ASCENDING' });
  }
  return { filters, orders };
}

function needsComposite({ filters, orders }) {
  const fields = new Set([...filters.map((f) => f.field), ...orders.map((o) => o.field)]);
  if (fields.size < 2) return false;
  // Só igualdades sem orderBy: o Firestore mescla índices simples.
  if (!orders.length && filters.every((f) => f.kind === 'eq')) return false;
  return true;
}

function covered(col, q) {
  const eq = q.filters.filter((f) => f.kind === 'eq').map((f) => f.field);
  const arr = q.filters.filter((f) => f.kind === 'arr').map((f) => f.field);
  const range = q.filters.filter((f) => f.kind === 'range').map((f) => f.field);
  const ord = q.orders.map((o) => o.field);
  return idx.some((ix) => {
    if (ix.collectionGroup !== col) return false;
    const fl = ix.fields.map((f) => f.fieldPath);
    const need = new Set([...eq, ...arr, ...range, ...ord]);
    if (fl.length !== need.size || ![...need].every((f) => fl.includes(f))) return false;
    for (const a of arr) if (ix.fields.find((f) => f.fieldPath === a).arrayConfig !== 'CONTAINS') return false;
    // Campos de ordenação/intervalo vêm depois das igualdades, na ordem da consulta.
    const tail = [...new Set([...range, ...ord])];
    const pos = tail.map((f) => fl.indexOf(f));
    if (pos.some((p, i) => i && p < pos[i - 1])) return false;
    return eq.concat(arr).every((f) => fl.indexOf(f) < Math.min(...pos, Infinity));
  });
}

const results = [];
const srcFiles = [...files(path.join(ROOT, 'lib'), '.dart'), ...files(path.join(ROOT, 'functions'), '.js')];
for (const file of srcFiles) {
  const text = fs.readFileSync(file, 'utf8');
  const re = /\.(collection|collectionGroup)\(\s*([^)]+?)\s*\)/g;
  let m;
  while ((m = re.exec(text))) {
    const arg = m[2].trim();
    const col = colConst[arg] || (arg.match(/^['"`]([A-Za-z]+)['"`]$/) || [])[1];
    if (!col) continue;
    // Expressão até o próximo ';' ou '.collection(' (o que vier antes).
    const rest = text.slice(re.lastIndex);
    const end = Math.min(...[rest.indexOf(';'), rest.search(/\.(collection|doc)\(/)].filter((i) => i >= 0), 1500);
    const chain = rest.slice(0, end);
    const q = parseChain(chain);
    if (!needsComposite(q)) continue;
    const line = text.slice(0, m.index).split('\n').length;
    results.push({ where: `${path.relative(ROOT, file)}:${line}`, col, q, ok: covered(col, q) });
  }
  // Referências guardadas em variáveis (functions): `const REQ = db.collection('x')`
  // e `{ orders: db.collection('x') }` → `REQ.where(...)` / `C.orders.where(...)`.
  const refs = {};
  for (const r of text.matchAll(/(?:const|let)\s+(\w+)\s*=\s*\w+\.collection\(\s*['"](\w+)['"]\s*\)/g)) refs[r[1]] = r[2];
  for (const r of text.matchAll(/(\w+)\s*:\s*\w+\.collection\(\s*['"](\w+)['"]\s*\)/g)) refs[`C.${r[1]}`] = r[2];
  for (const [name, col] of Object.entries(refs)) {
    const esc = name.replace('.', '\\.');
    const rr = new RegExp(`(?<![\\w.])${esc}\\s*\\.(?=where|orderBy)`, 'g');
    let k;
    while ((k = rr.exec(text))) {
      const rest = text.slice(k.index);
      const end = Math.min(...[rest.indexOf(';')].filter((i) => i >= 0), 1500);
      const q = parseChain(rest.slice(0, end));
      if (!needsComposite(q)) continue;
      const line = text.slice(0, k.index).split('\n').length;
      results.push({ where: `${path.relative(ROOT, file)}:${line}`, col, q, ok: covered(col, q) });
    }
  }
}
// Consultas montadas em passos (`q = q.where(...)`): combinações declaradas
// aqui a partir do código. Manter em sincronia ao mudar esses builders.
const eq = (field) => ({ field, kind: 'eq' }); const arr = (field) => ({ field, kind: 'arr' });
const rng = (field) => ({ field, kind: 'range' }); const ob = (field, dir = 'ASCENDING') => ({ field, dir });
const VARIANTS = [
  ['lib/shared/services/firebase_service.dart providerOrdersStream', 'orders', [eq('providerId'), eq('status')], [ob('createdAt', 'DESCENDING')]],
  ['lib/shared/services/firebase_service.dart orderHistoryStream', 'orders', [eq('clientId'), eq('status')], [ob('createdAt', 'DESCENDING')]],
  ['lib/shared/services/firebase_service.dart adminTicketsStream', 'support', [eq('status')], [ob('createdAt', 'DESCENDING')]],
  ['lib/shared/services/firebase_service.dart reportsStream', 'reports', [eq('status')], [ob('createdAt', 'DESCENDING')]],
];
for (const city of [false, true]) {
  for (const token of [false, true]) {
    const base = [eq('active'), eq('verified'), ...(city ? [eq('cityKey')] : []), ...(token ? [arr('searchTokens')] : [])];
    const tag = `cidade=${city} termo=${token}`;
    VARIANTS.push([`lib/core/catalog/provider_search.dart nota ${tag}`, 'providers', [...base, rng('rating')], [ob('rating', 'DESCENDING')]]);
    VARIANTS.push([`lib/core/catalog/provider_search.dart avaliações ${tag}`, 'providers', base, [ob('totalReviews', 'DESCENDING')]]);
    VARIANTS.push([`lib/core/catalog/provider_search.dart preço ${tag}`, 'providers', [...base, rng('minPrice')], [ob('minPrice')]]);
  }
}
for (const [where, col, filters, orders] of VARIANTS) {
  const q = { filters, orders };
  results.push({ where, col, q, ok: covered(col, q) });
}

const missing = results.filter((r) => !r.ok);
for (const r of results) {
  const desc = [...r.q.filters.map((f) => `${f.field}(${f.kind})`), ...r.q.orders.map((o) => `↓${o.field}:${o.dir[0]}`)].join(', ');
  console.log(`${r.ok ? 'OK     ' : 'FALTA  '} ${r.col.padEnd(18)} ${desc.padEnd(60)} ${r.where}`);
}
console.log(`\n${results.length} consultas compostas; ${missing.length} sem índice correspondente.`);
process.exit(missing.length ? 1 : 0);
