'use strict';

/**
 * Fluxo completo da Fase 2 executando as Functions reais de index.js sobre
 * um Firestore em memória: aceite com preço, pagamento pela carteira,
 * custódia, confirmação do cliente, repasse, liberação por prazo,
 * contestação, kill switch e aceite de proposta do Resolve.
 */
const { describe, it, before } = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');
const { createFakeAdmin, Timestamp } = require('./testing/fakeFirestore');

const { db, admin } = createFakeAdmin();
const originalLoad = Module._load;
Module._load = function load(request, ...rest) {
  if (request === 'firebase-admin') return admin;
  return originalLoad.call(this, request, ...rest);
};
const fns = require('./index');
Module._load = originalLoad;

const ctx = (uid) => ({ auth: { uid, token: {} } });
const call = (name, data, uid) => fns[name].run(data, ctx(uid));
const order = (id) => db.read(`orders/${id}`);
const balance = (uid) => Number((db.read(`wallets/${uid}`) || {}).balance || 0);
const rejectsWith = (p, code) => assert.rejects(p, (e) => e.code === code);

before(() => {
  db.seed('config/platform', { commissionRate: 0.1, escrowHoldDays: 3 });
  db.seed('users/c1', { type: 'client' });
  db.seed('users/p1', { type: 'provider' });
  db.seed('users/u3', { type: 'client' });
  db.seed('providers/p1', { active: true, verified: true });
  db.seed('wallets/c1', { userId: 'c1', balance: 1000 });
});

describe('F2 fluxo pedido direto', () => {
  before(() => {
    db.seed('orders/o1', {
      clientId: 'c1', providerId: 'p1', title: 'Tomadas', status: 'pending',
      paymentStatus: 'unpaid', payoutProcessed: false,
    });
  });

  it('aceitar sem valor é recusado; com valor define o preço', async () => {
    await rejectsWith(call('transitionOrder', { orderId: 'o1', action: 'accept' }, 'p1'), 'invalid-argument');
    await call('transitionOrder', { orderId: 'o1', action: 'accept', price: 200 }, 'p1');
    assert.equal(order('o1').status, 'accepted');
    assert.equal(order('o1').price, 200);
  });

  it('só o cliente paga; pagamento fica retido', async () => {
    await rejectsWith(call('payOrderWithWallet', { orderId: 'o1' }, 'p1'), 'permission-denied');
    await call('payOrderWithWallet', { orderId: 'o1' }, 'c1');
    const o = order('o1');
    assert.equal(o.paymentStatus, 'paid');
    assert.equal(o.escrowStatus, 'held');
    assert.equal(o.heldAmount, 200);
    assert.equal(balance('c1'), 800);
    const again = await call('payOrderWithWallet', { orderId: 'o1' }, 'c1');
    assert.equal(again.already, true);
    assert.equal(balance('c1'), 800);
  });

  it('pedido pago não pode ser cancelado pelas partes', async () => {
    await call('transitionOrder', { orderId: 'o1', action: 'start' }, 'p1');
    await rejectsWith(call('transitionOrder', { orderId: 'o1', action: 'cancel' }, 'c1'), 'failed-precondition');
  });

  it('conclusão pelo profissional não faz repasse', async () => {
    await call('transitionOrder', { orderId: 'o1', action: 'complete' }, 'p1');
    const o = order('o1');
    assert.equal(o.status, 'completed');
    assert.equal(o.completedBy, 'provider');
    assert.equal(o.payoutProcessed, false);
    assert.equal(o.escrowStatus, 'releasePending');
    const days = (o.releaseAt.toMillis() - Date.now()) / 86400000;
    assert.ok(days > 2.9 && days <= 3, `prazo ${days}`);
    assert.equal(balance('p1'), 0);
  });

  it('profissional não antecipa o repasse', async () => {
    await rejectsWith(call('processPayout', { orderId: 'o1' }, 'p1'), 'failed-precondition');
    await rejectsWith(call('transitionOrder', { orderId: 'o1', action: 'confirm' }, 'p1'), 'permission-denied');
  });

  it('confirmação do cliente libera o repasse com a comissão do Admin', async () => {
    await call('transitionOrder', { orderId: 'o1', action: 'confirm' }, 'c1');
    const o = order('o1');
    assert.equal(o.payoutProcessed, true);
    assert.equal(o.escrowStatus, 'released');
    assert.equal(o.commission, 20);
    assert.equal(balance('p1'), 180);
    const again = await call('transitionOrder', { orderId: 'o1', action: 'confirm' }, 'c1');
    assert.equal(again.already, true);
    assert.equal(balance('p1'), 180);
  });
});

