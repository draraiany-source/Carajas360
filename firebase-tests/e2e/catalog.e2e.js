'use strict';
/**
 * E2E da Fase 2 (navegador + emuladores). Uso:
 *   firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
 *     "node firebase-tests/e2e/catalog.e2e.js <build/web> <saida> <firebase-js-sdk-12 dir>"
 * O 3º argumento serve o SDK JS do Firebase localmente quando gstatic.com é bloqueado.
 */
const path = require('path'); const http = require('http'); const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK, MODE] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function signUp() {
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: `adm${Date.now()}@t.dev`, password: 'Senha123!', returnSecureToken: true }) });
  const j = await r.json(); return { uid: j.localId, token: j.idToken };
}
async function call(name, u, data) {
  const r = await fetch(`http://127.0.0.1:5001/${PROJECT}/us-central1/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${u.token}` }, body: JSON.stringify({ data }) });
  const j = await r.json(); if (j.error) throw new Error(j.error.message); return j.result;
}
function serve(dir, port) {
  const t = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.otf': 'font/otf', '.ttf': 'font/ttf' };
  return http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); if (!fs.existsSync(f)) { r.statusCode = 404; return r.end(); } r.setHeader('Content-Type', t[path.extname(f)] || 'application/octet-stream'); fs.createReadStream(f).pipe(r); }).listen(port);
}

async function seed() {
  const adm = await signUp();
  await db.doc(`users/${adm.uid}`).set({ type: 'admin' });
  await call('migrateCatalogV1', adm, { dryRun: false });
  const prov = (id, name, cats, rating, extra = {}) => db.doc(`providers/${id}`).set({ userId: id, name, categories: cats, rating, totalReviews: 5, verified: true, active: true, modalities: ['presential'], ...extra });
  await prov('p_adv', 'Paula Advogada', ['advogado'], 4.8);
  await prov('p_mec', 'Marcos Mecanico', ['mecanico'], 4.6);
  await prov('p_faxina', 'Rita Limpeza Total', ['diarista'], 4.7);
  await prov('p_ar', 'Clima Frio Instalações', ['svc_ar_instalacao'], 4.5);
  await prov('p_jose', 'José Ávila', ['pintor'], 4.2);
  await prov('p_autoel', 'Baterias do Beto', ['grp_auto_eletrica'], 4.4);
  await prov('p_pend', 'Pendente Nao Aprovado', ['eletricista'], 5, { verified: false, active: false });
  const b = db.batch();
  for (let i = 0; i < 45; i++) b.set(db.doc(`providers/el_${String(i).padStart(2, '0')}`), { userId: `el_${i}`, name: `Eletricista Numero ${i}`, categories: ['eletricista'], rating: 4.99 - i * 0.02, totalReviews: i, verified: true, active: true, modalities: ['presential'] });
  await b.commit();
  // aguarda índices (gatilho onProviderIndex)
  for (let k = 0; k < 60; k++) { const d = (await db.doc('providers/el_44').get()).data(); if (d.searchTokens) break; await sleep(500); }
  await sleep(1500);
  return adm;
}

