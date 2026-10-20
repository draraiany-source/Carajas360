'use strict';
const { test } = require('node:test');
const assert = require('node:assert');
const p = require('./push');

test('collectTargets: aparelhos sem repetidos, legado só se não estiver entre eles, limite', () => {
  const devs = [{ id: 'a', token: 't1' }, { id: 'b', token: 't2' }, { id: 'c', token: 't1' }, { id: 'd', token: '' }];
  assert.deepStrictEqual(p.collectTargets(devs, 't2').map((t) => t.token), ['t1', 't2']);
  const withLegacy = p.collectTargets(devs, 'old');
  assert.deepStrictEqual(withLegacy.map((t) => [t.token, Boolean(t.legacy)]), [['t1', false], ['t2', false], ['old', true]]);
  assert.deepStrictEqual(p.collectTargets([], 'old').map((t) => t.token), ['old']);
  const many = Array.from({ length: 30 }, (_, i) => ({ id: `d${i}`, token: `t${i}` }));
  assert.strictEqual(p.collectTargets(many, 'old').length, p.MAX_DEVICES);
});

test('isInvalidTokenError: só erros de token', () => {
  assert.ok(p.isInvalidTokenError({ code: 'messaging/registration-token-not-registered' }));
  assert.ok(p.isInvalidTokenError({ code: 'messaging/invalid-registration-token' }));
  assert.ok(p.isInvalidTokenError({ code: 'messaging/invalid-argument', message: 'The registration token is not a valid FCM registration token' }));
  assert.ok(!p.isInvalidTokenError({ code: 'messaging/invalid-argument', message: 'Invalid JSON payload' }));
  assert.ok(!p.isInvalidTokenError({ code: 'messaging/internal-error' }));
  assert.ok(!p.isInvalidTokenError(null));
});

test('pushTransportMode: simulador só no emulador', () => {
  assert.strictEqual(p.pushTransportMode({ PUSH_TRANSPORT: 'fake', FUNCTIONS_EMULATOR: 'true' }), 'fake');
  assert.strictEqual(p.pushTransportMode({ PUSH_TRANSPORT: 'fake' }), 'fcm');
  assert.strictEqual(p.pushTransportMode({}), 'fcm');
});

test('buildMessage: data só com textos (exigência do FCM)', () => {
  const m = p.buildMessage({ title: 'T', body: 'B', type: 'order', link: { route: 'marketOrder', id: 7 } });
  assert.deepStrictEqual(m.data, { type: 'order', route: 'marketOrder', id: '7' });
  assert.deepStrictEqual(p.buildMessage({}).data, { type: '', route: '', id: '' });
});
