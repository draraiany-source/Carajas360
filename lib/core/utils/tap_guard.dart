import 'package:flutter/material.dart';

/// Evita double-tap / double-submit em ações rápidas.
abstract final class TapGuard {
  static DateTime? _last;
  static const _gap = Duration(milliseconds: 450);

  static bool allow() {
    final now = DateTime.now();
    if (_last != null && now.difference(_last!) < _gap) return false;
    _last = now;
    return true;
  }

  static VoidCallback? wrap(VoidCallback? action) {
    if (action == null) return null;
    return () {
      if (!allow()) return;
      action();
    };
  }

  static Future<void> run(Future<void> Function() action) async {
    if (!allow()) return;
    await action();
  }
}
