'use strict';
const test = require('node:test');
const assert = require('node:assert');
const h = require('./healthCore');
const r = require('./rentalCore');

const H = 3600000;
// Segunda 12/10/2026 08:00 em Belém = 11:00 UTC
const NOW = Date.UTC(2026, 9, 12, 11, 0);
const sched = h.validateSchedule({
  slotMinutes: 30, minLeadHours: 2,
  weekly: { 1: [{ start: '08:00', end: '12:00' }, { start: '14:00', end: '16:00' }], 2: [{ start: '09:00', end: '10:00' }] },
  blockedDates: ['2026-10-19'],
  services: [{ catalogId: 'cardio', durationMin: 60, priceCents: 25000, modalities: ['online', 'presential'] }],
}).value;

test('fuso: horário local de Belém (UTC−3) ↔ UTC', () => {
  assert.strictEqual(h.localToUtc('2026-10-12', 8 * 60), NOW);
  assert.strictEqual(h.localDateOf(Date.UTC(2026, 9, 13, 2)), '2026-10-12');
  assert.strictEqual(h.localHmOf(NOW), '08:00');
});

test('agenda: validação de faixas, serviços e sobreposição de faixas', () => {
  assert.ok(!h.validateSchedule({ weekly: { 1: [{ start: '10:00', end: '09:00' }] } }).ok);
  assert.ok(!h.validateSchedule({ weekly: { 1: [{ start: '08:00', end: '11:00' }, { start: '10:00', end: '12:00' }] } }).ok);
  assert.ok(!h.validateSchedule({ weekly: { 9: [] } }).ok);
  assert.ok(!h.validateSchedule({ services: [{ catalogId: 'x', durationMin: 5, priceCents: 1, modalities: ['online'] }] }).ok);
  assert.ok(!h.validateSchedule({ services: [{ catalogId: 'x', durationMin: 30, priceCents: 100, modalities: [] }] }).ok);
  assert.strictEqual(sched.services[0].priceCents, 25000);
});

test('horários livres: faixas, duração, antecedência mínima, data bloqueada e ocupados', () => {
  const today = h.freeSlots(sched, '2026-10-12', 60, [], NOW).map((s) => s.label);
  // antecedência de 2 h: a partir das 10:00; 60 min cabem até 11:00 e 14:00–15:00
  assert.deepStrictEqual(today, ['10:00', '10:30', '11:00', '14:00', '14:30', '15:00']);
  const busy = [{ startMs: h.localToUtc('2026-10-12', 14 * 60 + 30), endMs: h.localToUtc('2026-10-12', 15 * 60 + 30) }];
  assert.deepStrictEqual(h.freeSlots(sched, '2026-10-12', 60, busy, NOW).map((s) => s.label), ['10:00', '10:30', '11:00']);
  assert.deepStrictEqual(h.freeSlots(sched, '2026-10-19', 60, [], NOW), [], 'data bloqueada');
  assert.deepStrictEqual(h.freeSlots(sched, '2026-10-14', 60, [], NOW), [], 'quarta sem faixa');
  assert.deepStrictEqual(h.freeSlots(sched, '2026-10-11', 60, [], NOW), [], 'passado');
  assert.deepStrictEqual(h.freeSlots(sched, '2027-03-01', 60, [], NOW), [], 'além de 90 dias');
  assert.ok(h.slotAllowed(sched, h.localToUtc('2026-10-13', 9 * 60), 60, [], NOW));
  assert.ok(!h.slotAllowed(sched, h.localToUtc('2026-10-13', 9 * 60 + 10), 30, [], NOW), 'fora da grade');
});

