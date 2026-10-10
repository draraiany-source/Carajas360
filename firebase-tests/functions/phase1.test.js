'use strict';
/**
 * Integração das Cloud Functions da Fase 1 contra os emuladores
 * (Auth + Firestore + Storage + Functions). Rode com `npm run emu`.
 */
const { test, before, describe } = require('node:test');
const assert = require('node:assert');
const admin = require('../../functions/node_modules/firebase-admin');

const PROJECT = process.env.GCLOUD_PROJECT || 'demo-carajas360';
const AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST || '127.0.0.1:9099';
const FN = `http://127.0.0.1:5001/${PROJECT}/us-central1`;

admin.initializeApp({ projectId: PROJECT, storageBucket: `${PROJECT}.appspot.com` });
const db = admin.firestore();
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

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
  if (j.error) {
    const e = new Error(j.error.message);
    e.status = j.error.status;
    throw e;
  }
  return j.result;
}

async function waitFor(fn, ms = 15000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    const v = await fn();
    if (v) return v;
    await sleep(300);
  }
  return null;
}

let client; let pro; let proOutside; let proOther; let pending; let adminUser;

before(async () => {
  [client, pro, proOutside, proOther, pending, adminUser] = await Promise.all(
    ['cli', 'pro', 'out', 'adv', 'pend', 'adm'].map(signUp));
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.doc(`users/${adminUser.uid}`).set({ type: 'admin', name: 'Admin' });
  await db.doc(`users/${client.uid}`).set({ type: 'client', name: 'Cliente' });
  const mk = (u, extra) => db.doc(`providers/${u.uid}`).set({
    userId: u.uid, name: `Prestador ${u.uid.slice(0, 4)}`, rating: 0, totalReviews: 0, createdAt: now, ...extra,
  });
  await mk(pro, { categories: ['eletricista'], verified: true, active: true, city: 'Parauapebas' });
  await mk(proOutside, { categories: ['eletricista'], verified: true, active: true, city: 'Marabá' });
  await mk(proOther, { categories: ['advogado'], verified: true, active: true, city: 'Parauapebas' });
  await mk(pending, { categories: ['eletricista'], verified: false, active: false, city: 'Parauapebas' });
});

async function newRequest(extra = {}) {
  const ref = db.collection('resolveRequests').doc();
  await ref.set({
    clientId: client.uid, clientName: 'Cliente', description: 'Trocar quadro de energia',
    category: 'eletricista', city: 'Parauapebas', status: 'open', proposalCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(), ...extra,
  });
  await ref.collection('private').doc('details').set({ address: 'Rua Secreta, 42' });
  return ref;
}

describe('Resolve: matching e propostas no servidor', () => {
  test('oportunidades só para prestador aprovado, ativo, do serviço e da região — sem endereço', async () => {
    const req = await newRequest();
    const mine = await call('listResolveOpportunities', pro);
    assert.strictEqual(mine.eligible, true);
    const item = mine.items.find((i) => i.id === req.id);
    assert.ok(item, 'prestador compatível deve ver a oportunidade');
    assert.strictEqual(item.address, undefined);
    assert.strictEqual(item.clientId, undefined);

    const outside = await call('listResolveOpportunities', proOutside);
    assert.ok(!outside.items.some((i) => i.id === req.id), 'outra cidade não vê');
    const other = await call('listResolveOpportunities', proOther);
    assert.ok(!other.items.some((i) => i.id === req.id), 'outro serviço não vê');
    const pend = await call('listResolveOpportunities', pending);
    assert.deepStrictEqual([pend.eligible, pend.reason], [false, 'not_verified']);
    const cli = await call('listResolveOpportunities', client);
    assert.deepStrictEqual([cli.eligible, cli.reason], [false, 'not_provider']);
  });

  test('proposta: elegibilidade, dados do servidor, sem duplicidade, contagem e notificação', async () => {
    const req = await newRequest();
    await assert.rejects(call('submitResolveProposal', pending, { requestId: req.id, price: 100, deadlineDays: 2 }), /não elegível/);
    await assert.rejects(call('submitResolveProposal', proOther, { requestId: req.id, price: 100, deadlineDays: 2 }), /não elegível/);
    await assert.rejects(call('submitResolveProposal', proOutside, { requestId: req.id, price: 100, deadlineDays: 2 }), /não elegível/);
    await assert.rejects(call('submitResolveProposal', pro, { requestId: req.id, price: -1, deadlineDays: 2 }), /inválida/);
    await assert.rejects(call('submitResolveProposal', null, { requestId: req.id, price: 100, deadlineDays: 2 }), /Login/);

    const r = await call('submitResolveProposal', pro, {
      requestId: req.id, price: 250, deadlineDays: 3, message: 'Posso amanhã', providerName: 'FORJADO', rating: 5,
    });
    assert.strictEqual(r.id, `${req.id}_${pro.uid}`);
    const p = (await db.doc(`resolveProposals/${r.id}`).get()).data();
    assert.strictEqual(p.clientId, client.uid);
    assert.strictEqual(p.providerId, pro.uid);
    assert.notStrictEqual(p.providerName, 'FORJADO');
    assert.strictEqual(p.rating, 0);
    assert.strictEqual(p.accepted, false);
    assert.strictEqual((await req.get()).data().proposalCount, 1);

    await assert.rejects(call('submitResolveProposal', pro, { requestId: req.id, price: 200, deadlineDays: 3 }), /já enviou/);
    assert.strictEqual((await req.get()).data().proposalCount, 1);

    const notif = await waitFor(async () => {
      const s = await db.collection('notifications').where('userId', '==', client.uid).where('type', '==', 'resolve').get();
      return s.empty ? null : s;
    });
    assert.ok(notif, 'cliente notificado pelo servidor');

    // Vínculo Resolve autoriza notificação direta (antes era recusada).
    const n = await call('createNotification', pro, { userId: client.uid, title: 'Olá', body: 'Sobre sua solicitação', type: 'resolve' });
    assert.strictEqual(n.ok, true);
    await assert.rejects(call('createNotification', proOther, { userId: client.uid, title: 'x', body: 'y' }), /Não é permitido/);
  });

  test('solicitação fechada não recebe propostas', async () => {
    const req = await newRequest({ status: 'matched' });
    await assert.rejects(call('submitResolveProposal', pro, { requestId: req.id, price: 100, deadlineDays: 1 }), /não está mais aberta/);
  });

  test('evento de criação notifica só prestadores elegíveis', async () => {
    const before = async (u) => (await db.collection('notifications').where('userId', '==', u.uid).get()).size;
    const counts = {
      pro: await before(pro), out: await before(proOutside), adv: await before(proOther), pend: await before(pending),
    };
    await newRequest({ description: 'Instalar chuveiro elétrico novo' });
    const got = await waitFor(async () => (await before(pro)) > counts.pro);
    assert.ok(got, 'prestador elegível notificado');
    await sleep(1500);
    assert.strictEqual(await before(proOutside), counts.out);
    assert.strictEqual(await before(proOther), counts.adv);
    assert.strictEqual(await before(pending), counts.pend);
  });
});

