/// Regras puras do formulário "Solicitar orçamento" (sem Firebase), para
/// validar e montar o pedido antes de gravar.
abstract final class ServiceRequest {
  static const minDescriptionLength = 10;

  /// Motivo que impede o envio, ou null quando o pedido pode ser criado.
  static String? blockReason({
    required String? uid,
    required String providerId,
    bool demoProvider = false,
  }) {
    if (uid == null) return 'Faça login para solicitar um serviço.';
    if (providerId.trim().isEmpty) {
      return 'Profissional não identificado. Volte e abra o perfil novamente.';
    }
    if (providerId == uid) {
      return 'Você não pode solicitar orçamento para o seu próprio perfil.';
    }
    if (demoProvider) {
      return 'Este é um perfil de demonstração: pedidos não são enviados.';
    }
    return null;
  }

  static String? titleError(String? v) =>
      (v ?? '').trim().isEmpty ? 'Informe um título' : null;

  static String? descriptionError(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Descreva o que você precisa';
    if (t.length < minDescriptionLength) {
      return 'Detalhe um pouco mais (mínimo de $minDescriptionLength caracteres)';
    }
    return null;
  }

  /// Endereço é obrigatório só para atendimento presencial.
  static String? addressError(String? v, {required bool remoteOnly}) {
    if (remoteOnly) return null;
    return (v ?? '').trim().isEmpty
        ? 'Informe o endereço do atendimento'
        : null;
  }

  /// Payload aceito pelas regras de `orders` (sem preço; o cliente é
  /// definido pelo serviço a partir do usuário autenticado).
  static Map<String, dynamic> payload({
    required String providerId,
    required String category,
    required String title,
    required String description,
    required String address,
    required bool urgent,
    required bool remoteOnly,
  }) =>
      {
        'providerId': providerId,
        'category': category,
        'title': title.trim(),
        'description': description.trim(),
        'address': remoteOnly ? '' : address.trim(),
        'urgent': urgent,
      };

  static String chatIntro(String title, String description) =>
      '📋 Nova solicitação: ${title.trim()}\n${description.trim()}';
}

/// Evita envios duplicados enquanto uma gravação está em andamento.
class SubmitGuard {
  bool _busy = false;
  bool get busy => _busy;

  /// Executa [action] só se nenhuma outra estiver em andamento; devolve
  /// null quando a chamada foi ignorada.
  Future<T?> run<T>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    try {
      return await action();
    } finally {
      _busy = false;
    }
  }
}
