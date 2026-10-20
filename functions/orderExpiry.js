'use strict';

/**
 * Expiração de pedidos de serviço pendentes (sem aceite do prestador).
 *
 * - Prazo: orderPolicy.PENDING_EXPIRY_MS (7 dias). `expiresAt` é gravado só
 *   pelo servidor (gatilho de criação); as regras impedem o cliente de
 *   gravá-lo. Pedido antigo sem o campo: createdAt + 7 dias
 *   (orderPolicy.expiresAtMs), e `backfillOrderExpiry` preenche o campo.
 * - Pedido expirado continua `cancelled` com cancelReason "Expirado
 *   automaticamente" (compatível com o app e o histórico), agora com
 *   `expired: true`, `expiredAt` e `cancelledBy: 'system'`.
 * - Concorrência: cada pedido expira numa transação que relê o status; o
 *   aceite (transitionOrder) também relê e recusa após o prazo. Um aceito
 *   não expira depois e um expirado não é aceito.
 * - Pedido pago (ou com pagamento em andamento) e pendente NÃO é cancelado
 *   automaticamente (regra existente): o aceite fica bloqueado, o cliente
 *   pode cancelar (o cancelamento pago já gera reembolso pelo caminho
 *   normal) e o suporte recebe um registro em financialIssues.
 */
const policy = require('./orderPolicy');
const clock = require('./clock');

const EXPIRED_REASON = 'Expirado automaticamente';

module.exports = function orderExpiry({ db, FieldValue, Timestamp, notifySafe }) {
  /**
   * Gatilho de criação: grava expiresAt = criação + prazo. A criação é o
   * menor entre createTime do documento (relógio do servidor, deslocado
   * pelo relógio de teste no emulador) e createdAt: o cliente não estende
   * o prazo com um createdAt no futuro.
   */
  async function stamp(snap) {
    const o = snap.data() || {};
    if ((o.status || 'pending') !== 'pending' || o.expiresAt) return null;
    const offset = (await clock.nowMs(db)) - Date.now();
    const created = snap.createTime ? snap.createTime.toMillis() + offset : clock.nowSync();
    const base = Math.min(created, policy.toMs(o.createdAt) || created);
    const expiresAt = Timestamp.fromMillis(base + policy.PENDING_EXPIRY_MS);
    try {
      // Precondição: não sobrescreve se o pedido mudou nesse meio-tempo
      // (ex.: aceito); nesse caso o legado createdAt + 7 dias vale.
      await snap.ref.update({ expiresAt }, { lastUpdateTime: snap.updateTime });
    } catch (e) {
      const cur = (await snap.ref.get()).data();
      if (cur && !cur.expiresAt && (cur.status || 'pending') === 'pending') {
        await snap.ref.update({ expiresAt }).catch((err) => console.warn('stampExpiry', snap.id, err.message));
      }
    }
    return expiresAt.toMillis();
  }

  /** Expira um pedido em transação. Devolve 'expired' | 'paid_kept' | 'noop'. */
  async function expireOne(ref, nowMs) {
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const o = snap.data();
      if (!o || !policy.isExpired(o, nowMs)) return 'noop';
      const ps = o.paymentStatus || 'unpaid';
      if (ps !== 'unpaid') {
        // Pago/pendente: tratado pelo suporte, nunca cancelado em silêncio.
        const issueRef = db.collection('financialIssues').doc(`order_expired_${ref.id}`);
        const issue = await tx.get(issueRef);
        if (issue.exists) return 'noop';
        tx.create(issueRef, {
          type: 'service_order_expired_paid', targetKind: 'service', targetId: ref.id,
          detail: `Pedido pendente com pagamento "${ps}" passou do prazo de aceite.`,
          status: 'open', createdAt: FieldValue.serverTimestamp(),
        });
        return 'paid_kept';
      }
      tx.update(ref, {
        status: 'cancelled',
        cancelReason: EXPIRED_REASON,
        cancelledBy: 'system',
        expired: true,
        expiredAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      return 'expired';
    });
  }

  /**
   * Tarefa agendada: pendentes com expiresAt vencido e, para os antigos sem
   * o campo, createdAt anterior a agora − prazo. Idempotente.
   */
  async function expireJob() {
    const nowMs = await clock.nowMs(db);
    const orders = db.collection('orders');
    const byExpQ = orders.where('status', '==', 'pending')
      .where('expiresAt', '<=', Timestamp.fromMillis(nowMs)).limit(300);
    const byCreatedQ = orders.where('status', '==', 'pending')
      .where('createdAt', '<=', Timestamp.fromMillis(nowMs - policy.PENDING_EXPIRY_MS)).limit(300);
    const [byExp, byCreated] = await Promise.all([byExpQ.get(), byCreatedQ.get()]);
    const refs = new Map();
    byExp.docs.forEach((d) => refs.set(d.id, d));
    byCreated.docs.forEach((d) => { if (!d.data().expiresAt) refs.set(d.id, d); });
    const out = { expired: 0, paidKept: 0 };
    for (const d of refs.values()) {
      try {
        const r = await expireOne(d.ref, nowMs);
        if (r === 'expired') {
          out.expired += 1;
          const o = d.data();
          if (o.clientId) {
            await notifySafe(o.clientId, '⌛ Pedido expirado',
              'Nenhum profissional aceitou a solicitação no prazo de 7 dias. Você pode solicitar novamente.', 'order', { route: 'myOrders' });
          }
        } else if (r === 'paid_kept') {
          out.paidKept += 1;
        }
      } catch (e) {
        console.error('expireServiceOrders', d.id, e && e.message);
      }
    }
    return out;
  }

  /**
   * Migração: grava expiresAt (createdAt + prazo) nos pedidos pendentes
   * antigos. Paginada por id; idempotente (só escreve onde falta) e com
   * precondição de lastUpdateTime para não disputar com um aceite.
   */
  async function backfillJob({ pageSize = 300, maxPages = 50 } = {}) {
    let last = null;
    const out = { scanned: 0, updated: 0, done: false };
    for (let page = 0; page < maxPages; page++) {
      let q = db.collection('orders').where('status', '==', 'pending')
        .orderBy('__name__').limit(pageSize);
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      for (const d of snap.docs) {
        out.scanned += 1;
        const o = d.data();
        if (o.expiresAt) continue;
        const exp = policy.expiresAtMs(o);
        if (!exp) continue;
        try {
          await d.ref.update({ expiresAt: Timestamp.fromMillis(exp) }, { lastUpdateTime: d.updateTime });
          out.updated += 1;
        } catch (e) {
          console.warn('backfillOrderExpiry', d.id, e && e.message);
        }
      }
      if (snap.size < pageSize) { out.done = true; break; }
      last = snap.docs[snap.docs.length - 1];
    }
    return out;
  }

  return { stamp, expireOne, expireJob, backfillJob, EXPIRED_REASON };
};
