'use strict';
/**
 * E2E da Fase 4 (Resolve): questionário → matching no servidor → proposta
 * → aceite transacional → pedido contratado → pagamento (gateway SIMULADO).
 *   firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
 *     "node firebase-tests/e2e/resolve.e2e.js <build/web> <saida> <firebase-js-sdk dir>"
 * Build: test_driver/e2e_resolve_main.dart.
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
  const K = `e2er4${Date.now().toString(36)}`;
  const cliEmail = `cli${Date.now()}@t.dev`; const proEmail = `pro${Date.now()}@t.dev`; const farEmail = `far${Date.now()}@t.dev`;
  const [cli, pro, far] = [await signUp(cliEmail), await signUp(proEmail), await signUp(farEmail)];
  const b = db.batch();
  b.set(db.doc(`catalogNodes/${K}_casa`), { level: 'category', name: 'Casa E2E', icon: '🏠', active: true, effectiveActive: true, order: 1 });
  b.set(db.doc(`catalogNodes/${K}_ele`), { level: 'group', name: 'Elétrica E2E', icon: '⚡', parentId: `${K}_casa`, active: true, effectiveActive: true, order: 1 });
  b.set(db.doc(`catalogNodes/${K}_tom`), { level: 'service', name: 'Tomadas E2E', icon: '🔌', parentId: `${K}_ele`, active: true, effectiveActive: true, order: 1, questionnaireId: `${K}_q` });
  b.set(db.doc(`serviceQuestionnaires/${K}_q`), { serviceId: `${K}_tom`, title: 'Sobre as tomadas', status: 'published', version: 1, questions: [
    { id: 'tipo', type: 'single_choice', label: 'O que precisa?', required: true, options: ['Instalar', 'Consertar'], showIf: null },
    { id: 'qtd', type: 'number', label: 'Quantas tomadas?', required: true, options: [], showIf: { questionId: 'tipo', op: 'equals', value: 'Instalar' } },
    { id: 'defeito', type: 'long_text', label: 'Qual o defeito?', required: true, options: [], showIf: { questionId: 'tipo', op: 'equals', value: 'Consertar' } },
  ] });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  b.set(db.doc(`users/${cli.uid}`), { type: 'client', name: 'Cliente E2E' });
  b.set(db.doc(`providers/${pro.uid}`), { userId: pro.uid, name: 'Eletricista Perto', verified: true, active: true, categories: [`${K}_tom`], modalities: ['presential'], city: 'Canaã dos Carajás', rating: 4.8, totalReviews: 12 });
  b.set(db.doc(`providers/${far.uid}`), { userId: far.uid, name: 'Eletricista Belém', verified: true, active: true, categories: [`${K}_tom`], modalities: ['presential'], city: 'Belém', rating: 5, totalReviews: 40 });
  await b.commit();

  const srv = serve(WEB, 8099);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const results = {}; global.__results = results;
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };
  const open = async (qs, w = 1280, h = 2200) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    global.__page = page;
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto(`http://localhost:8099/?${qs}`); await sleep(14000); return page;
  };
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, `${n}.png`) });

  // 1. Cliente: questionário condicional + envio.
  const c = await open(`email=${encodeURIComponent(cliEmail)}&pass=Senha123!&screen=new&catalogId=${K}_tom`);
  check('questionario_carregado', await waitText(c, 'Sobre as tomadas') && await hasText(c, 'O que precisa?'));
  check('condicional_oculta_antes', !(await hasText(c, 'Quantas tomadas?')) && !(await hasText(c, 'Qual o defeito?')));
  await click(c, 'Instalar', { exact: true });
  check('condicional_aparece', await waitText(c, 'Quantas tomadas?') && !(await hasText(c, 'Qual o defeito?')));
  await typeInto(c, 'Quantas tomadas?', '4');
  await typeInto(c, 'Ex.: Preciso instalar', 'Instalar 4 tomadas novas na cozinha');
  await shot(c, '1_questionario');
  await click(c, 'Pedir orçamento', { wait: 6000 });
  const reqs = (await db.collection('resolveRequests').where('clientId', '==', cli.uid).get()).docs;
  check('solicitacao_criada_pelo_servidor', reqs.length === 1 && reqs[0].data().answers.qtd === 4 && reqs[0].data().answers.tipo === 'Instalar', JSON.stringify(reqs.map((d) => d.data().answers)));
  const reqId = reqs[0] && reqs[0].id;
  check('tela_detalhe_aguardando', await waitText(c, 'aguardando propostas'));
  await shot(c, '2_aguardando_propostas');

  // 2. Matching: só o prestador da cidade vê; notificação por evento.
  const okList = await call('listResolveOpportunities', pro, {});
  const farList = await call('listResolveOpportunities', far, {});
  check('matching_regiao', okList.items.some((i) => i.id === reqId) && !farList.items.some((i) => i.id === reqId));
  const mob = await open(`email=${encodeURIComponent(proEmail)}&pass=Senha123!&screen=opps`, 400, 1200);
  check('oportunidade_com_respostas', await waitText(mob, 'Quantas tomadas?: 4'));
  await shot(mob, '3_oportunidade_prestador_mobile');
  await mob.close();
  await call('submitResolveProposal', pro, { requestId: reqId, price: 240, deadlineDays: 2, message: 'Levo o material' });

  // 3. Aceite transacional pela tela + contratação.
  check('proposta_na_tela', await waitText(c, 'Eletricista Perto'));
  await click(c, 'Aceitar', { exact: true, wait: 1500 });
  await shot(c, '4_confirmar_aceite');
  // diálogo: o botão "Aceitar" do diálogo é o menor elemento com o rótulo
  await click(c, 'Aceitar', { exact: true, wait: 6000 });
  check('pedido_contratado_na_tela', await waitText(c, 'Pedido contratado'));
  const order = (await db.doc(`orders/rs_${reqId}`).get()).data();
  check('pedido_operacional_criado', order && order.priceCents === 24000 && order.providerId === pro.uid && order.status === 'accepted');
  check('chat_e_agenda_vinculados', (await db.doc(`chatRooms/${order.chatRoomId}`).get()).exists && (await db.doc(`scheduleEntries/rs_${reqId}`).get()).exists);
  await shot(c, '5_contratado');

  // 4. Pagamento do serviço (cartão simulado).
  await click(c, 'Pagar', { exact: true });
  await click(c, 'Cartão de crédito');
  await click(c, 'Pagar R$', { wait: 5000 });
  check('pagamento_confirmado_servidor', await waitText(c, 'Pagamento confirmado pelo banco'));
  check('pedido_pago_firestore', (await db.doc(`orders/rs_${reqId}`).get()).data().paymentStatus === 'paid');
  await shot(c, '6_pago');

  console.log('RESULTS ' + JSON.stringify(results, null, 1));
  const failed = Object.values(results).filter((v) => v !== 'OK').length;
  await browser.close(); srv.close();
  process.exit(failed ? 1 : 0);
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
