import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/services/payment_gateway.dart';

void main() {
  test('identidade visível é Carajás 360', () {
    expect(AppInfo.name, 'Carajás 360');
    expect(AppInfo.supportEmail.contains('servicoconecta.com.br'), isTrue);
  });

  test('PaymentService expõe o contrato de gateway', () {
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.pix), isTrue);
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.wallet), isFalse);
    expect(PaymentMethod.wallet.label.contains('Carajás 360'), isTrue);
    expect(PlanTier.values.map((e) => e.name),
        containsAll(['free', 'professional', 'premium', 'corporate']));
  });
}
