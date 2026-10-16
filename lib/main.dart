import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shared/widgets/micro_interactions.dart';
import 'core/constants/app_constants.dart';
import 'core/config/app_env.dart';
import 'core/utils/firebase_bootstrap.dart';
import 'core/widgets/config_unavailable.dart';
import 'core/widgets/maintenance_gate.dart';
import 'shared/services/firebase_service.dart';

import 'package:servico_conecta/features/auth/auth_screen.dart';
import 'package:servico_conecta/features/home/home_screen.dart'
    show SearchScreen, ServicesHubScreen;
import 'package:servico_conecta/features/home/carajas_home_screen.dart';
import 'package:servico_conecta/features/resolve/resolve_screen.dart';
import 'package:servico_conecta/features/chat/chat_screen.dart';
import 'package:servico_conecta/features/chat/chat_inbox_screen.dart';
import 'package:servico_conecta/features/gps/gps_screen.dart';
import 'package:servico_conecta/features/wallet/wallet_screen.dart';
import 'package:servico_conecta/features/health/health_screen.dart';
import 'package:servico_conecta/features/marketplace/marketplace_screen.dart';
import 'package:servico_conecta/features/marketplace/store_screen.dart';
import 'package:servico_conecta/features/rental/rental_screen.dart';
import 'package:servico_conecta/features/profile/profile_screens.dart';
import 'package:servico_conecta/features/support/support_screens.dart';
import 'package:servico_conecta/features/support/tickets_screens.dart';
import 'package:servico_conecta/features/ai_assistant/ai_screen.dart';
import 'package:servico_conecta/features/admin/admin_screen.dart';
import 'package:servico_conecta/features/company/company_screen.dart';
import 'package:servico_conecta/features/orders/orders_screen.dart';
import 'package:servico_conecta/features/provider/provider_home_screen.dart';
import 'package:servico_conecta/core/auth/access_control.dart';
import 'package:servico_conecta/features/checkout/cart_service.dart';
import 'package:servico_conecta/core/navigation/app_navigation.dart';
import 'package:servico_conecta/shared/widgets/adaptive_nav.dart';
import 'package:servico_conecta/features/health/health_booking.dart';
import 'package:servico_conecta/features/provider/provider_profile_screen.dart';
import 'package:servico_conecta/features/checkout/checkout_screen.dart';
import 'package:servico_conecta/features/checkout/market_order_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // setPreferredOrientations é no-op seguro no Web.
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (_) {}
  await ThemeController.instance.load();

  bool firebaseOk = false;
  List<String> configProblems = const [];
  try {
    await FirebaseBootstrap.initialize();
    // FCM/Analytics podem falhar nos emuladores — nao bloqueiam auth.
    try {
      await PushSvc.init();
    } catch (e) {
      debugPrint('PushSvc.init: $e');
    }
    // Crashlytics nao e suportado no Web — usa handlers locais nesse caso.
    if (!kIsWeb) {
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } else {
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('FlutterError: ${details.exceptionAsString()}');
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught: $error\n$stack');
        return true;
      };
    }
    firebaseOk = true;
  } on AppConfigurationException catch (e) {
    configProblems = e.problems;
  } catch (e) {
    configProblems = ['Falha ao iniciar o Firebase: $e'];
  }

  // Sem configuração válida o app NÃO simula operação: mostra
  // indisponibilidade explícita (em qualquer ambiente).
  if (!firebaseOk) {
    debugPrint('Configuração indisponível:\n${configProblems.join('\n')}');
    runApp(ConfigUnavailableApp(problems: configProblems));
    return;
  }
  // Carrinho persistente (aparelho + conta); não bloqueia a abertura.
  CartService.instance.start();
  SessionGuard.instance.start();
  runApp(const ServicoConectaApp(firebaseOk: true));
}

RouteSettings? _routeSettings;

/// Rota do topo para o modo manutenção (único para o app inteiro).
final _maintenanceRoutes = MaintenanceRouteObserver();