describe('F2 aceite de pedido sem profissional', () => {
  before(() => {
    db.seed('orders/o4', { clientId: 'c1', title: 'Pintura', status: 'pending', paymentStatus: 'unpaid' });
  });

  it('cliente e usuário sem cadastro de profissional não aceitam', async () => {
    await rejectsWith(call('transitionOrder', { orderId: 'o4', action: 'accept', price: 90 }, 'c1'), 'permission-denied');
    await rejectsWith(call('transitionOrder', { orderId: 'o4', action: 'accept', price: 90 }, 'u3'), 'permission-denied');
  });

  it('profissional aprovado aceita', async () => {
    await call('transitionOrder', { orderId: 'o4', action: 'accept', price: 90 }, 'p1');
    assert.equal(order('o4').providerId, 'p1');
  });

  it('cancelado não é reaberto por ação comum', async () => {
    await call('transitionOrder', { orderId: 'o4', action: 'cancel' }, 'c1');
    await rejectsWith(call('transitionOrder', { orderId: 'o4', action: 'accept', price: 90 }, 'p1'), 'failed-precondition');
  });
});

describe('F2 liberação por prazo e contestação', () => {
  const past = Timestamp.fromMillis(Date.now() - 1000);
  const paidCompleted = {
    clientId: 'c1', providerId: 'p1', price: 100, status: 'completed',
    paymentStatus: 'paid', payoutProcessed: false, escrowStatus: 'releasePending',
    releaseAt: past, completedBy: 'provider',
  };

  before(() => {
    db.seed('payments/wallet_o2', { orderId: 'o2', status: 'approved', amount: 100 });
    db.seed('payments/wallet_o3', { orderId: 'o3', status: 'approved', amount: 100 });
    db.seed('orders/o2', { ...paidCompleted, transactionId: 'wallet_o2' });
    db.seed('orders/o3', { ...paidCompleted, transactionId: 'wallet_o3', releaseAt: Timestamp.fromMillis(Date.now() + 86400000) });
  });

  it('contestação antes do repasse bloqueia a liberação', async () => {
    await call('transitionOrder', { orderId: 'o3', action: 'dispute', reason: 'Serviço incompleto' }, 'c1');
    assert.equal(order('o3').status, 'disputed');
    assert.equal(order('o3').escrowStatus, 'disputed');
  });

  it('rotina agendada libera só o que venceu sem contestação', async () => {
    const before = balance('p1');
    await fns.releaseDueEscrows.run({}, {});
    assert.equal(order('o2').payoutProcessed, true);
    assert.equal(order('o3').payoutProcessed, false);
    assert.equal(balance('p1'), before + 90);
  });
});

describe('F2 kill switch financeiro', () => {
  it('bloqueia pagamento quando ligado', async () => {
    db.seed('orders/o5', {
      clientId: 'c1', providerId: 'p1', price: 50, status: 'accepted', paymentStatus: 'unpaid',
    });
    db.seed('config/platform', { commissionRate: 0.1, escrowHoldDays: 3, financialKillSwitch: true });
    await rejectsWith(call('payOrderWithWallet', { orderId: 'o5' }, 'c1'), 'failed-precondition');
    db.seed('config/platform', { commissionRate: 0.1, escrowHoldDays: 3 });
    await call('payOrderWithWallet', { orderId: 'o5' }, 'c1');
    assert.equal(order('o5').paymentStatus, 'paid');
  });
});

describe('F2 aceite de proposta do Resolve', () => {
  before(() => {
    db.seed('resolveRequests/r1', {
      clientId: 'c1', status: 'open', description: 'Trocar disjuntor', category: 'eletricista', city: 'Parauapebas',
    });
    db.seed('resolveRequests/r1/private/contact', { clientId: 'c1', clientName: 'Ana', address: 'Rua X, 10' });
    db.seed('resolveProposals/pr1', { requestId: 'r1', providerId: 'p1', price: 350, deadlineDays: 2 });
  });

  it('só o dono da solicitação aceita', async () => {
    await rejectsWith(call('acceptResolveProposal', { requestId: 'r1', proposalId: 'pr1' }, 'p1'), 'permission-denied');
  });

  it('aceitar cria o pedido com o valor da proposta e fecha a solicitação', async () => {
    const out = await call('acceptResolveProposal', { requestId: 'r1', proposalId: 'pr1' }, 'c1');
    assert.equal(out.orderId, 'resolve_r1');
    const o = order('resolve_r1');
    assert.equal(o.status, 'accepted');
    assert.equal(o.price, 350);
    assert.equal(o.providerId, 'p1');
    assert.equal(o.address, 'Rua X, 10');
    assert.equal(o.origin, 'resolve');
    const r = db.read('resolveRequests/r1');
    assert.equal(r.status, 'matched');
    assert.equal(r.orderId, 'resolve_r1');
    assert.equal(db.read('resolveProposals/pr1').accepted, true);
  });

  it('é idempotente e o pedido criado pode ser pago', async () => {
    const again = await call('acceptResolveProposal', { requestId: 'r1', proposalId: 'pr1' }, 'c1');
    assert.equal(again.already, true);
    await call('payOrderWithWallet', { orderId: 'resolve_r1' }, 'c1');
    assert.equal(order('resolve_r1').paymentStatus, 'paid');
  });
});
