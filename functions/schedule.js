'use strict';

/**
 * Saúde e Locação (Fase 5): agendamento com disponibilidade real e
 * reserva de locação com preço por período, ambos SERIALIZADOS por um
 * documento de calendário (por profissional / por anúncio) dentro da
 * transação — duas reservas simultâneas no mesmo horário não passam.
 * Notificações por evento (gatilhos), nunca escritas pelo app.
 */
const crypto = require('crypto');
const hc = require('./healthCore');
const rc = require('./rentalCore');
const catalogCore = require('./catalogCore');

// Versão do termo de consentimento para dados de saúde (LGPD, art. 11).
const HEALTH_CONSENT_VERSION = '2026-10';

module.exports = function scheduleFunctions(deps) {
  const { functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit, notifySafe } = deps;
  const { Timestamp } = require('firebase-admin/firestore');
  const sid = (...p) => crypto.createHash('sha256').update(p.join('|')).digest('hex').slice(0, 24);
  const APPTS = db.collection('appointments');
  const BOOKINGS = db.collection('bookings');
  const ex = {};

  let cache = null;
  async function nodes() {
    const meta = await db.collection('catalogMeta').doc('current').get();
    const v = meta.exists ? `${meta.data().version || 0}` : '0';
    if (cache && cache.v === v && Date.now() - cache.at < 10 * 60000) return cache.nodes;
    const s = await db.collection('catalogNodes').get();
    const out = {};
    s.docs.forEach((d) => { out[d.id] = { id: d.id, ...d.data() }; });
    cache = { at: Date.now(), v, nodes: out };
    return out;
  }
  const fmt = (ms) => `${hc.localDateOf(ms).split('-').reverse().join('/')} às ${hc.localHmOf(ms)}`;

  // ═════════════════════════════ SAÚDE ═════════════════════════════
  async function healthContext(providerId, catalogId) {
    const [provSnap, schedSnap, ns] = await Promise.all([
      db.collection('providers').doc(providerId).get(),
      db.collection('healthSchedules').doc(providerId).get(),
      nodes(),
    ]);
    const prov = provSnap.exists ? provSnap.data() : null;
    if (!prov || prov.verified !== true || prov.active !== true) throw httpsError('failed-precondition', 'Profissional indisponível');
    const root = catalogCore.rootOf(catalogId, ns);
    if (!root || root.vertical !== 'health' || !catalogCore.effectiveActive(catalogId, ns)) {
      throw httpsError('invalid-argument', 'Especialidade de saúde inválida');
    }
    // Auditoria: só especialidades do perfil aprovado (a agenda é editada
    // pelo prestador e não pode incluir especialidade não verificada).
    if (!(prov.categories || []).includes(catalogId)) {
      throw httpsError('failed-precondition', 'O profissional não atende esta especialidade');
    }
    if (!schedSnap.exists) throw httpsError('failed-precondition', 'Este profissional ainda não publicou a agenda');
    const sched = hc.validateSchedule(schedSnap.data()).value;
    const service = sched.services.find((s) => s.catalogId === catalogId);
    if (!service) throw httpsError('failed-precondition', 'O profissional não atende esta especialidade pela agenda');
    return { prov, sched, service, serviceName: (ns[catalogId] && ns[catalogId].name) || 'Consulta' };
  }

  function dayBusyQuery(providerId, dateStr) {
    const from = hc.localToUtc(dateStr, 0) - 4 * 3600000; // margem para consultas longas
    const to = hc.localToUtc(dateStr, 24 * 60);
    return APPTS.where('providerId', '==', providerId).where('status', '==', 'scheduled')
      .where('startMs', '>=', from).where('startMs', '<', to);
  }
  const busyOf = (snap, exceptId) => snap.docs.filter((d) => d.id !== exceptId)
    .map((d) => ({ startMs: d.data().startMs, endMs: d.data().endMs }));

  /** Horários livres de um dia (dados públicos: só horários). */
  ex.listHealthSlots = functions.region(REGION).https.onCall(async (data, context) => {
    requireAuth(context);
    const providerId = String(data?.providerId || '');
    const catalogId = String(data?.catalogId || '');
    const date = String(data?.date || '');
    const { sched, service } = await healthContext(providerId, catalogId);
    const busy = busyOf(await dayBusyQuery(providerId, date).get());
    return {
      date, timezone: hc.TZ, durationMin: service.durationMin, priceCents: service.priceCents,
      modalities: service.modalities,
      slots: hc.freeSlots(sched, date, service.durationMin, busy, Date.now()).map((s) => ({ startMs: s.startMs, label: s.label })),
    };
  });

  /**
   * Agenda a consulta. Exige profissional, especialidade, data/horário
   * válidos da agenda e consentimento. Idempotente por requestId.
   * Motivo/sintomas ficam em appointments/{id}/private/clinical.
   */
  ex.bookHealthAppointment = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'health_book', 20, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    if (data?.consentVersion !== HEALTH_CONSENT_VERSION) {
      throw httpsError('failed-precondition', 'É necessário aceitar o termo de uso de dados de saúde');
    }
    const providerId = String(data?.providerId || '');
    const catalogId = String(data?.catalogId || '');
    const startMs = Number(data?.startMs);
    const modality = String(data?.modality || '');
    if (!providerId || !catalogId || !Number.isFinite(startMs)) throw httpsError('invalid-argument', 'Profissional, especialidade e horário são obrigatórios');
    if (providerId === auth.uid) throw httpsError('invalid-argument', 'Você não pode agendar consigo mesmo');
    const id = `ap_${sid(auth.uid, requestId)}`;
    const ref = APPTS.doc(id);
    const existing = await ref.get();
    if (existing.exists) return { id, reused: true, startMs: existing.data().startMs };
    const { prov, service, serviceName } = await healthContext(providerId, catalogId);
    if (!service.modalities.includes(modality)) throw httpsError('invalid-argument', 'Modalidade não oferecida para esta especialidade');
    const reason = String(data?.reason || '').trim().slice(0, 1000);
    const date = hc.localDateOf(startMs);
    const calRef = db.collection('healthCalendars').doc(providerId);

    await db.runTransaction(async (tx) => {
      const [again, , schedSnap, busySnap] = await Promise.all([
        tx.get(ref), tx.get(calRef), tx.get(db.collection('healthSchedules').doc(providerId)), tx.get(dayBusyQuery(providerId, date)),
      ]);
      if (again.exists) return;
      const sched = hc.validateSchedule(schedSnap.data()).value;
      if (!hc.slotAllowed(sched, startMs, service.durationMin, busyOf(busySnap), Date.now())) {
        throw httpsError('failed-precondition', 'Horário indisponível. Escolha outro horário.');
      }
      const endMs = startMs + service.durationMin * 60000;
      tx.set(ref, {
        clientId: auth.uid, providerId, providerName: prov.name || '',
        catalogId, serviceName, modality,
        startMs, endMs, startAt: Timestamp.fromMillis(startMs), endAt: Timestamp.fromMillis(endMs),
        date, timezone: hc.TZ, priceCents: service.priceCents, status: 'scheduled', rescheduleCount: 0,
        consent: { version: HEALTH_CONSENT_VERSION, at: FieldValue.serverTimestamp() },
        requestId, createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('private').doc('clinical'), {
        clientId: auth.uid, providerId, reason: reason || null, updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(calRef, { version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      tx.set(db.collection('healthConsents').doc(auth.uid), {
        version: HEALTH_CONSENT_VERSION, acceptedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    });
    return { id, reused: false, startMs };
  });

  /** Cancelar, reagendar, concluir ou registrar falta — com autorização e prazos. */
  ex.healthAppointmentAction = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const action = String(data?.action || '');
    const apptId = String(data?.appointmentId || '');
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(apptId)) throw httpsError('invalid-argument', 'appointmentId inválido');
    const ref = APPTS.doc(apptId);
    const pre = await ref.get();
    if (!pre.exists) throw httpsError('not-found', 'Agendamento não encontrado');
    const ap0 = pre.data();
    let service = null;
    if (action === 'reschedule') ({ service } = await healthContext(ap0.providerId, ap0.catalogId));
    const newStart = Number(data?.newStartMs);
    const reason = String(data?.reason || '').trim().slice(0, 300);
    const calRef = db.collection('healthCalendars').doc(ap0.providerId);
    await db.runTransaction(async (tx) => {
      const reads = [tx.get(ref), tx.get(calRef)];
      if (action === 'reschedule') {
        if (!Number.isFinite(newStart)) throw httpsError('invalid-argument', 'Novo horário obrigatório');
        reads.push(tx.get(db.collection('healthSchedules').doc(ap0.providerId)), tx.get(dayBusyQuery(ap0.providerId, hc.localDateOf(newStart))));
      }
      const [snap, , schedSnap, busySnap] = await Promise.all(reads);
      const ap = snap.data();
      const ok = hc.actionAllowed(action, ap, auth.uid, Date.now());
      if (!ok.ok) {
        const msg = { too_late: `Cancelamento/reagendamento pelo paciente só até ${hc.CANCEL_MIN_HOURS} h antes`, limit_reached: 'Limite de reagendamentos atingido', not_participant: 'Sem permissão', not_active: 'Agendamento não está ativo', not_started: 'A consulta ainda não começou', provider_only: 'Somente o profissional' }[ok.reason] || ok.reason;
        throw httpsError(ok.reason === 'not_participant' ? 'permission-denied' : 'failed-precondition', msg);
      }
      const by = auth.uid === ap.clientId ? 'client' : 'provider';
      if (action === 'cancel') {
        if (by === 'provider' && !reason) throw httpsError('invalid-argument', 'Informe o motivo do cancelamento');
        tx.update(ref, { status: by === 'client' ? 'cancelled_by_client' : 'cancelled_by_provider', cancelReason: reason || null, cancelledAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() });
      } else if (action === 'reschedule') {
        const sched = hc.validateSchedule(schedSnap.data()).value;
        if (!hc.slotAllowed(sched, newStart, service.durationMin, busyOf(busySnap, ref.id), Date.now())) {
          throw httpsError('failed-precondition', 'Novo horário indisponível');
        }
        const endMs = newStart + service.durationMin * 60000;
        tx.update(ref, {
          startMs: newStart, endMs, startAt: Timestamp.fromMillis(newStart), endAt: Timestamp.fromMillis(endMs),
          date: hc.localDateOf(newStart), rescheduleCount: FieldValue.increment(1), lastRescheduledBy: by,
          previousStartMs: ap.startMs, updatedAt: FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(ref, { status: action === 'complete' ? 'completed' : 'no_show', updatedAt: FieldValue.serverTimestamp() });
      }
      tx.set(calRef, { version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    return { ok: true };
  });

  /**
   * Notificações por evento. Textos genéricos (sem especialidade nem
   * motivo): notificações não são lugar para dado sensível de saúde.
   */
  ex.onAppointmentWrite = functions.firestore.document('appointments/{id}').onWrite(async (change) => {
    if (!change.after.exists) return null;
    const a = change.after.data();
    const b = change.before.exists ? change.before.data() : null;
    if (!a.providerId || !a.startMs) return null; // registros antigos sem profissional
    if (!b) {
      await notifySafe(a.providerId, '📅 Nova consulta agendada', `Consulta em ${fmt(a.startMs)}.`, 'health', { route: 'appointments' });
      await notifySafe(a.clientId, '📅 Consulta agendada', `Sua consulta está marcada para ${fmt(a.startMs)}.`, 'health', { route: 'appointments' });
    } else if (b.status !== a.status && a.status.startsWith('cancelled')) {
      const other = a.status === 'cancelled_by_client' ? a.providerId : a.clientId;
      await notifySafe(other, 'Consulta cancelada', `A consulta de ${fmt(a.startMs)} foi cancelada.`, 'health', { route: 'appointments' });
    } else if (b.startMs !== a.startMs) {
      const other = a.lastRescheduledBy === 'client' ? a.providerId : a.clientId;
      await notifySafe(other, 'Consulta reagendada', `Nova data: ${fmt(a.startMs)}.`, 'health', { route: 'appointments' });
    }
    return null;
  });

  // ════════════════════════════ LOCAÇÃO ════════════════════════════
  function rentalBusyQuery(rentalId) {
    return BOOKINGS.where('rentalId', '==', rentalId).where('status', 'in', rc.BLOCKING);
  }

  /** Cotação (servidor) — o app só exibe. */
  ex.quoteRentalBooking = functions.region(REGION).https.onCall(async (data, context) => {
    requireAuth(context);
    const r = await db.collection('rentals').doc(String(data?.rentalId || '')).get();
    if (!r.exists) throw httpsError('not-found', 'Anúncio não encontrado');
    const q = rc.quote(r.data(), data || {}, Date.now());
    if (!q.ok) throw httpsError('failed-precondition', q.errors.join('; '));
    return q.value;
  });

  /** Períodos ocupados (sem dados de quem reservou). */
  ex.rentalAvailability = functions.region(REGION).https.onCall(async (data, context) => {
    requireAuth(context);
    const rentalId = String(data?.rentalId || '');
    const s = await rentalBusyQuery(rentalId).get();
    const now = Date.now();
    return {
      busy: s.docs.map((d) => d.data()).filter((b) => rc.blocking(b, now) && b.endMs > now)
        .map((b) => ({ startMs: b.startMs, endMs: b.endMs, status: b.status === 'pending' ? 'pending' : 'confirmed' }))
        .sort((a, b) => a.startMs - b.startMs),
    };
  });

  /**
   * Reserva: preço/total/fim calculados no servidor; sem sobreposição
   * (transação serializada pelo calendário do anúncio); idempotente.
   */
  ex.createRentalBooking = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    await enforceRateLimit(auth.uid, 'rental_book', 20, 60 * 60 * 1000);
    const requestId = String(data?.requestId || '');
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(requestId)) throw httpsError('invalid-argument', 'requestId obrigatório');
    const rentalId = String(data?.rentalId || '');
    const id = `bk_${sid(auth.uid, requestId)}`;
    const ref = BOOKINGS.doc(id);
    const rRef = db.collection('rentals').doc(rentalId);
    const calRef = rRef.collection('meta').doc('calendar');
    const user = await db.collection('users').doc(auth.uid).get();
    await db.runTransaction(async (tx) => {
      const [again, rentalSnap, , busySnap] = await Promise.all([tx.get(ref), tx.get(rRef), tx.get(calRef), tx.get(rentalBusyQuery(rentalId))]);
      if (again.exists) return;
      if (!rentalSnap.exists) throw httpsError('not-found', 'Anúncio não encontrado');
      const rental = rentalSnap.data();
      if (rental.ownerId === auth.uid) throw httpsError('invalid-argument', 'Você não pode reservar o próprio anúncio');
      const now = Date.now();
      const q = rc.quote(rental, data || {}, now);
      if (!q.ok) throw httpsError('failed-precondition', q.errors.join('; '));
      const v = q.value;
      const clash = busySnap.docs.map((d) => d.data()).some((b) => rc.blocking(b, now) && rc.overlaps(v.startMs, v.endMs, b.startMs, b.endMs));
      if (clash) throw httpsError('failed-precondition', 'O período escolhido já está reservado');
      tx.set(ref, {
        rentalId, rentalTitle: rental.title || '', ownerId: rental.ownerId, clientId: auth.uid,
        clientName: String((user.exists && user.data().name) || '').slice(0, 80),
        start: Timestamp.fromMillis(v.startMs), end: Timestamp.fromMillis(v.endMs), startMs: v.startMs, endMs: v.endMs,
        period: rc.PERIODS[v.period].label, periodKey: v.period, quantity: v.quantity,
        unitCents: v.unitCents, totalCents: v.totalCents, total: v.totalCents / 100,
        status: 'pending', note: String(data?.note || '').slice(0, 500) || null, requestId,
        history: [{ to: 'pending', by: auth.uid, at: Timestamp.fromMillis(now) }],
        createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      tx.set(calRef, { version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    });
    return { id };
  });

  /** Transições autorizadas (confirmar, recusar, cancelar, iniciar, concluir). */
  ex.transitionRentalBooking = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const action = String(data?.action || '');
    const bookingId = String(data?.bookingId || '');
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(bookingId)) throw httpsError('invalid-argument', 'bookingId inválido');
    const ref = BOOKINGS.doc(bookingId);
    const reason = String(data?.reason || '').trim().slice(0, 300);
    const pre = await ref.get();
    if (!pre.exists) throw httpsError('not-found', 'Reserva não encontrada');
    const b0 = pre.data();
    const calRef = db.collection('rentals').doc(b0.rentalId).collection('meta').doc('calendar');
    const res = await db.runTransaction(async (tx) => {
      const [snap] = await Promise.all([tx.get(ref), tx.get(calRef)]);
      const b = { ...snap.data(), startMs: snap.data().startMs || (snap.data().start && snap.data().start.toMillis()) };
      const ok = rc.transitionAllowed(action, b, auth.uid, Date.now(), reason);
      if (!ok.ok) {
        const msg = { too_late: `O locatário só cancela uma reserva confirmada até ${rc.CLIENT_CANCEL_MIN_HOURS} h antes do início`, reason_required: 'Informe o motivo do cancelamento', owner_only: 'Somente o anunciante', not_participant: 'Sem permissão', invalid_transition: 'Ação não permitida no status atual', not_started: 'A locação ainda não começou', start_passed: 'O início da reserva já passou; ela não pode mais ser confirmada' }[ok.reason] || ok.reason;
        throw httpsError(ok.reason === 'not_participant' ? 'permission-denied' : 'failed-precondition', msg);
      }
      const now = Timestamp.now();
      tx.update(ref, {
        status: ok.to, [`${ok.to}At`]: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
        ...(ok.to === 'cancelled' ? { cancelReason: reason || null, cancelledBy: auth.uid === b.ownerId ? 'owner' : 'client' } : {}),
        history: FieldValue.arrayUnion({ to: ok.to, by: auth.uid, at: now, action }),
      });
      tx.set(calRef, { version: FieldValue.increment(1), updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      return ok.to;
    });
    return { ok: true, status: res };
  });

  /** Notificações de locação por evento (substitui a escrita pelo app). */
  ex.onRentalBookingWrite = functions.firestore.document('bookings/{id}').onWrite(async (change) => {
    if (!change.after.exists) return null;
    const a = change.after.data();
    const b = change.before.exists ? change.before.data() : null;
    if (!b) {
      await notifySafe(a.ownerId, '🔑 Nova solicitação de reserva', `${a.clientName || 'Um cliente'} quer alugar ${a.rentalTitle}.`, 'rental', { route: 'bookings' });
      return null;
    }
    if (b.status === a.status) return null;
    const msgs = {
      confirmed: [a.clientId, 'Reserva confirmada', `${a.rentalTitle}: reserva confirmada pelo anunciante.`],
      // Cancelada pelo anunciante ou pelo sistema: avisa o locatário.
      cancelled: [a.cancelledBy === 'client' ? a.ownerId : a.clientId, 'Reserva cancelada', `${a.rentalTitle}: reserva cancelada${a.cancelReason ? ` (${a.cancelReason})` : ''}.`],
      active: [a.clientId, 'Locação iniciada', `${a.rentalTitle}: locação em andamento.`],
      completed: [a.clientId, 'Locação concluída', `${a.rentalTitle}: obrigado por alugar!`],
    }[a.status];
    if (msgs) await notifySafe(msgs[0], msgs[1], msgs[2], 'rental', { route: 'bookings' });
    return null;
  });

  /** Pendentes que passaram do início sem confirmação são encerradas. */
  ex.rentalMaintenance = functions.pubsub.schedule('every 60 minutes').onRun(async () => {
    const s = await BOOKINGS.where('status', '==', 'pending').where('startMs', '<=', Date.now()).limit(200).get();
    for (const d of s.docs) {
      // Auditoria: em transação e só se continuar pendente (o anunciante
      // pode ter confirmado entre a consulta e a atualização).
      await db.runTransaction(async (tx) => {
        const cur = await tx.get(d.ref);
        if (!cur.exists || cur.data().status !== 'pending') return;
        tx.update(d.ref, { status: 'cancelled', cancelReason: 'Não confirmada até o início', cancelledBy: 'system', updatedAt: FieldValue.serverTimestamp(), history: FieldValue.arrayUnion({ to: 'cancelled', by: 'system', at: Timestamp.now() }) });
      });
    }
    return null;
  });

  ex.__internals = { HEALTH_CONSENT_VERSION };
  return ex;
};

module.exports.HEALTH_CONSENT_VERSION = HEALTH_CONSENT_VERSION;
