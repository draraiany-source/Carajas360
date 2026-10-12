'use strict';
/**
 * Integração da Fase 4 (Resolve, matching e contratação) contra os
 * emuladores. Pagamento do pedido de serviço usa o gateway SIMULADO.
 */
const { test, before, describe } = require('node:test');
const assert = require('node:assert');
const crypto = require('node:crypto');
const admin = require('../../functions/node_modules/firebase-admin');
const rc = require('../../functions/resolveCore');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;
if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const bucket = admin.storage().bucket(`${PROJECT}.appspot.com`);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const rid = (p = 'r') => `${p}_${crypto.randomBytes(8).toString('hex')}`;

async function signUp(tag) {
  const email = `${tag}_${Date.now()}_${Math.random().toString(36).slice(2, 7)}@test.dev`;
  const r = await fetch(`http://${AUTH}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=demo`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password: 'Senha123!', returnSecureToken: true }),
  });
  const j = await r.json();
  return { uid: j.localId, token: j.idToken };
}
async function call(name, user, data) {
  const r = await fetch(`${FN}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(user ? { Authorization: `Bearer ${user.token}` } : {}) },
    body: JSON.stringify({ data: data || {} }),
  });
  const j = await r.json();
  if (j.error) { const e = new Error(`${j.error.status} ${j.error.message}`); throw e; }
  return j.result;
}
async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) { const v = await fn(); if (v) return v; await sleep(300); }
  return null;
}
/** Próxima data local (AAAA-MM-DD) com o dia da semana pedido (0=dom). */
function nextWeekday(wd) {
  let t = Date.now() + 86400000;
  for (let i = 0; i < 8; i++, t += 86400000) {
    const d = rc.localToday(t);
    if (rc.weekdayOf(d) === wd) return d;
  }
  throw new Error('sem data');
}
const notifCount = async (uid, type = 'resolve') => (await db.collection('notifications').where('userId', '==', uid).where('type', '==', type).get()).size;

const K = `r4${Date.now().toString(36)}`;
const CAT = `${K}_casa`; const GRP = `${K}_ele`; const SVC = `${K}_tomada`; const OFF = `${K}_off`;
const QID = `${K}_q`;
const GEO_MARABA = { lat: -5.37, lng: -49.12 };
const GEO_PERTO = { lat: -5.39, lng: -49.10 };
const GEO_LONGE = { lat: -6.07, lng: -49.90 }; // ~115 km
let client; let client2; let near; let near2; let far; let grp; let online; let paused; let blocked;

before(async () => {
  [client, client2, near, near2, far, grp, online, paused, blocked] = await Promise.all(
    ['cli', 'cli2', 'near', 'near2', 'far', 'grp', 'onl', 'pau', 'blk'].map(signUp));
  const b = db.batch();
  b.set(db.doc(`catalogNodes/${CAT}`), { level: 'category', name: 'Casa R4', active: true, effectiveActive: true, order: 1 });
  b.set(db.doc(`catalogNodes/${GRP}`), { level: 'group', name: 'Eletricista R4', parentId: CAT, active: true, effectiveActive: true, order: 1 });
  b.set(db.doc(`catalogNodes/${SVC}`), { level: 'service', name: 'Tomadas R4', parentId: GRP, active: true, effectiveActive: true, order: 1, questionnaireId: QID });
  b.set(db.doc(`catalogNodes/${OFF}`), { level: 'service', name: 'Desativado R4', parentId: GRP, active: false, effectiveActive: false, order: 2 });
  b.set(db.doc(`serviceQuestionnaires/${QID}`), {
    serviceId: SVC, title: 'Tomadas', status: 'published', version: 1,
    questions: [
      { id: 'tipo', type: 'single_choice', label: 'Tipo', required: true, options: ['instalar', 'consertar'], showIf: null },
      { id: 'qtd', type: 'number', label: 'Quantidade', required: true, options: [], showIf: { questionId: 'tipo', op: 'equals', value: 'instalar' } },
      { id: 'defeito', type: 'long_text', label: 'Defeito', required: true, options: [], showIf: { questionId: 'tipo', op: 'equals', value: 'consertar' } },
      { id: 'foto', type: 'attachment', label: 'Foto do local', required: false, options: [], showIf: null },
    ],
  });
  b.set(db.doc('catalogMeta/current'), { version: admin.firestore.FieldValue.increment(1) }, { merge: true });
  await b.commit();
  await db.doc(`users/${client.uid}`).set({ type: 'client', name: 'Cliente R4' });
  await db.doc(`users/${blocked.uid}`).set({ type: 'provider', status: 'blocked' });
  const mk = (u, extra) => db.doc(`providers/${u.uid}`).set({
    userId: u.uid, name: `Pro ${u.uid.slice(0, 4)}`, verified: true, active: true, rating: 4.5, totalReviews: 3,
    categories: [SVC], modalities: ['presential'], city: 'Marabá', geo: GEO_MARABA, radiusKm: 20,
    availability: { weekdays: [1, 2, 3, 4, 5], periods: ['morning', 'afternoon'] }, ...extra,
  });
  await Promise.all([
    mk(near, {}), mk(near2, {}), mk(far, { geo: GEO_LONGE, city: 'Parauapebas' }),
    mk(grp, { categories: [GRP] }), mk(online, { modalities: ['online'] }),
    mk(paused, { acceptingRequests: false }), mk(blocked, {}),
  ]);
});

const MON = () => nextWeekday(1);
async function newReq(extra = {}, who = client) {
  return call('createResolveRequest', who, {
    requestId: rid('req'), description: 'Instalar tomadas novas na cozinha', category: SVC, city: 'Marabá',
    modality: 'presential', preferredDate: MON(), preferredPeriod: 'morning', geo: GEO_PERTO,
    address: 'Rua Secreta, 42', phone: '94 99999-0000', answers: { tipo: 'instalar', qtd: 3 }, ...extra,
  });
}

describe('Questionário e criação da solicitação', () => {
  test('questionário validado no servidor (obrigatórias, condicionais, tipos); idempotente', async () => {
    await assert.rejects(newReq({ answers: {} }), /Tipo.*obrigatória/);
    await assert.rejects(newReq({ answers: { tipo: 'instalar' } }), /Quantidade.*obrigatória/);
    await assert.rejects(newReq({ answers: { tipo: 'consertar' } }), /Defeito/);
    await assert.rejects(newReq({ answers: { tipo: 'trocar' } }), /opção inválida/);
    const requestId = rid('req');
    const r1 = await newReq({ requestId, answers: { tipo: 'instalar', qtd: 3, defeito: 'oculta' } });
    const r2 = await newReq({ requestId });
    assert.strictEqual(r2.id, r1.id);
    assert.strictEqual(r2.reused, true);
    const d = (await db.doc(`resolveRequests/${r1.id}`).get()).data();
    assert.deepStrictEqual(d.answers, { tipo: 'instalar', qtd: 3 }, 'resposta de pergunta oculta descartada');
    assert.strictEqual(d.questionnaireId, QID);
    assert.ok(d.publicAnswers.some((a) => a.label === 'Quantidade' && a.value === '3'));
    assert.strictEqual(d.address, undefined, 'endereço não vai para o documento principal');
    assert.deepStrictEqual(d.geo, GEO_PERTO);
    const priv = (await db.doc(`resolveRequests/${r1.id}/private/details`).get()).data();
    assert.strictEqual(priv.address, 'Rua Secreta, 42');
  });

  test('serviço desativado, nível categoria e data passada são recusados', async () => {
    await assert.rejects(newReq({ category: OFF, answers: {} }), /não está disponível/);
    await assert.rejects(newReq({ category: CAT, answers: {} }), /grupo ou o serviço/);
    await assert.rejects(newReq({ preferredDate: '2020-01-01' }), /data preferida/);
    await assert.rejects(call('createResolveRequest', null, { requestId: rid() }), /UNAUTHENTICATED|Login/);
  });

  test('anexos: só da própria pasta, existentes e com tipo permitido', async () => {
    const mine = `resolveUploads/${client.uid}/${rid('u')}/foto.jpg`;
    await bucket.file(mine).save(Buffer.from('jpeg'), { contentType: 'image/jpeg' });
    const html = `resolveUploads/${client.uid}/${rid('u')}/x.html`;
    await bucket.file(html).save(Buffer.from('<b>'), { contentType: 'text/html' });
    const base = { tipo: 'instalar', qtd: 1 };
    await assert.rejects(newReq({ answers: { ...base, foto: [`resolveUploads/${near.uid}/x/a.jpg`] } }), /anexo inválido/);
    await assert.rejects(newReq({ answers: { ...base, foto: [`resolveUploads/${client.uid}/naoexiste.jpg`] } }), /não encontrado/);
    await assert.rejects(newReq({ answers: { ...base, foto: [html] } }), /imagem ou PDF/);
    const ok = await newReq({ answers: { ...base, foto: [mine] } });
    const d = (await db.doc(`resolveRequests/${ok.id}`).get()).data();
    assert.strictEqual(d.attachmentCount, 1);
    const priv = (await db.doc(`resolveRequests/${ok.id}/private/details`).get()).data();
    assert.strictEqual(priv.attachments[0].path, mine);
    // Antes do aceite, nenhum prestador acessa o anexo.
    await assert.rejects(call('getResolveAttachmentUrl', near, { requestId: ok.id, index: 0 }), /PERMISSION_DENIED/);
    const u = await call('getResolveAttachmentUrl', client, { requestId: ok.id, index: 0 });
    assert.ok(u.url.includes(encodeURIComponent(mine)));
  });
});

describe('Matching: serviço, aprovação, conta, raio, modalidade e disponibilidade', () => {
  let reqId;
  test('oportunidades e notificações só para prestadores compatíveis', async () => {
    const before = await Promise.all([near, far, grp, online, paused, blocked].map((u) => notifCount(u.uid)));
    reqId = (await newReq()).id;
    const vis = async (u) => (await call('listResolveOpportunities', u)).items.find((i) => i.id === reqId);
    const it = await vis(near);
    assert.ok(it, 'prestador próximo, do serviço, disponível');
    assert.ok(it.distanceKm < 5);
    assert.ok(it.answers.length > 0 && it.address === undefined && it.clientId === undefined);
    assert.ok(!(await vis(far)), 'fora do raio');
    assert.ok(!(await vis(grp)), 'declarou só o grupo: não cobre serviço específico');
    assert.ok(!(await vis(online)), 'modalidade diferente');
    assert.ok(!(await vis(paused)), 'pausado');
    const blk = await call('listResolveOpportunities', blocked);
    assert.deepStrictEqual([blk.eligible, blk.reason], [false, 'account_blocked']);
    const got = await waitFor(async () => ((await notifCount(near.uid)) > before[0]) || null);
    assert.ok(got, 'compatível notificado pelo servidor (evento)');
    await sleep(1500);
    const after = await Promise.all([far, grp, online, paused, blocked].map((u) => notifCount(u.uid)));
    assert.deepStrictEqual(after, before.slice(1), 'incompatíveis não são notificados');
  });

  test('disponibilidade: sábado não aparece para quem atende de seg a sex', async () => {
    const sat = (await newReq({ preferredDate: nextWeekday(6) })).id;
    const list = await call('listResolveOpportunities', near);
    assert.ok(!list.items.some((i) => i.id === sat));
    await assert.rejects(call('submitResolveProposal', near, { requestId: sat, price: 100, deadlineDays: 1 }), /weekday_unavailable/);
  });

  test('pedido em nível de grupo alcança quem declarou um serviço do grupo', async () => {
    const g = (await newReq({ category: GRP, answers: {} })).id;
    assert.ok((await call('listResolveOpportunities', near)).items.some((i) => i.id === g));
    assert.ok((await call('listResolveOpportunities', grp)).items.some((i) => i.id === g));
  });

  test('proposta de prestador incompatível é recusada no servidor', async () => {
    await assert.rejects(call('submitResolveProposal', far, { requestId: reqId, price: 100, deadlineDays: 1 }), /out_of_radius/);
    await assert.rejects(call('submitResolveProposal', online, { requestId: reqId, price: 100, deadlineDays: 1 }), /modality_mismatch/);
    await assert.rejects(call('submitResolveProposal', blocked, { requestId: reqId, price: 100, deadlineDays: 1 }), /account_blocked/);
  });
});

describe('Aceite transacional e contratação', () => {
  test('aceite cria pedido, chat, agenda e financeiro; repetição devolve o mesmo pedido', async () => {
    const reqId = (await newReq()).id;
    const p1 = await call('submitResolveProposal', near, { requestId: reqId, price: 180.5, deadlineDays: 2, message: 'Levo material' });
    const p2 = await call('submitResolveProposal', near2, { requestId: reqId, price: 150, deadlineDays: 3 });
    await assert.rejects(call('acceptResolveProposal', near2, { requestId: reqId, proposalId: p2.id }), /Só o cliente/);
    const r = await call('acceptResolveProposal', client, { requestId: reqId, proposalId: p1.id });
    assert.strictEqual(r.orderId, `rs_${reqId}`);
    const order = (await db.doc(`orders/${r.orderId}`).get()).data();
    assert.strictEqual(order.providerId, near.uid);
    assert.strictEqual(order.clientId, client.uid);
    assert.strictEqual(order.priceCents, 18050);
    assert.strictEqual(order.price, 180.5);
    assert.strictEqual(order.status, 'accepted');
    assert.strictEqual(order.paymentStatus, 'unpaid');
    assert.strictEqual(order.acceptedTerms.deadlineDays, 2);
    assert.strictEqual(order.acceptedTerms.message, 'Levo material');
    assert.ok(Number.isInteger(order.financeTerms.commissionBps));
    const room = (await db.doc(`chatRooms/${r.roomId}`).get()).data();
    assert.deepStrictEqual(room.participants, [client.uid, near.uid].sort());
    const sched = (await db.doc(`scheduleEntries/${r.orderId}`).get()).data();
    assert.strictEqual(sched.date, MON());
    assert.strictEqual(sched.timezone, 'America/Belem');
    const req = (await db.doc(`resolveRequests/${reqId}`).get()).data();
    assert.strictEqual(req.status, 'matched');
    assert.strictEqual(req.matchedProposalId, p1.id);
    // Repetição (clique duplo / resposta perdida) → mesmo pedido.
    const again = await call('acceptResolveProposal', client, { requestId: reqId, proposalId: p1.id });
    assert.strictEqual(again.already, true);
    assert.strictEqual(again.orderId, r.orderId);
    await assert.rejects(call('acceptResolveProposal', client, { requestId: reqId, proposalId: p2.id }), /Outra proposta já foi aceita/);
    // Demais propostas encerradas e prestadores avisados (evento).
    const other = await waitFor(async () => {
      const d = (await db.doc(`resolveProposals/${p2.id}`).get()).data();
      return d.status === 'not_selected' ? d : null;
    });
    assert.ok(other);
    assert.ok(await waitFor(async () => (await db.collection('notifications').where('userId', '==', near.uid).where('title', '==', '✅ Proposta aceita!').get()).size > 0 || null));
    // Profissional escolhido passa a acessar anexos e dados privados; outro não.
    await assert.rejects(call('getResolveAttachmentUrl', near2, { requestId: reqId, index: 0 }), /PERMISSION_DENIED/);
    await assert.rejects(call('submitResolveProposal', far, { requestId: reqId, price: 1, deadlineDays: 1 }), /não está mais aberta|não elegível/);
  });

  test('aceites concorrentes de propostas diferentes: exatamente um vence', async () => {
    const reqId = (await newReq()).id;
    const a = await call('submitResolveProposal', near, { requestId: reqId, price: 100, deadlineDays: 1 });
    const b = await call('submitResolveProposal', near2, { requestId: reqId, price: 90, deadlineDays: 1 });
    const res = await Promise.allSettled([
      call('acceptResolveProposal', client, { requestId: reqId, proposalId: a.id }),
      call('acceptResolveProposal', client, { requestId: reqId, proposalId: b.id }),
    ]);
    assert.strictEqual(res.filter((x) => x.status === 'fulfilled').length, 1, JSON.stringify(res.map((x) => x.reason && x.reason.message)));
    const req = (await db.doc(`resolveRequests/${reqId}`).get()).data();
    const props = await db.collection('resolveProposals').where('requestId', '==', reqId).where('accepted', '==', true).get();
    assert.strictEqual(props.size, 1);
    assert.strictEqual(props.docs[0].id, req.matchedProposalId);
    assert.ok((await db.doc(`orders/rs_${reqId}`).get()).exists);
  });

  test('proposta retirada, prestador desativado e solicitação cancelada bloqueiam o aceite', async () => {
    const r1 = (await newReq({}, client2)).id;
    const p = await call('submitResolveProposal', near, { requestId: r1, price: 100, deadlineDays: 1 });
    await db.doc(`resolveProposals/${p.id}`).update({ available: false });
    await assert.rejects(call('acceptResolveProposal', client2, { requestId: r1, proposalId: p.id }), /retirou/);

    const r2 = (await newReq({}, client2)).id;
    const p2 = await call('submitResolveProposal', near2, { requestId: r2, price: 100, deadlineDays: 1 });
    await db.doc(`providers/${near2.uid}`).update({ active: false });
    await assert.rejects(call('acceptResolveProposal', client2, { requestId: r2, proposalId: p2.id }), /não está mais elegível/);
    await db.doc(`providers/${near2.uid}`).update({ active: true });

    const r3 = (await newReq({}, client2)).id;
    const p3 = await call('submitResolveProposal', near, { requestId: r3, price: 100, deadlineDays: 1 });
    await call('cancelResolveRequest', client2, { requestId: r3 });
    await assert.rejects(call('acceptResolveProposal', client2, { requestId: r3, proposalId: p3.id }), /não está aberta/);
    assert.ok(!(await db.doc(`orders/rs_${r3}`).get()).exists);
  });

  test('pedido contratado segue no financeiro: pagamento (simulado), execução e repasse com a comissão do pedido', async () => {
    const reqId = (await newReq({}, client2)).id;
    const p = await call('submitResolveProposal', near, { requestId: reqId, price: 200, deadlineDays: 1 });
    const { orderId } = await call('acceptResolveProposal', client2, { requestId: reqId, proposalId: p.id });
    const bps = (await db.doc(`orders/${orderId}`).get()).data().financeTerms.commissionBps;
    const pay = await call('startPayment', client2, {
      targetKind: 'service', targetId: orderId, method: 'card', requestId: rid('pay'),
      card: { token: 'tok_approved', installments: 1 },
    });
    assert.strictEqual(pay.status, 'approved');
    assert.strictEqual((await db.doc(`orders/${orderId}`).get()).data().paymentStatus, 'paid');
    await call('transitionOrder', near, { orderId, action: 'start' });
    const before = ((await db.doc(`wallets/${near.uid}`).get()).data() || {}).balanceCents || 0;
    await call('transitionOrder', client2, { orderId, action: 'complete' });
    const after = (await db.doc(`wallets/${near.uid}`).get()).data().balanceCents;
    assert.strictEqual(after - before, 20000 - Math.round(20000 * bps / 10000), 'líquido com a comissão gravada no pedido');
  });
});
