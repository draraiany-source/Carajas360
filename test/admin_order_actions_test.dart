import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/security/order_policy.dart';

void main() {
  group('adminReopenAllowed', () {
    test('allows reopen only from cancelled', () {
      expect(OrderPolicy.adminReopenAllowed('cancelled'), isTrue);
      expect(OrderPolicy.adminReopenAllowed('completed'), isFalse);
    });
  });

  group('adminReopenTarget', () {
    test('returns accepted when provider assigned, else pending', () {
      expect(OrderPolicy.adminReopenTarget(), 'pending');
      expect(OrderPolicy.adminReopenTarget(providerId: 'p1'), 'accepted');
    });
  });

  group('adminCancelDefinitiveAllowed', () {
    test('blocks cancelled, refunded, and released escrow', () {
      expect(OrderPolicy.adminCancelDefinitiveAllowed(fromStatus: 'paid'), isTrue);
      expect(OrderPolicy.adminCancelDefinitiveAllowed(fromStatus: 'cancelled'), isFalse);
      expect(
        OrderPolicy.adminCancelDefinitiveAllowed(
          fromStatus: 'completed',
          escrowStatus: 'released',
        ),
        isFalse,
      );
    });
  });

  group('canReleaseEscrow', () {
    final paidAt = DateTime(2026, 3, 1, 10);

    test('denies unpaid and allows after releaseAt', () {
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
          status: 'completed',
          paymentStatus: 'paid',
          payoutProcessed: false,
          releaseAt: paidAt.add(const Duration(days: 3)),
          now: paidAt.add(const Duration(days: 3)),
        ).ok,
        isTrue,
      );
    });
  });
}
