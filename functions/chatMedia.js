'use strict';

/**
 * Anexos do chat (LGPD). A mensagem guarda só o CAMINHO no Storage
 * (`mediaPath` = chat_media/{roomId}/{uid}_{arquivo}) e metadados; nunca a
 * download URL com token permanente. O arquivo é liberado por URL assinada
 * curta (getChatMediaUrl), conferindo a participação ATUAL na conversa.
 *
 * - onFinalize: remove o token de download que o Storage cria no envio.
 * - onUpdate: "apagar para todos" apaga também o arquivo.
 * - adminMigrateChatMedia: converte mensagens antigas (mediaUrl com token)
 *   para mediaPath e revoga o token antigo.
 */
const { FieldPath } = require('firebase-admin/firestore');

const URL_TTL_MS = 10 * 60 * 1000;

/**
 * Caminho no Storage de uma download URL antiga do chat
 * (https://<host>/v0/b/<bucket>/o/chat_media%2F<sala>%2F<arquivo>?...).
 * Retorna null se não for um anexo da pasta da conversa.
 */
function chatPathFromUrl(url, roomId) {
  const m = /^https?:\/\/[^/]+\/(?:v0\/)?b\/[^/]+\/o\/([^?#]+)/.exec(String(url || ''));
  if (!m) return null;
  let path;
  try { path = decodeURIComponent(m[1]); } catch (_) { return null; }
  return isChatPath(path, roomId) ? path : null;
}

function isChatPath(path, roomId) {
  const p = String(path || '');
  const prefix = `chat_media/${roomId}/`;
  return Boolean(roomId) && p.startsWith(prefix) && p.length <= 512 &&
    /^[A-Za-z0-9._-]+$/.test(p.slice(prefix.length)) && !p.includes('..');
}

/** Caminho do anexo da mensagem (formato novo ou URL antiga). */
function mediaPathOf(m, roomId) {
  if (m.mediaPath) return isChatPath(m.mediaPath, roomId) ? m.mediaPath : null;
  return m.mediaUrl ? chatPathFromUrl(m.mediaUrl, roomId) : null;
}

/** Tipo do anexo antigo pelo prefixo do texto (📄 documento, 🎤 áudio). */
function legacyMediaType(text) {
  const t = String(text || '');
  if (t.startsWith('📄')) return 'document';
  if (t.startsWith('🎤')) return 'audio';
  return 'image';
}

function chatMediaFunctions(deps) {
  const { functions, admin, db, FieldValue, requireAuth, isAdmin, httpsError, REGION, enforceRateLimit, cleanId } = deps;
  const ex = {};
  const bucket = () => admin.storage().bucket();
  const emulator = () => process.env.FUNCTIONS_EMULATOR === 'true';

  /** Remove os tokens de download do objeto (links antigos param de abrir). */
  async function revokeTokens(file) {
    await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: null } });
    // O emulador do Storage ignora o null e só acumula tokens: regrava o
    // objeto sem token (em produção o null já remove e isto não roda).
    const [meta] = await file.getMetadata();
    const custom = { ...(meta.metadata || {}) };
    if (!custom.firebaseStorageDownloadTokens) return;
    delete custom.firebaseStorageDownloadTokens;
    const [buf] = await file.download();
    await file.save(buf, { resumable: false, metadata: { contentType: meta.contentType, metadata: custom } });
  }

  /**
   * URL temporária de um anexo, só para quem está AGORA na conversa
   * (quem saiu ou foi removido deixa de ter acesso no mesmo instante).
   */
  ex.getChatMediaUrl = functions.region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    const roomId = cleanId(data?.roomId, 'roomId');
    const messageId = cleanId(data?.messageId, 'messageId');
    await enforceRateLimit(auth.uid, 'chatMediaUrl', 600, 10 * 60 * 1000);
    const room = await db.collection('chatRooms').doc(roomId).get();
    const parts = (room.exists && room.data().participants) || [];
    if (!Array.isArray(parts) || !parts.includes(auth.uid)) {
      throw httpsError('permission-denied', 'Você não participa desta conversa');
    }
    const msg = await db.collection('chatRooms').doc(roomId).collection('messages').doc(messageId).get();
    if (!msg.exists) throw httpsError('not-found', 'Mensagem não encontrada');
    const m = msg.data() || {};
    if (m.deleted === true) throw httpsError('not-found', 'Esta mensagem foi apagada');
    const path = mediaPathOf(m, roomId);
    if (!path) throw httpsError('not-found', 'Esta mensagem não tem anexo');
    const file = bucket().file(path);
    const [exists] = await file.exists();
    if (!exists) throw httpsError('not-found', 'Arquivo não encontrado');
    const expiresAt = Date.now() + URL_TTL_MS;
    if (emulator()) {
      // Emulador não assina URLs: a URL sem token passa pelas storage.rules
      // (exige o login do participante no cabeçalho Authorization).
      const host = process.env.FIREBASE_STORAGE_EMULATOR_HOST || '127.0.0.1:9199';
      return { url: `http://${host}/v0/b/${bucket().name}/o/${encodeURIComponent(path)}?alt=media`, expiresAt };
    }
    const [url] = await file.getSignedUrl({ action: 'read', expires: expiresAt });
    return { url, expiresAt };
  });

  /** Envio novo: o Storage cria um token de download; o chat não o usa. */
  ex.onChatMediaUploaded = functions.storage.object().onFinalize(async (obj) => {
    if (!String(obj.name || '').startsWith('chat_media/')) return null;
    // Só age se o envio criou token (o evento traz o estado do envio).
    if (!(obj.metadata && obj.metadata.firebaseStorageDownloadTokens)) return null;
    await revokeTokens(admin.storage().bucket(obj.bucket).file(obj.name)).catch((e) => {
      console.error('onChatMediaUploaded', obj.name, e.message);
    });
    return null;
  });

  /** "Apagar para todos": o arquivo do anexo também sai do Storage. */
  ex.onChatMessageDeletedForAll = functions.firestore
    .document('chatRooms/{roomId}/messages/{msgId}')
    .onUpdate(async (change, ctx) => {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      if (before.deleted === true || after.deleted !== true) return null;
      const { roomId } = ctx.params;
      // Restos de anexo no documento (as regras já exigem a remoção).
      if (['mediaPath', 'mediaUrl', 'mediaType', 'mediaName'].some((k) => k in after)) {
        await change.after.ref.update({
          mediaPath: FieldValue.delete(), mediaUrl: FieldValue.delete(),
          mediaType: FieldValue.delete(), mediaName: FieldValue.delete(),
        });
      }
      const path = mediaPathOf(before, roomId);
      if (!path) return null;
      // Formato novo: só apaga arquivo enviado pelo próprio remetente
      // (o nome começa com o uid; evita apagar o anexo da outra pessoa).
      if (before.mediaPath && !path.startsWith(`chat_media/${roomId}/${before.senderId}_`)) return null;
      await bucket().file(path).delete({ ignoreNotFound: true }).catch((e) => {
        console.error('onChatMessageDeletedForAll', path, e.message);
      });
      return null;
    });

  /**
   * Admin (master/financeiro): migra anexos antigos. Paginada por sala
   * (`cursor` = último roomId; repita até `done`). Idempotente: mensagens
   * já migradas não têm mais mediaUrl. Revoga o token antigo ANTES de
   * gravar (se falhar, a mensagem fica para a próxima execução).
   */
  ex.adminMigrateChatMedia = functions.runWith({ timeoutSeconds: 540 }).region(REGION).https.onCall(async (data, context) => {
    const auth = requireAuth(context);
    if (!(await isAdmin(auth))) throw httpsError('permission-denied', 'Somente admin');
    const role = ((await db.collection('users').doc(auth.uid).get()).data() || {}).adminRole;
    if (role && !['master', 'financial'].includes(role) && auth.token.admin !== true) {
      throw httpsError('permission-denied', 'Perfil sem acesso a esta manutenção');
    }
    const pageSize = Math.min(Math.max(Number(data?.pageSize) || 50, 1), 200);
    const cursor = data?.cursor ? cleanId(data.cursor, 'cursor') : null;
    let q = db.collection('chatRooms').orderBy(FieldPath.documentId()).limit(pageSize);
    if (cursor) q = q.startAfter(cursor);
    const rooms = await q.get();
    const report = { rooms: rooms.size, migrated: 0, skipped: 0, discarded: 0, missing: 0, errors: 0, items: [] };
    const note = (item) => { if (report.items.length < 100) report.items.push(item); };
    for (const room of rooms.docs) {
      const msgs = await room.ref.collection('messages').where('mediaUrl', '>', '').get();
      for (const msg of msgs.docs) {
        const m = msg.data();
        const where = `${room.id}/${msg.id}`;
        try {
          if (m.mediaPath || m.deleted === true) {
            // Resto de link antigo em mensagem já migrada/apagada: só remove.
            await msg.ref.update({ mediaUrl: FieldValue.delete() });
            report.skipped++;
            continue;
          }
          const path = chatPathFromUrl(m.mediaUrl, room.id);
          if (!path) {
            // Link externo ou de outra pasta: não é anexo da conversa.
            await msg.ref.update({ mediaUrl: FieldValue.delete(), mediaDiscarded: true });
            report.discarded++;
            note({ message: where, result: 'discarded' });
            continue;
          }
          const file = bucket().file(path);
          const [exists] = await file.exists();
          if (exists) await revokeTokens(file);
          else { report.missing++; note({ message: where, result: 'missing' }); }
          const type = legacyMediaType(m.text);
          await msg.ref.update({
            mediaPath: path,
            mediaType: type,
            ...(type === 'document' ? { mediaName: String(m.text || '').replace(/^📄\s*/, '').slice(0, 200) } : {}),
            mediaUrl: FieldValue.delete(),
          });
          report.migrated++;
        } catch (e) {
          report.errors++;
          note({ message: where, result: 'error', error: String(e.message || e).slice(0, 120) });
          console.error('adminMigrateChatMedia', where, e.message);
        }
      }
    }
    report.nextCursor = rooms.size === pageSize ? rooms.docs[rooms.size - 1].id : null;
    report.done = report.nextCursor === null;
    await db.collection('auditLogs').add({
      adminId: auth.uid, adminName: 'Admin', action: 'Migrou anexos do chat',
      target: 'chat_media', details: { cursor, rooms: report.rooms, migrated: report.migrated, discarded: report.discarded, missing: report.missing, errors: report.errors },
      timestamp: FieldValue.serverTimestamp(),
    });
    return report;
  });

  return ex;
}

module.exports = chatMediaFunctions;
module.exports.chatPathFromUrl = chatPathFromUrl;
module.exports.isChatPath = isChatPath;
module.exports.legacyMediaType = legacyMediaType;