class ServicoConectaApp extends StatelessWidget {
  final bool firebaseOk;
  const ServicoConectaApp({super.key, this.firebaseOk = false});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, themeMode, _) => MaterialApp(
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          // Faixa de ambiente fora de produção (evita confundir dados).
          // Aviso de conexão em todas as telas. Modo manutenção cobre todas
          // as rotas, exceto abertura/login/cadastro.
          builder: (context, child) {
            final app = OfflineBanner(
                child: MaintenanceGate(
                    exempt: _maintenanceRoutes.exempt, child: child!));
            return AppEnv.isProd
                ? app
                : Banner(
                    message: AppEnv.isHml ? 'HML' : 'DEV',
                    location: BannerLocation.topEnd,
                    color: AppEnv.isHml ? Colors.deepOrange : Colors.purple,
                    child: app);
          },
          navigatorObservers: [
            _maintenanceRoutes,
            if (firebaseOk)
              FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          initialRoute: Routes.splash,
          onGenerateRoute: (settings) {
            // Nome/argumentos ficam na rota (retomada após login e sessão expirada).
            _routeSettings = settings;
            switch (settings.name) {
              case Routes.splash:
                return _route(SplashScreen(firebaseReady: firebaseOk));
              case Routes.onboarding:
                return _route(const OnboardingScreen());
              case Routes.login:
                return _route(const LoginScreen());
              case Routes.register:
                return _route(const RegisterScreen());
              case Routes.main:
                // Modo manutenção: aplicado no builder (todas as rotas).
                return _route(const MainNav());
              case Routes.search:
                final sa = settings.arguments as Map<String, dynamic>?;
                // 'category' mantido por compatibilidade (IDs antigos).
                return _route(SearchScreen(
                    initialCatalogId:
                        (sa?['catalogId'] ?? sa?['category']) as String?));
              case Routes.chat:
                final a = settings.arguments as Map<String, dynamic>?;
                final roomId = (a?['roomId'] ?? a?['id'] ?? '').toString();
                // Sem sala definida: abre a caixa de conversas.
                if (roomId.isEmpty) return _route(const ChatInboxScreen());
                return _route(ChatScreen(
                  roomId: roomId,
                  otherName: a?['name'] ?? 'Profissional',
                  otherPhoto: a?['photo'],
                ));
              case Routes.gps:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(GpsScreen(
                    ctxKey: a?['ctx'] ?? 'servico',
                    deliveryId: a?['deliveryId'],
                    orderId: a?['orderId']));
              case Routes.wallet:
                return _route(const RequireAuth(title: 'Carteira', child: WalletScreen()));
              case Routes.admin:
                return _route(const AdminGate(child: AdminScreen()));
              case Routes.health:
                final ha = settings.arguments as Map<String, dynamic>?;
                return _route(HealthScreen(
                    initialCatalogId: ha?['catalogId'] as String?));
              case Routes.marketplace:
                return _route(const MarketplaceScreen());
              case Routes.store:
                return _route(const StoreScreen());
              case Routes.rental:
                final ra = settings.arguments as Map<String, dynamic>?;
                return _route(
                    RentalScreen(initialTab: (ra?['tab'] as int?) ?? 0));
              case Routes.bookings:
                return _route(const RequireAuth(title: 'Reservas', child: MyBookingsScreen()));
              case Routes.stores:
                return _route(const StoresListScreen());
              case Routes.delivery:
                return _route(const DeliveryScreen());
              case Routes.profile:
                return _route(const ProfileScreen());
              case Routes.notifications:
                return _route(const NotificationsScreen());
              case Routes.reviews:
                final a = settings.arguments as Map<String, dynamic>?;
                final reviewOrderId = (a?['orderId'] ?? '').toString();
                // Avaliação exige pedido real.
                if (reviewOrderId.isEmpty) {
                  return _route(const MyOrdersScreen());
                }
                return _route(ReviewScreen(
                    orderId: reviewOrderId,
                    providerId: a?['providerId'],
                    providerName: a?['providerName']));
              case Routes.support:
                return _route(const RequireAuth(title: 'Suporte', child: SupportScreen()));
              case Routes.supportTickets:
                return _route(const RequireAuth(title: 'Meus chamados', child: MyTicketsScreen()));
              case Routes.coupons:
                return _route(const CouponsScreen());
              case Routes.aiAssistant:
                return _route(const RequireAuth(title: 'Assistente', child: AiAssistantScreen()));
              case Routes.companyProfile:
                return _route(const RequireAuth(title: 'Empresa', child: CompanyProfileScreen()));
              case Routes.favorites:
                return _route(const FavoritesScreen());
              case Routes.myOrders:
                return _route(const MyOrdersScreen());
              case Routes.cart:
                return _route(const CartScreen());
              case Routes.appointments:
                return _route(const RequireAuth(
                    title: 'Agendamentos', child: AppointmentsScreen()));
              case Routes.marketOrder:
                final mo = settings.arguments as Map<String, dynamic>?;
                final moId = '${mo?['id'] ?? ''}';
                if (moId.isEmpty) {
                  return _route(const RequireAuth(
                      title: 'Pedidos', child: MyMarketOrdersScreen()));
                }
                return _route(RequireAuth(
                    title: 'Pedido', child: MarketOrderScreen(orderId: moId)));
              case Routes.providerProfile:
                final pp = settings.arguments as Map<String, dynamic>?;
                final ppId = '${pp?['providerId'] ?? ''}';
                if (ppId.isEmpty) return _route(const MainNav());
                return _route(ProviderProfileScreen(
                    providerId: ppId,
                    category: pp?['category'] as String?));
              case Routes.marketOrders:
                return _route(const RequireAuth(
                    title: 'Pedidos', child: MyMarketOrdersScreen()));
              case Routes.storeOrders:
                return _route(const RequireAuth(
                    title: 'Pedidos da loja', child: StoreOrdersScreen()));
              case Routes.requestService:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(RequestServiceScreen(
                  providerId: a?['providerId'] ?? '',
                  providerName: a?['providerName'] ?? 'Profissional',
                  category: a?['category'] ?? '',
                  providerColor: a?['providerColor'] ?? AppColors.primary,
                ));
              case Routes.providerHome:
                return _route(const ProviderHomeScreen());
              case Routes.providerOnboarding:
                return _route(const ProviderOnboardingScreen());
              case Routes.servicesHub:
                return _route(const ServicesHubScreen());
              case Routes.resolve:
                final ra2 = settings.arguments as Map<String, dynamic>?;
                return _route(ResolveScreen(
                    initialCatalogId: ra2?['catalogId'] as String?));
              case Routes.resolveDetail:
                final a = settings.arguments as Map<String, dynamic>?;
                final rid = a?['id'] as String? ?? '';
                if (rid.isEmpty) {
                  return _route(const MyResolveScreen());
                }
                return _route(ResolveDetailScreen(requestId: rid));
              case Routes.resolveOpportunities:
                return _route(const ResolveOpportunitiesScreen());
              case Routes.myResolve:
                return _route(const MyResolveScreen());
              case Routes.chatInbox:
                return _route(const ChatInboxScreen());
              default:
                // Rota desconhecida: volta ao app principal (evita splash “presa”).
                return _route(const MainNav());
            }
          },
        ),
      );

  PageRoute _route(Widget page) =>
      FadeSlidePageRoute(page: page, settings: _routeSettings);
}

