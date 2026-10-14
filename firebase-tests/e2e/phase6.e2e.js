'use strict';
/**
 * E2E da Fase 6: caixa de entrada com perfil público mínimo, navegação por
 * notificação, "marcar todas como lidas", perfil do prestador em celular,
 * tablet e desktop, e retomada após login.
 *   firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
 *     "node firebase-tests/e2e/phase6.e2e.js <build/web> <saida> <firebase-js-sdk dir>"
 * Build: test_driver/e2e_phase6_main.dart.
 */
const path = require('path'); const http = require('http'); const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
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


async function waitDoc(ref, pred, ms = 20000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const s = await ref.get(); if (s.exists && (!pred || pred(s.data()))) return s.data(); await sleep(500); }
  return null;
}

(async () => {
  const em = (t) => `${t}${Date.now()}@t.dev`;
  const [cliE, proE] = [em('cli6'), em('pro6')];
  const [cli, pro] = [await signUp(cliE), await signUp(proE)];
  const K = `e2ef6${Date.now().toString(36)}`;
  const b = db.batch();
  // Perfis PRIVADOS com dados sensíveis (telefone, CPF, sobrenome completo).
  b.set(db.doc(`users/${cli.uid}`), { type: 'client', name: 'Maria Silva Souza', phone: '+5594999990000', cpf: '00000000000', email: cliE });
  b.set(db.doc(`users/${pro.uid}`), { type: 'provider', name: 'João Pereira Lima', phone: '+5594988887777', email: proE });
  b.set(db.doc(`providers/${pro.uid}`), { userId: pro.uid, name: 'Eletricista João P.', verified: true, active: true, categories: ['eletricista'], modalities: ['presential'], rating: 4.8, totalReviews: 12, city: 'Parauapebas', bio: 'Instalações residenciais.' });
  b.set(db.doc(`chatRooms/${K}`), { participants: [cli.uid, pro.uid], lastMsg: 'Olá, tudo bem?', lastMsgTime: new Date() });
  const t0 = Date.now();
  b.set(db.doc(`notifications/${K}_a`), { userId: cli.uid, title: 'Nova proposta recebida', body: 'Abra o pedido para comparar.', type: 'resolve', read: false, createdAt: new Date(t0), link: { route: 'resolveDetail', id: `rr_${K}` } });
  b.set(db.doc(`notifications/${K}_b`), { userId: cli.uid, title: 'Consulta confirmada', body: 'Veja seus agendamentos.', type: 'health', read: false, createdAt: new Date(t0 - 60000), link: { route: 'appointments' } });
  b.set(db.doc(`notifications/${K}_c`), { userId: cli.uid, title: 'Aviso antigo', body: 'Sem link.', type: 'order', read: false, createdAt: new Date(t0 - 120000) });
  await b.commit();

  const results = {}; global.__results = results;
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };

  // Perfis públicos mínimos criados pelos triggers.
  const pc = await waitDoc(db.doc(`publicProfiles/${cli.uid}`), (d) => d.name === 'Maria S.');
  const pp = await waitDoc(db.doc(`publicProfiles/${pro.uid}`), (d) => d.verified === true);
  const allowed = new Set(['name', 'photoUrl', 'kind', 'verified', 'updatedAt']);
  check('perfil_publico_minimo_cliente', pc && Object.keys(pc).every((k) => allowed.has(k)), JSON.stringify(pc));
  check('perfil_publico_prestador_verificado', pp && pp.name === 'Eletricista João P.', JSON.stringify(pp));

  const srv = serve(WEB, 8100);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const open = async (qs, w = 400, h = 900) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    global.__page = page;
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto(`http://localhost:8100/?${qs}`); await sleep(14000); return page;
  };
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, `${n}.png`) });
  const login = (e) => `email=${encodeURIComponent(e)}&pass=Senha123!`;

  // ── Caixa de entrada: nome público, nunca "Contato" nem dados privados ──
  const ic = await open(`${login(cliE)}&screen=inbox`);
  check('inbox_cliente_ve_nome_do_prestador', await waitText(ic, 'Eletricista João P.'));
  await shot(ic, '1_inbox_cliente');
  await ic.close();
  const ip = await open(`${login(proE)}&screen=inbox`);
  check('inbox_prestador_ve_nome_minimo', await waitText(ip, 'Maria S.'));
  const lp = (await labels(ip)).join(' | ');
  check('inbox_sem_contato_generico', !lp.includes('Contato'), lp.slice(0, 200));
  check('inbox_sem_dado_privado', !lp.includes('Souza') && !lp.includes('99999'), lp.slice(0, 200));
  await shot(ip, '2_inbox_prestador');
  await ip.close();

  // ── Notificações: o toque abre o destino do link e marca como lida ──
  const n = await open(`${login(cliE)}&screen=notifs`);
  await waitText(n, 'Nova proposta recebida');
  await shot(n, '3_notificacoes');
  await click(n, 'Nova proposta recebida', { wait: 3000 });
  check('notificacao_abre_pedido_do_link', await waitText(n, `DESTINO /resolve-detail {id: rr_${K}}`, 8000), JSON.stringify((await labels(n)).slice(0, 10)));
  check('notificacao_marcada_lida', (await db.doc(`notifications/${K}_a`).get()).data().read === true);
  await n.goBack().catch(() => {});
  await n.close();
  const n2 = await open(`${login(cliE)}&screen=notifs`);
  await waitText(n2, 'Aviso antigo');
  await click(n2, 'Aviso antigo', { wait: 3000 });
  check('notificacao_antiga_usa_tipo', await waitText(n2, 'DESTINO /my-orders', 8000) || await waitText(n2, 'DESTINO /orders', 2000), JSON.stringify((await labels(n2)).slice(0, 10)));
  await n2.close();
  const n3 = await open(`${login(cliE)}&screen=notifs`);
  await click(n3, 'Marcar todas como lidas', { wait: 4000 });
  const unread = (await db.collection('notifications').where('userId', '==', cli.uid).where('read', '==', false).get()).size;
  check('marcar_todas_como_lidas', unread === 0, `restantes=${unread}`);
  await n3.close();

  // ── Perfil do prestador: celular, tablet e desktop ──
  const sizes = [[360, 800, 'celular'], [800, 1100, 'tablet'], [1440, 900, 'desktop']];
  for (const [w, h, nome] of sizes) {
    const pg = await open(`${login(cliE)}&screen=profile&provider=${pro.uid}`, w, h);
    const ok = await waitText(pg, 'Eletricista João P.');
    const box = await findBox(pg, 'Solicitar serviço', false);
    const sw = await pg.evaluate(() => document.documentElement.scrollWidth);
    check(`perfil_${nome}`, ok && box && sw <= w, JSON.stringify({ box, sw }));
    if (nome === 'desktop') check('desktop_conteudo_centralizado', box && box.x > 260, JSON.stringify(box));
    await shot(pg, `4_perfil_${nome}`);
    await pg.close();
  }
  // Sem login: ações levam ao login guardando a retomada.
  const anon = await open(`screen=profile&provider=${pro.uid}`);
  await click(anon, 'Solicitar serviço', { wait: 3000 });
  check('sem_login_leva_ao_login', await waitText(anon, 'DESTINO /login', 8000));
  const pending = await anon.evaluate(() => localStorage.getItem('flutter.pending_route_v1'));
  check('retomada_guardada', pending && pending.includes(pro.uid) && pending.includes('provider-profile'), pending);
  await anon.close();

  console.log('RESULTS ' + JSON.stringify(results, null, 1));
  const failed = Object.values(results).filter((v) => v !== 'OK').length;
  await browser.close(); srv.close();
  process.exit(failed ? 1 : 0);
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
