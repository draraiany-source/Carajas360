import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/security/order_policy.dart';
import 'package:carajas_360/shared/models/models.dart';

void main() {
  group('BLOCO A — testes de fraude financeira (devem ser bloqueados)', () {
    test('1) alterar price é campo sensível', () {
      expect(OrderPolicy.sensitiveFields.contains('price'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('amount'), isTrue);
    });

    test('2) trocar providerId é bloqueado no payout oficial', () {
      final r = OrderPolicy.canPayout(
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: false,
        providerId: 'hacker',
        officialProviderId: 'p1',
        price: 150,
        orderId: 'o1',
        paymentOrderId: 'o1',
        gatewayStatus: 'approved',
        paidAmount: 150,
      );
      expect(r.ok, isFalse);
      expect(r.reason, 'provider_mismatch');
    });

    test('3) concluir sem pagamento falha', () {
      expect(
        OrderPolicy.completeBlockReason(
            currentStatus: 'inProgress', paymentStatus: 'unpaid'),
        'payment_not_confirmed',
      );
      expect(OrderPolicy.isAllowedTransition('pending', 'completed'), isFalse);
    });

    test('4) pagar duas vezes falha', () {
      expect(OrderPolicy.rejectDoubleCharge(paymentStatus: 'paid'), 'already_paid');
      expect(OrderPolicy.rejectDoubleCharge(paymentStatus: 'unpaid'), isNull);
    });

    test('5) payout duas vezes é idempotente (already_processed)', () {
      final r = OrderPolicy.canPayout(
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: true,
        providerId: 'p1',
        price: 100,
        orderId: 'o1',
        paymentOrderId: 'o1',
        gatewayStatus: 'approved',
        paidAmount: 100,
      );
      expect(r.ok, isFalse);
      expect(r.reason, 'already_processed');
    });

    test('6) Function sem auth: actor inválido não executa ação', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'complete', uid: '', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('7) Function com usuário errado não completa/paga pedido alheio', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'complete', uid: 'hacker', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
      expect(
        OrderPolicy.actorMayPerform(
            action: 'accept', uid: 'hacker', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('8) manipular status manualmente / pular estados falha', () {
      expect(OrderPolicy.sensitiveFields.contains('status'), isTrue);
      expect(OrderPolicy.isAllowedTransition('pending', 'paid'), isFalse);
      expect(OrderPolicy.actorMayPerform(
          action: 'markPaid', uid: 'c1', clientId: 'c1', providerId: 'p1'),
          isFalse);
      expect(OrderPolicy.actorMayPerform(
          action: 'refund', uid: 'c1', clientId: 'c1', providerId: 'p1'),
          isFalse);
    });
  });

  group('perfil / empresa não se autoaprovam', () {
    test('campos privilegiados de user/provider/company estão protegidos', () {
      expect(OrderPolicy.protectedUserFields.contains('verified'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('plan'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('moderationStatus'), isTrue);
      expect(OrderPolicy.protectedProviderFields.contains('approved'), isTrue);
      expect(OrderPolicy.protectedCompanyFields.contains('plan'), isTrue);
      expect(OrderPolicy.protectedCompanyFields.contains('active'), isTrue);
    });

    test('empresa no create envia verified/plan/active neutros', () {
      final c = CompanyModel(
        id: 'u1',
        ownerId: 'u1',
        name: 'Loja',
        cnpj: '000',
        createdAt: DateTime(2024, 1, 1),
        plan: PlanTier.premium,
        verified: true,
        active: true,
      );
      final creating = c.toOwnerWriteMap(creating: true);
      expect(creating['plan'], 'free');
      expect(creating['verified'], isFalse);
      expect(creating['active'], isFalse);
      expect(creating['approved'], isFalse);
      final updating = c.toOwnerWriteMap();
      expect(updating.containsKey('plan'), isFalse);
      expect(updating.containsKey('verified'), isFalse);
      expect(updating.containsKey('active'), isFalse);
    });
  });

  group('aliases de status', () {
    test('created e in_progress são normalizados', () {
      expect(OrderPolicy.normalizeStatus('created'), 'pending');
      expect(OrderPolicy.normalizeStatus('in_progress'), 'inProgress');
      expect(OrderModel.fromMap('x', {'status': 'created'}).status,
          OrderStatus.pending);
      expect(OrderModel.fromMap('x', {'status': 'in_progress'}).status,
          OrderStatus.inProgress);
    });
  });
}
