import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/security/order_policy.dart';
import 'package:servico_conecta/core/utils/demo_data.dart';

void main() {
  group('DemoData', () {
    test('nunca liga em release', () {
      expect(
        DemoData.enabledFor(releaseMode: true, debugMode: true),
        isFalse,
      );
      expect(
        DemoData.enabledFor(releaseMode: true, debugMode: false),
        isFalse,
      );
    });

    test('só debug (não profile/release)', () {
      expect(
        DemoData.enabledFor(releaseMode: false, debugMode: true),
        isTrue,
      );
      expect(
        DemoData.enabledFor(releaseMode: false, debugMode: false),
        isFalse,
      );
    });

    test('não substitui lista real do backend (nem vazia)', () {
      expect(DemoData.orEmpty<int>([1, 2], [9]), [1, 2]);
      expect(DemoData.orEmpty<int>(<int>[], [9]), isEmpty);
    });
  });

  group('AUTH / ORDERS / PAYMENTS / WALLET / REVIEWS (policy)', () {
    test('unauth não executa ação de pedido', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'complete', uid: '', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('ownership: terceiro não aceita', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'accept', uid: 'x', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('preço e providerId são campos protegidos', () {
      expect(OrderPolicy.sensitiveFields.contains('price'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('providerId'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('plan'), isTrue);
      expect(OrderPolicy.protectedUserFields.contains('xp'), isTrue);
      expect(OrderPolicy.protectedProviderFields.contains('verified'), isTrue);
    });

    test('payout único', () {
      final r = OrderPolicy.canPayout(
        status: 'completed',
        paymentStatus: 'paid',
        payoutProcessed: true,
        providerId: 'p1',
        price: 80,
        orderId: 'o1',
        paymentOrderId: 'o1',
        gatewayStatus: 'approved',
        paidAmount: 80,
      );
      expect(r.ok, isFalse);
      expect(r.reason, 'already_processed');
    });

    test('double charge bloqueado', () {
      expect(OrderPolicy.rejectDoubleCharge(paymentStatus: 'paid'), 'already_paid');
    });
  });
}
