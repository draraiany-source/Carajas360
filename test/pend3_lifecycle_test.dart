import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/utils/memo.dart';
import 'package:servico_conecta/features/support/tickets_screens.dart';
import 'package:servico_conecta/shared/models/models.dart';

/// Tela de teste no mesmo padrão das telas corrigidas: o stream vem de uma
/// fábrica (contadora) e é guardado num Memo; o build só lê o Memo.
class _Harness extends StatefulWidget {
  final Stream<int> Function() factory;
  final Object? Function() keyOf;
  const _Harness({required this.factory, required this.keyOf});
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final _memo = Memo<Stream<int>>();
  int rebuilds = 0;

  void rebuild() => setState(() => rebuilds++);

  @override
  Widget build(BuildContext context) => StreamBuilder<int>(
        stream: _memo.of(widget.keyOf(), widget.factory),
        builder: (_, s) => Text(s.hasData ? 'v${s.data}' : 'carregando',
            textDirection: TextDirection.ltr),
      );
}

/// Stream broadcast (como os do Firestore) que conta assinaturas.
class _Source {
  int created = 0, listens = 0, cancels = 0;
  final ctrls = <StreamController<int>>[];
  Stream<int> make() {
    created++;
    late StreamController<int> c;
    c = StreamController<int>.broadcast(
        onListen: () {
          listens++;
          scheduleMicrotask(() => c.add(created));
        },
        onCancel: () => cancels++);
    ctrls.add(c);
    return c.stream;
  }
}

void main() {
  group('Memo', () {
    test('mesma chave devolve a mesma instância; chave nova recria', () {
      var n = 0;
      Object make() {
        n++;
        return Object();
      }

      final m = Memo<Object>();
      final a = m.of('u1', make);
      expect(m.of('u1', make), same(a));
      expect(n, 1);
      expect(m.of('u2', make), isNot(same(a)));
      expect(n, 2);
      // Chave nula também é uma chave válida (deslogado).
      final c = m.of(null, make);
      expect(m.of(null, make), same(c));
      expect(n, 3);
    });
  });

  testWidgets('rebuild NÃO recria o stream nem refaz a assinatura',
      (t) async {
    final src = _Source();
    var key = 'uid-0';
    await t.pumpWidget(_Harness(factory: src.make, keyOf: () => key));
    await t.pump();
    expect(find.text('v1'), findsOneWidget);
    final state = t.state<_HarnessState>(find.byType(_Harness));
    for (var i = 0; i < 5; i++) {
      state.rebuild();
      await t.pump();
    }
    expect(state.rebuilds, 5);
    expect(src.created, 1, reason: 'um stream só, apesar de 5 rebuilds');
    expect(src.listens, 1);
    expect(src.cancels, 0);
    expect(find.text('v1'), findsOneWidget, reason: 'sem voltar a "carregando"');

    // Mudou a chave (ex.: outro usuário / "puxar para atualizar"): recria
    // uma vez e cancela a assinatura anterior.
    key = 'uid-1';
    state.rebuild();
    await t.pump();
    await t.pump();
    expect(src.created, 2);
    expect(src.listens, 2);
    expect(src.cancels, 1);
    expect(find.text('v2'), findsOneWidget);

    // Sair da tela cancela o listener (sem vazamento).
    await t.pumpWidget(const SizedBox());
    expect(src.cancels, 2);
  });

  testWidgets('MyTicketsScreen: rebuild do pai mantém uma única assinatura',
      (t) async {
    var listens = 0, cancels = 0;
    final ctrl = StreamController<List<TicketModel>>.broadcast(
        onListen: () => listens++, onCancel: () => cancels++);
    Widget app(double scale) => MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: MyTicketsScreen(stream: ctrl.stream)));
    await t.pumpWidget(app(1));
    ctrl.add([
      TicketModel(
          id: 't1',
          userId: 'u',
          userName: 'U',
          subject: 'Pedido atrasado',
          message: 'm',
          createdAt: DateTime(2026, 1, 1)),
    ]);
    await t.pump();
    expect(find.text('Pedido atrasado'), findsOneWidget);
    for (final s in [1.1, 1.2, 1.0]) {
      await t.pumpWidget(app(s));
      await t.pump();
    }
    expect(listens, 1);
    expect(cancels, 0);
    expect(find.text('Pedido atrasado'), findsOneWidget);
    await ctrl.close();
  });
}
