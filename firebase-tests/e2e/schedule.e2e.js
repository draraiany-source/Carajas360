'use strict';
/**
 * E2E da Fase 5 (Saúde e Locação): agenda real → agendamento com
 * consentimento → reagendamento; reserva de locação com valor do servidor
 * → confirmação pelo anunciante.
 *   firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
 *     "node firebase-tests/e2e/schedule.e2e.js <build/web> <saida> <firebase-js-sdk dir>"
 * Build: test_driver/e2e_schedule_main.dart.
 */
const hc = require('../../functions/healthCore');
const path = require('path'); const http = require('http'); const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function signUp(email) {
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }) });
  const j = await r.json(); return { uid: j.localId, token: j.idToken };
}
async function call(name, u, data) {
  const r = await fetch(`${FN}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${u.token}` }, body: JSON.stringify({ data }) });
  const j = await r.json(); if (j.error) throw new Error(j.error.message); return j.result;
}
function serve(dir, port) {
  const t = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.otf': 'font/otf', '.ttf': 'font/ttf' };
  return http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); if (!fs.existsSync(f)) { r.statusCode = 404; return r.end(); } r.setHeader('Content-Type', t[path.extname(f)] || 'application/octet-stream'); fs.createReadStream(f).pipe(r); }).listen(port);
}
async function labels(page) {
  return page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics, input, textarea')).map((e) => (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.textContent || '').trim()).filter(Boolean));
}
async function findBox(page, text, exact) {
  return page.evaluate(({ text, exact }) => {
    const els = Array.from(document.querySelectorAll('flt-semantics, input, textarea'));
    // Menor elemento que casa (evita clicar no centro de um card inteiro).
    const hits = els.filter((e) => { const l = (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.textContent || '').trim(); return exact ? l === text : l.includes(text); })
      .map((e) => ({ e, r: e.getBoundingClientRect() })).filter((h) => h.r.width > 0 && h.r.height > 0)
      .sort((a, b) => a.r.width * a.r.height - b.r.width * b.r.height);
    if (!hits.length) return null; const r = hits[0].r; return { x: r.x + r.width / 2, y: r.y + r.height / 2 };
  }, { text, exact });
}
async function hasText(page, text) { return (await labels(page)).some((l) => l.includes(text)); }
async function waitText(page, text, ms = 20000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { if (await hasText(page, text)) return true; await sleep(500); }
  return false;
}
async function click(page, text, { exact = false, wait = 2500 } = {}) {
  let box = null;
  for (let i = 0; i < 20 && !box; i++) { box = await findBox(page, text, exact); if (!box) await sleep(500); }
  if (!box) { const ls = await labels(page); throw new Error('não encontrado: ' + text + ' | ' + JSON.stringify(ls.filter((l) => l.length < 80).slice(0, 60))); }
  await page.mouse.click(box.x, box.y); await sleep(wait);
}
async function typeInto(page, label, text) {
  await click(page, label, { wait: 800 });
  await page.keyboard.type(text, { delay: 25 });
  await sleep(800);
}

