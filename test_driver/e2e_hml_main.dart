// Harness de E2E web da etapa de homologação (somente dev/emulador). Build:
//   flutter build web --profile --no-web-resources-cdn \
//     --dart-define=APP_ENV=dev -t test_driver/e2e_hml_main.dart
// Uso: ?email=..&pass=..&screen=tickets|gate|providerHome
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/core/utils/firebase_bootstrap.dart';
import 'package:servico_conecta/core/widgets/maintenance_gate.dart';
import 'package:servico_conecta/features/provider/provider_home_screen.dart';
import 'package:servico_conecta/features/support/tickets_screens.dart';

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
  final Widget home = switch (q['screen']) {
    'gate' => const MaintenanceGate(child: Scaffold(body: Center(child: Text('APP LIBERADO')))),
    'providerHome' => const ProviderHomeScreen(),
    _ => const MyTicketsScreen(),
  };
  runApp(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    navigatorKey: rootNavigatorKey,
    home: home,
    onGenerateRoute: (s) => MaterialPageRoute(
        settings: s, builder: (_) => Scaffold(body: Center(child: Text('DESTINO ${s.name}')))),
  ));
}
