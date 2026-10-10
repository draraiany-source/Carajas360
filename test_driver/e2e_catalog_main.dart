// Harness de E2E web (somente dev/emulador; não é o app publicado).
// Build: flutter build web --profile --no-web-resources-cdn \
//   --dart-define=APP_ENV=dev -t test_driver/e2e_catalog_main.dart
// Uso: ?screen=hub|search|health
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/core/utils/firebase_bootstrap.dart';
import 'package:servico_conecta/features/health/health_screen.dart';
import 'package:servico_conecta/features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await FirebaseBootstrap.initialize();
  final screen = Uri.base.queryParameters['screen'] ?? 'hub';
  final q = Uri.base.queryParameters['catalogId'];
  runApp(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: switch (screen) {
      'search' => SearchScreen(initialCatalogId: q),
      'health' => const HealthScreen(),
      _ => const ServicesHubScreen(),
    },
    onGenerateRoute: (s) => MaterialPageRoute(
        builder: (_) => s.name == Routes.search
            ? SearchScreen(initialCatalogId: (s.arguments as Map?)?['catalogId'] as String?)
            : Scaffold(body: Center(child: Text('Rota ${s.name}')))),
  ));
}
