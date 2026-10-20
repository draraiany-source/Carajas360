'use strict';
/** Pend. 3 (admin): listas paginadas por cursor e filtro de usuários por tipo na consulta. */
const { test, before, after } = require('node:test');
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, writeBatch, collection, getDocs, query, where, orderBy, limit, startAfter, Timestamp } = require('firebase/firestore');

const TYPES = ['client', 'company', 'deliverer'];
const T0 = Date.UTC(2026, 0, 1);
let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-pend3-admin',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'support', createdAt: Timestamp.fromMillis(T0 - 1000) });
    await setDoc(doc(db, 'users/fin'), { type: 'admin', adminRole: 'financial', createdAt: Timestamp.fromMillis(T0 - 2000) });
    // 130 usuários: 104 prestadores intercalados com clientes/empresas/entregadores.
    const b = writeBatch(db);
    for (let i = 0; i < 130; i++) {
      const type = i % 5 === 0 ? TYPES[(i / 5) % 3] : 'provider';
      b.set(doc(db, `users/u${String(i).padStart(3, '0')}`), { type, name: `U${i}`, createdAt: Timestamp.fromMillis(T0 + i * 1000) });
    }
    for (let i = 0; i < 3; i++) {
      b.set(doc(db, `support/t${i}`), { userId: 'x', status: i ? 'open' : 'resolved', createdAt: Timestamp.fromMillis(T0 + i) });
      b.set(doc(db, `reports/r${i}`), { reporterId: 'x', status: 'pending', createdAt: Timestamp.fromMillis(T0 + i) });
      b.set(doc(db, `auditLogs/a${i}`), { adminId: 'adm', timestamp: Timestamp.fromMillis(T0 + i) });
      b.set(doc(db, `coupons/c${i}`), { code: `C${i}`, createdAt: Timestamp.fromMillis(T0 + i) });
      b.set(doc(db, `refunds/f${i}`), { status: 'approved', createdAt: Timestamp.fromMillis(T0 + i) });
    }
    await b.commit();
  });
});
after(async () => { await env.cleanup(); });
const as = (uid) => env.authenticatedContext(uid).firestore();

/** Lê todas as páginas como o app (limit + startAfter do último documento). */
async function allPages(q, size) {
  const pages = [];
  let last = null;
  for (;;) {
    const s = await getDocs(last ? query(q, startAfter(last), limit(size)) : query(q, limit(size)));
    pages.push(s.docs);
    if (s.docs.length < size) return pages;
    last = s.docs[s.docs.length - 1];
  }
}

test('filtro de usuários por tipo na consulta: 2ª e 3ª páginas trazem o tipo filtrado, sem repetir nem faltar', async () => {
  const q = query(collection(as('adm'), 'users'), where('type', '==', 'provider'), orderBy('createdAt', 'desc'));
  const pages = await allPages(q, 50);
  assert.deepStrictEqual(pages.map((p) => p.length), [50, 50, 4]);
  const docs = pages.flat();
  assert.ok(docs.every((d) => d.data().type === 'provider'));
  const ids = docs.map((d) => d.id);
  assert.strictEqual(new Set(ids).size, 104, 'sem repetição');
  const expected = [];
  for (let i = 129; i >= 0; i--) if (i % 5 !== 0) expected.push(`u${String(i).padStart(3, '0')}`);
  assert.deepStrictEqual(ids, expected, 'todos, na ordem do mais recente');
  // Antes o filtro era local entre os 50 mais recentes: só 40 prestadores.
  // Tipos minoritários também paginam (8 a 9 de cada).
  const del = (await allPages(query(collection(as('adm'), 'users'), where('type', '==', 'deliverer'), orderBy('createdAt', 'desc')), 5)).flat();
  assert.strictEqual(del.length, 8);
  // Sem filtro: 132 (inclui os dois admins), em 3 páginas.
  assert.deepStrictEqual((await allPages(query(collection(as('adm'), 'users'), orderBy('createdAt', 'desc')), 50)).map((p) => p.length), [50, 50, 32]);
});

test('consultas paginadas do painel são permitidas ao admin e negadas a quem não é', async () => {
  const adm = as('adm');
  const page = (col, ...c) => getDocs(query(collection(adm, col), ...c, limit(50)));
  await assertSucceeds(page('support', where('status', '==', 'open'), orderBy('createdAt', 'desc')));
  await assertSucceeds(page('support', orderBy('createdAt', 'desc')));
  await assertSucceeds(page('reports', orderBy('createdAt', 'desc')));
  await assertSucceeds(page('auditLogs', orderBy('timestamp', 'desc')));
  await assertSucceeds(page('coupons', orderBy('createdAt', 'desc')));
  await assertSucceeds(page('providers', where('verified', '==', false)));
  await assertSucceeds(page('companies', where('verified', '==', false)));
  await assertSucceeds(page('orders', orderBy('createdAt', 'desc')));
  const first = await page('support', orderBy('createdAt', 'desc'));
  await assertSucceeds(getDocs(query(collection(adm, 'support'), orderBy('createdAt', 'desc'), startAfter(first.docs[0]), limit(50))));
  // Financeiro: só master/financeiro.
  await assertFails(page('refunds', orderBy('createdAt', 'desc')));
  await assertSucceeds(getDocs(query(collection(as('fin'), 'refunds'), orderBy('createdAt', 'desc'), limit(50))));
  // Não-admin.
  await assertFails(getDocs(query(collection(as('u001'), 'users'), where('type', '==', 'provider'), orderBy('createdAt', 'desc'), limit(50))));
  await assertFails(getDocs(query(collection(as('u001'), 'auditLogs'), orderBy('timestamp', 'desc'), limit(50))));
});
