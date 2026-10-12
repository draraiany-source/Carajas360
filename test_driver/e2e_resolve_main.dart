// Harness de E2E web do Resolve (somente dev/emulador; não é o app
// publicado). Build:
//   flutter build web --profile --no-web-resources-cdn \
//     --dart-define=APP_ENV=dev --dart-define=PAYMENTS_FAKE_TOKENS=true \
//     -t test_driver/e2e_resolve_main.dart
// Uso: ?email=..&pass=..&screen=new|detail|opps&catalogId=..&id=..
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/core/utils/firebase_bootstrap.dart';
import 'package:servico_conecta/features/resolve/resolve_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await FirebaseBootstrap.initialize();
  final q = Uri.base.queryParameters;
  // Login a cada carga (o emulador de Auth não renova sessão restaurada).
  await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  if (q['email'] != null) {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: q['email']!, password: q['pass'] ?? '');
    } catch (e) {
      debugPrint('login E2E: $e');
    }
  }
  runApp(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: switch (q['screen']) {
      'detail' => ResolveDetailScreen(requestId: q['id'] ?? ''),
      'opps' => const ResolveOpportunitiesScreen(),
      _ => ResolveScreen(initialCatalogId: q['catalogId']),
    },
    onGenerateRoute: (s) => MaterialPageRoute(
        builder: (_) => s.name == Routes.resolveDetail
            ? ResolveDetailScreen(requestId: '${(s.arguments as Map?)?['id']}')
            : Scaffold(body: Center(child: Text('Rota ${s.name}')))),
  ));
}