describe('Avaliações validadas no servidor', () => {
  test('avaliação válida recalcula nota; inválida é removida', async () => {
    const order = db.collection('orders').doc();
    await order.set({ clientId: client.uid, providerId: pro.uid, status: 'completed', price: 100 });
    await db.doc(`reviews/${order.id}_${client.uid}`).set({
      orderId: order.id, clientId: client.uid, providerId: pro.uid, stars: 4,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const ok = await waitFor(async () => {
      const p = (await db.doc(`providers/${pro.uid}`).get()).data();
      return p.totalReviews === 1 ? p : null;
    });
    assert.ok(ok, 'nota recalculada');
    assert.strictEqual(ok.rating, 4);
    assert.strictEqual((await order.get()).data().reviewed, true);

    // Inserida contornando as regras (ex.: script) com prestador errado.
    const order2 = db.collection('orders').doc();
    await order2.set({ clientId: client.uid, providerId: pro.uid, status: 'completed', price: 100 });
    const bad = db.doc(`reviews/${order2.id}_${client.uid}`);
    await bad.set({ orderId: order2.id, clientId: client.uid, providerId: proOther.uid, stars: 1 });
    const removed = await waitFor(async () => !(await bad.get()).exists);
    assert.ok(removed, 'avaliação inválida removida');
    const adv = (await db.doc(`providers/${proOther.uid}`).get()).data();
    assert.strictEqual(adv.totalReviews, 0);
  });
});

describe('Migração de privacidade (Fase 1)', () => {
  test('somente admin; move documentos para private e invalida URLs antigas', async () => {
    const legacy = await signUp('leg');
    const bucket = admin.storage().bucket();
    const path = `providers/${legacy.uid}/document/rg.jpg`;
    await bucket.file(path).save(Buffer.from('rg'), { contentType: 'image/jpeg', metadata: { metadata: { firebaseStorageDownloadTokens: 'token-antigo' } } });
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=token-antigo`;
    await db.doc(`providers/${legacy.uid}`).set({
      userId: legacy.uid, name: 'Legado', categories: ['pintor'], verified: true, active: true,
      documentUrl: url, selfieUrl: null, certificates: ['NR-35'],
    });
    const reqRef = db.collection('resolveRequests').doc();
    await reqRef.set({ clientId: client.uid, description: 'Antigo pedido', category: 'pintor', city: 'X', status: 'open', address: 'Rua Velha, 1' });

    await assert.rejects(call('migratePhase1Privacy', pro, {}), /Somente admin/);
    const dry = await call('migratePhase1Privacy', adminUser, { dryRun: true });
    assert.ok(dry.providersMigrated >= 1);
    assert.ok('documentUrl' in (await db.doc(`providers/${legacy.uid}`).get()).data(), 'dryRun não altera');

    const rep = await call('migratePhase1Privacy', adminUser, {});
    assert.ok(rep.providersMigrated >= 1 && rep.requestsMigrated >= 1);
    const pub = (await db.doc(`providers/${legacy.uid}`).get()).data();
    for (const f of ['documentUrl', 'selfieUrl', 'certificates']) assert.ok(!(f in pub), `${f} removido`);
    const priv = (await db.doc(`providers/${legacy.uid}/private/verification`).get()).data();
    assert.strictEqual(priv.documentPath, path);
    assert.deepStrictEqual(priv.certificates, ['NR-35']);
    const [meta] = await bucket.file(path).getMetadata();
    assert.notStrictEqual(meta.metadata.firebaseStorageDownloadTokens, 'token-antigo', 'token antigo invalidado');
    assert.ok(!('address' in (await reqRef.get()).data()), 'endereço removido do doc principal');
    assert.strictEqual((await reqRef.collection('private').doc('details').get()).data().address, 'Rua Velha, 1');

    const again = await call('migratePhase1Privacy', adminUser, {});
    assert.ok(again.providersMigrated === 0 && again.requestsMigrated === 0, 'idempotente');

    await assert.rejects(call('getVerificationFileUrl', pro, { providerId: legacy.uid, path }), /Somente admin/);
    const signed = await call('getVerificationFileUrl', adminUser, { providerId: legacy.uid, path });
    assert.ok(signed.url.includes(encodeURIComponent(path)));
    await assert.rejects(call('getVerificationFileUrl', adminUser, { providerId: legacy.uid, path: 'outra/coisa.jpg' }), /inválido/);
  });
});
