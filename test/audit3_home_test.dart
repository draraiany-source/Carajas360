import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/widgets/config_unavailable.dart';
import 'package:servico_conecta/features/profile/profile_screens.dart';

String _src(String path) => File(path).readAsStringSync();

void main() {
  group('Avaliação', () {
    testWidgets('começa sem estrelas e exige escolha antes de enviar',
        (t) async {
      await t.pumpWidget(
          const MaterialApp(home: ReviewScreen(orderId: 'o1')));
      await t.pump();

      ElevatedButton submit() => t.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Enviar avaliação ⭐'));
      expect(find.text('Toque nas estrelas para avaliar'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(submit().onPressed, isNull);

      await t.tap(find.byKey(const Key('review-star-4')));
      await t.pump();
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      expect(find.text('😄 Bom'), findsOneWidget);
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('estrelas têm rótulo acessível', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
          const MaterialApp(home: ReviewScreen(orderId: 'o1')));
      await t.pump();
      expect(find.bySemanticsLabel('1 estrela'), findsOneWidget);
      expect(find.bySemanticsLabel('5 estrelas'), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('tela de configuração indisponível usa pt_BR', (t) async {
    await t.pumpWidget(const ConfigUnavailableApp(problems: []));
    await t.pump();
    final ctx = t.element(find.byType(ConfigUnavailableScreen));
    expect(Localizations.localeOf(ctx).toString(), 'pt_BR');
    expect(MaterialLocalizations.of(ctx).backButtonTooltip, 'Voltar');
    expect(find.text('Serviço temporariamente indisponível'), findsOneWidget);
  });

  group('Sem conteúdo fictício', () {
    test('carteira sem aba Planos nem preços de assinatura', () {
      final s = _src('lib/features/wallet/wallet_screen.dart');
      expect(s.contains("Tab(text: 'Planos')"), isFalse);
      expect(s.contains('49,90'), isFalse);
      expect(s.contains('Assinar'), isFalse);
      expect(s.contains('TabController(length: 2'), isTrue);
    });

    test('onboarding e cadastro sem promessas não suportadas', () {
      final s = _src('lib/features/auth/auth_screen.dart');
      expect(s.contains('Mais de 300'), isFalse);
      expect(s.contains('GPS ao vivo'), isFalse);
      expect(s.contains('Passo 1 de 1'), isFalse);
      expect(s.contains('app premium'), isFalse);
      expect(s.contains('UserType.deliverer'), isFalse);
      expect(s.contains("'Fretes'"), isFalse);
    });

    test('perfil sem cashback, endereços ou estatísticas vazias', () {
      final s = _src('lib/features/profile/profile_screens.dart');
      expect(s.contains('ganhe cashback'), isFalse);
      expect(s.contains("'Endereços'"), isFalse);
      expect(s.contains("label: 'Economia'"), isFalse);
      expect(s.contains('Compartilhar o app'), isTrue);
    });

    test('assistente com aviso de IA e sem "Sempre disponível"', () {
      final s = _src('lib/features/ai_assistant/ai_screen.dart');
      expect(s.contains('Sempre disponível'), isFalse);
      expect(s.contains('podem conter erros'), isTrue);
    });

    test('GPS centraliza na região de Carajás', () {
      final s = _src('lib/features/gps/gps_screen.dart');
      expect(s.contains('-23.5505'), isFalse);
      expect(s.contains('LatLng(-6.07, -49.90)'), isTrue);
    });
  });
}
