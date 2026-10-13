// Harness de E2E web de Saúde e Locação (somente dev/emulador). Build:
//   flutter build web --profile --no-web-resources-cdn \
//     --dart-define=APP_ENV=dev -t test_driver/e2e_schedule_main.dart
// Uso: ?email=..&pass=..&screen=health|appts|rental&provider=..&catalogId=..&rental=..
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/core/utils/firebase_bootstrap.dart';
import 'package:servico_conecta/features/health/health_booking.dart';
import 'package:servico_conecta/features/rental/rental_screen.dart';
import 'package:servico_conecta/shared/models/models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await FirebaseBootstrap.initialize();
  final q = Uri.base.queryParameters;
  await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  if (q['email'] != null) {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: q['email']!, password: q['pass'] ?? '');
    } catch (e) {
      debugPrint('login E2E: $e');
    }
  }
  Widget home;
  switch (q['screen']) {
    case 'appts':
      home = const AppointmentsScreen();
    case 'rental':
      final d = await FirebaseFirestore.instance.collection('rentals').doc(q['rental']).get();
      home = RentalDetailScreen(rental: RentalModel.fromMap(d.id, d.data()!));
    case 'bookings':
      home = const MyBookingsScreen();
    default:
      home = HealthBookingScreen(
          providerId: q['provider'] ?? '', providerName: 'Dra. Ana E2E', catalogId: q['catalogId'] ?? '', serviceName: 'Cardiologia');
  }
  runApp(MaterialApp(theme: AppTheme.light, debugShowCheckedModeBanner: false, home: home));
}
