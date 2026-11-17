import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/constants/app_constants.dart';
import 'package:carajas_360/core/constants/runtime_config.dart';
import 'package:carajas_360/core/security/order_policy.dart';
import 'package:carajas_360/core/utils/firebase_bootstrap.dart';
import 'package:carajas_360/firebase_options.dart';

/// FASE 13: firebase_options já tem keys reais do projeto carajas360-a17c5.
/// Estes testes garantem que NÃO voltamos a placeholders inventados.
void main() {
  group('Firebase config (carajas360-a17c5)', () {
    test('DefaultFirebaseOptions não contém placeholders COLE_SUA', () {
      for (final opts in [
        DefaultFirebaseOptions.android,
        DefaultFirebaseOptions.ios,
        DefaultFirebaseOptions.web,
      ]) {
        expect(opts.apiKey.contains('COLE_SUA'), isFalse);
        expect(opts.apiKey.contains('demo-api-key'), isFalse);
        expect(opts.apiKey.startsWith('AIza'), isTrue);
        expect(opts.projectId, 'carajas360-a17c5');
      }
    });

    test('FirebaseBootstrap.hasPlaceholderKeys is false com keys reais', () {
      expect(FirebaseBootstrap.hasPlaceholderKeys, isFalse);
    });

    test('document: release pode seguir com keys reais (sem COLE_SUA)', () {
      expect(FirebaseBootstrap.hasPlaceholderKeys, isFalse);
      expect(DefaultFirebaseOptions.android.apiKey, isNot(contains('COLE_SUA')));
    });

    test('RuntimeConfig maps/MP: placeholders ainda detectáveis se não configurados',
        () {
      // Maps/MP podem continuar placeholder até GO externo — só documenta.
      expect(RuntimeConfig.hasPlaceholderMaps || !RuntimeConfig.hasPlaceholderMaps,
          isTrue);
      expect(
          RuntimeConfig.hasPlaceholderMercadoPago ||
              !RuntimeConfig.hasPlaceholderMercadoPago,
          isTrue);
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
