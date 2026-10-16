#!/usr/bin/env node
'use strict';
/**
 * Contas de teste de homologação (cliente, prestador, loja, admin).
 *
 *   # emulador local
 *   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
 *     node tool/seed_hml_accounts.js --project demo-carajas360
 *   # homologação (credencial de serviço do projeto hml, fora do Git)
 *   GOOGLE_APPLICATION_CREDENTIALS=/caminho/sa-hml.json node tool/seed_hml_accounts.js --project carajas360-hml
 *
 * Segurança:
 *  - Recusa projetos de produção (lista em PROD_PROJECT_IDS e nomes sem "hml"/"demo-").
 *  - Senhas aleatórias geradas aqui e mostradas UMA vez no terminal de quem
 *    executa (guarde num cofre de senhas); nada é gravado em arquivo ou log.
 *  - Reexecutar redefine as senhas das mesmas contas (e-mails fixos por papel).
 */
const crypto = require('crypto');
const path = require('path');
const admin = require(path.join(__dirname, '../functions/node_modules/firebase-admin'));

const args = process.argv.slice(2);
const project = args[args.indexOf('--project') + 1];
const domain = (args.includes('--domain') && args[args.indexOf('--domain') + 1]) || 'hml.carajas360.test';
const PROD = (process.env.PROD_PROJECT_IDS || 'servicoconecta,carajas360-a17c5').split(',').map((s) => s.trim());
if (!project || args.indexOf('--project') < 0) { console.error('Informe --project <id-do-projeto-de-homologação>'); process.exit(2); }
if (PROD.includes(project) || !/(^demo-|hml|homolog|staging)/.test(project)) {
  console.error(`Recusado: "${project}" não parece homologação. Este script nunca roda em produção.`);
  process.exit(3);
}

admin.initializeApp({ projectId: project });
const auth = admin.auth();
const db = admin.firestore();
const password = () => `${crypto.randomBytes(9).toString('base64url')}#9a`;

const ACCOUNTS = [
  { role: 'cliente', email: `cliente@${domain}`, name: 'Cliente Teste', user: { type: 'client' } },
  { role: 'prestador', email: `prestador@${domain}`, name: 'Prestador Teste', user: { type: 'provider' },
    provider: { name: 'Prestador Teste', categories: ['eletricista'], modalities: ['presential'], city: 'Marabá', verified: true, active: true } },
  { role: 'loja', email: `loja@${domain}`, name: 'Loja Teste', user: { type: 'company' } },
  { role: 'admin', email: `admin@${domain}`, name: 'Admin Teste', user: { type: 'admin', adminRole: 'master' } },
];

(async () => {
  const out = [];
  for (const a of ACCOUNTS) {
    const pw = password();
    let u;
    try {
      u = await auth.getUserByEmail(a.email);
      await auth.updateUser(u.uid, { password: pw, disabled: false });
    } catch (e) {
      if (e.code !== 'auth/user-not-found') throw e;
      u = await auth.createUser({ email: a.email, password: pw, displayName: a.name, emailVerified: true });
    }
    await db.doc(`users/${u.uid}`).set({ name: a.name, email: a.email, ...a.user, status: 'active', testAccount: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    if (a.provider) await db.doc(`providers/${u.uid}`).set({ userId: u.uid, rating: 0, totalReviews: 0, verificationStatus: 'approved', ...a.provider }, { merge: true });
    if (a.role === 'loja') {
      await db.doc(`stores/${u.uid}_loja`).set({ ownerId: u.uid, name: 'Loja Teste', active: true, verified: false, rating: 0, totalReviews: 0, pickupEnabled: true, deliveryEnabled: true, deliveryFeeCents: 500 }, { merge: true });
    }
    out.push({ papel: a.role, email: a.email, senha: pw });
  }
  // Exibição única no terminal (não redirecione para arquivo versionado).
  console.log('\nContas de teste (guarde num cofre de senhas; não envie por chat/e-mail):');
  for (const o of out) console.log(`  ${o.papel.padEnd(10)} ${o.email.padEnd(32)} ${o.senha}`);
  console.log('\nReexecutar o script gera senhas novas para as mesmas contas.');
  process.exit(0);
})().catch((e) => { console.error('Falhou:', e.message); process.exit(1); });
