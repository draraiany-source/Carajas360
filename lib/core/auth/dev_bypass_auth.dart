import 'package:flutter/foundation.dart';

import '../constants/runtime_config.dart';
import '../../shared/models/models.dart';

/// Login de smoke TEMPORÁRIO. Só debug/profile.
/// Release ignora `--dart-define=DEV_BYPASS_LOGIN=true`.
/// Ver `DEV_BYPASS_LOGIN.md`.
abstract final class DevBypassAuth {
  static const uid = 'dev-bypass-user';

  static bool enabledFor({
    required bool releaseMode,
    required bool defineOn,
  }) {
    if (releaseMode) return false;
    return defineOn;
  }

  static bool get enabled {
    final on = enabledFor(
      releaseMode: kReleaseMode,
      defineOn: RuntimeConfig.devBypassLoginDefine,
    );
    assert(() {
      if (kReleaseMode && on) {
        throw StateError('DEV_BYPASS_LOGIN não pode estar ativo em release');
      }
      return true;
    }());
    if (kReleaseMode) return false;
    return on;
  }

  /// Perfil local: client comum, sem claim/admin, sem verified.
  static UserModel get mockUser => UserModel(
        id: uid,
        name: 'Cliente Teste',
        email: 'dev-bypass-user@servicoconecta.com.br',
        phone: '',
        type: UserType.client,
        city: 'Canaã dos Carajás',
        state: 'PA',
        termsAccepted: true,
        createdAt: DateTime.utc(2026, 1, 1),
        roles: const ['client'],
      );
}
