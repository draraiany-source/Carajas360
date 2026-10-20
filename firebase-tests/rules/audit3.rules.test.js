'use strict';
/** Auditoria 3: empresas não aprovadas e anexos do chat. */
const { test, before, after, beforeEach } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { doc, setDoc, addDoc, collection, getDoc, getDocs, query, where, serverTimestamp } = require('firebase/firestore');

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-carajas360-audit3-rules',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/adm'), { type: 'admin', adminRole: 'support' });
    await setDoc(doc(db, 'companies/dono'), { ownerId: 'dono', name: 'Nova', email: 'x@y.z', phone: '9499', verified: false, active: false });
    await setDoc(doc(db, 'companies/ok'), { ownerId: 'ok', name: 'Aprovada', verified: true, active: true });
    await setDoc(doc(db, 'chatRooms/a_b'), { participants: ['a', 'b'] });
  });
});
const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

test('empresa não aprovada (com contato) só para o dono e a equipe; aprovada é pública', async () => {
  await assertFails(getDoc(doc(as('outro'), 'companies/dono')));
  await assertFails(getDoc(doc(anon(), 'companies/dono')));
  await assertSucceeds(getDoc(doc(as('dono'), 'companies/dono')));
  await assertSucceeds(getDoc(doc(as('adm'), 'companies/dono')));
  await assertSucceeds(getDoc(doc(anon(), 'companies/ok')));
  // Consultas que o app faz continuam permitidas.
  await assertSucceeds(getDocs(query(collection(as('dono'), 'companies'), where('ownerId', '==', 'dono'))));
  await assertSucceeds(getDocs(query(collection(anon(), 'companies'), where('verified', '==', true))));
  await assertSucceeds(getDocs(query(collection(as('adm'), 'companies'), where('verified', '==', false))));
  await assertFails(getDocs(query(collection(as('outro'), 'companies'), where('verified', '==', false))));
});

test('anexo do chat só do Storage do app, na pasta da própria conversa', async () => {
  // pend3 (LGPD): download URL com token não é mais aceita; o anexo é o
  // caminho no Storage (ver pend3_chatmedia.rules.test.js).
  const m = (mediaUrl) => ({ senderId: 'a', senderName: 'A', text: '📷 Foto', read: false, createdAt: serverTimestamp(), mediaUrl });
  const p = (mediaPath) => ({ senderId: 'a', senderName: 'A', text: '📷 Foto', read: false, createdAt: serverTimestamp(), mediaPath, mediaType: 'image' });
  const col = collection(as('a'), 'chatRooms/a_b/messages');
  await assertSucceeds(addDoc(col, p('chat_media/a_b/a_1.jpg')));
  await assertSucceeds(addDoc(col, m(null)));
  await assertFails(addDoc(col, m('https://firebasestorage.googleapis.com/v0/b/proj.appspot.com/o/chat_media%2Fa_b%2F1.jpg?alt=media&token=t')), 'URL com token');
  await assertFails(addDoc(col, m('http://127.0.0.1:9199/v0/b/proj.appspot.com/o/chat_media%2Fa_b%2F2.jpg?alt=media')), 'URL do emulador');
  await assertFails(addDoc(col, m('https://golpe.example.com/premio.jpg')), 'link externo');
  await assertFails(addDoc(col, p('chat_media/c_d/a_1.jpg')), 'outra conversa');
  await assertFails(addDoc(col, p('users/b/doc.jpg')), 'outra pasta');
});
