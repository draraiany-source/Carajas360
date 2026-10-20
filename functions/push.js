'use strict';

/**
 * Pendência 3: push por APARELHO. Cada instalação do app grava
 * users/{uid}/devices/{deviceId} = { token, platform, updatedAt }; o envio
 * vai para todos os aparelhos da pessoa (os 20 mais recentes) e só os
 * tokens recusados como inválidos são apagados.
 *
 * Compatibilidade: o campo antigo users/{uid}.fcmToken (um token por
 * usuário) continua sendo usado como reserva até o aparelho dele se
 * registrar de novo (o app apaga o campo quando ele é igual ao seu token).
 *
 * Emulador: não existe FCM real. Com PUSH_TRANSPORT=fake (aceito só com
 * FUNCTIONS_EMULATOR=true) o envio é simulado e registrado em _fakePush;
 * tokens "invalid-…" respondem não registrado, "malformed-…" token
 * inválido e "fail-…" erro temporário (o token fica).
 */
const MAX_DEVICES = 20;

/** Erro do FCM que significa "este token nunca mais vai funcionar". */
function isInvalidTokenError(err) {
  const code = String((err && (err.code || (err.errorInfo && err.errorInfo.code))) || '');
  if (/registration-token-not-registered|invalid-registration-token/.test(code)) return true;
  // invalid-argument também vale para a mensagem inteira: só conta quando é o token.
  return code === 'messaging/invalid-argument' && /token/i.test(String((err && err.message) || ''));
}

/**
 * Destinos do envio: aparelhos (já em ordem do mais recente) + token
 * legado se ainda não estiver entre eles. Sem repetidos, no máximo [max].
 */
function collectTargets(devices, legacyToken, max = MAX_DEVICES) {
  const out = [];
  const seen = new Set();
  for (const d of devices || []) {
    const token = typeof d.token === 'string' ? d.token : '';
    if (!token || seen.has(token)) continue;
    seen.add(token);
    out.push({ token, deviceId: d.id, updateTime: d.updateTime || null });
  }
  if (typeof legacyToken === 'string' && legacyToken && !seen.has(legacyToken)) {
    out.push({ token: legacyToken, legacy: true });
  }
  return out.slice(0, max);
}

/** Mensagem FCM (sem destino): mesmo conteúdo para todos os aparelhos. */
function buildMessage({ title, body, type, link }) {
  return {
    notification: { title: String(title || 'Carajás 360'), body: String(body || '') },
    // Destino do toque no aviso (mesmo mapa das notificações do app).
    data: { type: String(type || ''), route: String((link && link.route) || ''), id: String((link && link.id) || '') },
    android: { notification: { icon: 'ic_launcher', color: '#0B3D91' } },
    apns: { payload: { aps: { badge: 1, sound: 'default' } } },
  };
}

/** Simulador do FCM para o emulador (estado em _fakePush). */
function fakePushTransport(db) {
  return {
    name: 'fake',
    async sendEachForMulticast(msg, meta) {
      const responses = msg.tokens.map((t) => {
        if (t.startsWith('invalid-')) return { success: false, error: { code: 'messaging/registration-token-not-registered', message: 'Requested entity was not found.' } };
        if (t.startsWith('malformed-')) return { success: false, error: { code: 'messaging/invalid-argument', message: 'The registration token is not a valid FCM registration token' } };
        if (t.startsWith('fail-')) return { success: false, error: { code: 'messaging/internal-error', message: 'Erro temporário simulado' } };
        return { success: true, messageId: `fake-${Math.random().toString(36).slice(2, 10)}` };
      });
      await db.collection('_fakePush').add({
        ...(meta || {}), tokens: msg.tokens, data: msg.data, title: msg.notification.title,
        delivered: msg.tokens.filter((_, i) => responses[i].success), at: new Date(),
      });
      return { responses, successCount: responses.filter((r) => r.success).length, failureCount: responses.filter((r) => !r.success).length };
    },
  };
}

function pushTransportMode(env) {
  const e = env || {};
  if (String(e.PUSH_TRANSPORT || '').trim() === 'fake') {
    return e.FUNCTIONS_EMULATOR === 'true' ? 'fake' : 'fcm';
  }
  return 'fcm';
}

module.exports = function pushFunctions(deps) {
  const { functions, admin, db, FieldValue } = deps;
  const transport = () => (pushTransportMode(process.env) === 'fake'
    ? fakePushTransport(db)
    : { name: 'fcm', sendEachForMulticast: (msg) => admin.messaging().sendEachForMulticast(msg) });

  /** Envia para todos os aparelhos do usuário; devolve { sent, removed }. */
  async function sendToUser(userId, content, meta) {
    const userRef = db.collection('users').doc(userId);
    const [userDoc, devSnap] = await Promise.all([
      userRef.get(),
      userRef.collection('devices').orderBy('updatedAt', 'desc').limit(MAX_DEVICES).get(),
    ]);
    const targets = collectTargets(
      devSnap.docs.map((d) => ({ id: d.id, token: d.get('token'), updateTime: d.updateTime })),
      userDoc.exists ? userDoc.get('fcmToken') : null,
    );
    if (!targets.length) return { sent: 0, removed: 0 };
    const res = await transport().sendEachForMulticast({ ...buildMessage(content), tokens: targets.map((t) => t.token) }, meta);
    const bad = targets.filter((_, i) => res.responses[i] && !res.responses[i].success && isInvalidTokenError(res.responses[i].error));
    let removed = 0;
    for (const t of bad) {
      try {
        if (t.legacy) {
          // Só apaga se o campo ainda é o mesmo token (o app pode ter trocado).
          await db.runTransaction(async (tx) => {
            const s = await tx.get(userRef);
            if (s.exists && s.get('fcmToken') === t.token) tx.update(userRef, { fcmToken: FieldValue.delete() });
          });
        } else {
          // Precondição: se o aparelho renovou o token nesse meio tempo, fica.
          await userRef.collection('devices').doc(t.deviceId).delete(t.updateTime ? { lastUpdateTime: t.updateTime } : undefined);
        }
        removed++;
      } catch (e) {
        console.warn('push cleanup', userId, e.code || e.message);
      }
    }
    return { sent: res.successCount || 0, removed };
  }

  const ex = {};
  ex.sendPushNotification = functions.firestore
    .document('notifications/{notifId}')
    .onCreate(async (snap, ctx) => {
      const { userId, title, body, type, link } = snap.data() || {};
      if (!userId) return null;
      try {
        await sendToUser(String(userId), { title, body, type, link }, { userId: String(userId), notifId: ctx.params.notifId });
      } catch (e) {
        // Push é melhor-esforço: a notificação já está salva no Firestore.
        console.warn('sendPushNotification', userId, e.code || e.message);
      }
      return null;
    });
  return ex;
};

module.exports.MAX_DEVICES = MAX_DEVICES;
module.exports.isInvalidTokenError = isInvalidTokenError;
module.exports.collectTargets = collectTargets;
module.exports.buildMessage = buildMessage;
module.exports.pushTransportMode = pushTransportMode;
module.exports.fakePushTransport = fakePushTransport;
