import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/utils/app_error.dart';

void main() {
  group('AppError — não vaza stack ao usuário', () {
    test('exception e token viram fallback', () {
      expect(
        AppError.userMessage(Exception('secret token=abc'),
            message: 'Falha ao salvar.'),
        'Falha ao salvar.',
      );
      expect(
        AppError.userMessage('FirebaseException: boom\n at foo.dart'),
        AppError.fallback,
      );
    });

    test('null usa fallback informado', () {
      expect(AppError.userMessage(null, message: 'Tente de novo.'),
          'Tente de novo.');
    });
  });
}
