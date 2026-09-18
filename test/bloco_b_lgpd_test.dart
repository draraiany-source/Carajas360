import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/security/order_policy.dart';
import 'package:servico_conecta/core/utils/auth_validators.dart';

void main() {
  group('BLOCO B — CPF', () {
    test('algoritmo rejeita 000... e 111... e aceita CPF real', () {
      expect(AuthValidators.isValidCpf('00000000000'), isFalse);
      expect(AuthValidators.isValidCpf('11111111111'), isFalse);
      expect(AuthValidators.isValidCpf('22222222222'), isFalse);
      expect(AuthValidators.isValidCpf('52998224725'), isTrue);
    });
  });

  group('BLOCO B — XP', () {
    test('XP é campo protegido (client não grava)', () {
      expect(OrderPolicy.protectedUserFields.contains('xp'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('anonymized'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('deletedAt'), isTrue);
    });
  });
}