// ─────────────────────────────────────────────────────────────
// MAIN NAVIGATION — Bottom NavBar
// ─────────────────────────────────────────────────────────────
class MainNav extends StatefulWidget {
  const MainNav({super.key});
  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _idx = 0;

  final _screens = const [
    HomeScreen(),
    SearchScreen(),
    MyOrdersScreen(),
    ChatInboxScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AdaptiveNavScaffold(
      destinations: const [
        NavDest(Icons.home_rounded, 'Início'),
        NavDest(Icons.explore_rounded, 'Explorar'),
        NavDest(Icons.receipt_long_rounded, 'Pedidos'),
        NavDest(Icons.chat_bubble_outline_rounded, 'Mensagens'),
        NavDest(Icons.person_outline_rounded, 'Perfil'),
      ],
      index: _idx,
      onSelect: (i) => setState(() => _idx = i),
      body: IndexedStack(index: _idx, children: _screens),
      bottomBar: (context) => Semantics(
        container: true,
        label: 'Navegação principal',
        child: Container(
          decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              border: Border(
                  top: BorderSide(
                      color: isDark ? AppColors.darkDivider : AppColors.divider)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.navy.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -8))
              ]),
          child: SafeArea(
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navItem(0, Icons.home_rounded, 'Início', scheme),
                  _navItem(1, Icons.explore_rounded, 'Explorar', scheme),
                  _navItem(2, Icons.receipt_long_rounded, 'Pedidos', scheme),
                  _navItem(3, Icons.chat_bubble_outline_rounded, 'Mensagens',
                      scheme),
                  _navItem(4, Icons.person_outline_rounded, 'Perfil', scheme),
                ]),
          )),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, ColorScheme scheme) {
    final sel = _idx == i;
    final isDark = scheme.brightness == Brightness.dark;
    // Expanded: 5 itens cabem em telas de 320px sem overflow.
    return Expanded(
        child: Semantics(
      button: true,
      selected: sel,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _idx = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
              color: sel
                  ? (isDark
                      ? AppColors.primaryLight.withValues(alpha: 0.18)
                      : AppColors.primarySoft)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: sel ? 24 : 22,
                color: sel
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : (isDark ? AppColors.darkTextLow : AppColors.textLight)),
            const SizedBox(height: 3),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel
                        ? (isDark ? AppColors.primaryLight : AppColors.primary)
                        : (isDark
                            ? AppColors.darkTextLow
                            : AppColors.textLight))),
          ]),
        ),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────
// SPLASH SCREEN wrapper (imported from auth_screen.dart)
// ─────────────────────────────────────────────────────────────
