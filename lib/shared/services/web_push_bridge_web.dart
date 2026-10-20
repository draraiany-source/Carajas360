import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Clique no push web (web/firebase-messaging-sw.js): com a janela
/// fechada o service worker abre o app com `?c360push=<json>`; aqui o
/// parâmetro é lido uma vez e tirado da barra de endereço.
String? takeWebPushLaunchPayload() {
  final p = Uri.base.queryParameters['c360push'];
  if (p == null || p.isEmpty) return null;
  try {
    final q = Map<String, String>.from(Uri.base.queryParameters)..remove('c360push');
    final clean = Uri.base.replace(queryParameters: q.isEmpty ? null : q).toString();
    globalContext
        .getProperty<JSObject>('history'.toJS)
        .callMethod<JSAny?>('replaceState'.toJS, null, ''.toJS, clean.toJS);
  } catch (_) {}
  return p;
}

/// Com a janela aberta o service worker foca e manda `{c360push: <json>}`.
void listenWebPushClicks(void Function(String payload) onClick) {
  try {
    final nav = globalContext.getProperty<JSObject?>('navigator'.toJS);
    final sw = nav?.getProperty<JSObject?>('serviceWorker'.toJS);
    if (sw == null) return;
    sw.callMethod<JSAny?>(
      'addEventListener'.toJS,
      'message'.toJS,
      ((JSObject e) {
        final d = e.getProperty<JSAny?>('data'.toJS).dartify();
        if (d is Map && d['c360push'] is String) onClick(d['c360push'] as String);
      }).toJS,
    );
  } catch (_) {}
}
