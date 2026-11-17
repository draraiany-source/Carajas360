import 'dart:typed_data';

/// Regras puras de fotos do orçamento (sem Firebase) — testáveis.
abstract final class OrderPhotos {
  static const maxCount = 10;
  static const maxBytes = 8 * 1024 * 1024; // alinhado a storage.rules isImage
  static const allowedExt = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};

  static String? countError(int current, int adding) {
    if (current + adding > maxCount) {
      return 'Máximo de $maxCount fotos por solicitação.';
    }
    return null;
  }

  static String? fileError({
    required String fileName,
    required int byteLength,
  }) {
    final ext = _ext(fileName);
    if (!allowedExt.contains(ext)) {
      return 'Formato não suportado ($ext). Use JPG, PNG ou WebP.';
    }
    if (byteLength <= 0) return 'Arquivo de imagem inválido.';
    if (byteLength > maxBytes) {
      return 'Cada foto deve ter no máximo 8 MB (após compressão).';
    }
    return null;
  }

  static bool isAllowedBytes(Uint8List bytes, String fileName) =>
      fileError(fileName: fileName, byteLength: bytes.length) == null;

  static String _ext(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Texto honesto para IA: não inventa diagnóstico nem preço.
  static String iaPromptHint({
    required String draftDescription,
    required int photoCount,
  }) {
    final n = photoCount.clamp(0, maxCount);
    return 'O cliente anexou $n foto(s) do ambiente e escreveu: '
        '"${draftDescription.trim()}". '
        'Sugira apenas uma descrição clara do pedido de orçamento em português, '
        'sem inventar diagnóstico técnico, materiais, prazos ou preços.';
  }
}

/// Foto local ainda não enviada ao Storage.
class OrderPhotoDraft {
  final String id;
  final String fileName;
  final Uint8List bytes;

  const OrderPhotoDraft({
    required this.id,
    required this.fileName,
    required this.bytes,
  });
}
