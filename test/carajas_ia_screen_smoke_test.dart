import 'package:carajas_360/features/ai_assistant/ai_screen.dart';
import 'package:carajas_360/features/ai_assistant/carajas_ia_character.dart';
import 'package:carajas_360/features/ai_assistant/carajas_ia_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Central Carajás IA mostra personagem e boas-vindas (mobile)',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: AiAssistantScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('Carajás IA'), findsWidgets);
    expect(find.byType(CarajasIaAvatar), findsWidgets);
    expect(find.textContaining('Encontrar um profissional'), findsOneWidget);
    expect(find.textContaining('Serviços de saúde'), findsOneWidget);
    expect(find.textContaining('Humano'), findsOneWidget);
  });

  testWidgets('Painel embedded Web renderiza e tem Fechar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 720,
            child: AiAssistantScreen(embedded: true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byTooltip('Fechar'), findsOneWidget);
    expect(find.byType(CarajasIaAvatar), findsWidgets);
  });

  testWidgets('FAB Carajás IA está acessível', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          floatingActionButton: CarajasIaFab(embedPanel: false),
          body: SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CarajasIaFab), findsOneWidget);
    expect(find.bySemanticsLabel('Abrir Carajás 360 IA'), findsOneWidget);
  });
}
