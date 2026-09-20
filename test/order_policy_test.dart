import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/security/order_policy.dart';

void main() {
  group('máquina de estados do pedido', () {
    test('transições explícitas permitidas', () {
      expect(OrderPolicy.isAllowedTransition('pending', 'accepted'), isTrue);
      expect(OrderPolicy.isAllowedTransition('accepted', 'inProgress'), isTrue);
      expect(OrderPolicy.isAllowedTransition('inProgress', 'completed'), isTrue);
      expect(OrderPolicy.isAllowedTransition('pending', 'cancelled'), isTrue);
    });

    test('completar pedido duas vezes / pular estados falha', () {
      expect(OrderPolicy.isAllowedTransition('pending', 'completed'), isFalse);
      expect(OrderPolicy.isAllowedTransition('accepted', 'completed'), isFalse);
      expect(OrderPolicy.isAllowedTransition('completed', 'completed'), isFalse);
      expect(OrderPolicy.isAllowedTransition('completed', 'inProgress'), isFalse);
    });

    test('admin reabre cancelled → pending ou accepted', () {
      expect(OrderPolicy.adminReopenAllowed('cancelled'), isTrue);
      expect(OrderPolicy.adminReopenAllowed('completed'), isFalse);
      expect(OrderPolicy.adminReopenTarget(), 'pending');
      expect(OrderPolicy.adminReopenTarget(providerId: 'p1'), 'accepted');
      expect(OrderPolicy.isAllowedTransition('cancelled', 'pending'), isTrue);
      expect(OrderPolicy.isAllowedTransition('cancelled', 'accepted'), isTrue);
    });

    test('cliente não troca providerId (campo sensível)', () {
      expect(OrderPolicy.sensitiveFields.contains('providerId'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('price'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('clientId'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('escrowStatus'), isTrue);
      expect(OrderPolicy.sensitiveFields.contains('releaseAt'), isTrue);
    });
  });

  group('complete sem pagamento', () {
    test('deve falhar se unpaid/pending', () {
      expect(
        OrderPolicy.completeBlockReason(
            currentStatus: 'inProgress', paymentStatus: 'unpaid'),
        'payment_not_confirmed',
      );
      expect(
        OrderPolicy.completeBlockReason(
            currentStatus: 'inProgress', paymentStatus: 'pending'),
        'payment_not_confirmed',
      );
    });

    test('só de inProgress + paid', () {
      expect(
        OrderPolicy.completeBlockReason(
            currentStatus: 'inProgress', paymentStatus: 'paid'),
        isNull,
      );
      expect(
        OrderPolicy.completeBlockReason(
            currentStatus: 'pending', paymentStatus: 'paid'),
        'invalid_transition',
      );
    });
  });

  group('payout', () {
    PayoutDecision payout({
      bool processed = false,
      String status = 'completed',
      String payment = 'paid',
      String? provider = 'p1',
      num price = 100,
      String payOrder = 'o1',
      num paid = 100,
    }) =>
        OrderPolicy.canPayout(
          status: status,
          paymentStatus: payment,
          payoutProcessed: processed,
          providerId: provider,
          price: price,
          orderId: 'o1',
          paymentOrderId: payOrder,
          gatewayStatus: payment == 'paid' ? 'approved' : 'pending',
          paidAmount: paid,
        );

    test('repasse único calcula 8% de comissão (100 → 8/92)', () {
      final r = payout();
      expect(r.ok, isTrue);
      expect(r.commission, 8);
      expect(r.providerAmount, 92);
    });

    test('250 → 20/230', () {
      final r = payout(price: 250, paid: 250);
      expect(r.commission, 20);
      expect(r.providerAmount, 230);
    });

    test('1000 → 80/920', () {
      final r = payout(price: 1000, paid: 1000);
      expect(r.commission, 80);
      expect(r.providerAmount, 920);
    });

    test('executar payout duas vezes falha com already_processed', () {
      final r = payout(processed: true);
      expect(r.ok, isFalse);
      expect(r.reason, 'already_processed');
    });

    test('alterar price (valor pago ≠ price) falha', () {
      final r = payout(paid: 1);
      expect(r.ok, isFalse);
      expect(r.reason, 'amount_mismatch');
    });

    test('pedido de outro orderId no pagamento falha', () {
      final r = payout(payOrder: 'outro');
      expect(r.ok, isFalse);
      expect(r.reason, 'payment_order_mismatch');
    });

    test('concluir sem pagamento falha', () {
      final r = payout(payment: 'unpaid', paid: 0);
      expect(r.ok, isFalse);
      expect(r.reason, 'payment_not_confirmed');
    });

    test('providerId ausente falha', () {
      final r = payout(provider: '');
      expect(r.ok, isFalse);
      expect(r.reason, 'missing_provider');
    });
  });

  group('escrow staging', () {
    test('escrowHoldOnPaid retém e calcula releaseAt +3 dias', () {
      final paidAt = DateTime(2026, 1, 1, 12);
      final hold = OrderPolicy.escrowHoldOnPaid(amount: 100, paidAt: paidAt);
      expect(hold.escrowStatus, 'held');
      expect(hold.heldAmount, 100);
      expect(hold.releaseAt, paidAt.add(const Duration(days: 3)));
    });

    test('canReleaseEscrow bloqueia client e estados inválidos', () {
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'completed',
          paymentStatus: 'unpaid',
          payoutProcessed: false,
        ).ok,
        isFalse,
      );
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'disputed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          escrowStatus: 'disputed',
        ).reason,
        'disputed',
      );
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'completed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          escrowStatus: 'released',
        ).reason,
        'already_released',
      );
    });

    test('canReleaseEscrow libera com confirmação do cliente ou após prazo', () {
      final paidAt = DateTime(2026, 1, 1);
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'completed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          clientConfirmed: true,
        ).ok,
        isTrue,
      );
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'completed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          paidAt: paidAt,
          now: paidAt.add(const Duration(days: 3)),
        ).ok,
        isTrue,
      );
      expect(
        OrderPolicy.canReleaseEscrow(
          status: 'completed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          paidAt: paidAt,
          now: paidAt.add(const Duration(days: 2)),
        ).reason,
        'release_not_due',
      );
    });

    test('adminCancelDefinitiveAllowed', () {
      expect(
        OrderPolicy.adminCancelDefinitiveAllowed(fromStatus: 'paid'),
        isTrue,
      );
      expect(
        OrderPolicy.adminCancelDefinitiveAllowed(fromStatus: 'cancelled'),
        isFalse,
      );
      expect(
        OrderPolicy.adminCancelDefinitiveAllowed(
          fromStatus: 'completed',
          escrowStatus: 'released',
        ),
        isFalse,
      );
    });
  });

  group('quem pode agir', () {
    test('terceiro não aceita pedido de outro prestador', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'accept', uid: 'p2', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('cliente não inicia atendimento', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'start', uid: 'c1', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
    });

    test('reopen/cancelDefinitive/releaseEscrow só admin', () {
      expect(
        OrderPolicy.actorMayPerform(
            action: 'reopen', uid: 'c1', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
      expect(
        OrderPolicy.actorMayPerform(
            action: 'reopen',
            uid: 'admin',
            clientId: 'c1',
            providerId: 'p1',
            isAdmin: true),
        isTrue,
      );
      expect(
        OrderPolicy.actorMayPerform(
            action: 'releaseEscrow', uid: 'c1', clientId: 'c1', providerId: 'p1'),
        isFalse,
      );
      expect(
        OrderPolicy.actorMayPerform(
            action: 'releaseEscrow',
            uid: 'admin',
            clientId: 'c1',
            providerId: 'p1',
            isAdmin: true),
        isTrue,
      );
    });
  });
}
