import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/navigation/app_navigation.dart';

/// Pendência 3: identificação do aparelho para push. Cada instalação tem
/// um id próprio (gerado uma vez e guardado localmente), usado como
/// users/{uid}/devices/{deviceId}: vários aparelhos da mesma conta não se
/// sobrescrevem e o logout tira só este.
abstract final class PushDevice {
  static const prefsKey = 'push_device_id_v1';
  static final _valid = RegExp(r'^[A-Za-z0-9_-]{16,64}$');
  static String? _cached;

  /// Id desta instalação (cria e guarda na primeira vez).
  static Future<String> id({SharedPreferences? prefs, Random? random}) async {
    final c = _cached;
    if (c != null) return c;
    final p = prefs ?? await SharedPreferences.getInstance();
    var v = p.getString(prefsKey);
    if (v == null || !_valid.hasMatch(v)) {
      v = generate(random);
      await p.setString(prefsKey, v);
    }
    return _cached = v;
  }

  /// 32 caracteres hexadecimais aleatórios (128 bits).
  static String generate([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static bool isValidId(String v) => _valid.hasMatch(v);

  /// Só para testes: esquece o id em memória.
  @visibleForTesting
  static void resetCache() => _cached = null;

  /// Plataforma gravada no documento (validada nas regras).
  static String platformName({bool web = kIsWeb, TargetPlatform? platform}) {
    if (web) return 'web';
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'other',
    };
  }
}

/// Chave VAPID do push web (dart-define FCM_VAPID_KEY, por ambiente).
const fcmVapidKey = String.fromEnvironment('FCM_VAPID_KEY');

/// Push web só liga com chave VAPID real e Firebase de verdade (sem
/// placeholders nem emulador, onde não há FCM). Sem isso: desligado em
/// silêncio, o app segue com as notificações internas.
bool webPushEnabled({
  required String vapidKey,
  required bool firebasePlaceholder,
  required bool emulator,
}) {
  final k = vapidKey.trim();
  if (k.isEmpty || RegExp('COLE_SUA|AQUI|PLACEHOLDER', caseSensitive: false).hasMatch(k)) return false;
  return !firebasePlaceholder && !emulator;
}

/// Destino do toque num push. Mesma função para app aberto (payload da
/// notificação local), segundo plano, encerrado e web (clique no service
/// worker): dados `{type, route, id}` gravados pelo servidor.
({String route, Map<String, dynamic>? args})? pushTarget(Map<String, dynamic>? data) {
  if (data == null) return null;
  String? s(Object? v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? null : t;
  }

  final route = s(data['route']);
  final id = s(data['id']);
  return notificationTarget(s(data['type']), {
    if (route != null) 'route': route,
    if (id != null) 'id': id,
  });
}

/// [pushTarget] a partir do payload em texto (notificação local / web).
({String route, Map<String, dynamic>? args})? pushTargetFromPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final m = jsonDecode(payload);
    return m is Map ? pushTarget(Map<String, dynamic>.from(m)) : null;
  } catch (_) {
    return null;
  }
}
