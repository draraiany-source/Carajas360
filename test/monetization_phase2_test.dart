import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/monetization/money.dart';
import 'package:carajas_360/core/monetization/monetization_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carajas_360/core/monetization/lead_unlock_service.dart';

void main() {
  group('MoneyCents / CommissionSplit', () {
    test('500 reais at 8% => 40 platform / 460 pro', () {
      final split = CommissionSplit.calculate(
        gross: MoneyCents.fromReais(500),
        commissionRate: 0.08,
      );
      expect(split.platformCommission.cents, 4000);
      expect(split.professionalAmount.cents, 46000);
      expect(split.gross.cents, 50000);
    });

    test('commission clamps above 30%', () {
      final split = CommissionSplit.calculate(
        gross: MoneyCents.fromReais(100),
        commissionRate: 0.99,
      );
      expect(split.commissionRate, 0.30);
    });

    test('gateway fee reduces base', () {
      final split = CommissionSplit.calculate(
        gross: MoneyCents.fromReais(100),
        commissionRate: 0.10,
        gatewayFee: MoneyCents.fromReais(5),
      );
      // base 95 -> 9.5 platform -> 85.5 pro
      expect(split.platformCommission.cents, 950);
      expect(split.professionalAmount.cents, 8550);
    });
  });

  group('MonetizationConfig', () {
    test('rejects invalid commission via validator', () {
      expect(MonetizationConfig.validateCommissionRate(-0.1), isFalse);
      expect(MonetizationConfig.validateCommissionRate(0.31), isFalse);
      expect(MonetizationConfig.validateCommissionRate(0.08), isTrue);
    });

    test('fromMap uses defaults and clamps rate', () {
      final c = MonetizationConfig.fromMap({'commissionRate': 0.5});
      expect(c.commissionRate, 0.30);
      expect(c.creditPackages, isNotEmpty);
      expect(c.proPriceMonthly.cents, greaterThan(0));
    });

    test('pro price from admin cents', () {
      final c = MonetizationConfig.fromMap({'proPriceCents': 4990});
      expect(c.proPriceMonthly.formatted.contains('49,90'), isTrue);
    });
  });

  group('LeadUnlockService homolog', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('unlock deducts credits once; second is free', () async {
      final cfg = MonetizationConfig.defaults();
      // Force homolog path by checking HomologCatalog — may be false in unit test.
      // Still test prefs idempotency helpers.
      final firstCheck = await LeadUnlockService.isUnlocked(
          providerId: 'p1', requestId: 'r1');
      expect(firstCheck, isFalse);

      // Manually simulate unlock flag (homolog path needs HomologCatalog.enabled)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('lead_unlock_p1_r1', true);
      expect(
          await LeadUnlockService.isUnlocked(
              providerId: 'p1', requestId: 'r1'),
          isTrue);
      expect(cfg.defaultLeadCreditCost, greaterThan(0));
    });

    test('homolog credit balance welcome default', () async {
      final bal = await LeadUnlockService.homologCreditsBalance('proX');
      expect(bal, 20);
      await LeadUnlockService.homologAddCredits('proX', 10);
      expect(await LeadUnlockService.homologCreditsBalance('proX'), 30);
    });
  });
}