(async () => {
  const K = `e2ef5${Date.now().toString(36)}`;
  const em = (t) => `${t}${Date.now()}@t.dev`;
  const [patE, docE, ownE, renE] = [em('pac'), em('doc'), em('own'), em('ren')];
  const [pat, doc, own, ren] = [await signUp(patE), await signUp(docE), await signUp(ownE), await signUp(renE)];
  const weekly = {};
  for (let d = 0; d < 7; d++) weekly[d] = [{ start: '08:00', end: '12:00' }, { start: '14:00', end: '18:00' }];
  const b = db.batch();
  b.set(db.doc(`catalogNodes/${K}_saude`), { level: 'category', name: 'Saúde E2E', vertical: 'health', active: true, effectiveActive: true });
  b.set(db.doc(`catalogNodes/${K}_cardio`), { level: 'group', name: 'Cardiologia E2E', parentId: `${K}_saude`, active: true, effectiveActive: true });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  b.set(db.doc(`providers/${doc.uid}`), { userId: doc.uid, name: 'Dra. Ana E2E', verified: true, active: true, categories: [`${K}_cardio`], modalities: ['online', 'presential'] });
  b.set(db.doc(`healthSchedules/${doc.uid}`), { slotMinutes: 30, minLeadHours: 2, weekly, blockedDates: [], services: [{ catalogId: `${K}_cardio`, durationMin: 60, priceCents: 28000, modalities: ['online', 'presential'] }] });
  b.set(db.doc(`users/${ren.uid}`), { type: 'client', name: 'Locatário E2E' });
  b.set(db.doc(`rentals/${K}_car`), { ownerId: own.uid, ownerName: 'Locadora E2E', title: 'Hilux E2E', category: 'pickup', kind: 'vehicle', pricePerDay: 350, active: true, available: true, rating: 0, totalReviews: 0, photos: [], createdAt: new Date() });
  await b.commit();

  const srv = serve(WEB, 8100);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const results = {}; global.__results = results;
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };
  const open = async (qs, w = 1280, h = 1800) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    global.__page = page;
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto(`http://localhost:8100/?${qs}`); await sleep(14000); return page;
  };
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, `${n}.png`) });
  const tomorrow = hc.localDateOf(Date.now() + 86400000);
  const chip = `${tomorrow.slice(8)}/${tomorrow.slice(5, 7)}`;

  // ── Saúde: agendar com horário real e consentimento ──
  const p = await open(`email=${encodeURIComponent(patE)}&pass=Senha123!&screen=health&provider=${doc.uid}&catalogId=${K}_cardio`, 400, 1400);
  await click(p, chip);
  check('horarios_reais_da_agenda', await waitText(p, '09:00') && !(await hasText(p, '12:30')));
  await click(p, '09:00', { exact: true });
  await click(p, 'Online');
  await shot(p, '1_saude_horario');
  await click(p, 'Reservar e pagar', { wait: 3000 });
  check('sem_consentimento_nao_agenda', (await db.collection('appointments').where('clientId', '==', pat.uid).get()).empty);
  await click(p, 'Autorizo o uso');
  await click(p, 'Reservar e pagar', { wait: 5000 });
  // B15: o horário fica retido e o pagamento abre em seguida.
  check('retencao_com_prazo', await waitText(p, 'Pague até'));
  await shot(p, '1b_saude_pagar_ate');
  await click(p, 'Cartão de crédito', { wait: 4000 });
  await click(p, 'Pagar R$', { wait: 5000 });
  check('pagamento_reserva_aprovado', await waitText(p, 'Pagamento confirmado pelo banco'));
  const aps = (await db.collection('appointments').where('clientId', '==', pat.uid).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
  check('consulta_com_profissional_e_data', aps.length === 1 && aps[0].providerId === doc.uid && aps[0].date === tomorrow && hc.localHmOf(aps[0].startMs) === '09:00' && aps[0].consent.version === '2026-10', JSON.stringify(aps.map((a) => [a.date, a.startMs])));
  let ok = false;
  for (let i = 0; i < 30 && !ok; i++) { ok = (await db.doc(`appointments/${aps[0].id}`).get()).data().status === 'scheduled'; if (!ok) await sleep(500); }
  check('consulta_confirmada_apos_pagamento', ok);
  await p.close();

  // ── Saúde: reagendar pela lista ──
  const a = await open(`email=${encodeURIComponent(patE)}&pass=Senha123!&screen=appts`, 400, 1400);
  check('lista_agendamentos', await waitText(a, '09:00'));
  await shot(a, '2_saude_agendamentos');
  await click(a, 'Reagendar', { exact: true });
  await click(a, chip);
  await waitText(a, '15:00');
  await click(a, '15:00', { exact: true, wait: 5000 });
  const ap2 = (await db.doc(`appointments/${aps[0].id}`).get()).data();
  check('reagendado_no_servidor', hc.localHmOf(ap2.startMs) === '15:00' && ap2.rescheduleCount === 1);
  check('lista_atualizada', await waitText(a, '15:00'));
  await shot(a, '3_saude_reagendado');
  await a.close();

  // ── Locação: reserva com valor do servidor ──
  const r = await open(`email=${encodeURIComponent(renE)}&pass=Senha123!&screen=rental&rental=${K}_car`);
  await click(r, 'Reservar', { exact: true });
  check('cotacao_do_servidor', await waitText(r, 'valor calculado pelo servidor'));
  await shot(r, '4_locacao_reserva');
  await click(r, 'Reservar e pagar', { wait: 5000 });
  check('locacao_retida_com_prazo', await waitText(r, 'Pague até'));
  await click(r, 'Cartão de crédito', { wait: 4000 });
  await click(r, 'Pagar R$', { wait: 5000 });
  check('locacao_paga', await waitText(r, 'Pagamento confirmado pelo banco'));
  let bks = [];
  for (let i = 0; i < 30; i++) {
    bks = (await db.collection('bookings').where('clientId', '==', ren.uid).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
    if (bks[0] && bks[0].status === 'pending') break;
    await sleep(500);
  }
  check('reserva_criada_pelo_servidor', bks.length === 1 && bks[0].totalCents === 35000 && bks[0].status === 'pending' && bks[0].paymentStatus === 'approved', JSON.stringify(bks.map((x) => [x.totalCents, x.status, x.paymentStatus])));
  await r.close();
  const o = await open(`email=${encodeURIComponent(ownE)}&pass=Senha123!&screen=bookings`);
  await click(o, 'Recebi');
  check('anunciante_ve_reserva', await waitText(o, 'Hilux E2E'));
  await click(o, 'Confirmar', { exact: true, wait: 4000 });
  check('confirmada_no_servidor', (await db.doc(`bookings/${bks[0].id}`).get()).data().status === 'confirmed');
  check('notificacao_por_evento', (await db.collection('notifications').where('userId', '==', ren.uid).where('type', '==', 'rental').get()).size >= 1);
  await shot(o, '5_locacao_confirmada');

  console.log('RESULTS ' + JSON.stringify(results, null, 1));
  const failed = Object.values(results).filter((v) => v !== 'OK').length;
  await browser.close(); srv.close();
  process.exit(failed ? 1 : 0);
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
