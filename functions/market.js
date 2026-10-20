'use strict';

/**
 * Mercado: campos públicos mantidos SÓ pelo servidor (as regras impedem o
 * lojista de gravá-los).
 *
 * - products.storeActive: true só quando a loja do produto está ativa
 *   (active == true) E aprovada (verified == true). A vitrine, a busca e
 *   o perfil público da loja consultam storeActive == true.
 * - stores.totalProducts: recalculado por count() dos produtos ativos da
 *   loja. É idempotente por natureza (rodar o gatilho 2x dá o mesmo
 *   número), ao contrário do antigo increment(±1) do app.
 * - config/market.storeActiveReady: ligado pela reconciliação depois de
 *   preencher storeActive nos produtos antigos. Até lá o app usa a
 *   consulta antiga (sem o filtro) e só esconde storeActive == false, para
 *   não esvaziar a vitrine antes da migração. O pedido é sempre validado
 *   no servidor (createMarketOrder recusa loja inativa/não aprovada).
 */
const PAGE = 300;

/** Loja pode aparecer e vender? (inativa ou não aprovada = não) */
function storeSellable(store) {
  return Boolean(store) && store.active === true && store.verified === true;
}

module.exports = function marketFunctions(deps) {
  const { functions, db, FieldValue, FieldPath, requireAuth, isAdmin, httpsError, REGION } = deps;
  const products = db.collection('products');
  const stores = db.collection('stores');
  const MARKET_CFG = db.collection('config').doc('market');
  const ex = {};

  async function sellableOf(storeId) {
    if (!storeId || typeof storeId !== 'string') return false;
    const s = await stores.doc(storeId).get();
    return storeSellable(s.exists ? s.data() : null);
  }

  /**
   * Recalcula stores/{id}.totalProducts pela contagem agregada (produtos
   * ativos). Transação: a contagem e a gravação veem o mesmo estado.
   */
  async function recountStore(storeId) {
    if (!storeId || typeof storeId !== 'string') return null;
    const ref = stores.doc(storeId);
    return db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return null; // loja excluída: nada a manter
      const agg = await tx.get(products.where('storeId', '==', storeId).where('active', '==', true).count());
      const n = agg.data().count;
      if (snap.data().totalProducts !== n) tx.update(ref, { totalProducts: n });
      return n;
    });
  }

  /** Grava storeActive (estado ATUAL da loja) nos produtos dela, em lotes. */
  async function syncStoreProducts(storeId) {
    const want = await sellableOf(storeId);
    let last = null; let changed = 0;
    for (;;) {
      let q = products.where('storeId', '==', storeId).orderBy(FieldPath.documentId()).limit(PAGE);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      const batch = db.batch(); let n = 0;
      for (const d of page.docs) {
        if (d.get('storeActive') !== want) { batch.update(d.ref, { storeActive: want }); n += 1; }
      }
      if (n) await batch.commit();
      changed += n;
      last = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
    return { storeActive: want, changed };
  }

  // Loja ativada/desativada/aprovada/excluída: atualiza os produtos dela.
  ex.onStoreMarketSync = functions.firestore.document('stores/{storeId}').onWrite(async (change, ctx) => {
    const was = storeSellable(change.before.exists ? change.before.data() : null);
    const now = storeSellable(change.after.exists ? change.after.data() : null);
    // Mudou só outra coisa (nome, frete, o próprio totalProducts): nada a fazer.
    if (change.before.exists && change.after.exists && was === now) return null;
    return syncStoreProducts(ctx.params.storeId);
  });

  // Produto criado/alterado/excluído: storeActive e contador da loja.
  ex.onProductMarketSync = functions.firestore.document('products/{productId}').onWrite(async (change) => {
    const before = change.before.exists ? change.before.data() : null;
    const after = change.after.exists ? change.after.data() : null;
    const work = [];
    if (after) {
      const want = await sellableOf(after.storeId);
      // Só grava se diferente: a própria gravação reexecuta o gatilho, que para aqui.
      if (after.storeActive !== want) {
        work.push(change.after.ref.update({ storeActive: want }).catch((e) => {
          if (e.code !== 5) throw e; // NOT_FOUND: excluído no meio, ignora
        }));
      }
    }
    const counts = !before || !after || before.storeId !== after.storeId ||
      (before.active === true) !== (after.active === true);
    if (counts) {
      for (const id of new Set([before && before.storeId, after && after.storeId])) {
        if (id) work.push(recountStore(id));
      }
    }
    await Promise.all(work);
    return null;
  });

  /**
   * Reconciliação (dados antigos): storeActive de TODOS os produtos e
   * totalProducts de TODAS as lojas, paginada e idempotente. Ao terminar
   * liga config/market.storeActiveReady (vitrine passa a filtrar).
   */
  async function reconcileMarket({ dryRun = false } = {}) {
    const report = { dryRun, products: 0, productsFixed: 0, stores: 0, countersFixed: 0 };
    const cache = new Map();
    let last = null;
    for (;;) {
      let q = products.orderBy(FieldPath.documentId()).limit(PAGE);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      const missing = [...new Set(page.docs.map((d) => d.get('storeId')).filter((id) => typeof id === 'string' && id && !cache.has(id)))];
      if (missing.length) {
        const snaps = await db.getAll(...missing.map((id) => stores.doc(id)));
        snaps.forEach((s) => cache.set(s.id, storeSellable(s.exists ? s.data() : null)));
      }
      const batch = db.batch(); let n = 0;
      for (const d of page.docs) {
        const sid = d.get('storeId');
        const want = typeof sid === 'string' && cache.get(sid) === true;
        if (d.get('storeActive') !== want) { n += 1; if (!dryRun) batch.update(d.ref, { storeActive: want }); }
      }
      if (n && !dryRun) await batch.commit();
      report.products += page.size; report.productsFixed += n;
      last = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
    last = null;
    for (;;) {
      let q = stores.orderBy(FieldPath.documentId()).limit(PAGE);
      if (last) q = q.startAfter(last);
      const page = await q.get();
      if (page.empty) break;
      for (const d of page.docs) {
        const agg = await products.where('storeId', '==', d.id).where('active', '==', true).count().get();
        if (d.get('totalProducts') !== agg.data().count) {
          report.countersFixed += 1;
          if (!dryRun) await recountStore(d.id);
        }
      }
      report.stores += page.size;
      last = page.docs[page.docs.length - 1];
      if (page.size < PAGE) break;
    }
    if (!dryRun) await MARKET_CFG.set({ storeActiveReady: true, reconciledAt: FieldValue.serverTimestamp() }, { merge: true });
    return report;
  }

  /** Admin: reconciliação do Mercado (também em adminRunMaintenance). */
  ex.adminReconcileMarket = functions.runWith({ timeoutSeconds: 540 }).region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
    // Mesmo critério de adminRunMaintenance: grava dados, exige master/financeiro.
    const role = ((await db.collection('users').doc(auth.uid).get()).data() || {}).adminRole;
    if (role && !['master', 'financial'].includes(role) && auth.token.admin !== true) {
      throw httpsError('permission-denied', 'Perfil sem acesso a esta manutenção');
    }
    return reconcileMarket({ dryRun: data?.dryRun === true });
  });

  ex.__internals = { recountStore, syncStoreProducts, reconcileMarket, jobs: { marketReconcile: () => reconcileMarket() } };
  return ex;
};
module.exports.storeSellable = storeSellable;
