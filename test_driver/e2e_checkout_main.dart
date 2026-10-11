// Harness de E2E web do checkout (somente dev/emulador; não é o app
// publicado). Build:
//   flutter build web --profile --no-web-resources-cdn \
//     --dart-define=APP_ENV=dev --dart-define=PAYMENTS_FAKE_TOKENS=true \
//     -t test_driver/e2e_checkout_main.dart
// Uso: ?email=...&pass=...  (login no emulador de Auth)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/core/utils/firebase_bootstrap.dart';
import 'package:servico_conecta/features/checkout/cart_service.dart';
import 'package:servico_conecta/features/checkout/market_order_screen.dart';
import 'package:servico_conecta/features/marketplace/marketplace_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  await FirebaseBootstrap.initialize();
  final q = Uri.base.queryParameters;
  // Login a cada carga (sem persistência): no emulador, restaurar a sessão
  // salva tenta renovar o token fora do emulador. O CARRINHO continua
  // salvo no armazenamento local, que é o que o teste de recarga verifica.
  await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  if (q['email'] != null) {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: q['email']!, password: q['pass'] ?? '');
    } catch (e) {
      debugPrint('login E2E: $e');
    }
  }
  await CartService.instance.start();
  runApp(MaterialApp(
    theme: AppTheme.light,
    debugShowCheckedModeBanner: false,
    home: q['screen'] == 'orders'
        ? const MyMarketOrdersScreen()
        : const MarketplaceScreen(),
  ));
}
