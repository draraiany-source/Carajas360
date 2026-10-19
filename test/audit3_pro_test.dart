import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/provider/money_parse.dart';
import 'package:servico_conecta/features/provider/provider_home_screen.dart';
import 'package:servico_conecta/features/resolve/resolve_screen.dart';
import 'package:servico_conecta/shared/models/models.dart';

void main() {
  group('Valores em reais (formato BR)', () {
    test('"1.500,00" vira 1500.00', () {
      expect(parseBrlAmount('1.500,00'), 1500.0);
      expect(parseQuote('1.500,00'), 1500.0);
    });
    test('outros formatos aceitos', () {
      expect(parseBrlAmount('1500,5'), 1500.5);
      expect(parseBrlAmount('1500.50'), 1500.5);
      expect(parseBrlAmount('1.500'), 1500.0);
      expect(parseBrlAmount('R\$ 12,34'), 12.34);
      expect(parseBrlAmount('0,50'), 0.5);
    });
    test('inválidos retornam null', () {
      expect(parseBrlAmount(''), isNull);
      expect(parseBrlAmount('abc'), isNull);
      expect(parseBrlAmount('1,2,3'), isNull);
      expect(parseQuote('0,50'), isNull);
    });
  });

  test('status do Resolve em português', () {
    expect(resolveStatusLabel(ResolveStatus.open), 'Aguardando propostas');
    expect(resolveStatusLabel(ResolveStatus.matched), 'Contratado');
    expect(resolveStatusLabel(ResolveStatus.closed), 'Encerrado');
    expect(resolveStatusLabel(ResolveStatus.cancelled), 'Cancelado');
  });

  testWidgets('onboarding: envio exige documento e selfie', (t) async {
    await t.pumpWidget(const MaterialApp(home: ProviderOnboardingScreen()));
    final btn = t.widget<ElevatedButton>(find.byKey(const Key('onboarding-submit')));
    expect(btn.onPressed, isNull);
    expect(find.byKey(const Key('onboarding-missing-docs')), findsOneWidget);
  });
}
