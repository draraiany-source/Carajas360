import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/auth/dev_bypass_auth.dart';
import 'package:carajas_360/core/constants/app_constants.dart';
import 'package:carajas_360/core/constants/runtime_config.dart';
import 'package:carajas_360/firebase_options.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/services/payment_gateway.dart';

void main() {
  test('identidade visível é Carajás 360', () {
    expect(AppInfo.name, 'Carajás 360');
    expect(AppInfo.supportEmail.contains('carajas360.com.br'), isTrue);
    expect(AppInfo.privacyEmail.contains('carajas360.com.br'), isTrue);
  });

  test('IDs técnicos migrados (autorização da Raiany)', () {
    expect(AppInfo.dartPackage, 'carajas_360');
    expect(AppInfo.applicationId, 'br.com.carajas360');
    expect(AppInfo.iosBundleId, 'br.com.carajas360');
    expect(AppInfo.firebaseProjectId, 'carajas360-a17c5');
  });

  test('Firebase options apontam para carajas360-a17c5 sem inventar keys', () {
    expect(DefaultFirebaseOptions.android.projectId, 'carajas360-a17c5');
    expect(DefaultFirebaseOptions.ios.projectId, 'carajas360-a17c5');
    expect(DefaultFirebaseOptions.web.projectId, 'carajas360-a17c5');
    expect(DefaultFirebaseOptions.ios.iosBundleId, 'br.com.carajas360');
    // Bucket moderno (.firebasestorage.app) ou legado (.appspot.com).
    final bucket = DefaultFirebaseOptions.android.storageBucket;
    expect(
      bucket == 'carajas360-a17c5.firebasestorage.app' ||
          bucket == 'carajas360-a17c5.appspot.com',
      isTrue,
      reason: 'storageBucket inesperado: $bucket',
    );
    expect(DefaultFirebaseOptions.web.authDomain,
        'carajas360-a17c5.firebaseapp.com');
    expect(DefaultFirebaseOptions.android.apiKey.contains('COLE_SUA'), isFalse);
    expect(DefaultFirebaseOptions.ios.apiKey.contains('COLE_SUA'), isFalse);
    expect(DefaultFirebaseOptions.web.apiKey.contains('COLE_SUA'), isFalse);
    expect(DefaultFirebaseOptions.android.apiKey.startsWith('AIza'), isTrue);
  });

  test('PaymentService expõe o contrato de gateway', () {
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.pix), isTrue);
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.wallet), isFalse);
    expect(PaymentMethod.wallet.label.contains('Carajás 360'), isTrue);
    expect(PlanTier.values.map((e) => e.name),
        containsAll(['free', 'professional', 'premium', 'corporate']));
  });

  test('DEV_BYPASS_LOGIN default false e mock não é admin', () {
    expect(RuntimeConfig.devBypassLoginDefine, isFalse);
    expect(DevBypassAuth.mockUser.type, UserType.client);
    expect(DevBypassAuth.enabledFor(releaseMode: true, defineOn: true), isFalse);
  });
}
