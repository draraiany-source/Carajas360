#!/usr/bin/env node
'use strict';

/**
 * Migração 001 — contato de pedidos abertos (resolveRequests) para
 * resolveRequests/{id}/private/contact.
 *
 * Padrão: simulação (nada é gravado). Opções:
 *   --apply          grava a cópia em private/contact (idempotente)
 *   --remove-public  com --apply, remove clientName/address/clientPhone do
 *                    documento público depois de copiados
 *
 * Credenciais: GOOGLE_APPLICATION_CREDENTIALS (conta de serviço) ou
 * FIRESTORE_EMULATOR_HOST para rodar no emulador. Rodar primeiro no
 * emulador/staging e só depois de um export do Firestore.
 */
const path = require('path');
const admin = require(path.join(__dirname, '..', '..', 'functions', 'node_modules', 'firebase-admin'));

const APPLY = process.argv.includes('--apply');
const REMOVE_PUBLIC = APPLY && process.argv.includes('--remove-public');
const CONTACT_KEYS = ['clientName', 'address', 'clientPhone'];

async function main() {
  admin.initializeApp();
  const db = admin.firestore();
  const snap = await db.collection('resolveRequests').get();
  let toCopy = 0;
  let copied = 0;
  let cleaned = 0;

  for (const doc of snap.docs) {
    const data = doc.data() || {};
    const present = CONTACT_KEYS.filter((k) => data[k] != null && data[k] !== '');
    if (present.length === 0) continue;
    toCopy += 1;
    const privRef = doc.ref.collection('private').doc('contact');
    if (!APPLY) {
      console.log(`[simulação] ${doc.id}: copiaria ${present.join(', ')}`);
      continue;
    }
    const existing = await privRef.get();
    const current = existing.exists ? existing.data() || {} : {};
    const patch = { clientId: data.clientId || current.clientId || null };
    for (const k of present) {
      if (current[k] == null || current[k] === '') patch[k] = data[k];
    }
    await privRef.set(patch, { merge: true });
    copied += 1;
    if (REMOVE_PUBLIC) {
      const del = {};
      for (const k of present) del[k] = admin.firestore.FieldValue.delete();
      await doc.ref.update(del);
      cleaned += 1;
    }
  }

  console.log(JSON.stringify({
    mode: APPLY ? 'apply' : 'dry-run',
    scanned: snap.size,
    withPublicContact: toCopy,
    copied,
    publicFieldsRemoved: cleaned,
  }, null, 2));
}

main().catch((err) => {
  console.error('Falha na migração:', err && err.message);
  process.exit(1);
});
