// Validações dos formulários do painel admin (puras, testáveis). O
// servidor revalida; aqui só evitamos gravar dados que ele recusaria.

/// Cupom: código, desconto (percentual 0 < x ≤ 100 ou valor > 0) e
/// limites opcionais. Devolve a mensagem de erro ou null se válido.
String? validateCouponInput({
  required String code,
  required String discount,
  required bool isPercentage,
  String maxUses = '',
  String perUserLimit = '',
}) {
  final c = code.trim().toUpperCase();
  if (!RegExp(r'^[A-Z0-9_-]{2,40}$').hasMatch(c)) {
    return 'Código: 2 a 40 letras, números, "-" ou "_"';
  }
  final d = double.tryParse(discount.trim().replaceAll(',', '.'));
  if (d == null || d <= 0) return 'Informe um desconto maior que zero';
  if (isPercentage && d > 100) {
    return 'Percentual deve ser maior que 0 e no máximo 100';
  }
  if (maxUses.trim().isNotEmpty) {
    final n = int.tryParse(maxUses.trim());
    if (n == null || n < 1) {
      return 'Limite total de usos deve ser um inteiro ≥ 1';
    }
  }
  if (perUserLimit.trim().isNotEmpty) {
    final n = int.tryParse(perUserLimit.trim());
    if (n == null || n < 1) return 'Limite por cliente deve ser um inteiro ≥ 1';
  }
  return null;
}

/// Reservas (config/booking): mesmos limites do servidor (bookingCore).
String? validateBookingConfigInput(String holdMinutes, String maxPending) {
  final h = int.tryParse(holdMinutes.trim());
  if (h == null || h < 5 || h > 120) {
    return 'Prazo de pagamento: inteiro entre 5 e 120 minutos';
  }
  final m = int.tryParse(maxPending.trim());
  if (m == null || m < 1 || m > 10) {
    return 'Reservas pendentes por cliente: inteiro entre 1 e 10';
  }
  return null;
}
