'use strict';

/**
 * Carteira interna em CENTAVOS com razão auditável (coleção
 * `transactions`). Uso em DUAS FASES dentro de uma transação:
 *
 *   const w = await readWallet(tx, db, uid, ledgerKey);   // só leituras
 *   ...outras leituras...
 *   postLedger(tx, db, w, {...});                          // só escritas
 *
 * - A chave do lançamento (doc id em `transactions`) torna o lançamento
 *   idempotente: repetir a mesma operação não credita/debita de novo.
 * - Saldo nunca fica negativo (débito recusado).
 * - `balance` (reais) é mantido só como espelho legado para exibição.
 */
const { FieldValue } = require('firebase-admin/firestore');
const fin = require('../financeCore');

const ICONS = {
  credit: '💰', recharge: '⚡', payment: '👜', refund: '↩️', cashback: '🎁',
  cashback_reversal: '🎁', sale_release: '🏪', sale_reversal: '🏪', payout: '💰', debit: '👜',
};

async function readWallet(tx, db, uid, ledgerKey) {
  const ref = db.collection('wallets').doc(uid);
  const ledgerRef = db.collection('transactions').doc(ledgerKey);
  const [w, l] = await Promise.all([tx.get(ref), tx.get(ledgerRef)]);
  const d = w.exists ? w.data() : {};
  const balanceCents = Number.isInteger(d.balanceCents) ? d.balanceCents : (fin.toCents(d.balance || 0) || 0);
  return { uid, ref, ledgerRef, ledgerKey, balanceCents, alreadyPosted: l.exists };
}

/**
 * Escreve o lançamento. Retorna { ok, posted, error, balanceCents }.
 * Nunca lança exceção por saldo: o chamador decide o que fazer.
 */
function postLedger(tx, w, { type, amountCents, description, refKind, refId, extra }) {
  if (w.alreadyPosted) return { ok: true, posted: false, balanceCents: w.balanceCents };
  const r = fin.applyLedger(w.balanceCents, type, amountCents);
  if (!r.ok) return { ok: false, posted: false, error: r.error, balanceCents: w.balanceCents };
  tx.set(w.ref, {
    userId: w.uid,
    balanceCents: r.balanceCents,
    balance: fin.fromCents(r.balanceCents),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  tx.set(w.ledgerRef, {
    userId: w.uid,
    type,
    amountCents,
    signedCents: r.signed,
    amount: fin.fromCents(amountCents),
    balanceAfterCents: r.balanceCents,
    description: String(description || '').slice(0, 200),
    icon: ICONS[type] || '💰',
    refKind: refKind || null,
    refId: refId || null,
    status: 'done',
    createdAt: FieldValue.serverTimestamp(),
    ...(extra || {}),
  });
  w.balanceCents = r.balanceCents;
  w.alreadyPosted = true;
  return { ok: true, posted: true, balanceCents: r.balanceCents };
}

/** Soma assinada do razão (inclui lançamentos legados em reais). */
function signedOf(t) {
  if (Number.isInteger(t.signedCents)) return t.signedCents;
  const cents = Number.isInteger(t.amountCents) ? t.amountCents : (fin.toCents(t.amount || 0) || 0);
  const debit = ['debit', 'payment', 'withdraw', 'sale_reversal', 'cashback_reversal'].includes(t.type);
  if (t.type === 'withdraw' && t.status === 'pending') return -cents; // legado: saque debitava na hora
  return debit ? -cents : cents;
}

module.exports = { readWallet, postLedger, signedOf };
