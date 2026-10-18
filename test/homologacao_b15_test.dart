import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/core/widgets/maintenance_gate.dart';
import 'package:servico_conecta/features/admin/admin_forms.dart';
import 'package:servico_conecta/features/checkout/payments_api.dart';
import 'package:servico_conecta/features/health/health_booking.dart';
import 'package:servico_conecta/features/support/support_screens.dart';
import 'package:servico_conecta/features/support/tickets_screens.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/services/firebase_service.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 12);
  final inTen = now.add(const Duration(minutes: 10)).millisecondsSinceEpoch;
  final ago = now.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;

  group('Saúde: reserva aguardando pagamento (B15)', () {
    test('modelo lê holdUntilMs, paymentStatus, totalCents e lateRefund', () {
      final a = AppointmentModel.fromMap('ap_1', {
        'status': 'pending_payment',
        'startMs': inTen + 86400000,
        'holdUntilMs': inTen,
        'paymentStatus': 'unpaid',
        'totalCents': 15000,
      });
      expect(a.pendingPayment, isTrue);
      expect(a.totalCents, 15000);
      expect(a.paymentStatus, 'unpaid');
      expect(a.canPay(now), isTrue);
      expect(appointmentStatusText(a, now: now),
          '⏳ Aguardando pagamento até ${holdTimeLabel(inTen)}');
      expect(appointmentStatusText(a, asProvider: true, now: now),
          contains('do paciente'));
    });

    test('retorno da callable (sem id no mapa) também é lido', () {
      final r = {
        'id': 'ap_2',
        'reused': false,
        'startMs': 1,
        'status': 'pending_payment',
        'holdUntilMs': inTen,
        'totalCents': 9000
      };
      final a = AppointmentModel.fromMap('${r['id']}', r);
      expect(a.id, 'ap_2');
      expect(a.holdUntilMs, inTen);
    });

    test('prazo vencido, expirada e devolvida', () {
      final lapsed = AppointmentModel.fromMap('a', {
        'status': 'pending_payment',
        'startMs': 1,
        'holdUntilMs': ago,
        'totalCents': 100
      });
      expect(lapsed.canPay(now), isFalse);
      expect(appointmentStatusText(lapsed, now: now),
          contains('Reserva expirada — horário liberado'));
      final expired =
          AppointmentModel.fromMap('a', {'status': 'expired', 'startMs': 1});
      expect(appointmentStatusText(expired, now: now),
          contains('Reserva expirada — horário liberado'));
      final refunded = AppointmentModel.fromMap(
          'a', {'status': 'expired', 'startMs': 1, 'lateRefund': true});
      expect(refunded.lateRefund, isTrue);
      expect(appointmentStatusText(refunded, now: now),
          contains('Valor devolvido'));
    });

    test('consulta gratuita continua agendada direto (sem pagamento)', () {
      final free = AppointmentModel.fromMap(
          'a', {'status': 'scheduled', 'startMs': 1, 'priceCents': 0});
      expect(free.canPay(now), isFalse);
      expect(appointmentStatusText(free, now: now), contains('Agendada'));
    });

    test('horário-limite em HH:MM no fuso de Belém, qualquer que seja o do aparelho', () {
      final ms = DateTime.utc(2026, 10, 16, 12, 5).millisecondsSinceEpoch;
      expect(holdTimeLabel(ms), '09:05');
    });
  });

  group('Locação: reserva aguardando pagamento (B15)', () {
    test('pending_payment, paga aguardando anunciante, expirada e devolvida',
        () {
      final b = BookingModel.fromMap('bk', {
        'status': 'pending_payment',
        'holdUntilMs': inTen,
        'totalCents': 70000
      });
      expect(b.status, BookingStatus.pendingPayment);
      expect(b.canPay(now), isTrue);
      expect(b.totalCents, 70000);
      expect(b.ownerStatusLabel, 'Aguardando pagamento do cliente');
      expect(b.isOpen, isTrue);
      final paid = BookingModel.fromMap(
          'bk', {'status': 'pending', 'paymentStatus': 'approved'});
      expect(paid.statusLabel, 'Pago — aguardando confirmação do anunciante');
      expect(BookingModel.fromMap('bk', {'status': 'expired'}).statusLabel,
          'Reserva expirada');
      final late =
          BookingModel.fromMap('bk', {'status': 'expired', 'lateRefund': true});
      expect(late.lateRefund, isTrue);
      expect(late.statusLabel, 'Valor devolvido');
      expect(
          BookingModel.fromMap(
                  'bk', {'status': 'pending_payment', 'holdUntilMs': ago})
              .canPay(now),
          isFalse);
    });

    test('status desconhecido não vira pending_payment', () {
      expect(bookingStatusOf('qualquer'), BookingStatus.pending);
      expect(bookingStatusOf('pending_payment'), BookingStatus.pendingPayment);
    });
  });

  group('Notificações', () {
    test('supportTickets e providerOrders', () {
      expect(notificationTarget('info', {'route': 'supportTickets'})?.route,
          Routes.supportTickets);
      expect(notificationTarget('order', {'route': 'providerOrders'})?.route,
          Routes.providerHome);
    });
  });

  group('Cupons', () {
    test('validação do formulário do admin', () {
      expect(
          validateCouponInput(
              code: 'PROMO10', discount: '10', isPercentage: true),
          isNull);
      expect(
          validateCouponInput(
              code: 'PROMO10', discount: '0', isPercentage: true),
          isNotNull);
      expect(
          validateCouponInput(
              code: 'PROMO10', discount: '101', isPercentage: true),
          isNotNull);
      expect(
          validateCouponInput(
              code: 'PROMO10', discount: '100', isPercentage: true),
          isNull);
      expect(
          validateCouponInput(
              code: 'FIXO', discount: '150', isPercentage: false),
          isNull);
      expect(
          validateCouponInput(
              code: 'FIXO', discount: '-1', isPercentage: false),
          isNotNull);
      expect(validateCouponInput(code: 'x', discount: '5', isPercentage: true),
          isNotNull);
      expect(
          validateCouponInput(
              code: 'OK', discount: '5', isPercentage: true, maxUses: '0'),
          isNotNull);
      expect(
          validateCouponInput(
              code: 'OK',
              discount: '5',
              isPercentage: true,
              maxUses: '50',
              perUserLimit: '1'),
          isNull);
      expect(
          validateCouponInput(
              code: 'OK', discount: '5', isPercentage: true, perUserLimit: 'a'),
          isNotNull);
    });

    test('motivo da recusa vindo do servidor', () {
      expect(
          FS.couponRejectReason({
            'valid': false,
            'reason': 'Este cupom atingiu o limite de usos'
          }),
          'Este cupom atingiu o limite de usos');
      expect(FS.couponRejectReason({'valid': false}), isNull);
      expect(FS.couponRejectReason({'valid': true, 'reason': 'x'}), isNull);
    });

    test('config de reservas: limites do servidor', () {
      expect(validateBookingConfigInput('15', '3'), isNull);
      expect(validateBookingConfigInput('4', '3'), isNotNull);
      expect(validateBookingConfigInput('121', '3'), isNotNull);
      expect(validateBookingConfigInput('15', '0'), isNotNull);
      expect(validateBookingConfigInput('15', '11'), isNotNull);
    });
  });

  group('Prestador: recusa e nova análise', () {
    test('recusados saem da fila até pedirem nova análise', () {
      expect(providerAwaitingReview({'verified': false}), isTrue);
      expect(
          providerAwaitingReview(
              {'verified': false, 'verificationStatus': 'rejected'}),
          isFalse);
      expect(
          providerAwaitingReview(
              {'verified': false, 'verificationStatus': 'pending_review'}),
          isTrue);
      expect(providerAwaitingReview({'verified': true}), isFalse);
    });

    test('modelo lê situação e motivo', () {
      final p = ProviderModel.fromMap('p', {
        'verified': false,
        'verificationStatus': 'rejected',
        'rejectionReason': 'Documento ilegível'
      });
      expect(p.rejected, isTrue);
      expect(p.rejectionReason, 'Documento ilegível');
      expect(
          ProviderModel.fromMap('p', {
            'verified': false,
            'verificationStatus': 'pending_review'
          }).inReview,
          isTrue);
    });
  });

  group('Modo manutenção', () {
    Widget gate({required bool on, required bool admin}) => MaterialApp(
          home: MaintenanceGate(
            config: Stream.value({
              'maintenanceMode': on,
              'maintenanceMessage': 'Voltamos às 14h'
            }),
            currentUid: () => 'u1',
            isAdmin: () async => admin,
            child: const Scaffold(body: Text('APP')),
          ),
        );

    testWidgets('não admin vê a tela de manutenção', (t) async {
      await t.pumpWidget(gate(on: true, admin: false));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('maintenance-screen')), findsOneWidget);
      expect(find.text('Voltamos às 14h'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(find.text('APP'), findsNothing);
    });

    testWidgets('admin continua no app, com aviso', (t) async {
      await t.pumpWidget(gate(on: true, admin: true));
      await t.pumpAndSettle();
      expect(find.text('APP'), findsOneWidget);
      expect(find.text('Modo manutenção ativo'), findsOneWidget);
      expect(find.byKey(const Key('maintenance-screen')), findsNothing);
    });

    testWidgets('desligado: app normal para todos', (t) async {
      await t.pumpWidget(gate(on: false, admin: false));
      await t.pumpAndSettle();
      expect(find.text('APP'), findsOneWidget);
      expect(find.text('Modo manutenção ativo'), findsNothing);
    });

    testWidgets('visitante vê "Entrar" (admin consegue fazer login)',
        (t) async {
      await t.pumpWidget(MaterialApp(
          home: MaintenanceGate(
              config: Stream.value(const {'maintenanceMode': true}),
              currentUid: () => null,
              child: const Text('APP'))));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('maintenance-screen')), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('Suporte sem contato inventado', () {
    testWidgets('sem e-mail/telefone configurado: só chamado pelo app',
        (t) async {
      // Sem Firebase no teste, supportContact volta vazio (igual a config ausente).
      await t.pumpWidget(const MaterialApp(home: SupportScreen()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('support-app-only')), findsOneWidget);
      expect(find.text('E-mail'), findsNothing);
      expect(find.text('Ligar'), findsNothing);
      expect(find.text('Meus chamados'), findsWidgets);
    });
  });

  group('Meus chamados', () {
    test('chamado lê respondido, não lido e última mensagem', () {
      final t = TicketModel.fromMap('t1', {
        'userId': 'u1',
        'subject': 'Pagamento',
        'message': 'Ajuda',
        'status': 'answered',
        'unreadByUser': true,
        'lastMessageBy': 'support',
        'createdAt': Timestamp.fromDate(now),
      });
      expect(t.status, TicketStatus.answered);
      expect(t.statusLabel, contains('Respondido'));
      expect(t.unreadByUser, isTrue);
      expect(
          TicketMessage.fromMap('m', {'authorRole': 'support', 'text': 'Oi'})
              .fromSupport,
          isTrue);
    });

    testWidgets('lista: vazio e marcador de não lido', (t) async {
      final ctrl = StreamController<List<TicketModel>>();
      addTearDown(ctrl.close);
      await t
          .pumpWidget(MaterialApp(home: MyTicketsScreen(stream: ctrl.stream)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      ctrl.add(const []);
      await t.pump();
      expect(find.text('Nenhum chamado'), findsOneWidget);
      ctrl.add([
        TicketModel(
            id: 't1',
            userId: 'u1',
            userName: '',
            subject: 'Reembolso',
            message: 'm',
            status: TicketStatus.answered,
            createdAt: now,
            unreadByUser: true),
        TicketModel(
            id: 't2',
            userId: 'u1',
            userName: '',
            subject: 'Cadastro',
            message: 'm',
            createdAt: now),
      ]);
      await t.pump();
      expect(find.text('Reembolso'), findsOneWidget);
      expect(find.text('Cadastro'), findsOneWidget);
      expect(find.byKey(const Key('ticket-unread')), findsOneWidget);
    });

    testWidgets('erro de consulta é exibido (sem lista fictícia)', (t) async {
      await t.pumpWidget(MaterialApp(
          home: MyTicketsScreen(
              stream: Stream.error(FirebaseException(
                  plugin: 'cloud_firestore', code: 'permission-denied')))));
      await t.pump();
      expect(find.text('Não foi possível carregar'), findsOneWidget);
    });
  });
}