async function labels(page) {
  return page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics[aria-label], [role][aria-label], flt-semantics')).map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean));
}
async function findBox(page, text, exact) {
  return page.evaluate(({ text, exact }) => {
    const els = Array.from(document.querySelectorAll('flt-semantics'));
    const el = els.find((e) => { const l = (e.getAttribute('aria-label') || e.textContent || '').trim(); return exact ? l === text : l.includes(text); });
    if (!el) return null; const r = el.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width };
  }, { text, exact });
}
async function clickLabel(page, text, { exact = false, row } = {}) {
  const W = page.viewportSize().width;
  let box = await findBox(page, text, exact);
  if (!box && row) {
    for (const dir of [300, -300]) {
      for (let i = 0; i < 14 && !box; i++) {
        const moved = await page.evaluate(({ row, dir }) => {
          const els = Array.from(document.querySelectorAll('flt-semantics'));
          let el = els.find((e) => (e.getAttribute('aria-label') || e.textContent || '').trim() === row);
          while (el && !(el.scrollWidth > el.clientWidth + 5)) el = el.parentElement;
          if (!el) return false;
          el.scrollLeft += dir; el.dispatchEvent(new Event('scroll'));
          return true;
        }, { row, dir });
        if (!moved) break;
        await sleep(500);
        box = await findBox(page, text, exact);
      }
      if (box) break;
    }
  }
  for (let i = 0; i < 12 && box && (box.x < 30 || box.x > W - 30); i++) {
    await page.mouse.move(W / 2, box.y);
    await page.mouse.wheel(box.x > W - 30 ? 250 : -250, 0);
    await sleep(400);
    box = await findBox(page, text, exact);
  }
  if (!box) { const ls = await labels(page); throw new Error('não encontrado: ' + text + ' | ' + JSON.stringify(ls.filter((l) => l.length < 60).slice(0, 80))); }
  await page.mouse.click(box.x, box.y); await sleep(2500);
}
async function hasText(page, text) { return (await labels(page)).some((l) => l.includes(text)); }

