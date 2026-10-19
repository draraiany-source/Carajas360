/// Valor em reais digitado pelo usuário → double (2 casas).
/// Aceita "1.500,00", "1500,5", "1500.50", "1.500" (milhar) e "R$ 10".
/// Retorna null se o texto não for um número válido.
double? parseBrlAmount(String raw) {
  var t = raw.trim().replaceAll(RegExp(r'[R$\s]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    // Formato brasileiro: ponto = milhar, vírgula = decimal.
    t = t.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
    // "1.500" sem vírgula: ponto como separador de milhar.
    t = t.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) return null;
  final v = double.tryParse(t);
  if (v == null) return null;
  return (v * 100).roundToDouble() / 100;
}

/// "1.234,56" / "1234.5" → valor; null fora de 1..1.000.000.
double? parseQuote(String raw) {
  final v = parseBrlAmount(raw);
  if (v == null || v < 1 || v > 1000000) return null;
  return v;
}
