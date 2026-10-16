import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/core/widgets/maintenance_gate.dart';
import 'package:servico_conecta/features/checkout/payment_screens.dart';
import 'package:servico_conecta/features/checkout/payments_api.dart';
import 'package:servico_conecta/features/support/tickets_screens.dart';
import 'package:servico_conecta/shared/models/models.dart';

void main() {
  group('Modo manutenção em todas as rotas', () {
    Widget app(MaintenanceRouteObserver obs,
            {required Stream<Map<String, dynamic>> config,
            bool admin = false,
            String? uid = 'u1'}) =>
        MaterialApp(
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [obs],
          initialRoute: Routes.login,
          builder: (context, child) => MaintenanceGate(
              exempt: obs.exempt,
              config: config,
              currentUid: () => uid,
              isAdmin: () async => admin,
              child: child!),
          routes: {
            Routes.login: (_) => const Scaffold(body: Text('LOGIN')),
            Routes.rental: (_) => const Scaffold(body: Text('LOCAÇÃO')),
          },
        );

    testWidgets('login fica livre; outra rota (não main) é bloqueada',
        (t) async {
      final obs = MaintenanceRouteObserver();
      await t.pumpWidget(
          app(obs, config: Stream.value(const {'maintenanceMode': true})));
      await t.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.byKey(const Key('maintenance-screen')), findsNothing);

      rootNavigatorKey.currentState!.pushNamed(Routes.rental);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('maintenance-screen')), findsOneWidget);
      expect(find.text('LOCAÇÃO'), findsNothing);

      // Voltar ao login libera de novo.
      rootNavigatorKey.currentState!.pop();
      await t.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.byKey(const Key('maintenance-screen')), findsNothing);
    });

    testWidgets('visitante: "Entrar" (acima do navegador) abre o login',
        (t) async {
      final obs = MaintenanceRouteObserver();
      await t.pumpWidget(app(obs,
          config: Stream.value(const {'maintenanceMode': true}), uid: null));
      await t.pumpAndSettle();
      rootNavigatorKey.currentState!.pushNamed(Routes.rental);
      await t.pumpAndSettle();
      await t.tap(find.text('Entrar'));
      await t.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.byKey(const Key('maintenance-screen')), findsNothing);
    });

    testWidgets('admin usa a rota com aviso', (t) async {
      final obs = MaintenanceRouteObserver();
      await t.pumpWidget(app(obs,
          config: Stream.value(const {'maintenanceMode': true}), admin: true));
      await t.pumpAndSettle();
      rootNavigatorKey.currentState!.pushNamed(Routes.rental);
      await t.pumpAndSettle();
      expect(find.text('LOCAÇÃO'), findsOneWidget);
      expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
    });

    testWidgets('carregando até a 1ª leitura da configuração (sem piscar)',
        (t) async {
      final ctrl = StreamController<Map<String, dynamic>>();
      addTearDown(ctrl.close);
      await t.pumpWidget(MaterialApp(
          home: MaintenanceGate(
              config: ctrl.stream,
              currentUid: () => 'u1',
              isAdmin: () async => false,
              child: const Text('APP'))));
      expect(find.text('APP'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ctrl.add(const {'maintenanceMode': false});
      await t.pumpAndSettle();
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('sem resposta da configuração: libera após o prazo',
        (t) async {
      final ctrl = StreamController<Map<String, dynamic>>();
      addTearDown(ctrl.close);
      await t.pumpWidget(MaterialApp(
          home: MaintenanceGate(
              config: ctrl.stream,
              configTimeout: const Duration(seconds: 2),
              child: const Text('APP'))));
      expect(find.text('APP'), findsNothing);
      await t.pump(const Duration(seconds: 3));
      expect(find.text('APP'), findsOneWidget);
    });

    testWidgets('estado do filho preservado quando o aviso aparece',
        (t) async {
      final ctrl = StreamController<Map<String, dynamic>>();
      addTearDown(ctrl.close);
      await t.pumpWidget(MaterialApp(
          home: MaintenanceGate(
              config: ctrl.stream,
              currentUid: () => 'u1',
              isAdmin: () async => true,
              child: const _Counter())));
      ctrl.add(const {'maintenanceMode': false});
      await t.pumpAndSettle();
      await t.tap(find.text('0'));
      await t.pump();
      expect(find.text('1'), findsOneWidget);
      ctrl.add(const {'maintenanceMode': true});
      await t.pumpAndSettle();
      expect(find.byKey(const Key('maintenance-banner')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('Conversa do chamado', () {
    TicketModel ticket({bool unread = false}) => TicketModel.fromMap('t1', {
          'userId': 'u1',
          'subject': 'Pagamento',
          'message': 'Ajuda',
          'status': 'answered',
          'unreadByUser': unread,
        });

    testWidgets('documento inexistente: "Chamado não encontrado."',
        (t) async {
      await t.pumpWidget(MaterialApp(
          home: TicketDetailScreen(
              ticketId: 'x',
              ticketStream: Stream.value(null),
              messagesStream: Stream.value(const []),
              markRead: (_) async {})));
      await t.pumpAndSettle();
      expect(find.text('Chamado não encontrado.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('abrir com resposta nova marca como lido (uma vez)',
        (t) async {
      final calls = <String>[];
      final ctrl = StreamController<TicketModel?>();
      addTearDown(ctrl.close);
      await t.pumpWidget(MaterialApp(
          home: TicketDetailScreen(
              ticketId: 't1',
              initial: ticket(unread: true),
              ticketStream: ctrl.stream,
              messagesStream: Stream.value(const []),
              markRead: (id) async => calls.add(id))));
      await t.pumpAndSettle();
      ctrl.add(ticket(unread: true));
      await t.pumpAndSettle();
      expect(calls, ['t1']);
    });

    testWidgets('admin no suporte não marca como lido', (t) async {
      final calls = <String>[];
      await t.pumpWidget(MaterialApp(
          home: TicketDetailScreen(
              ticketId: 't1',
              asSupport: true,
              initial: ticket(unread: true),
              ticketStream: Stream.value(ticket(unread: true)),
              messagesStream: Stream.value(const []),
              markRead: (id) async => calls.add(id))));
      await t.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('falha ao marcar como lido é ignorada', (t) async {
      await t.pumpWidget(MaterialApp(
          home: TicketDetailScreen(
              ticketId: 't1',
              initial: ticket(unread: true),
              ticketStream: Stream.value(ticket(unread: true)),
              messagesStream: Stream.value(const []),
              markRead: (_) async => throw Exception('offline'))));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Ajuda'), findsOneWidget);
    });
  });

  group('Pagamento de reserva com prazo vencido', () {
    final past = DateTime.now()
        .subtract(const Duration(minutes: 1))
        .millisecondsSinceEpoch;

    test('holdDeadlinePassed', () {
      final now = DateTime.utc(2026, 10, 16, 12);
      expect(holdDeadlinePassed(null, now), isFalse);
      expect(holdDeadlinePassed(now.millisecondsSinceEpoch + 1, now), isFalse);
      expect(holdDeadlinePassed(now.millisecondsSinceEpoch, now), isTrue);
    });

    for (final method in ['pix', 'card']) {
      testWidgets('$method: não inicia cobrança e avisa', (t) async {
        await t.pumpWidget(MaterialApp(
            home: PaymentScreen(
                target: const PayTarget('rental', 'b1', 10000, 'Locação'),
                method: method,
                deadlineMs: past)));
        await t.pump();
        expect(find.byKey(const Key('payment-deadline-passed')),
            findsOneWidget);
        expect(find.text('O prazo para pagar terminou.'), findsOneWidget);
        expect(find.text('Tentar novamente'), findsNothing);
      });
    }
  });

  group('Retomada após login', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('argumentos não serializáveis: guarda só a rota', () async {
      await AuthResume.set(Routes.rental, {'obj': Object()});
      final p = await SharedPreferences.getInstance();
      expect(jsonDecode(p.getString('pending_route_v1')!),
          {'route': Routes.rental});
      final r = await AuthResume.take();
      expect(r?.route, Routes.rental);
      expect(r?.args, isNull);
    });

    test('clear descarta a pendência antiga', () async {
      await AuthResume.set(Routes.coupons);
      await AuthResume.clear();
      expect(await AuthResume.take(), isNull);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: TextButton(
          onPressed: () => setState(() => n++), child: Text('$n')));
}
