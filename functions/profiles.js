'use strict';

/**
 * Perfil público MÍNIMO (Fase 6): publicProfiles/{uid} = nome de exibição,
 * foto e tipo. Mantido só pelo servidor a partir de users/{uid} (privado)
 * e de providers/{uid} aprovado. Usado no chat e onde o app precisa
 * mostrar "quem é a outra pessoa" sem ler o perfil privado.
 *
 * Cliente: primeiro nome + inicial do sobrenome ("Maria S.").
 * Prestador aprovado: nome do perfil público de prestador (já público).
 */
function displayName(full) {
  const parts = String(full || '').trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return null;
  const first = parts[0].slice(0, 30);
  return parts.length > 1 ? `${first} ${parts[parts.length - 1][0].toUpperCase()}.` : first;
}

function buildPublicProfile(user, provider) {
  const u = user || {};
  const p = provider && provider.verified === true && provider.active !== false ? provider : null;
  return {
    name: (p && String(p.name || '').trim().slice(0, 80)) || displayName(u.name) || 'Usuário',
    photoUrl: (p && p.photoUrl) || u.photoUrl || null,
    kind: p ? 'provider' : (u.type === 'admin' ? 'support' : (u.type || 'client')),
    verified: Boolean(p),
  };
}

function profileFunctions(deps) {
  const { functions, db, FieldValue, requireAuth, isAdmin, httpsError, REGION } = deps;
  const ex = {};

  async function refresh(uid) {
    const [u, p] = await Promise.all([db.collection('users').doc(uid).get(), db.collection('providers').doc(uid).get()]);
    if (!u.exists && !p.exists) {
      await db.collection('publicProfiles').doc(uid).delete().catch(() => {});
      return null;
    }
    const prof = buildPublicProfile(u.exists ? u.data() : null, p.exists ? p.data() : null);
    await db.collection('publicProfiles').doc(uid).set({ ...prof, updatedAt: FieldValue.serverTimestamp() });
    return prof;
  }

  ex.onUserPublicProfile = functions.firestore.document('users/{uid}').onWrite((c, ctx) => refresh(ctx.params.uid));
  ex.onProviderPublicProfile = functions.firestore.document('providers/{uid}').onWrite((c, ctx) => refresh(ctx.params.uid));

  /** Admin: gera perfis públicos dos usuários existentes (idempotente). */
  ex.migratePublicProfiles = functions.region(REGION).runWith({ timeoutSeconds: 540 }).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
    const dryRun = data?.dryRun === true;
    const users = await db.collection('users').select().get();
    let done = 0;
    if (!dryRun) for (const d of users.docs) { await refresh(d.id); done += 1; }
    return { dryRun, users: users.size, updated: done };
  });
  return ex;
}

module.exports = profileFunctions;
module.exports.displayName = displayName;
module.exports.buildPublicProfile = buildPublicProfile;
