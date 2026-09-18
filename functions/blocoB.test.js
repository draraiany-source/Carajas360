'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const security = require('./security');
const deletion = require('./accountDeletion');

describe('CPF — validação matemática', () => {
  it('aceita CPF válido com e sem máscara', () => {
    assert.equal(security.isValidCpf('52998224725'), true);
    assert.equal(security.isValidCpf('529.982.247-25'), true);
    assert.equal(security.isValidCpf('11144477735'), true);
  });

  it('rejeita sequências repetidas', () => {
    assert.equal(security.isValidCpf('00000000000'), false);
    assert.equal(security.isValidCpf('111.111.111-11'), false);
    assert.equal(security.isValidCpf('99999999999'), false);
  });

  it('rejeita tamanho errado e dígito verificador inválido', () => {
    assert.equal(security.isValidCpf('123'), false);
    assert.equal(security.isValidCpf('12345678901'), false);
    assert.equal(security.isValidCpf('52998224724'), false);
    assert.equal(security.isValidCpf(''), false);
  });

  it('sanitizePiiWrite remove CPF inválido', () => {
    const bad = security.sanitizePiiWrite({ cpf: '11111111111', phone: '11999999999' });
    assert.equal(bad.cpf, undefined);
    assert.equal(bad.cpfRejected, true);
    const good = security.sanitizePiiWrite({ cpf: '529.982.247-25' });
    assert.equal(good.cpf, '52998224725');
  });
});

describe('XP — só backend', () => {
  it('client não pode escrever XP', () => {
    assert.equal(security.clientMayWriteXp(), false);
    assert.ok(security.USER_PROTECTED_KEYS.includes('xp'));
  });

  it('recompensas oficiais e eventId idempotente', () => {
    assert.equal(security.xpAmountFor('signup'), 50);
    assert.equal(security.xpAmountFor('review'), 30);
    assert.equal(security.xpAmountFor('hack'), 0);
    assert.equal(security.xpEventId('review', 'abc'), 'review_abc');
  });
});

describe('LGPD — exclusão / retenção', () => {
  it('não apaga coleções financeiras/fiscais', () => {
    for (const c of ['orders', 'payments', 'transactions', 'financialAudits', 'contracts']) {
      assert.equal(deletion.mustRetainCollection(c), true);
      assert.equal(deletion.mayDeleteCollection(c), false);
    }
  });

  it('pode apagar favoritos e notificações', () => {
    assert.equal(deletion.mayDeleteCollection('favorites'), true);
    assert.equal(deletion.mayDeleteCollection('notifications'), true);
  });

  it('perfil anonimizado remove PII e marca deleted', () => {
    const p = deletion.userAnonymizedProfile();
    assert.equal(p.status, 'deleted');
    assert.equal(p.anonymized, true);
    assert.equal(p.name, 'Usuário removido');
    assert.equal(p.cpf, null);
    assert.equal(p.phone, null);
    assert.equal(p.email, '');
  });

  it('não permite hard-delete do doc de usuário pelo client', () => {
    assert.equal(deletion.adminMayHardDeleteUserDoc(), false);
  });

  it('retenção legal é de 5 anos', () => {
    assert.equal(deletion.retentionYears(), 5);
    const until = deletion.retentionUntil(new Date('2026-01-01T00:00:00Z'));
    assert.equal(until.getUTCFullYear(), 2031);
  });
});
