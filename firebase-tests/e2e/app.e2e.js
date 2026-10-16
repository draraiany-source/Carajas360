'use strict';
/**
 * E2E do aplicativo REAL (lib/main.dart, dev/emulador): visitante navega
 * pelo catálogo público sem login; ações protegidas pedem login.
 */
const path = require('path'); const http = require('http'); const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
async function call(name, u, data) {
  const r = await fetch(`${FN}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${u.token}` }, body: JSON.stringify({ data }) });
  const j = await r.json(); if (j.error) throw new Error(j.error.message); return j.result;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function signUp(email) {
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }) });
  const j = await r.json(); return { uid: j.localId, token: j.idToken };
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
  const pro = await signUp(`proapp${Date.now()}@t.dev`);
  await db.doc(`providers/${pro.uid}`).set({ userId: pro.uid, name: 'Marcos Eletricista Público', verified: true, active: true, categories: ['eletricista'], modalities: ['presential'], rating: 4.7, totalReviews: 8, city: 'Marabá' });
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });

  const results = {}; global.__results = results;
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };
  const srv = serve(WEB, 8100);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const open = async (qs, w = 400, h = 900) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    global.__page = page;
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto(`http://localhost:8100/?${qs}`); await sleep(14000);
    // App real: liga a árvore de acessibilidade do Flutter web como um leitor
    // de tela faria (botão "Enable accessibility") e esconde o aviso do emulador.
    await page.evaluate(() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); });
    await page.addStyleTag({ content: '.firebase-emulator-warning{display:none!important}' }).catch(() => {});
    await sleep(1500);
    return page;
  };
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, `${n}.png`) });
  const login = (e) => `email=${encodeURIComponent(e)}&pass=Senha123!`;
  const finish = async () => {
    console.log('RESULTS ' + JSON.stringify(results, null, 1));
    const failed = Object.values(results).filter((v) => v !== 'OK').length;
    await browser.close(); srv.close();
    process.exit(failed ? 1 : 0);
  };

  const p = await open('', 400, 900);
  await sleep(6000); // splash
  check('visitante_ve_opcao_explorar', await waitText(p, 'Explorar sem entrar', 25000), JSON.stringify((await labels(p)).slice(0, 15)));
  await shot(p, '1_onboarding_explorar');
  await click(p, 'Explorar sem entrar', { exact: true, wait: 6000 });
  const ls = (await labels(p)).join(' | ');
  check('visitante_entra_no_app_sem_login', !/Entrar com Google|Senha/.test(ls) && /Início|Inicio|Serviços|Buscar/.test(ls), ls.slice(0, 300));
  await shot(p, '2_home_visitante');
  // Ação protegida pede login (aba Pedidos mostra convite para entrar).
  await click(p, 'Pedidos', { wait: 4000 });
  check('acao_protegida_pede_login', await waitText(p, 'Entrar', 8000), JSON.stringify((await labels(p)).slice(0, 20)));
  await shot(p, '3_pedidos_pede_login');
  await p.close();
  await finish();
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
