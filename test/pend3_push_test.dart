import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/shared/services/push_device.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('pushTarget (aberto, segundo plano, encerrado e web usam a mesma função)', () {
    // Formato que o servidor manda (functions/push.js buildMessage).
    final data = <String, dynamic>{'type': 'market', 'route': 'marketOrder', 'id': 'p1'};

    test('data do FCM (segundo plano / encerrado) → mesma tela das notificações do app', () {
      final t = pushTarget(data)!;
      final n = notificationTarget('market', {'route': 'marketOrder', 'id': 'p1'})!;
      expect(t.route, Routes.marketOrder);
      expect(t.args, {'id': 'p1'});
      expect(t.route, n.route);
      expect(t.args, n.args);
    });

    test('app aberto: payload da notificação local (jsonEncode do data) dá o mesmo destino', () {
      final t = pushTargetFromPayload(jsonEncode(data))!;
      expect(t.route, Routes.marketOrder);
      expect(t.args, {'id': 'p1'});
    });

    test('web: payload do service worker (sempre com as 3 chaves, vazias = ausentes)', () {
      final t = pushTargetFromPayload(jsonEncode({'type': 'order', 'route': '', 'id': ''}))!;
      expect(t.route, Routes.myOrders);
      expect(t.args, isNull);
      expect(pushTargetFromPayload(jsonEncode({'type': '', 'route': 'marketOrder', 'id': ''}))!.route, Routes.marketOrders);
    });

    test('sem destino conhecido ou payload inválido → nada', () {
      expect(pushTarget(null), isNull);
      expect(pushTarget({'type': 'general', 'route': '', 'id': ''}), isNull);
      expect(pushTargetFromPayload(null), isNull);
      expect(pushTargetFromPayload('não é json'), isNull);
      expect(pushTargetFromPayload('[1,2]'), isNull);
    });
  });

  group('PushDevice.id', () {
    setUp(PushDevice.resetCache);

    test('gera uma vez, guarda e reaproveita (mesma instalação)', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final a = await PushDevice.id(prefs: p);
      expect(PushDevice.isValidId(a), isTrue);
      expect(a.length, 32);
      expect(p.getString(PushDevice.prefsKey), a);
      PushDevice.resetCache(); // reabre o app: lê do armazenamento
      expect(await PushDevice.id(prefs: p), a);
    });

    test('instalações diferentes têm ids diferentes; id guardado inválido é trocado', () async {
      expect(PushDevice.generate(Random(1)), isNot(PushDevice.generate(Random(2))));
      SharedPreferences.setMockInitialValues({PushDevice.prefsKey: 'x/../y'});
      final p = await SharedPreferences.getInstance();
      final v = await PushDevice.id(prefs: p);
      expect(PushDevice.isValidId(v), isTrue);
      expect(p.getString(PushDevice.prefsKey), v);
    });

    test('plataforma gravada é uma das aceitas pelas regras', () {
      expect(PushDevice.platformName(web: true), 'web');
      expect(PushDevice.platformName(web: false, platform: TargetPlatform.android), 'android');
      expect(PushDevice.platformName(web: false, platform: TargetPlatform.iOS), 'ios');
      expect(PushDevice.platformName(web: false, platform: TargetPlatform.fuchsia), 'other');
    });
  });

  test('push web só com chave VAPID real e Firebase de verdade', () {
    expect(webPushEnabled(vapidKey: '', firebasePlaceholder: false, emulator: false), isFalse);
    expect(webPushEnabled(vapidKey: 'COLE_SUA_VAPID', firebasePlaceholder: false, emulator: false), isFalse);
    expect(webPushEnabled(vapidKey: 'BKxyz', firebasePlaceholder: true, emulator: false), isFalse);
    expect(webPushEnabled(vapidKey: 'BKxyz', firebasePlaceholder: false, emulator: true), isFalse);
    expect(webPushEnabled(vapidKey: 'BKxyz', firebasePlaceholder: false, emulator: false), isTrue);
  });
}
