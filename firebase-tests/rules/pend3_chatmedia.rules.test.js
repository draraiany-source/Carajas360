'use strict';
/** pend3 (LGPD): anexos do chat por caminho privado, sem download URL. */
const { test, before, after } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, updateDoc, deleteField, collection, serverTimestamp } = require('firebase/firestore');
const { ref, uploadString, getBytes, deleteObject } = require('firebase/storage');

const FS_RULES = fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8');
let fsEnv; let stEnv;
// Sala própria por execução (o projeto do Storage é o mesmo do emulador).
const ROOM = `pa${Date.now().toString(36)}_pb${Date.now().toString(36)}`;
const [A, B] = ROOM.split('_');

before(async () => {
  fsEnv = await initializeTestEnvironment({
    projectId: 'demo-carajas360-pend3-rules',
    firestore: { rules: FS_RULES, host: '127.0.0.1', port: 8080 },
  });
  // Regras cross-service (Storage→Firestore) usam o projeto do emulador.
  stEnv = await initializeTestEnvironment({
    projectId: process.env.GCLOUD_PROJECT || 'demo-carajas360',
    storage: { rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'), host: '127.0.0.1', port: 9199 },
    firestore: { rules: FS_RULES, host: '127.0.0.1', port: 8080 },
  });
  await fsEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'chatRooms/a_b'), { participants: ['a', 'b'] });
    await setDoc(doc(ctx.firestore(), 'chatRooms/a_b/messages/old'), {
      senderId: 'a', senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(),
      mediaPath: 'chat_media/a_b/a_1.jpg', mediaType: 'image',
    });
    await setDoc(doc(ctx.firestore(), 'chatRooms/a_b/messages/legacy'), {
      senderId: 'a', senderName: 'A', text: '📷 Foto', read: false, createdAt: new Date(),
      mediaUrl: 'https://firebasestorage.googleapis.com/v0/b/p/o/chat_media%2Fa_b%2F1.jpg?alt=media&token=t',
    });
  });
  await stEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `chatRooms/${ROOM}`), { participants: [A, B] });
    await uploadString(ref(ctx.storage(), `chat_media/${ROOM}/${A}_1.jpg`), 'x', 'raw', { contentType: 'image/jpeg' });
  });
});
after(async () => { await fsEnv.cleanup(); await stEnv.cleanup(); });

const as = (uid) => fsEnv.authenticatedContext(uid).firestore();
const msg = (extra) => ({ senderId: 'a', senderName: 'A', text: '📷 Foto', read: false, createdAt: serverTimestamp(), ...extra });

test('mensagem nova: mediaPath só na pasta da conversa e com o uid do remetente; sem mediaUrl', async () => {
  const col = collection(as('a'), 'chatRooms/a_b/messages');
  await assertSucceeds(addDoc(col, msg({ mediaPath: 'chat_media/a_b/a_17.jpg', mediaType: 'image' })));
  await assertSucceeds(addDoc(col, msg({ text: '📄 c.pdf', mediaPath: 'chat_media/a_b/a_18.pdf', mediaType: 'document', mediaName: 'c.pdf' })));
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/c_d/a_1.jpg', mediaType: 'image' })), 'outra sala');
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/a_b/b_1.jpg', mediaType: 'image' })), 'arquivo da outra pessoa');
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/a_b/a_1.jpg/../x', mediaType: 'image' })), 'caminho estranho');
  await assertFails(addDoc(col, msg({ mediaPath: 'users/a/x.jpg', mediaType: 'image' })), 'outra pasta');
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/a_b/a_2.jpg' })), 'sem tipo');
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/a_b/a_2.jpg', mediaType: 'video' })), 'tipo inválido');
  await assertFails(addDoc(col, msg({ mediaType: 'image' })), 'tipo sem caminho');
  await assertFails(addDoc(col, msg({ mediaPath: 'chat_media/a_b/a_2.pdf', mediaType: 'document', mediaName: 'x'.repeat(201) })), 'nome longo');
  await assertFails(addDoc(col, msg({ mediaUrl: 'https://firebasestorage.googleapis.com/v0/b/p/o/chat_media%2Fa_b%2F1.jpg?alt=media&token=t' })), 'mediaUrl novo');
  await assertFails(addDoc(collection(as('b'), 'chatRooms/a_b/messages'), msg({ mediaPath: 'chat_media/a_b/a_17.jpg', mediaType: 'image' })), 'remetente forjado');
});

test('apagar para todos exige remover o anexo do documento', async () => {
  const r = doc(as('a'), 'chatRooms/a_b/messages/old');
  await assertFails(updateDoc(r, { deleted: true, text: '' }), 'mediaPath ficaria');
  await assertFails(updateDoc(doc(as('b'), 'chatRooms/a_b/messages/old'), { deleted: true, text: '', mediaPath: deleteField(), mediaType: deleteField() }), 'não é o remetente');
  await assertFails(updateDoc(r, { mediaPath: 'chat_media/a_b/a_9.jpg' }), 'troca do anexo');
  await assertSucceeds(updateDoc(r, { deleted: true, text: '', mediaPath: deleteField(), mediaType: deleteField(), mediaName: deleteField(), mediaUrl: deleteField() }));
  await assertFails(updateDoc(doc(as('a'), 'chatRooms/a_b/messages/legacy'), { deleted: true, text: '' }), 'mediaUrl antigo ficaria');
  await assertSucceeds(updateDoc(doc(as('a'), 'chatRooms/a_b/messages/legacy'), { deleted: true, text: '', mediaUrl: deleteField() }));
});

test('Storage: só participantes leem; envio só com o próprio uid no nome; cliente não apaga', async () => {
  const st = (uid) => (uid ? stEnv.authenticatedContext(uid) : stEnv.unauthenticatedContext()).storage();
  const p = `chat_media/${ROOM}/${A}_1.jpg`;
  await assertSucceeds(getBytes(ref(st(A), p)));
  await assertSucceeds(getBytes(ref(st(B), p)));
  await assertFails(getBytes(ref(st('intruso'), p)), 'outro usuário');
  await assertFails(getBytes(ref(st(null), p)), 'visitante');
  await assertSucceeds(uploadString(ref(st(B), `chat_media/${ROOM}/${B}_2.jpg`), 'x', 'raw', { contentType: 'image/jpeg' }));
  await assertFails(uploadString(ref(st(B), `chat_media/${ROOM}/${A}_3.jpg`), 'x', 'raw', { contentType: 'image/jpeg' }), 'nome com uid de outro');
  await assertFails(uploadString(ref(st(B), `chat_media/${ROOM}/4.jpg`), 'x', 'raw', { contentType: 'image/jpeg' }), 'nome sem uid');
  await assertFails(uploadString(ref(st('intruso'), `chat_media/${ROOM}/intruso_5.jpg`), 'x', 'raw', { contentType: 'image/jpeg' }), 'não participante');
  await assertFails(deleteObject(ref(st(A), p)), 'remoção só pelo servidor');
});
