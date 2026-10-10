/// Normalização de texto do catálogo — IDÊNTICA a `functions/catalogCore.js`
/// (vetores compartilhados em functions/catalog/normalization_vectors.json).
abstract final class CatalogText {
  static const _from = 'àáâãäåāăąçćĉċčďèéêëēĕėęěĝğġģĥìíîïĩīĭįĵķĺļľñńņňòóôõöōŏőŕŗřśŝşšţťùúûüũūŭůűųŵýÿŷźżž';
  static const _to = 'aaaaaaaaacccccdeeeeeeeeegggghiiiiiiiijklllnnnnoooooooorrrssssttuuuuuuuuuuwyyyzzz';

  static String foldAccents(String input) {
    final b = StringBuffer();
    for (final r in input.runes) {
      final ch = String.fromCharCode(r);
      final i = _from.indexOf(ch);
      b.write(i >= 0 ? _to[i] : ch);
    }
    return b.toString();
  }

  /// minúsculas, sem acentos, só [a-z0-9] e espaços simples.
  static String normalize(String? text) => foldAccents((text ?? '').toLowerCase())
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  /// "ar condicionado" → "arcondicionado".
  static String compact(String? text) => normalize(text).replaceAll(' ', '');
}