(async () => {
  const adm = await seed();
  const srv = serve(WEB, 8097);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const results = {};
  const open = async (screen, w, h) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto(`http://localhost:8097/?screen=${screen}`); await sleep(14000); return page;
  };
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };
  const names = ['Paula Advogada', 'Marcos Mecanico', 'Rita Limpeza Total', 'Clima Frio', 'José Ávila', 'Baterias do Beto', 'Pendente Nao Aprovado', 'Eletricista Numero 0'];
  const visible = async (page) => { const ls = await labels(page); return names.filter((n) => ls.some((l) => l.includes(n))); };

  // ── HUB (mobile) ─────────────────────────
  const mob = await open('hub', 400, 2400);
  await mob.screenshot({ path: path.join(OUT, 'mobile_hub.png') });
  check('mobile_render', (await visible(mob)).length > 0 && (await hasText(mob, 'Casa e Reformas')));
  await mob.close();
  const hub = await open('hub', 1280, 2600);
  await hub.screenshot({ path: path.join(OUT, 'hub_0_todos.png') });
  let v = await visible(hub);
  check('hub_todos_sem_pendente', !v.includes('Pendente Nao Aprovado') && v.length > 0, JSON.stringify(v));
  await clickLabel(hub, 'Casa e Reformas', { exact: true });
  v = await visible(hub); await hub.screenshot({ path: path.join(OUT, 'hub_1_casa.png') });
  check('hub_casa', v.includes('Eletricista Numero 0') && !v.includes('Paula Advogada') && !v.includes('Marcos Mecanico') && !v.includes('Rita Limpeza Total') && !v.includes('Baterias do Beto'), JSON.stringify(v));
  await clickLabel(hub, 'Automóveis', { exact: true });
  v = await visible(hub); await hub.screenshot({ path: path.join(OUT, 'hub_2_automoveis.png') });
  check('hub_automoveis', v.includes('Marcos Mecanico') && v.includes('Baterias do Beto') && !v.includes('José Ávila') && !v.includes('Paula Advogada'), JSON.stringify(v));
  await clickLabel(hub, 'Mecânica', { exact: true });
  v = await visible(hub); await hub.screenshot({ path: path.join(OUT, 'hub_3_mecanica.png') });
  check('hub_mecanica', v.includes('Marcos Mecanico') && !v.includes('Baterias do Beto'), JSON.stringify(v));
  await clickLabel(hub, 'Jurídico e Contabilidade', { exact: true, row: 'Automóveis' });
  v = await visible(hub); await hub.screenshot({ path: path.join(OUT, 'hub_4_juridico.png') });
  check('hub_juridico_limpa_grupo', v.includes('Paula Advogada') && !v.includes('Marcos Mecanico') && !(await hasText(hub, 'Freios')), JSON.stringify(v));

  // Admin cria serviço → aparece sem recarregar
  await clickLabel(hub, 'Automóveis', { exact: true, row: 'Jurídico e Contabilidade' });
  await clickLabel(hub, 'Mecânica', { exact: true });
  const before = await hasText(hub, 'Alinhamento');
  await call('catalogUpsert', adm, { isNew: true, node: { id: 'svc_alinhamento', level: 'service', name: 'Alinhamento e balanceamento', parentId: 'mecanico', icon: '🛞', commercialModel: 'fixed' } });
  await sleep(4000);
  const after = await hasText(hub, 'Alinhamento');
  await hub.screenshot({ path: path.join(OUT, 'hub_5_admin_novo_servico.png') });
  check('admin_cadastro_aparece_ao_vivo', !before && after);
  // Desativar remove das seleções
  await call('catalogSetActive', adm, { id: 'svc_alinhamento', active: false });
  await sleep(4000);
  check('admin_desativar_remove_selecao', !(await hasText(hub, 'Alinhamento')));
  await hub.close();

  // ── BUSCA (mobile) ───────────────────────
  const search = await open('search', 1280, 16000);
  const type = async (txt) => {
    const box = await search.evaluate(() => { const e = document.querySelector('input, textarea, flt-semantics[role="textbox"]'); if (!e) return null; const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; });
    await search.mouse.click(box ? box.x : 200, box ? box.y : 28);
    await search.keyboard.press('Control+A'); await search.keyboard.press('Backspace');
    await search.keyboard.type(txt, { delay: 30 }); await sleep(4000);
  };
  for (const [q, expect, label] of [
    ['faxina', 'Rita Limpeza Total', 'sinonimo_faxina'],
    ['ar-condicionado', 'Clima Frio', 'hifen_ar_condicionado'],
    ['ar condicionado', 'Clima Frio', 'espaco_ar_condicionado'],
    ['autoelétrico', 'Baterias do Beto', 'acento_autoeletrico'],
    ['auto eletrica', 'Baterias do Beto', 'auto_eletrica'],
    ['jose', 'José Ávila', 'nome_sem_acento'],
  ]) {
    await type(q);
    const ok = await hasText(search, expect);
    check(`busca_${label}`, ok);
    await search.screenshot({ path: path.join(OUT, `busca_${label}.png`) });
  }
  // Paginação: "eletricista" → 45 profissionais; o nº 44 só aparece após mais páginas
  await type('eletricista');
  const firstPage = await hasText(search, 'Eletricista Numero 44');
  const firstHas0 = await hasText(search, 'Eletricista Numero 0');
  const countNums = async () => (await labels(search)).join('|').match(/Eletricista Numero \d+/g)?.filter((v, i, a) => a.indexOf(v) === i).length || 0;
  console.log('PAGE1_COUNT', await countNums());
  for (let i = 0; i < 4 && !(await hasText(search, 'Eletricista Numero 44')); i++) {
    await clickLabel(search, 'Carregar mais', { exact: true });
  }
  const found = await hasText(search, 'Eletricista Numero 44');
  console.log('FINAL_COUNT', await countNums());
  check('paginacao_fora_da_primeira_pagina', firstHas0 && !firstPage && found, `p0=${firstHas0} primeira=${firstPage} achou=${found}`);
  await search.screenshot({ path: path.join(OUT, 'busca_paginacao.png'), fullPage: false });
  await search.close();

  // ── BUSCA no celular ─────────────────────
  const ms = await open('search', 400, 1600);
  await ms.screenshot({ path: path.join(OUT, 'mobile_busca.png') });
  check('mobile_busca_render', (await visible(ms)).length > 0);
  await ms.close();

  console.log('RESULTS ' + JSON.stringify(results, null, 1));
  await browser.close(); srv.close();
})().catch((e) => { console.error('E2E_FAIL', e); process.exit(1); });
