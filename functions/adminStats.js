'use strict';

/**
 * Painel admin: indicadores e relatório financeiro calculados no
 * servidor com consultas de AGREGAÇÃO (count/sum) do Firestore — nenhum
 * documento é baixado, então o custo não cresce com a base inteira.
 * Cada número é calculado de forma independente: se uma agregação falhar
 * (ex.: índice ausente), ela volta `null` e entra em `unavailable`, e o
 * app mostra "indisponível" em vez de um zero falso.
 */
const { AggregateField, Timestamp } = require('firebase-admin/firestore');

module.exports = function adminStatsFunctions(deps) {
  const { functions, db, requireAuth, isAdmin, httpsError, REGION } = deps;
  const ex = {};

  async function requireAdmin(auth) {
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
  }

  // Mesmo critério das regras (isFinanceAdmin) e do adminRunMaintenance:
  // claim admin, ou perfil admin com adminRole master/financial (ausente = master).
  async function requireFinanceAdmin(auth) {
    await requireAdmin(auth);
    if (auth.token && auth.token.admin === true) return;
    const role = ((await db.collection('users').doc(auth.uid).get()).data() || {}).adminRole;
    if (role && !['master', 'financial'].includes(role)) {
      throw httpsError('permission-denied', 'Perfil sem acesso financeiro');
    }
  }

  /** Executa as agregações nomeadas; falhas viram null + lista `unavailable`. */
  async function collect(jobs) {
    const out = {};
    const unavailable = [];
    await Promise.all(Object.entries(jobs).map(async ([k, run]) => {
      try {
        const v = await run();
        out[k] = Number.isFinite(v) ? v : null;
        if (out[k] === null) unavailable.push(k);
      } catch (e) {
        console.error('adminStats', k, e.message || e);
        out[k] = null;
        unavailable.push(k);
      }
    }));
    return { out, unavailable: unavailable.sort() };
  }

  const count = async (q) => (await q.count().get()).data().count;
  // sum() ignora documentos sem o campo ou com valor não numérico.
  const sum = async (q, field) => Number((await q.aggregate({ s: AggregateField.sum(field) }).get()).data().s || 0);
  const cents2 = (v) => Math.round(v * 100) / 100;

  /** Período opcional em dias (1 a 366); ausente/0 = desde o início. */
  function periodOf(data) {
    const raw = data && data.periodDays;
    if (raw === undefined || raw === null || raw === 0) return null;
    const n = Number(raw);
    if (!Number.isInteger(n) || n < 1 || n > 366) throw httpsError('invalid-argument', 'Período inválido (1 a 366 dias)');
    return n;
  }

  ex.adminDashboardStats = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await requireAdmin(auth);
    const weekAgo = Timestamp.fromMillis(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const completed = db.collection('orders').where('status', '==', 'completed');
    const { out, unavailable } = await collect({
      totalUsers: () => count(db.collection('users')),
      totalProviders: () => count(db.collection('providers').where('verified', '==', true)),
      newUsersThisWeek: () => count(db.collection('users').where('createdAt', '>', weekAgo)),
      completedOrders: () => count(completed),
      // Soma dos serviços concluídos (GMV), não receita da plataforma.
      revenue: async () => cents2(await sum(completed, 'price')),
    });
    return { ...out, unavailable, generatedAt: Date.now() };
  });

  ex.adminFinancialReport = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await requireFinanceAdmin(auth);
    const days = periodOf(data);
    const since = days ? Timestamp.fromMillis(Date.now() - days * 24 * 60 * 60 * 1000) : null;
    // Cada coleção é filtrada pelo seu marco de data (índices compostos
    // em firestore.indexes.json). Sem período: base inteira.
    const scoped = (q, field) => (since ? q.where(field, '>=', since) : q);
    const completed = scoped(db.collection('orders').where('status', '==', 'completed'), 'completedAt');
    // Repasse processado = comissão e líquido gravados pelo servidor.
    const settled = scoped(db.collection('orders').where('status', '==', 'completed').where('payoutProcessed', '==', true), 'completedAt');
    const recharges = scoped(db.collection('transactions').where('type', '==', 'recharge'), 'createdAt');
    const refunds = scoped(db.collection('refunds').where('status', '==', 'approved'), 'confirmedAt');
    const { out, unavailable } = await collect({
      grossRevenue: async () => cents2(await sum(completed, 'price')),
      completedCount: () => count(completed),
      settledCount: () => count(settled),
      commission: async () => cents2(await sum(completed, 'commission')),
      netToProviders: async () => cents2(await sum(completed, 'providerAmount')),
      // Lançamentos do razão gravam `amount` (reais) junto de `amountCents`.
      pixProcessed: async () => cents2(await sum(recharges, 'amount')),
      refunds: async () => cents2((await sum(refunds, 'amountCents')) / 100),
      refundsCount: () => count(refunds),
    });
    // Pedidos concluídos sem repasse registrado (antigos): a comissão e o
    // líquido deles não estão no documento; o app avisa que é parcial.
    out.ordersWithoutCommission = out.completedCount !== null && out.settledCount !== null
      ? Math.max(0, out.completedCount - out.settledCount) : null;
    if (out.ordersWithoutCommission === null) unavailable.push('ordersWithoutCommission');
    return { ...out, unavailable, periodDays: days, generatedAt: Date.now() };
  });

  return ex;
};
