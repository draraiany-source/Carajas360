/* Carajás 360 — service worker do push web (Firebase Cloud Messaging).
 *
 * Registrado pelo SDK do Firebase quando o app pede o token web (só com
 * FCM_VAPID_KEY definida). A configuração do Firebase vem de
 * firebase-messaging-config.js, gerado por ambiente no build:
 *   node tool/gen_web_push_config.js --env hml   (grava em build/web)
 * Sem configuração real (arquivo padrão = null), o SDK não é carregado e
 * o push web fica desligado.
 *
 * Versão dos scripts compat FIXA e igual à do Firebase JS usado pelo
 * Flutter web (firebase_core_web 3.9.1 → supportedFirebaseJsSdkVersion
 * 12.15.0). Ao atualizar firebase_core_web, atualize aqui também.
 */
'use strict';

// Clique: registrado ANTES do SDK para ter prioridade. Abre/foca o app e
// entrega {type, route, id}; o app resolve a tela com pushTarget().
self.addEventListener('notificationclick', (event) => {
  const n = event.notification;
  const msg = (n && n.data && (n.data.FCM_MSG || n.data)) || {};
  const d = msg.data || {};
  event.stopImmediatePropagation();
  n.close();
  const payload = JSON.stringify({ type: d.type || '', route: d.route || '', id: d.id || '' });
  const base = new URL('./', self.location.href).href;
  event.waitUntil((async () => {
    const wins = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const win = wins.find((c) => c.url.startsWith(base));
    if (win) {
      await win.focus();
      win.postMessage({ c360push: payload });
      return;
    }
    const url = new URL(base);
    url.searchParams.set('c360push', payload);
    await self.clients.openWindow(url.href);
  })());
});

importScripts('firebase-messaging-config.js');
const cfg = self.C360_FIREBASE_WEB;
if (cfg && cfg.apiKey && cfg.projectId && cfg.messagingSenderId && cfg.appId) {
  importScripts(
    'https://www.gstatic.com/firebasejs/12.15.0/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/12.15.0/firebase-messaging-compat.js',
  );
  firebase.initializeApp(cfg);
  // Em segundo plano o SDK mostra o aviso do campo `notification`.
  firebase.messaging();
}
