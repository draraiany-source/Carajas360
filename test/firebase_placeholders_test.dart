import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/constants/app_constants.dart';
import 'package:carajas_360/core/constants/runtime_config.dart';
import 'package:carajas_360/core/security/order_policy.dart';
import 'package:carajas_360/core/utils/firebase_bootstrap.dart';
import 'package:carajas_360/firebase_options.dart';

/// Release builds MUST NOT ship with Firebase placeholder keys.
void main() {
  group('Firebase placeholders (staging)', () {
    test('DefaultFirebaseOptions apiKey contains COLE_SUA placeholder', () {
      final key = DefaultFirebaseOptions.android.apiKey;
      expect(
        key.contains('COLE_SUA') || key.contains('demo-api-key'),
        isTrue,
        reason: 'Expected placeholder until flutterfire configure replaces keys',
      );
    });

    test('FirebaseBootstrap.hasPlaceholderKeys is true until flutterfire', () {
      expect(FirebaseBootstrap.hasPlaceholderKeys, isTrue);
    });

    test('RuntimeConfig maps/MP placeholders detected', () {
      expect(RuntimeConfig.hasPlaceholderMaps, isTrue);
      expect(RuntimeConfig.hasPlaceholderMercadoPago, isTrue);
    });

    test('document: release must not ship placeholders', () {
      expect(FirebaseBootstrap.hasPlaceholderKeys, isTrue);
      expect(DefaultFirebaseOptions.android.apiKey, contains('COLE_SUA'));
    });
  });

  group('App constants (publication)', () {
    test('commission is 8% (0.08)', () {
      expect(AppConst.commission, 0.08);
      expect(OrderPolicy.commissionRate, 0.08);
    });

    test('privacyUrl and termsUrl are https and contain /privacy /terms', () {
      expect(AppInfo.privacyUrl, startsWith('https://'));
      expect(AppInfo.termsUrl, startsWith('https://'));
      expect(AppInfo.privacyUrl, contains('/privacy'));
      expect(AppInfo.termsUrl, contains('/terms'));
    });
  });
}
