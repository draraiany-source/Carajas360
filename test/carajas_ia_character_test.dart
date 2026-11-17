import 'package:carajas_360/features/ai_assistant/carajas_ia_actions.dart';
import 'package:carajas_360/features/ai_assistant/carajas_ia_assets.dart';
import 'package:carajas_360/features/ai_assistant/carajas_ia_character.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recepção tem boas-vindas e atalhos reais', () {
    expect(CarajasIaReception.welcome, contains('Carajás IA'));
    expect(CarajasIaReception.welcome, contains('te ajudar'));
    expect(CarajasIaReception.actions.length, greaterThanOrEqualTo(5));
    expect(
      CarajasIaReception.actions.any((a) => a.id == 'find_pro'),
      isTrue,
    );
    expect(
      CarajasIaReception.actions.any((a) => a.id == 'health'),
      isTrue,
    );
    expect(
      CarajasIaReception.actions.every((a) =>
          a.route != null ||
          a.chatPrompt != null ||
          a.unavailableMessage != null),
      isTrue,
    );
  });

  test('assets oficiais apontam para pasta carajas_ia', () {
    expect(CarajasIaAssets.avatar, contains('carajas_ia'));
    expect(CarajasIaAssets.portrait, contains('carajas_ia'));
    expect(CarajasIaAssets.fullBody, contains('carajas_ia'));
    expect(CarajasIaAssets.fab, contains('carajas_ia'));
  });

  testWidgets('CarajasIaAvatar renderiza sem crash', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CarajasIaAvatar(size: 40))),
      ),
    );
    await tester.pump();
    expect(find.byType(CarajasIaAvatar), findsOneWidget);
  });
}
