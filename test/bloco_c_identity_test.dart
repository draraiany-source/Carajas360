import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/constants/app_constants.dart';
import 'package:carajas_360/firebase_options.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/services/payment_gateway.dart';

void main() {
  test('identidade visível é Carajás 360', () {
    expect(AppInfo.name, 'Carajás 360');
    expect(AppInfo.supportEmail.contains('servicoconecta.com.br'), isTrue);
    expect(AppInfo.privacyEmail.contains('servicoconecta.com.br'), isTrue);
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
    expect(DefaultFirebaseOptions.android.storageBucket,
        'carajas360-a17c5.appspot.com');
    expect(DefaultFirebaseOptions.web.authDomain,
        'carajas360-a17c5.firebaseapp.com');
    expect(DefaultFirebaseOptions.android.apiKey.contains('COLE_SUA'), isTrue);
    expect(DefaultFirebaseOptions.ios.apiKey.contains('COLE_SUA'), isTrue);
    expect(DefaultFirebaseOptions.web.apiKey.contains('COLE_SUA'), isTrue);
  });

  test('PaymentService expõe o contrato de gateway', () {
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.pix), isTrue);
    expect(PaymentService.needsDedicatedScreen(PaymentMethod.wallet), isFalse);
    expect(PaymentMethod.wallet.label.contains('Carajás 360'), isTrue);
    expect(PlanTier.values.map((e) => e.name),
        containsAll(['free', 'professional', 'premium', 'corporate']));
  });
}
