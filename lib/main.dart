import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/brand.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shared/widgets/micro_interactions.dart';
import 'core/constants/app_constants.dart';
import 'core/utils/firebase_bootstrap.dart';
import 'shared/services/firebase_service.dart';
import 'shared/models/models.dart' show ProviderModel, UserModel;

import 'package:carajas_360/features/auth/auth_screen.dart';
import 'package:carajas_360/features/home/home_screen.dart'
    show ServicesHubScreen;
import 'package:carajas_360/features/home/carajas_home_screen.dart';
import 'package:carajas_360/features/resolve/resolve_screen.dart';
import 'package:carajas_360/features/resolve/assisted_request_screen.dart';
import 'package:carajas_360/features/services/service_marketplace_screen.dart';
import 'package:carajas_360/features/search/universal_search_screen.dart';
import 'package:carajas_360/features/monetization/opportunities_screen.dart';
import 'package:carajas_360/features/monetization/monetization_screens.dart';
import 'package:carajas_360/core/catalog/taxonomy_repository.dart';
import 'package:carajas_360/features/chat/chat_screen.dart';
import 'package:carajas_360/features/chat/chat_inbox_screen.dart';
import 'package:carajas_360/features/gps/gps_screen.dart';
import 'package:carajas_360/features/wallet/wallet_screen.dart';
import 'package:carajas_360/features/health/health_screen.dart';
import 'package:carajas_360/features/marketplace/marketplace_screen.dart';
import 'package:carajas_360/features/marketplace/store_screen.dart';
import 'package:carajas_360/features/rental/rental_screen.dart';
import 'package:carajas_360/features/profile/profile_screens.dart';
import 'package:carajas_360/features/support/support_screens.dart';
import 'package:carajas_360/features/ai_assistant/ai_screen.dart';
import 'package:carajas_360/features/ai_assistant/carajas_ia_fab.dart';
import 'package:carajas_360/features/admin/admin_screen.dart';
import 'package:carajas_360/features/company/company_screen.dart';
import 'package:carajas_360/features/orders/orders_screen.dart';
import 'package:carajas_360/features/orders/favorites_screen_ui.dart';
import 'package:carajas_360/features/orders/service_request_flow_screen.dart';
import 'package:carajas_360/shared/widgets/brand_shell.dart';
import 'package:carajas_360/core/modules/platform_modules.dart';
import 'package:carajas_360/features/provider/provider_home_screen.dart';
import 'package:carajas_360/features/provider/provider_profile_screen.dart';
import 'package:carajas_360/core/auth/access_control.dart';
import 'core/auth/dev_bypass_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorWidget.builder = (details) {
    debugPrint('ErrorWidget: ${details.exceptionAsString()}');
    return const Material(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Não foi possível carregar esta tela.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  };
  // setPreferredOrientations é no-op seguro no Web.
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  } catch (_) {}
  await ThemeController.instance.load();

  bool firebaseOk = false;
  try {
    await FirebaseBootstrap.initialize();
    // Placeholders = homologação/demo: UI sem Auth real.
    if (FirebaseBootstrap.hasPlaceholderKeys) {
      debugPrint(
          'Firebase com placeholders — modo demonstração (sem login obrigatório).');
      firebaseOk = false;
    } else {
      try {
        await FirebaseBootstrap.maybeActivateAppCheck();
      } catch (e) {
        debugPrint('App Check: $e');
      }
      try {
        await PushSvc.init();
      } catch (e) {
        debugPrint('PushSvc.init: $e');
      }
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
    }
  } catch (e) {
    debugPrint('Firebase nao configurado — modo demonstracao: $e');
    firebaseOk = false;
  }

  if (DevBypassAuth.enabled) {
    debugPrint(
        'DEV_BYPASS_LOGIN ativo — smoke sem Auth (uid=${DevBypassAuth.uid}). '
        'NÃO usar em produção.');
  }

  runApp(Carajas360App(firebaseOk: firebaseOk));
}

