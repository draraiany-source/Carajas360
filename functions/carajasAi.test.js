const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const ai = require('./carajasAi');

describe('carajasAi', () => {
  it('normalizeMode', () => {
    assert.equal(ai.normalizeMode('health'), 'health');
    assert.equal(ai.normalizeMode('x'), 'client');
  });

  it('detectIntent urgency', () => {
    assert.equal(ai.detectIntent('preciso de SAMU urgente'), 'urgency');
  });

  it('guessCategory', () => {
    assert.equal(ai.guessCategory('tomada queimou'), 'eletricista');
    assert.equal(ai.guessCategory('consulta com psicólogo'), 'psicologo');
  });

  it('groundedFallback não inventa quando lista vazia', () => {
    const out = ai.groundedFallback({
      mode: 'client',
      providers: [],
      intent: 'search',
      message: 'quero alguém',
    });
    assert.match(out.reply, /Não encontrei profissionais/i);
    assert.equal(out.providers.length, 0);
  });

  it('groundedFallback lista só providers fornecidos', () => {
    const out = ai.groundedFallback({
      mode: 'client',
      providers: [{ id: 'a', name: '[TESTE] Ana', categories: ['medico'], city: 'Marabá' }],
      intent: 'health',
      message: 'médico',
    });
    assert.match(out.reply, /\[TESTE\] Ana/);
    assert.equal(out.providers[0].id, 'a');
  });

  it('urgency prioriza emergência', () => {
    const out = ai.groundedFallback({
      mode: 'health',
      providers: [{ id: 'a', name: 'X', categories: ['medico'] }],
      intent: 'urgency',
      message: 'infarto',
    });
    assert.match(out.reply, /192/);
    assert.equal(out.providers.length, 0);
  });

  it('estimateCostUsd zero sem LLM', () => {
    const c = ai.estimateCostUsd({ inputChars: 100, outputChars: 100, usedLlm: false });
    assert.equal(c.usd, 0);
  });

  it('scopedConversationId isola por uid', () => {
    const a = ai.scopedConversationId('userA', 'userB', 'client');
    const b = ai.scopedConversationId('userB', 'userA', 'client');
    assert.match(a, /^u_userA_/);
    assert.match(b, /^u_userB_/);
    assert.notEqual(a, b);
    assert.ok(!a.includes('userB') || a.startsWith('u_userA_'));
  });

  it('sanitizeAnthropicKey rejeita placeholders', () => {
    assert.equal(ai.sanitizeAnthropicKey(''), '');
    assert.equal(ai.sanitizeAnthropicKey('disabled'), '');
    assert.equal(ai.sanitizeAnthropicKey('short'), '');
    assert.ok(ai.sanitizeAnthropicKey('sk-ant-api03-abcdefghijklmnopqrstuvwxyz').length > 0);
  });
});
