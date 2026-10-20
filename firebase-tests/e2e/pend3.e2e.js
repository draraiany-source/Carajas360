'use strict';
/**
 * E2E pend3 no aplicativo REAL (lib/main.dart, dev/emulador): correções da
 * etapa pend3 vistas pelo usuário.
 *  1. Mercado: só produtos de loja ativa+aprovada na vitrine; item de loja
 *     que é desativada fica "Indisponível" no carrinho e bloqueia "Finalizar".
 *  2. Prestador: pedido pendente vencido mostra "Expirado" (aceite
 *     desabilitado); pedido válido mostra "Expira em".
 *  3. Admin › Usuários: filtro por tipo + "Carregar mais" (2ª página).
 *  4. Perfil de cliente: "Quero ser prestador" abre o fluxo.
 *  5. Chat: anexo novo (mediaPath) pedido por getChatMediaUrl, sem link com token.
 *  6. Admin › Configurações: "Migrações de dados" › Mercado › Simular.
 * O app real não tem login por parâmetro: entra pela tela de login (e-mail)
 * e navega por rota (#/rota), como um link aberto no navegador.
 */
const path = require('path'); const http = require('http'); const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const [WEB, OUT, SDK] = process.argv.slice(2);
const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const BUCKET = `${PROJECT}.appspot.com`;
admin.initializeApp({ projectId: PROJECT, storageBucket: BUCKET });
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
    const ok = (e) => { const l = (e.getAttribute('aria-label') || e.getAttribute('placeholder') || e.textContent || '').trim(); return exact ? l === text : l.includes(text); };
    // Só o nó mais interno que casa: contêineres herdam o texto dos filhos
    // (textContent) e cobrem a tela toda, inclusive o que está fora dela.
    const hits = els.filter((e) => ok(e) && !Array.from(e.querySelectorAll('flt-semantics')).some(ok))
      .map((e) => ({ e, r: e.getBoundingClientRect() })).filter((h) => h.r.width > 0 && h.r.height > 0 && h.r.y + h.r.height / 2 < innerHeight && h.r.y + h.r.height / 2 > 0)
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
/**
 * Botões (role=button) cujo rótulo casa: [{label, disabled, x, y}]. O
 * Flutter web marca botão sem onPressed com aria-disabled="true".
 */
async function buttons(page, text, exact) {
  return page.evaluate(({ text, exact }) => Array.from(document.querySelectorAll('flt-semantics[role="button"], [role="button"]'))
    .map((e) => ({ e, l: (e.getAttribute('aria-label') || e.textContent || '').trim(), r: e.getBoundingClientRect() }))
    .filter((h) => (exact ? h.l === text : h.l.includes(text)) && h.r.width > 0)
    .map((h) => ({ label: h.l, disabled: h.e.getAttribute('aria-disabled') === 'true' || h.e.hasAttribute('disabled'), x: h.r.x + h.r.width / 2, y: h.r.y + h.r.height / 2 })), { text, exact });
}
async function waitButton(page, text, pred, { exact = false, ms = 20000 } = {}) {
  const end = Date.now() + ms; let last = [];
  while (Date.now() < end) { last = await buttons(page, text, exact); if (last.length && pred(last)) return last; await sleep(500); }
  return pred(last) ? last : null;
}
/** Botão mais próximo (abaixo) do texto âncora: "+ Adicionar" do card certo. */
async function clickNear(page, anchor, btnText, wait = 2500) {
  const a = await findBox(page, anchor, false);
  if (!a) throw new Error('âncora não encontrada: ' + anchor);
  const bs = (await buttons(page, btnText, false)).filter((b) => b.y > a.y - 5).sort((p, q) => Math.hypot(p.x - a.x, p.y - a.y) - Math.hypot(q.x - a.x, q.y - a.y));
  if (!bs.length) throw new Error('botão não encontrado perto de ' + anchor);
  await page.mouse.click(bs[0].x, bs[0].y); await sleep(wait);
}
/** Rola (roda do mouse em x,y) até o texto aparecer. */
async function scrollUntil(page, text, { x = 200, y = 500, dy = 400, max = 40 } = {}) {
  for (let i = 0; i < max; i++) {
    if (await findBox(page, text, false)) return true;
    await page.mouse.move(x, y); await page.mouse.wheel(0, dy); await sleep(700);
  }
  return Boolean(await findBox(page, text, false));
}
/** Abre uma rota nomeada do app como link (#/rota): o Flutter empilha a rota. */
async function go(page, route, wait = 5000) {
  await page.evaluate((r) => { location.hash = '#' + r; }, route); await sleep(wait);
}
async function waitDoc(ref, pred, ms = 20000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const s = await ref.get(); if (s.exists && (!pred || pred(s.data()))) return s.data(); await sleep(500); }
  return null;
}
// PNG 1x1 válido (anexo do chat).
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64');

