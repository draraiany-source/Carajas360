'use strict';

/**
 * Cloud Functions do catálogo (Fase 2): fonte única administrável,
 * migração sem perda, questionários versionados e índice de busca.
 * Todas as escritas no catálogo passam por aqui (regras: write false).
 */
const core = require('./catalogCore');
const seed = require('./catalog/seed_v1.json');

module.exports = function catalogFunctions(deps) {
  const { functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION } = deps;
  const NODES = 'catalogNodes';
  const META = db.collection('catalogMeta').doc('current');

  async function requireAdmin(context) {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente administradores alteram o catálogo');
    return auth;
  }

  async function loadNodes() {
    const snap = await db.collection(NODES).get();
    const out = {};
    snap.docs.forEach((d) => { out[d.id] = { id: d.id, ...d.data() }; });
    return out;
  }

  // Cache para gatilhos, invalidado pela versão em catalogMeta/current.
  // Auditoria: o cache só por tempo (30 s) fazia outras instâncias
  // indexarem prestadores com o catálogo antigo logo após uma mudança.
  let cache = null;
  let cacheAt = 0;
  let cacheV = null;
  async function cachedNodes() {
    const meta = await META.get();
    const v = meta.exists ? `${meta.data().version || 0}` : '0';
    if (!cache || cacheV !== v || Date.now() - cacheAt > 10 * 60000) {
      cache = await loadNodes();
      cacheAt = Date.now();
      cacheV = v;
    }
    return cache;
  }

  function audit(uid, action, target, details) {
    return db.collection('auditLogs').add({
      adminId: uid, adminName: 'Admin', action, target, details: details || {},
      timestamp: FieldValue.serverTimestamp(),
    });
  }

  async function bumpMeta(uid, reason) {
    await META.set({
      version: FieldValue.increment(1),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: uid,
      reason,
    }, { merge: true });
  }

  /** Recalcula effectiveActive e searchTerms dos nós indicados. */
  async function recomputeDerived(ids, nodes) {
    let batch = db.batch();
    let n = 0;
    for (const id of ids) {
      const node = nodes[id];
      if (!node) continue;
      const eff = core.effectiveActive(id, nodes);
      const terms = core.searchTerms(node);
      const path = core.pathOf(id, nodes).map((p) => p.id);
      if (node.effectiveActive !== eff || !core.sameArray(node.searchTerms, terms) ||
          !core.sameArray(node.path, path)) {
        batch.update(db.collection(NODES).doc(id), { effectiveActive: eff, searchTerms: terms, path });
        node.effectiveActive = eff;
        n += 1;
        if (n % 400 === 0) { await batch.commit(); batch = db.batch(); }
      }
    }
    if (n % 400 !== 0) await batch.commit();
    return n;
  }

  /** Reindexa prestadores que declaram algum dos IDs (blocos de 30). */
  async function reindexProvidersFor(ids, nodes) {
    let count = 0;
    for (const part of chunk([...new Set(ids)], 30)) {
      const snap = await db.collection('providers').where('categories', 'array-contains-any', part).get();
      for (const d of snap.docs) {
        if (await writeProviderIndex(d.ref, d.data(), nodes)) count += 1;
      }
    }
    return count;
  }

  async function writeProviderIndex(ref, data, nodes) {
    const idx = core.providerIndex(data, nodes);
    const same = core.sameArray(data.searchTokens, idx.searchTokens) &&
      (data.cityKey || null) === idx.cityKey &&
      core.sameArray(data.groupIds, idx.groupIds) &&
      core.sameArray(data.categoryIds, idx.categoryIds);
    if (same) return false;
    await ref.update({
      searchTokens: idx.searchTokens, cityKey: idx.cityKey,
      groupIds: idx.groupIds, categoryIds: idx.categoryIds,
    });
    return true;
  }

  async function writeCompanyIndex(ref, data) {
    const idx = core.companyIndex(data);
    if (core.sameArray(data.searchTokens, idx.searchTokens) && (data.cityKey || null) === idx.cityKey) return false;
    await ref.update({ searchTokens: idx.searchTokens, cityKey: idx.cityKey });
    return true;
  }

  function chunk(list, size) {
    const out = [];
    for (let i = 0; i < list.length; i += size) out.push(list.slice(i, i + size));
    return out;
  }

  const ex = {};

  /** Admin: cria ou edita categoria/grupo/serviço (validado no servidor). */
  ex.catalogUpsert = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireAdmin(context);
    const isNew = data?.isNew === true;
    const nodes = await loadNodes();
    const v = core.validateNode(data?.node || {}, nodes, { isNew });
    if (!v.ok) throw httpsError('invalid-argument', v.errors.join('; '));
    const node = v.value;
    const prev = nodes[node.id];
    const ref = db.collection(NODES).doc(node.id);
    await db.runTransaction(async (tx) => {
      const cur = await tx.get(ref);
      if (isNew && cur.exists) throw httpsError('already-exists', 'id já existe');
      if (!isNew && !cur.exists) throw httpsError('not-found', 'nó não encontrado');
      tx.set(ref, {
        ...node,
        updatedAt: FieldValue.serverTimestamp(),
        editedAt: FieldValue.serverTimestamp(),
        editedBy: auth.uid,
        ...(isNew ? { createdAt: FieldValue.serverTimestamp(), source: 'admin' } : {}),
      }, { merge: true });
    });
    nodes[node.id] = { ...(prev || {}), ...node };
    const affected = [node.id, ...core.descendants(node.id, nodes)];
    await recomputeDerived(affected, nodes);
    let reindexed = 0;
    if (prev && (prev.parentId || null) !== (node.parentId || null)) {
      reindexed = await reindexProvidersFor(affected, nodes);
    }
    await audit(auth.uid, isNew ? 'Criou item do catálogo' : 'Editou item do catálogo', node.id,
      { level: node.level, name: node.name, parentId: node.parentId });
    await bumpMeta(auth.uid, `upsert:${node.id}`);
    cache = null;
    return { ok: true, id: node.id, reindexedProviders: reindexed };
  });

  /**
   * Admin: ativa/desativa. Desativar impede novas seleções/contratações
   * (effectiveActive=false em toda a subárvore) sem apagar nada.
   */
  ex.catalogSetActive = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireAdmin(context);
    const id = String(data?.id || '');
    const active = data?.active === true;
    const nodes = await loadNodes();
    if (!nodes[id]) throw httpsError('not-found', 'nó não encontrado');
    await db.collection(NODES).doc(id).update({
      active, updatedAt: FieldValue.serverTimestamp(), editedAt: FieldValue.serverTimestamp(), editedBy: auth.uid,
    });
    nodes[id].active = active;
    const affected = [id, ...core.descendants(id, nodes)];
    const changed = await recomputeDerived(affected, nodes);
    await audit(auth.uid, active ? 'Ativou item do catálogo' : 'Desativou item do catálogo', id,
      { affected: affected.length });
    await bumpMeta(auth.uid, `${active ? 'activate' : 'deactivate'}:${id}`);
    cache = null;
    return { ok: true, affected: affected.length, changed };
  });

  /** Admin: reordena os filhos de um nível (lista completa de irmãos). */
  ex.catalogReorder = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireAdmin(context);
    const parentId = data?.parentId ? String(data.parentId) : null;
    const ordered = Array.isArray(data?.orderedIds) ? data.orderedIds.map(String) : [];
    const nodes = await loadNodes();
    const siblings = Object.values(nodes).filter((n) => (n.parentId || null) === parentId).map((n) => n.id);
    if (ordered.length !== siblings.length || !siblings.every((id) => ordered.includes(id))) {
      throw httpsError('invalid-argument', 'Envie todos os itens deste nível, sem repetição');
    }
    const batch = db.batch();
    ordered.forEach((id, i) => batch.update(db.collection(NODES).doc(id), {
      order: (i + 1) * 10, updatedAt: FieldValue.serverTimestamp(),
    }));
    await batch.commit();
    await audit(auth.uid, 'Reordenou catálogo', parentId || 'raiz', { orderedIds: ordered });
    await bumpMeta(auth.uid, `reorder:${parentId || 'root'}`);
    cache = null;
    return { ok: true };
  });

  /**
   * Admin: migração do catálogo v1 (seed com os 133 IDs legados).
   * Idempotente, com dryRun, relatório de conflitos e sem exclusões.
   */
  ex.migrateCatalogV1 = functions.region(REGION)
    .runWith({ timeoutSeconds: 540, memory: '512MB' })
    .https.onCall(async (data, context) => {
      const auth = await requireAdmin(context);
      const dryRun = data?.dryRun === true;
      const existing = await loadNodes();
      const plan = core.planSeedMigration(seed.nodes, existing);

      // Inventário de referências (nada é reclassificado).
      const refs = [];
      const scan = async (col, pick) => {
        const snap = await db.collection(col).select(...pick.fields).get();
        snap.docs.forEach((d) => pick.ids(d.data()).forEach((id) => refs.push({ collection: col, id })));
        return snap.size;
      };
      const scanned = {
        providers: await scan('providers', { fields: ['categories'], ids: (x) => x.categories || [] }),
        orders: await scan('orders', { fields: ['category', 'type'], ids: (x) => (x.type === 'marketplace' ? [] : [x.category]) }),
        resolveRequests: await scan('resolveRequests', { fields: ['category'], ids: (x) => [x.category] }),
        stores: await scan('stores', { fields: ['categories'], ids: (x) => x.categories || [] }),
        rentals: await scan('rentals', { fields: ['category'], ids: (x) => [x.category] }),
        companies: await scan('companies', { fields: ['categories'], ids: (x) => x.categories || [] }),
      };
      const known = new Set([...Object.keys(existing), ...seed.nodes.map((n) => n.id)]);
      const unknown = core.unknownReferences(refs, known);
      const legacyAdminDocs = (await db.collection('categories').get()).docs
        .map((d) => ({ id: d.id, name: d.data().name || null, mappedTo: known.has(d.id) ? d.id : null }));

      const report = {
        dryRun,
        seedVersion: seed.version,
        seedNodes: seed.nodes.length,
        toCreate: plan.create.length,
        unchanged: plan.unchanged.length,
        conflicts: plan.conflicts,
        unknownReferences: unknown,
        legacyAdminCategories: legacyAdminDocs,
        scanned,
        providersReindexed: 0,
        companiesReindexed: 0,
      };
      if (dryRun) return report;

      let batch = db.batch();
      let n = 0;
      for (const s of plan.create) {
        batch.set(db.collection(NODES).doc(s.id), {
          ...s,
          slug: core.slugify(s.name),
          active: true,
          source: 'seed_v1',
          seedVersion: seed.version,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        n += 1;
        if (n % 400 === 0) { await batch.commit(); batch = db.batch(); }
      }
      if (n % 400 !== 0) await batch.commit();

      const nodes = await loadNodes();
      await recomputeDerived(Object.keys(nodes), nodes);
      for (const d of (await db.collection('providers').get()).docs) {
        if (await writeProviderIndex(d.ref, d.data(), nodes)) report.providersReindexed += 1;
      }
      for (const d of (await db.collection('companies').get()).docs) {
        if (await writeCompanyIndex(d.ref, d.data())) report.companiesReindexed += 1;
      }
      await db.collection('catalogMeta').doc('legacyIdMap').set({
        seedVersion: seed.version,
        // IDs antigos de serviço = IDs de nó (identidade, sem renomear).
        idsPreserved: seed.legacyIds,
        // Grupos antigos (Categories.groups) → categoria nova principal.
        groupNameToCategory: seed.legacyGroupMap,
        updatedAt: FieldValue.serverTimestamp(),
      });
      await db.collection('catalogMigrations').doc(`v${seed.version}`).set({
        ...report,
        runBy: auth.uid,
        ranAt: FieldValue.serverTimestamp(),
        runs: FieldValue.increment(1),
      }, { merge: true });
      await audit(auth.uid, 'Executou migração do catálogo v1', 'catalog', {
        created: plan.create.length, conflicts: plan.conflicts.length, unknown: unknown.length,
      });
      await bumpMeta(auth.uid, 'migration:v1');
      cache = null;
      return report;
    });

  /**
   * Admin: reversão EXPLÍCITA da migração v1. Remove apenas nós criados
   * pelo seed e nunca editados; exige confirmação textual. Campos de
   * busca dos prestadores são aditivos e permanecem (inofensivos).
   */
  ex.rollbackCatalogV1 = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireAdmin(context);
    const dryRun = data?.dryRun !== false;
    if (!dryRun && data?.confirm !== 'ROLLBACK_CATALOG_V1') {
      throw httpsError('failed-precondition', 'Confirme com confirm="ROLLBACK_CATALOG_V1"');
    }
    const nodes = await loadNodes();
    const removable = Object.values(nodes).filter((x) => x.source === 'seed_v1' && !x.editedAt).map((x) => x.id);
    const kept = Object.values(nodes).filter((x) => !removable.includes(x.id)).map((x) => x.id);
    if (!dryRun) {
      for (const part of chunk(removable, 400)) {
        const b = db.batch();
        part.forEach((id) => b.delete(db.collection(NODES).doc(id)));
        await b.commit();
      }
      await audit(auth.uid, 'Reverteu migração do catálogo v1', 'catalog', { removed: removable.length, kept: kept.length });
      await bumpMeta(auth.uid, 'rollback:v1');
      cache = null;
    }
    return { dryRun, removable: removable.length, kept };
  });

  /**
   * Admin: salva questionário versionado. Rascunhos são editáveis;
   * publicar cria versão imutável e arquiva a anterior. A aplicação nas
   * solicitações fica para a fase do Resolve.
   */
  ex.questionnaireSave = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = await requireAdmin(context);
    const nodes = await loadNodes();
    const v = core.validateQuestionnaire(data || {}, nodes);
    if (!v.ok) throw httpsError('invalid-argument', v.errors.join('; '));
    const publish = data?.publish === true;
    const col = db.collection('serviceQuestionnaires');
    const id = data?.id ? String(data.id) : null;
    const result = await db.runTransaction(async (tx) => {
      let ref = id ? col.doc(id) : col.doc();
      if (id) {
        const cur = await tx.get(ref);
        if (!cur.exists) throw httpsError('not-found', 'Questionário não encontrado');
        if (cur.data().status !== 'draft') ref = col.doc(); // publicado é imutável: vira novo rascunho
      }
      let version = null;
      let previous = null;
      if (publish) {
        const pub = await tx.get(col.where('serviceId', '==', v.value.serviceId).where('status', '==', 'published'));
        previous = pub.docs.map((d) => d.ref);
        const all = await tx.get(col.where('serviceId', '==', v.value.serviceId));
        version = all.docs.reduce((m, d) => Math.max(m, Number(d.data().version || 0)), 0) + 1;
      }
      previous && previous.forEach((p) => tx.update(p, { status: 'archived', archivedAt: FieldValue.serverTimestamp() }));
      tx.set(ref, {
        ...v.value,
        status: publish ? 'published' : 'draft',
        version,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: auth.uid,
        ...(publish ? { publishedAt: FieldValue.serverTimestamp() } : {}),
      }, { merge: true });
      if (publish) {
        tx.update(db.collection(NODES).doc(v.value.serviceId), {
          questionnaireId: ref.id, questionnaireVersion: version, updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return { id: ref.id, version };
    });
    await audit(auth.uid, publish ? 'Publicou questionário' : 'Salvou rascunho de questionário',
      v.value.serviceId, result);
    if (publish) await bumpMeta(auth.uid, `questionnaire:${v.value.serviceId}`);
    return { ok: true, ...result, status: publish ? 'published' : 'draft' };
  });

  /** Índice de busca do prestador (tokens, cidade normalizada). */
  ex.onProviderIndex = functions.firestore.document('providers/{id}').onWrite(async (change) => {
    if (!change.after.exists) return null;
    await writeProviderIndex(change.after.ref, change.after.data(), await cachedNodes());
    return null;
  });

  ex.onCompanyIndex = functions.firestore.document('companies/{id}').onWrite(async (change) => {
    if (!change.after.exists) return null;
    await writeCompanyIndex(change.after.ref, change.after.data());
    return null;
  });

  /** Snapshot do serviço contratado: pedidos antigos seguem legíveis. */
  async function stampSnapshot(snap) {
    const d = snap.data() || {};
    if (!d.category || d.serviceSnapshot || d.type === 'marketplace') return null;
    const s = core.serviceSnapshot(d.category, await cachedNodes());
    if (s) await snap.ref.update({ serviceSnapshot: s });
    return null;
  }
  ex.onOrderSnapshot = functions.firestore.document('orders/{id}').onCreate(stampSnapshot);
  ex.onResolveSnapshot = functions.firestore.document('resolveRequests/{id}').onCreate(stampSnapshot);

  return ex;
};
