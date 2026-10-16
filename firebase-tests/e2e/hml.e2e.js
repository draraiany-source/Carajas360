'use strict';
/**
 * E2E da etapa de homologação: "Meus chamados" (conversa com o suporte),
 * modo manutenção (usuário bloqueado, admin liberado) e recusa de
 * prestador com pedido de nova análise.
 * Build: test_driver/e2e_hml_main.dart.
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


async function waitDoc(ref, pred, ms = 20000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const s = await ref.get(); if (s.exists && (!pred || pred(s.data()))) return s.data(); await sleep(500); }
  return null;
}

(async () => {
  const em = (t) => `${t}${Date.now()}@t.dev`;
  const [cliE, admE, proE] = [em('cli7'), em('adm7'), em('pro7')];
  const [cli, adm, pro] = [await signUp(cliE), await signUp(admE), await signUp(proE)];
  await db.doc(`users/${cli.uid}`).set({ type: 'client', name: 'Rita Souza' });
  await db.doc(`users/${adm.uid}`).set({ type: 'admin', adminRole: 'support', name: 'Suporte' });
  await db.doc(`users/${pro.uid}`).set({ type: 'provider', name: 'Paulo Pintor' });
  await db.doc(`providers/${pro.uid}`).set({ userId: pro.uid, name: 'Paulo Pintor', verified: false, active: false, categories: ['pintor'], rating: 0, totalReviews: 0 });
  const t = await db.collection('support').add({ userId: cli.uid, userName: 'Rita', subject: 'Pagamento em dobro', message: 'Fui cobrada duas vezes no pedido.', status: 'open', priority: 'normal', createdAt: new Date() });
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
    // O aviso "Running in emulator mode" do SDK cobre a barra inferior (campo de resposta).
    await page.addStyleTag({ content: '.firebase-emulator-warning{display:none!important}' }).catch(() => {});
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

  // ── Meus chamados: cliente responde; suporte responde; cliente vê ──
  const tk = await open(`${login(cliE)}&screen=tickets`);
  check('lista_meus_chamados', await waitText(tk, 'Pagamento em dobro'));
  await click(tk, 'Pagamento em dobro', { wait: 3000 });
  check('detalhe_mostra_mensagem_original', await waitText(tk, 'Fui cobrada duas vezes'));
  await typeInto(tk, 'Escreva sua mensagem', 'Segue o comprovante.');
  await click(tk, 'Enviar', { exact: true, wait: 3000 });
  const mine = await waitDoc(t, () => true) && (await t.collection('messages').where('authorId', '==', cli.uid).get());
  check('mensagem_do_cliente_gravada', mine && mine.size === 1 && mine.docs[0].data().authorRole === 'user');
  await t.collection('messages').add({ authorId: adm.uid, authorRole: 'support', text: 'Estornamos a segunda cobrança.', createdAt: new Date() });
  check('cliente_ve_resposta_do_suporte', await waitText(tk, 'Estornamos a segunda cobrança'));
  check('chamado_respondido', Boolean(await waitDoc(t, (d) => d.status === 'answered')));
  await shot(tk, '1_chamado_conversa');
  await tk.close();

  // ── Modo manutenção ──
  await db.doc('config/platform').set({ maintenanceMode: true, maintenanceMessage: 'Voltamos às 14h.' }, { merge: true });
  const g1 = await open(`${login(cliE)}&screen=gate`);
  check('usuario_bloqueado_na_manutencao', await waitText(g1, 'Estamos em manutenção') && await waitText(g1, 'Voltamos às 14h') && !(await hasText(g1, 'APP LIBERADO')));
  await shot(g1, '2_manutencao_usuario');
  await g1.close();
  const g2 = await open(`${login(admE)}&screen=gate`);
  check('admin_liberado_com_aviso', await waitText(g2, 'APP LIBERADO') && await waitText(g2, 'Modo manutenção ativo'));
  await shot(g2, '3_manutencao_admin');
  await g2.close();
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });

  // ── Recusa de prestador e nova análise ──
  await call('reviewProvider', adm, { providerId: pro.uid, decision: 'reject', reason: 'Foto do documento ilegível' });
  const ph = await open(`${login(proE)}&screen=providerHome`);
  check('prestador_ve_motivo_da_recusa', await waitText(ph, 'Cadastro não aprovado: Foto do documento ilegível'));
  await shot(ph, '4_prestador_recusado');
  await click(ph, 'Pedir nova análise', { wait: 4000 });
  check('nova_analise_solicitada', Boolean(await waitDoc(db.doc(`providers/${pro.uid}`), (d) => d.verificationStatus === 'pending_review')));
  check('banner_em_analise', await waitText(ph, 'Seu cadastro está em análise'));
  await shot(ph, '5_prestador_em_analise');
  await ph.close();
  await finish();
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