(async () => {
  const em = (t) => `${t}${Date.now()}@t.dev`;
  const [cliE, proE, admE, ownE] = [em('p3cli'), em('p3pro'), em('p3adm'), em('p3own')];
  const [cli, pro, adm, own] = [await signUp(cliE), await signUp(proE), await signUp(admE), await signUp(ownE)];
  const now = Date.now(); const ts = (ms) => admin.firestore.Timestamp.fromMillis(ms);
  await db.doc('config/platform').set({ maintenanceMode: false }, { merge: true });
  await db.doc(`users/${cli.uid}`).set({ type: 'client', name: 'Rita Cliente', email: cliE, city: 'Marabá', createdAt: ts(now) });
  await db.doc(`users/${pro.uid}`).set({ type: 'provider', name: 'Paulo Prestador', email: proE, createdAt: ts(now) });
  await db.doc(`users/${adm.uid}`).set({ type: 'admin', adminRole: 'master', name: 'Admin Master', email: admE, createdAt: ts(now) });
  await db.doc(`users/${own.uid}`).set({ type: 'company', name: 'Dono das Lojas', createdAt: ts(now - 864e5) }); // fim da 2ª página
  await db.doc(`providers/${pro.uid}`).set({ userId: pro.uid, name: 'Paulo Prestador', verified: true, active: true, verificationStatus: 'approved', categories: ['eletricista'], modalities: ['presential'], rating: 4.8, totalReviews: 3, city: 'Marabá' });
  await db.doc(`publicProfiles/${pro.uid}`).set({ name: 'Paulo Prestador', kind: 'provider' });
  await db.doc(`publicProfiles/${cli.uid}`).set({ name: 'Rita Cliente', kind: 'client' });

  // ── Seeds 1: Mercado (4 lojas; storeActive vem do gatilho) ──
  const stores = {
    ok: { name: 'Mercadinho Aberto', active: true, verified: true },
    off: { name: 'Loja Desativada', active: false, verified: true },
    pend: { name: 'Loja Em Aprovação', active: true, verified: false },
    close: { name: 'Loja Que Fecha', active: true, verified: true },
  };
  const prodName = { ok: 'Arroz Vitrine OK', off: 'Feijão Loja Desativada', pend: 'Café Loja Pendente', close: 'Açúcar Loja Que Fecha' };
  for (const [k, s] of Object.entries(stores)) {
    await db.doc(`stores/p3_${k}`).set({ ...s, ownerId: own.uid, category: 'market', rating: 0, totalReviews: 0, totalProducts: 0, createdAt: ts(now) });
    await db.doc(`products/p3p_${k}`).set({ storeId: `p3_${k}`, storeName: s.name, name: prodName[k], category: 'market', emoji: '📦', price: 10, stock: 20, active: true, rating: 0, totalReviews: 0, createdAt: ts(now) });
  }
  // Gatilho onProductMarketSync grava storeActive (true só na loja vendável).
  for (const k of Object.keys(stores)) {
    await waitDoc(db.doc(`products/p3p_${k}`), (d) => typeof d.storeActive === 'boolean', 30000);
  }
  const sa = {}; for (const k of Object.keys(stores)) sa[k] = (await db.doc(`products/p3p_${k}`).get()).get('storeActive');

  // ── Seeds 2: pedidos do prestador (um vencido, um válido) ──
  const order = (title, created, expires) => ({ clientId: cli.uid, providerId: pro.uid, category: 'eletricista', title, description: 'Pedido semeado pelo E2E pend3', address: 'Rua A, 10 - Marabá', status: 'pending', paymentStatus: 'unpaid', urgent: false, createdAt: ts(created), expiresAt: ts(expires) });
  await db.doc('orders/p3_expirado').set(order('Troca de tomada vencida', now - 8 * 864e5, now - 3600e3));
  await db.doc('orders/p3_valido').set(order('Instalar chuveiro novo', now - 60e3, now + 3 * 864e5));

  // ── Seeds 3: 60 usuários "company" + o dono das lojas (página de 50 + 11) ──
  const bw = db.batch();
  for (let i = 1; i <= 60; i++) {
    const n = String(i).padStart(2, '0');
    bw.set(db.doc(`users/p3emp_${n}`), { type: 'company', name: `Empresa Paginada ${n}`, city: 'Parauapebas', createdAt: ts(now - (61 - i) * 60e3) });
  }
  await bw.commit();

  // ── Seeds 5: conversa com anexo no formato novo (mediaPath) ──
  const room = [cli.uid, pro.uid].sort().join('_');
  const mediaPath = `chat_media/${room}/${pro.uid}_foto.png`;
  await admin.storage().bucket(BUCKET).file(mediaPath).save(PNG, { resumable: false, metadata: { contentType: 'image/png' } });
  await db.doc(`chatRooms/${room}`).set({ participants: [cli.uid, pro.uid].sort(), lastMsg: '📷 Foto', lastMsgTime: ts(now), createdAt: ts(now - 60e3) });
  await db.doc(`chatRooms/${room}/messages/p3_txt`).set({ senderId: pro.uid, senderName: 'Paulo Prestador', text: 'Segue a foto do quadro de luz', read: false, createdAt: ts(now - 30e3) });
  await db.doc(`chatRooms/${room}/messages/p3_img`).set({ senderId: pro.uid, senderName: 'Paulo Prestador', text: '📷 Foto', mediaPath, mediaType: 'image', read: false, createdAt: ts(now) });

  const results = {}; global.__results = results; const notes = {};
  const ONLY = process.env.P3_ONLY ? process.env.P3_ONLY.split(',') : null; // depuração
  const check = (name, ok, extra) => { results[name] = ok ? 'OK' : `FALHOU ${extra || ''}`.trim(); };
  const srv = serve(WEB, 8100);
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH, args: ['--no-sandbox'] });
  const shot = (page, n) => page.screenshot({ path: path.join(OUT, `${n}.png`) }).catch(() => {});
  const open = async (w = 400, h = 900) => {
    const page = await browser.newPage({ viewport: { width: w, height: h } });
    global.__page = page;
    page.on('console', (m) => { if (/Uncaught|FlutterError/.test(m.text())) console.log('[browser]', m.text().slice(0, 300)); });
    await page.route(/https:\/\/www\.gstatic\.com\/firebasejs\/[^/]+\/(firebase-[a-z-]+\.js)$/, (r) => { const f = path.join(SDK, r.request().url().split('/').pop()); fs.existsSync(f) ? r.fulfill({ status: 200, contentType: 'text/javascript', body: fs.readFileSync(f) }) : r.abort(); });
    await page.goto('http://localhost:8100/'); await sleep(14000);
    // Árvore de acessibilidade do Flutter web (como um leitor de tela) e
    // sem o aviso do emulador cobrindo a parte de baixo.
    await page.evaluate(() => { const b = document.querySelector('flt-semantics-placeholder'); if (b) b.click(); });
    await page.addStyleTag({ content: '.firebase-emulator-warning{display:none!important}' }).catch(() => {});
    await sleep(1500);
    return page;
  };
  /** Login real: abertura › Pular › aba E-mail › Entrar. */
  const login = async (page, email) => {
    if (!(await waitText(page, 'Pular', 25000))) throw new Error('abertura sem "Pular"');
    await click(page, 'Pular', { exact: true, wait: 3000 });
    await click(page, 'E-mail', { exact: true, wait: 1500 });
    await typeInto(page, 'seu@email.com', email);
    await typeInto(page, 'Senha', 'Senha123!');
    await click(page, 'Entrar', { exact: true, wait: 8000 });
    if (!(await waitText(page, 'Mensagens', 20000))) throw new Error('login não chegou ao app: ' + JSON.stringify((await labels(page)).slice(0, 20)));
  };
  /** Cenário isolado: falha/exceção não derruba os demais. */
  const scenario = async (name, page, fn) => {
    if (ONLY && !ONLY.includes(name)) return;
    try { await fn(); } catch (e) {
      console.error(`CENARIO_FAIL ${name}`, e.message);
      if (!Object.keys(results).some((k) => k.startsWith(name))) results[`${name}_execucao`] = `FALHOU ${e.message.slice(0, 300)}`;
      await shot(page, `falha_${name}`);
    }
  };
  const finish = async () => {
    console.log('NOTES ' + JSON.stringify(notes, null, 1));
    console.log('RESULTS ' + JSON.stringify(results, null, 1));
    const failed = Object.values(results).filter((v) => v !== 'OK').length;
    await browser.close(); srv.close();
    process.exit(failed ? 1 : 0);
  };

  check('m_gatilho_storeActive', sa.ok === true && sa.close === true && sa.off === false && sa.pend === false, JSON.stringify(sa));
  // Reconciliação (admin master) liga config/market.storeActiveReady: a vitrine
  // passa a consultar storeActive == true no servidor.
  const rec = await call('adminReconcileMarket', adm, { dryRun: false }).catch((e) => ({ error: e.message }));
  check('m_reconciliacao_liga_storeActiveReady', !rec.error && Boolean(await waitDoc(db.doc('config/market'), (d) => d.storeActiveReady === true, 10000)), JSON.stringify(rec));

  // ═══ Cliente: Mercado, carrinho, perfil, chat ═══
  const want = (...n) => !ONLY || n.some((x) => ONLY.includes(x));
  const requests = [];
  if (want('m', 'p', 'c')) {
  const c = await open(400, 900);
  c.on('request', (r) => requests.push(r.url()));
  const responses = [];
  c.on('response', (r) => { if (/:9199\//.test(r.url())) responses.push({ url: r.url(), status: r.status() }); });
  await login(c, cliE);
  await shot(c, '0_cliente_logado');

  await scenario('m', c, async () => {
    await go(c, '/marketplace', 6000);
    check('m_vitrine_mostra_loja_vendavel', await waitText(c, prodName.ok, 20000) && await waitText(c, prodName.close, 5000), JSON.stringify((await labels(c)).slice(0, 25)));
    const ls = (await labels(c)).join(' | ');
    check('m_vitrine_oculta_loja_desativada_e_nao_aprovada', !ls.includes(prodName.off) && !ls.includes(prodName.pend), ls.slice(0, 300));
    await shot(c, '1_mercado_vitrine');
    await clickNear(c, prodName.close, '+ Adicionar', 2500);
    await click(c, 'Abrir carrinho', { wait: 4000 });
    const okBtn = await waitButton(c, 'Finalizar pedido desta loja', (b) => b.some((x) => !x.disabled), { ms: 15000 });
    check('m_carrinho_finalizar_habilitado_loja_ativa', Boolean(okBtn), JSON.stringify(await buttons(c, 'Finalizar', false)));
    await shot(c, '2_carrinho_loja_ativa');
    // Lojista/admin desativa a loja com o carrinho aberto (stream ao vivo).
    await db.doc('stores/p3_close').update({ active: false });
    check('m_carrinho_item_indisponivel', await waitText(c, 'Indisponível', 20000) && await waitText(c, 'Esta loja está desativada', 5000), JSON.stringify((await labels(c)).slice(0, 25)));
    const blocked = await waitButton(c, 'Finalizar pedido desta loja', (b) => b.length > 0 && b.every((x) => x.disabled), { ms: 10000 });
    check('m_carrinho_finalizar_bloqueado', Boolean(blocked), JSON.stringify(await buttons(c, 'Finalizar', false)));
    await shot(c, '3_carrinho_loja_desativada');
    // O gatilho da loja também tira o produto da vitrine.
    check('m_gatilho_loja_desativada_atualiza_produto', Boolean(await waitDoc(db.doc('products/p3p_close'), (d) => d.storeActive === false, 15000)));
  });

  await scenario('p', c, async () => {
    await go(c, '/profile', 6000);
    check('p_perfil_cliente_mostra_quero_ser_prestador', await scrollUntil(c, 'Quero ser prestador', { y: 450 }), JSON.stringify((await labels(c)).slice(-25)));
    await shot(c, '4_perfil_quero_ser_prestador');
    await click(c, 'Quero ser prestador', { wait: 5000 });
    check('p_abre_fluxo_quero_ser_prestador', await waitText(c, 'Escolha o que você atende', 15000) && await waitText(c, 'Continuar para documentos', 5000), JSON.stringify((await labels(c)).slice(0, 25)));
    await shot(c, '5_fluxo_quero_ser_prestador');
  });

  await scenario('c', c, async () => {
    requests.length = 0;
    await go(c, '/chat-inbox', 6000);
    await click(c, 'Paulo Prestador', { wait: 8000 });
    check('c_abre_conversa', await waitText(c, 'Segue a foto do quadro de luz', 15000), JSON.stringify((await labels(c)).slice(0, 25)));
    const end = Date.now() + 15000;
    while (Date.now() < end && !requests.some((u) => u.includes('getChatMediaUrl'))) await sleep(500);
    await sleep(8000); // tempo para a imagem tentar carregar
    const fnCalls = requests.filter((u) => u.includes('getChatMediaUrl'));
    const withToken = requests.filter((u) => /[?&]token=/.test(u));
    check('c_url_pela_callable_getChatMediaUrl', fnCalls.length > 0, `sem chamada; ${requests.length} requisições`);
    check('c_nenhuma_requisicao_com_token', withToken.length === 0, JSON.stringify(withToken.slice(0, 3)));
    const broken = await hasText(c, 'Imagem indisponível');
    const media = responses.filter((r) => r.url.includes(encodeURIComponent(mediaPath)));
    // A URL do servidor chega ao widget (antes do ajuste em FS.chatMediaUrl o
    // futuro nunca concluía e a imagem ficava carregando para sempre).
    check('c_anexo_sai_do_carregamento', media.length > 0 || broken, 'imagem presa no carregamento (URL não chegou ao widget)');
    notes.chat_imagem = { getChatMediaUrl: fnCalls.length, storageRespostas: media.map((r) => r.status), mostraImagemIndisponivel: broken,
      obs: 'No emulador a URL devolvida não é assinada; o CachedNetworkImage não envia Authorization, então as storage.rules recusam (403) e o app mostra "Imagem indisponível". Em produção a URL é assinada (getSignedUrl) e abre sem cabeçalho.' };
    await shot(c, '6_chat_anexo_mediaPath');
  });
  await c.close();
  }

  // ═══ Prestador: pedidos pendentes com prazo ═══
  if (want('e')) {
  const pv = await open(400, 1400);
  await scenario('e', pv, async () => {
    await login(pv, proE);
    await go(pv, '/provider-home', 8000);
    check('e_lista_pedidos_novos', await waitText(pv, 'Troca de tomada vencida', 20000) && await waitText(pv, 'Instalar chuveiro novo', 5000), JSON.stringify((await labels(pv)).slice(0, 30)));
    check('e_vencido_mostra_expirado', await hasText(pv, 'Expirado · prazo de resposta encerrado'));
    check('e_valido_mostra_expira_em', await hasText(pv, 'Expira em'));
    const exp = await buttons(pv, 'Expirado', true);
    check('e_vencido_aceite_desabilitado', exp.length === 1 && exp[0].disabled, JSON.stringify(exp));
    const acc = await buttons(pv, 'Aceitar', true);
    check('e_valido_aceite_habilitado', acc.length === 1 && !acc[0].disabled, JSON.stringify(acc));
    await shot(pv, '7_prestador_expirado_e_valido');
  });
  await pv.close();
  }

  // ═══ Admin master: paginação de usuários e migrações ═══
  if (want('a', 'g')) {
  const ad = await open(1280, 900);
  await scenario('a', ad, async () => {
    await login(ad, admE);
    await go(ad, '/admin', 8000);
    check('a_abre_painel_admin', await waitText(ad, 'Usuários', 20000), JSON.stringify((await labels(ad)).slice(0, 20)));
    await click(ad, 'Empresas', { exact: true, wait: 5000 });
    check('a_filtro_tipo_primeira_pagina', await waitText(ad, 'Empresa Paginada 60', 15000), JSON.stringify((await labels(ad)).slice(0, 30)));
    // Rola até o rodapé da 1ª página (50 itens: 60..11).
    const found = await scrollUntil(ad, 'Carregar mais', { x: 640, y: 600, dy: 600, max: 40 });
    const ls1 = (await labels(ad)).join(' | ');
    check('a_primeira_pagina_tem_50', found && ls1.includes('Empresa Paginada 11') && !ls1.includes('Empresa Paginada 10'), ls1.slice(-300));
    await shot(ad, '8_admin_usuarios_pagina1');
    await click(ad, 'Carregar mais', { exact: true, wait: 5000 });
    const end2 = await scrollUntil(ad, 'Fim da lista', { x: 640, y: 600, dy: 600, max: 20 });
    const ls2 = (await labels(ad)).join(' | ');
    check('a_carregar_mais_traz_segunda_pagina', end2 && ls2.includes('Empresa Paginada 01') && ls2.includes('Dono das Lojas'), ls2.slice(-300));
    check('a_filtro_so_do_tipo', !/Rita Cliente|Paulo Prestador|Admin Master/.test(ls2), ls2.slice(-300));
    await shot(ad, '9_admin_usuarios_pagina2');
  });
  await scenario('g', ad, async () => {
    // As abas ficam no cabeçalho que rola junto com a lista: volta ao topo.
    for (let i = 0; i < 15 && !(await findBox(ad, 'Configurações', true)); i++) { await ad.mouse.move(640, 500); await ad.mouse.wheel(0, -1500); await sleep(500); }
    await click(ad, 'Configurações', { exact: true, wait: 5000 });
    check('g_secao_migracoes_visivel', await scrollUntil(ad, 'Migrações de dados', { x: 640, y: 600, dy: 500, max: 30 }), JSON.stringify((await labels(ad)).slice(-25)));
    await scrollUntil(ad, 'Simular', { x: 640, y: 600, dy: 300, max: 10 });
    await shot(ad, '10_admin_migracoes');
    await click(ad, 'Simular', { exact: true, wait: 2000 });
    await click(ad, 'Executar', { exact: true, wait: 4000 });
    const ok = await waitText(ad, 'Simulação:', 30000);
    const txt = (((await labels(ad)).find((l) => l.includes('Simulação:')) || '').match(/Simulação:[^.]*\./) || [''])[0];
    check('g_simular_mercado_mostra_resultado', ok && /seriam corrigidos/.test(txt), JSON.stringify((await labels(ad)).slice(-15)));
    notes.simulacao = txt;
    // dryRun não grava: a reconciliação já tinha rodado, nada a corrigir além da loja que fechou (já sincronizada pelo gatilho).
    await shot(ad, '11_admin_simular_resultado');
  });
  await ad.close();
  }
  await finish();
})().catch(async (e) => { console.error('E2E_FAIL', e); console.log('PARTIAL ' + JSON.stringify(global.__results || {})); try { if (global.__page) await global.__page.screenshot({ path: path.join(OUT, 'falha.png') }); } catch (_) {} process.exit(1); });
