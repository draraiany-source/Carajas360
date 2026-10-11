'use strict';
/**
 * E2E da Fase 3 (navegador + emuladores + gateway SIMULADO). Uso:
 *   firebase emulators:exec --project demo-carajas360 --only auth,firestore,storage,functions \
 *     "node firebase-tests/e2e/checkout.e2e.js <build/web> <saida> <firebase-js-sdk-12 dir>"
 * Build: test_driver/e2e_checkout_main.dart (ver cabeçalho do arquivo).
 * Nenhuma chamada ao Mercado Pago real: PAYMENTS_GATEWAY=fake no emulador.
 */
const path = require('path'); const http = require('http'); const fs = require('fs'); const crypto = require('crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
admin.initializeApp({ projectId: PROJECT });
const db = admin.firestore();
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
const SECRET = 'emulator-only-webhook-secret-not-a-real-credential';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function signUp(email) {
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }) });
  const j = await r.json(); return { uid: j.localId, token: j.idToken };
}
async function webhook(dataId) {
  const ts = Math.floor(Date.now() / 1000); const rid = crypto.randomUUID();
  const v1 = crypto.createHmac('sha256', SECRET).update(`id:${dataId};request-id:${rid};ts:${ts};`).digest('hex');
  const r = await fetch(`${FN}/paymentsWebhook?data.id=${dataId}&type=payment`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-signature': `ts=${ts},v1=${v1}`, 'x-request-id': rid }, body: JSON.stringify({ type: 'payment', data: { id: dataId } }) });
  return r.status;
}
function serve(dir, port) {
  const t = { '.js': 'text/javascript', '.html': 'text/html', '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png', '.svg': 'image/svg+xml', '.otf': 'font/otf', '.ttf': 'font/ttf' };
  return http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); if (!fs.existsSync(f)) { r.statusCode = 404; return r.end(); } r.setHeader('Content-Type', t[path.extname(f)] || 'application/octet-stream'); fs.createReadStream(f).pipe(r); }).listen(port);
}
async function labels(page) {
  return page.evaluate(() => Array.from(document.querySelectorAll('flt-semantics')).map((e) => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean));
}
async function findBox(page, text, exact) {
  return page.evaluate(({ text, exact }) => {
    const els = Array.from(document.querySelectorAll('flt-semantics'));
    // Menor elemento que casa (evita clicar no centro de um card inteiro).
    const hits = els.filter((e) => { const l = (e.getAttribute('aria-label') || e.textContent || '').trim(); return exact ? l === text : l.includes(text); })
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
const orders = async (uid) => (await db.collection('marketOrders').where('clientId', '==', uid).get()).docs.map((d) => ({ id: d.id, ...d.data() }));
const cartItems = async (uid) => ((await db.doc(`carts/${uid}`).get()).data() || { items: [] }).items;

(async () => {
  // Seed: duas lojas (multi-loja), um produto em cada.
  const owner = await signUp(`dono${Date.now()}@t.dev`);
  const email = `cliente${Date.now()}@t.dev`;
  const cli = await signUp(email);
  await db.doc('stores/e2e_a').set({ ownerId: owner.uid, name: 'Mercado Alfa', active: true, deliveryFeeCents: 700, pickupEnabled: true, deliveryEnabled: true });
  await db.doc('stores/e2e_b').set({ ownerId: owner.uid, name: 'Farmácia Beta', active: true, deliveryFeeCents: 300, pickupEnabled: true, deliveryEnabled: true });
  await db.doc('products/e2e_arroz').set({ storeId: 'e2e_a', storeName: 'Mercado Alfa', name: 'Arroz E2E 5kg', price: 25, stock: 10, active: true, category: 'market', emoji: '🌾', rating: 5, createdAt: new Date() });
  await db.doc('products/e2e_vitamina').set({ storeId: 'e2e_b', storeName: 'Farmácia Beta', name: 'Vitamina E2E', price: 10, stock: 10, active: true, category: 'pharmacy', emoji: '💊', rating: 5, createdAt: new Date() });

  const srv = serve(WEB, 8098);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 1800 } });
  global.__page = page;
  page.on('console', (m) => { console.log('BROWSER_' + m.type(), m.text().slice(0, 300)); });
  await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
  const url = `http://localhost:8098/?email=${encodeURIComponent(email)}&pass=Senha123!`;
  const results = {}; global.__results = results;
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`; };
  const shot = (n) => page.screenshot({ path: path.join(OUT, `${n}.png`) });

  await page.goto(url); await sleep(14000);
  check('vitrine', await waitText(page, 'Arroz E2E 5kg') && await hasText(page, 'Vitamina E2E'));
  await click(page, '+ Adicionar', { exact: true }); await click(page, '+ Adicionar', { exact: true });
  await sleep(2000);
  const synced = await cartItems(cli.uid);
  check('carrinho_sincronizado_na_conta', synced.length === 2, JSON.stringify(synced));
  await shot('1_vitrine_carrinho');

  // Fechar/atualizar: o carrinho continua.
  await page.goto(url); await sleep(16000);
  check('carrinho_preservado_apos_recarregar', await waitText(page, 'Finalizar pedido'));
  await click(page, 'Finalizar pedido');
  check('multiloja_aviso', await waitText(page, 'lojas diferentes'));
  await shot('2_carrinho_multiloja');

  // Loja 1: retirada + cartão (simulador)
  await click(page, 'Finalizar pedido desta loja');
  await click(page, 'Retirada');
  check('cotacao_servidor', await waitText(page, 'Total'));
  await shot('3_checkout_cotacao');
  await click(page, 'Criar pedido e escolher pagamento', { wait: 5000 });
  let os = await orders(cli.uid);
  check('pedido_criado_antes_da_cobranca', os.length === 1 && os[0].status === 'pending_payment' && !(await db.collection('paymentAttempts').where('targetId', '==', os[0].id).get()).size, JSON.stringify(os.map((o) => o.status)));
  check('tela_pedido_aguardando', await waitText(page, 'Aguardando pagamento'));
  await shot('4_pedido_aguardando');
  const first = os[0];
  await click(page, 'Cartão de crédito');
  await shot('5_cartao_simulado');
  await click(page, 'Pagar R$', { wait: 4000 });
  check('cartao_aprovado_pelo_servidor', await waitText(page, 'Pagamento confirmado pelo banco'));
  await shot('6_cartao_aprovado');
  os = await orders(cli.uid);
  const paid = os.find((o) => o.id === first.id);
  check('pedido_pago_no_firestore', paid.status === 'paid' && paid.paymentStatus === 'approved', `${paid.status}/${paid.paymentStatus}`);
  await click(page, 'Continuar');
  check('acompanhamento_pago', await waitText(page, 'Pago — aguardando a loja'));
  await sleep(2000);
  const left = await cartItems(cli.uid);
  check('carrinho_remove_so_itens_pagos', left.length === 1 && left[0].storeId !== first.storeId, JSON.stringify(left));
  await shot('7_pedido_pago');

  // Loja 2: Pix; confirmação chega pelo webhook (sem ação no app).
  await click(page, 'Back');
  await click(page, 'Finalizar pedido desta loja');
  await click(page, 'Retirada');
  await waitText(page, 'Total');
  await click(page, 'Criar pedido e escolher pagamento', { wait: 5000 });
  await click(page, 'Pix');
  check('pix_qr_e_copia_cola', await waitText(page, 'Pix copia e cola') && await waitText(page, 'Vence em'));
  await shot('8_pix_aguardando');
  os = await orders(cli.uid);
  const pixOrder = os.find((o) => o.id !== first.id);
  const att = (await db.doc(`paymentAttempts/${pixOrder.activeAttemptId}`).get()).data();
  check('pix_usa_id_persistido', att.targetId === pixOrder.id);
  await db.doc(`_fakeGateway/${att.gatewayPaymentId}`).update({ status: 'approved', status_detail: 'accredited', date_last_updated: new Date(Date.now() + 60000).toISOString() });
  const st = await webhook(att.gatewayPaymentId);
  check('webhook_aceito', st === 200, String(st));
  check('pix_confirmado_na_tela_via_servidor', await waitText(page, 'Pagamento confirmado pelo banco', 25000));
  await shot('9_pix_confirmado');
  check('carrinho_vazio_apos_pagamentos', await (async () => { await sleep(1500); await click(page, 'Continuar'); await sleep(1500); return (await cartItems(cli.uid)).length === 0; })());

  // Celular: histórico de pedidos
  const mob = await browser.newPage({ viewport: { width: 400, height: 900 } });
  await mob.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
  await mob.goto(`${url}&screen=orders`); await sleep(14000);
  check('mobile_historico', await waitText(mob, 'Mercado Alfa') && await hasText(mob, 'Farmácia Beta'));
  await mob.screenshot({ path: path.join(OUT, '10_mobile_historico.png') });

  console.log('RESULTS ' + JSON.stringify(results, null, 1));
  const failed = Object.values(results).filter((v) => v !== 'OK').length;
  await browser.close(); srv.close();
  process.exit(failed ? 1 : 0);
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
