import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/widgets/adaptive_nav.dart';
import 'package:servico_conecta/shared/widgets/widgets.dart';

const _dests = [
  NavDest(Icons.home_rounded, 'Início'),
  NavDest(Icons.explore_rounded, 'Explorar'),
  NavDest(Icons.receipt_long_rounded, 'Pedidos'),
  NavDest(Icons.chat_bubble_outline_rounded, 'Mensagens'),
  NavDest(Icons.person_outline_rounded, 'Perfil'),
];

Widget _nav(int idx, ValueChanged<int> onSel) => MaterialApp(
      home: AdaptiveNavScaffold(
        destinations: _dests,
        index: idx,
        onSelect: onSel,
        body: Text('aba $idx'),
        bottomBar: (_) => const SizedBox(key: Key('bottom-bar'), height: 60),
      ),
    );

void main() {
  group('Notificação abre a tela certa', () {
    test('link do servidor tem prioridade; tipo é o fallback para antigas', () {
      expect(notificationTarget('resolve', {'route': 'resolveDetail', 'id': 'rr1'})?.route, Routes.resolveDetail);
      expect(notificationTarget('resolve', {'route': 'resolveDetail', 'id': 'rr1'})?.args, {'id': 'rr1'});
      expect(notificationTarget('health', {'route': 'appointments'})?.route, Routes.appointments);
      expect(notificationTarget('rental', null)?.route, Routes.bookings);
      expect(notificationTarget('order', null)?.route, Routes.myOrders);
      expect(notificationTarget('market', {'route': 'marketOrder', 'id': 'mo_1'})?.args, {'id': 'mo_1'});
      expect(notificationTarget('promo', null), isNull, reason: 'sem destino: só marca como lida');
      expect(notificationTarget('x', {'route': 'admin'}), isNull, reason: 'rota desconhecida ignorada');
    });
  });

  group('Navegação principal adaptativa', () {
    testWidgets('celular: barra inferior; desktop: navegação lateral', (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      t.view.physicalSize = const Size(390, 800);
      await t.pumpWidget(_nav(0, (_) {}));
      expect(find.byKey(const Key('bottom-bar')), findsOneWidget);
      expect(find.byKey(const Key('main-rail')), findsNothing);
      t.view.physicalSize = const Size(1280, 800);
      var sel = -1;
      await t.pumpWidget(_nav(0, (i) => sel = i));
      expect(find.byKey(const Key('main-rail')), findsOneWidget);
      expect(find.byKey(const Key('bottom-bar')), findsNothing);
      await t.tap(find.text('Pedidos'));
      expect(sel, 2);
    });

    testWidgets('tablet com texto ampliado (1.5x) sem overflow', (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      t.view.physicalSize = const Size(1000, 700);
      await t.pumpWidget(MediaQuery(
          data: const MediaQueryData(size: Size(1000, 700), textScaler: TextScaler.linear(1.5)),
          child: _nav(1, (_) {})));
      expect(t.takeException(), isNull);
      expect(find.text('Explorar'), findsOneWidget);
    });
  });

  group('Conteúdo proporcional', () {
    testWidgets('pagePadding: 16 px no celular; centraliza em telas largas', (t) async {
      late EdgeInsets phone, desk;
      await t.pumpWidget(MediaQuery(
          data: const MediaQueryData(size: Size(390, 800)),
          child: Builder(builder: (c) {
            phone = pagePadding(c);
            return const SizedBox();
          })));
      await t.pumpWidget(MediaQuery(
          data: const MediaQueryData(size: Size(1440, 900)),
          child: Builder(builder: (c) {
            desk = pagePadding(c);
            return const SizedBox();
          })));
      expect(phone.left, 16);
      expect(desk.left, (1440 - 920) / 2);
    });
  });

  group('Login retoma a ação; sessão expirada preserva a tela', () {
    test('AuthResume guarda rota e argumentos e é consumido uma vez', () async {
      SharedPreferences.setMockInitialValues({});
      await AuthResume.set(Routes.providerProfile, {'providerId': 'p1', 'category': 'eletricista'});
      final r = await AuthResume.take();
      expect(r?.route, Routes.providerProfile);
      expect(r?.args, {'providerId': 'p1', 'category': 'eletricista'});
      expect(await AuthResume.take(), isNull);
      await AuthResume.set(Routes.login);
      expect(await AuthResume.take(), isNull, reason: 'login não é destino de retomada');
    });

    testWidgets('sessão expirada leva ao login e guarda a tela atual', (t) async {
      SharedPreferences.setMockInitialValues({});
      await t.pumpWidget(MaterialApp(
        navigatorKey: rootNavigatorKey,
        initialRoute: '/',
        onGenerateRoute: (s) => MaterialPageRoute(
            settings: s,
            builder: (_) => Scaffold(body: Text(s.name == Routes.login ? 'TELA LOGIN' : 'tela ${s.name}'))),
      ));
      rootNavigatorKey.currentState!.pushNamed(Routes.wallet, arguments: {'tab': 1});
      await t.pumpAndSettle();
      final done = SessionGuard.instance.expired();
      await t.pump();
      await done;
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(find.text('TELA LOGIN'), findsOneWidget);
      expect(find.text('Sua sessão expirou. Entre novamente para continuar.'), findsOneWidget);
      final r = await AuthResume.take();
      expect(r?.route, Routes.wallet);
      expect(r?.args, {'tab': 1});
      await t.pump(const Duration(seconds: 5)); // fecha o aviso
    });
  });

  group('Painel do prestador', () {
    test('ganho usa a comissão do pedido e a data de conclusão', () {
      final created = DateTime(2026, 10, 1);
      final done = DateTime(2026, 10, 3);
      final o = OrderModel.fromMap('o1', {
        'price': 200,
        'status': 'completed',
        'financeTerms': {'commissionBps': 1000},
        'createdAt': Timestamp.fromDate(created),
        'completedAt': Timestamp.fromDate(done),
      });
      expect(o.providerNet, 180);
      expect(o.earnedAt, done);
      final legado = OrderModel.fromMap('o2', {'price': 100, 'createdAt': Timestamp.fromDate(created)});
      expect(legado.providerNet, 85, reason: 'pedido antigo sem snapshot: 15%');
      expect(legado.earnedAt, created);
    });
  });
}