test('cancelar/reagendar/concluir: autorização e prazos', () => {
  const ap = { clientId: 'c', providerId: 'p', status: 'scheduled', startMs: NOW + 5 * H, rescheduleCount: 0 };
  assert.ok(h.actionAllowed('cancel', ap, 'c', NOW).ok);
  assert.strictEqual(h.actionAllowed('cancel', { ...ap, startMs: NOW + H }, 'c', NOW).reason, 'too_late');
  assert.ok(h.actionAllowed('cancel', { ...ap, startMs: NOW + H }, 'p', NOW).ok, 'profissional cancela sempre');
  assert.strictEqual(h.actionAllowed('cancel', ap, 'x', NOW).reason, 'not_participant');
  assert.strictEqual(h.actionAllowed('reschedule', { ...ap, rescheduleCount: 2 }, 'c', NOW).reason, 'limit_reached');
  assert.strictEqual(h.actionAllowed('complete', ap, 'p', NOW).reason, 'not_started');
  assert.strictEqual(h.actionAllowed('complete', ap, 'c', NOW + 6 * H).reason, 'provider_only');
  assert.ok(h.actionAllowed('complete', ap, 'p', NOW + 6 * H).ok);
  assert.strictEqual(h.actionAllowed('cancel', { ...ap, status: 'cancelled' }, 'c', NOW).reason, 'not_active');
});

const rental = { active: true, available: true, pricePerHour: 50, pricePerDay: 300, pricePerMonth: 5000 };

test('locação: preço e total no servidor, fim do período e limites', () => {
  const start = NOW + 24 * H;
  const q = r.quote(rental, { period: 'day', quantity: 3, startMs: start }, NOW);
  assert.ok(q.ok, q.errors.join());
  assert.strictEqual(q.value.totalCents, 90000);
  assert.strictEqual(q.value.endMs, start + 72 * H);
  assert.ok(r.quote(rental, { period: 'diária', quantity: 1, startMs: start }, NOW).ok, 'rótulo legado');
  assert.ok(!r.quote(rental, { period: 'week', quantity: 1, startMs: start }, NOW).ok, 'sem preço semanal');
  assert.ok(!r.quote(rental, { period: 'day', quantity: 0, startMs: start }, NOW).ok);
  assert.ok(!r.quote(rental, { period: 'hour', quantity: 100, startMs: start }, NOW).ok);
  assert.ok(!r.quote(rental, { period: 'day', quantity: 1, startMs: NOW }, NOW).ok, 'início no passado/imediato');
  assert.ok(!r.quote({ ...rental, available: false }, { period: 'day', quantity: 1, startMs: start }, NOW).ok);
  // 31/01 + 1 mês = 28/02 (sem transbordar)
  const jan31 = h.localToUtc('2027-01-31', 9 * 60);
  assert.strictEqual(h.localDateOf(r.endOf(jan31, 'month', 1)), '2027-02-28');
});

test('locação: sobreposição e reservas que bloqueiam', () => {
  assert.ok(r.overlaps(0, 10, 9, 20));
  assert.ok(!r.overlaps(0, 10, 10, 20), 'encostar não sobrepõe');
  assert.ok(r.blocking({ status: 'confirmed', startMs: NOW - H }, NOW));
  assert.ok(!r.blocking({ status: 'pending', startMs: NOW - H }, NOW), 'pendente vencida não bloqueia');
  assert.ok(!r.blocking({ status: 'cancelled', startMs: NOW + H }, NOW));
});

test('locação: transições autorizadas por papel e prazo', () => {
  const b = { ownerId: 'o', clientId: 'c', status: 'pending', startMs: NOW + 48 * H };
  assert.ok(r.transitionAllowed('confirm', b, 'o', NOW).ok);
  assert.strictEqual(r.transitionAllowed('confirm', b, 'c', NOW).reason, 'owner_only');
  assert.ok(r.transitionAllowed('cancel', b, 'c', NOW).ok);
  const c = { ...b, status: 'confirmed' };
  assert.ok(r.transitionAllowed('cancel', c, 'c', NOW).ok, 'cliente até 24 h antes');
  assert.strictEqual(r.transitionAllowed('cancel', { ...c, startMs: NOW + 10 * H }, 'c', NOW).reason, 'too_late');
  assert.strictEqual(r.transitionAllowed('cancel', c, 'o', NOW).reason, 'reason_required');
  assert.ok(r.transitionAllowed('cancel', c, 'o', NOW, 'Veículo em manutenção').ok);
  assert.strictEqual(r.transitionAllowed('start', c, 'o', NOW).reason, 'not_started');
  assert.ok(r.transitionAllowed('start', c, 'o', NOW + 48 * H).ok);
  assert.strictEqual(r.transitionAllowed('complete', c, 'o', NOW).reason, 'invalid_transition');
  assert.strictEqual(r.transitionAllowed('confirm', b, 'x', NOW).reason, 'not_participant');
});
