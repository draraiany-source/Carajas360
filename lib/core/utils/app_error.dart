/// Mensagens seguras para a UI. Stack, paths e tokens nunca vão ao snack.
abstract final class AppError {
  static const fallback = 'Algo deu errado. Tente novamente.';

  static String userMessage(Object? error, {String message = fallback}) {
    if (error == null) return message;
    final raw = error.toString();
    if (_looksSensitive(raw)) return message;
    if (raw.length > 140) return message;
    return message;
  }

  static bool _looksSensitive(String raw) {
    final lower = raw.toLowerCase();
    if (raw.contains('\n') || raw.contains(' at ')) return true;
    if (lower.contains('exception') || lower.contains('error:')) return true;
    if (lower.contains('token') || lower.contains('secret')) return true;
    if (lower.contains('firebase') || lower.contains('httpsfunction')) return true;
    return false;
  }
}
