import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../theme/app_colors.dart';

/// Abre o chat com roomId canônico `{uidA}_{uidB}` (getOrCreateRoom).
abstract final class ChatNav {
  static Future<void> open(
    BuildContext context, {
    required String otherUserId,
    required String otherName,
    String? otherPhoto,
  }) async {
    if (otherUserId.isEmpty) return;
    // Sem login: leva ao login em vez de lançar exceção.
    if (!AuthService.isAuth) {
      await Navigator.pushNamed(context, Routes.login);
      return;
    }
    final String roomId;
    try {
      roomId = await FS.getOrCreateRoom(otherUserId);
    } catch (e) {
      if (context.mounted) {
        snack(context, 'Não foi possível abrir o chat: $e',
            bg: AppColors.error);
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.pushNamed(context, Routes.chat, arguments: {
      'roomId': roomId,
      'name': otherName,
      if (otherPhoto != null) 'photo': otherPhoto,
    });
  }
}
