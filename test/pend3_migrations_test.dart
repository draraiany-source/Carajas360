import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/admin/data_migrations.dart';

void main() {
  testWidgets('migrações de dados: três tarefas, nada roda sem confirmação',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: DataMigrationsCard()))));
    expect(find.text('Mercado: lojas e contadores'), findsOneWidget);
    expect(find.text('Anexos do chat'), findsOneWidget);
    expect(find.text('Prazo dos pedidos'), findsOneWidget);
    await tester.tap(find.text('Migrar'));
    await tester.pumpAndSettle();
    expect(find.text('Executar migração?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byKey(const Key('migration-result-chat')), findsNothing);
  });
}