class Carajas360App extends StatelessWidget {
  final bool firebaseOk;
  const Carajas360App({super.key, this.firebaseOk = false});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, themeMode, _) => MaterialApp(
          title: AppInfo.name,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final page = child ?? const SizedBox.shrink();
            if (!DevBypassAuth.enabled) return page;
            return Banner(
              message: 'DEV BYPASS',
              location: BannerLocation.topEnd,
              color: const Color(0xFFE65100),
              child: page,
            );
          },
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: themeMode,
          navigatorObservers: firebaseOk
              ? [
                  FirebaseAnalyticsObserver(
                      analytics: FirebaseAnalytics.instance)
                ]
              : const <NavigatorObserver>[],
          initialRoute: '/',
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name == Routes.admin || name.startsWith('/admin/')) {
              return _route(const AdminGate(child: AdminScreen()));
            }
            switch (settings.name) {
              case Routes.splash:
                // Web/homolog: `/` abre a home sem login (visita).
                return _route(const MainNav());
              case Routes.onboarding:
                return _route(const OnboardingScreen());
              case Routes.login:
                return _route(const LoginScreen());
              case Routes.register:
                final ra = settings.arguments as Map<String, dynamic>?;
                return _route(
                    RegisterScreen(asProvider: ra?['asProvider'] == true));
              case Routes.main:
                return _route(const MainNav());
              case Routes.search:
              case Routes.universalSearch:
                final sa = settings.arguments as Map<String, dynamic>?;
                return _route(UniversalSearchScreen(
                  initialQuery: sa?['q'] as String?,
                  initialCategory: sa?['category'] as String?,
                  initialGroup: sa?['group'] as String?,
                ));
              case Routes.chat:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(RequireAuth(
                  title: 'Chat',
                  subtitle: 'Entre na conta para enviar e ler mensagens.',
                  child: ChatScreen(
                    roomId: a?['roomId'] ?? a?['id'] ?? 'demo',
                    otherName: a?['name'] ?? 'Profissional',
                    otherPhoto: a?['photo'],
                    orderId: a?['orderId'] as String?,
                  ),
                ));
              case Routes.gps:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(GpsScreen(
                    ctxKey: a?['ctx'] ?? 'servico',
                    deliveryId: a?['deliveryId'],
                    orderId: a?['orderId']));
              case Routes.wallet:
                return _route(const RequireAuth(
                    title: 'Carteira', child: WalletScreen()));
              case Routes.health:
                return _route(const HealthScreen());
              case Routes.marketplace:
                return _route(const MarketplaceScreen());
              case Routes.store:
                return _route(const StoreScreen());
              case Routes.rental:
                final ra = settings.arguments as Map<String, dynamic>?;
                return _route(
                    RentalScreen(initialTab: (ra?['tab'] as int?) ?? 0));
              case Routes.bookings:
                return _route(const RequireAuth(
                    title: 'Reservas', child: MyBookingsScreen()));
              case Routes.stores:
                return _route(const StoresListScreen());
              case Routes.delivery:
                return _route(const DeliveryScreen());
              case Routes.profile:
                return _route(const ProfileScreen());
              case Routes.notifications:
                return _route(const RequireAuth(
                    title: 'Notificações', child: NotificationsScreen()));
              case Routes.reviews:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(RequireAuth(
                  title: 'Avaliar serviço',
                  subtitle: 'Entre na conta para avaliar um pedido concluído.',
                  child: ReviewScreen(
                    orderId: a?['orderId'] ?? 'demo',
                    providerId: a?['providerId'],
                    providerName: a?['providerName'],
                  ),
                ));
              case Routes.support:
                return _route(const RequireAuth(
                    title: 'Suporte', child: SupportScreen()));
              case Routes.coupons:
                return _route(const CouponsScreen());
              case Routes.aiAssistant:
                final aiArgs = settings.arguments as Map<String, dynamic>?;
                // Central visível sem login; o callable exige auth no envio.
                return _route(AiAssistantScreen(
                  initialMessage: aiArgs?['initialMessage'] as String?,
                ));
              case Routes.companyProfile:
                return _route(const RequireAuth(
                    title: 'Empresa', child: CompanyProfileScreen()));
              case Routes.favorites:
                return _route(const RequireAuth(
                    title: 'Favoritos', child: FavoritesScreen()));
              case Routes.myOrders:
                return _route(const RequireAuth(
                    title: 'Meus pedidos', child: MyOrdersScreen()));
              case Routes.requestService:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(RequireAuth(
                  title: 'Solicitar serviço',
                  child: QuoteRequestFlowScreen(
                    providerId: a?['providerId'] ?? '',
                    providerName: a?['providerName'] ?? 'Profissional',
                    category: a?['category'] ?? '',
                    initialDescription: a?['description'] as String?,
                    initialPreferredDate: a?['preferredDate'] as DateTime?,
                    initialPeriod: a?['period'] as String?,
                    remoteOnly: a?['remoteOnly'] == true,
                    providerColor: a?['providerColor'] ?? AppColors.primary,
                  ),
                ));
              case Routes.providerProfile:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(ProviderProfileScreen(
                  providerId: a?['providerId'] as String? ?? '',
                  initial: a?['provider'] as ProviderModel?,
                ));
              case Routes.providerHome:
                return _route(const RequireAuth(
                    title: 'Área do prestador', child: ProviderHomeScreen()));
              case Routes.providerOnboarding:
                final oa = settings.arguments as Map<String, dynamic>?;
                return _route(ProviderOnboardingScreen(
                    allowBack: oa?['allowBack'] == true));
              case Routes.servicesHub:
                return _route(const ServicesHubScreen());
              case Routes.serviceMarketplace:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(ServiceMarketplaceScreen(
                  verticalId: a?['verticalId'] as String?,
                  categoryId: a?['category'] as String?,
                ));
              case Routes.resolve:
                return _route(const ResolveScreen());
              case Routes.assistedRequest:
                return _route(const RequireAuth(
                    title: 'Pedido assistido', child: AssistedRequestScreen()));
              case Routes.resolveDetail:
                final a = settings.arguments as Map<String, dynamic>?;
                final rid = a?['id'] as String? ?? '';
                if (rid.isEmpty) {
                  return _route(const RequireAuth(
                      title: 'Meus Resolve', child: MyResolveScreen()));
                }
                return _route(RequireAuth(
                    title: 'Pedido Resolve',
                    child: ResolveDetailScreen(requestId: rid)));
              case Routes.resolveOpportunities:
                return _route(const RequireAuth(
                    title: 'Oportunidades', child: OpportunitiesHubScreen()));
              case Routes.creditPackages:
                return _route(const RequireAuth(
                    title: 'Creditos', child: CreditPackagesScreen()));
              case Routes.carajasPro:
                return _route(const RequireAuth(
                    title: 'Carajas PRO', child: CarajasProScreen()));
              case Routes.highlightsBuy:
                return _route(const RequireAuth(
                    title: 'Destaques', child: HighlightsBuyScreen()));
              case Routes.disputeHelp:
                final a = settings.arguments as Map<String, dynamic>?;
                return _route(RequireAuth(
                    title: 'Ajuda',
                    child: DisputeHelpScreen(
                      orderId: a?['orderId'] as String?,
                      paymentId: a?['paymentId'] as String?,
                    )));
              case Routes.myResolve:
                return _route(const RequireAuth(
                    title: 'Meus Resolve', child: MyResolveScreen()));
              case Routes.chatInbox:
                return _route(const RequireAuth(
                    title: 'Mensagens', child: ChatInboxScreen()));
              default:
                // Rota desconhecida: volta ao app principal (evita splash “presa”).
                return _route(const MainNav());
            }
          },
        ),
      );

  PageRoute _route(Widget page) => FadeSlidePageRoute(page: page);
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
  String _city = RegionCities.defaultCity;
  UserModel? _user;
  StreamSubscription? _taxonomySub;
  StreamSubscription? _userSub;

  static const _destinations = [
    (Icons.home_rounded, 'Início'),
    (Icons.explore_rounded, 'Explorar'),
    (Icons.receipt_long_rounded, 'Pedidos'),
    (Icons.chat_bubble_outline_rounded, 'Mensagens'),
    (Icons.person_outline_rounded, 'Perfil'),
  ];

  final List<Widget?> _tabs = List<Widget?>.filled(5, null);

  BrandNavDest? get _navActive => switch (_idx) {
        0 => BrandNavDest.home,
        1 => BrandNavDest.explore,
        2 => BrandNavDest.orders,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    _taxonomySub = FS.serviceTaxonomyStream().listen((docs) {
      if (TaxonomyRepository.shouldPreferSeed) return;
      TaxonomyRepository.applyDocs(docs);
      if (mounted) setState(() {});
    }, onError: (_) {});
    _bindUser();
  }

  void _bindUser() {
    _userSub?.cancel();
    final uid = AuthService.uid;
    if (uid == null) {
      _user = null;
      return;
    }
    _userSub = FS.userStream(uid).listen((u) {
      if (!mounted) return;
      setState(() {
        _user = u;
        final c = u?.city?.trim();
        if (c != null && c.isNotEmpty) _city = c;
      });
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _taxonomySub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }

  void _onBrandNav(BrandNavDest dest) {
    switch (dest) {
      case BrandNavDest.home:
        setState(() => _idx = 0);
      case BrandNavDest.explore:
        setState(() => _idx = 1);
      case BrandNavDest.orders:
        setState(() => _idx = 2);
      case BrandNavDest.favorites:
        Navigator.pushNamed(context, Routes.favorites);
    }
  }

  void _pickCity() {
    final cities = [...RegionCities.priority, ...RegionCities.nearby];
    showModalBottomSheet(
      context: context,
      backgroundColor: Brand.surface(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: ListView(
          children: [
            const ListTile(
                title: Text('Sua localização',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            for (final c in cities)
              ListTile(
                title: Text(c),
                trailing: c == _city
                    ? const Icon(Icons.check_rounded, color: Brand.green)
                    : null,
                onTap: () {
                  setState(() => _city = c);
                  final uid = AuthService.uid;
                  if (uid != null) {
                    FS.updateUser({'city': c}).catchError((_) {});
                  }
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    return _tabs[i] ??= switch (i) {
      0 => HomeScreen(onSelectTab: (t) => setState(() => _idx = t)),
      1 => const UniversalSearchScreen(),
      2 => const MyOrdersScreen(),
      3 => const ChatInboxScreen(),
      4 => const ProfileScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final body = IndexedStack(
        index: _idx, children: [for (var i = 0; i < 5; i++) _tab(i)]);

    if (wide) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Brand.background,
        floatingActionButton: const CarajasIaFab(embedPanel: true),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: Column(
          children: [
            BrandTopNav(
              active: _navActive,
              city: _city,
              user: _user,
              onCity: _pickCity,
              onNav: _onBrandNav,
              onProfile: () => setState(() => _idx = 4),
              onNotifications: () =>
                  Navigator.pushNamed(context, Routes.notifications),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: CarajasIaFab(embedPanel: false),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Semantics(
        container: true,
        label: 'Navegação principal',
        child: Container(
          decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.white,
              border: Border(
                  top: BorderSide(
                      color:
                          isDark ? AppColors.darkDivider : AppColors.divider)),
              boxShadow: [
                BoxShadow(
                    color:
                        AppColors.navy.withValues(alpha: isDark ? 0.35 : 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -8))
              ]),
          child: SafeArea(
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    _navItem(
                        i, _destinations[i].$1, _destinations[i].$2, scheme),
                ]),
          )),
        ),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label, ColorScheme scheme) {
    final sel = _idx == i;
    final isDark = scheme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      selected: sel ? true : null,
      label: label,
      excludeSemantics: true,
      onTap: () => setState(() => _idx = i),
      child: GestureDetector(
        onTap: () => setState(() => _idx = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: sel
                  ? (isDark
                      ? Brand.gold.withValues(alpha: 0.16)
                      : Brand.greenLight)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: sel ? 24 : 22,
                color: sel
                    ? (isDark ? Brand.gold : Brand.green)
                    : (isDark ? AppColors.darkTextLow : AppColors.textLight)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                    color: sel
                        ? (isDark ? Brand.gold : Brand.green)
                        : (isDark
                            ? AppColors.darkTextLow
                            : AppColors.textLight))),
          ]),
        ),
      ),
    );
  }
}
