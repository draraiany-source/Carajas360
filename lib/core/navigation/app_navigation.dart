import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Navegador raiz (sessão expirada e destinos de notificação usam fora do
/// contexto de uma tela).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Voltar seguro: se não há para onde voltar (deep link / rota única),
/// vai para o início em vez de deixar tela preta ou cair no splash.
Future<void> safeBack(BuildContext context) async {
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.pop();
  } else {
    nav.pushReplacementNamed(Routes.main);
  }
}

/// Ação pendente para retomar depois do login (qualquer rota protegida).
abstract final class AuthResume {
  static const _key = 'pending_route_v1';

  static Future<void> set(String route, [Object? args]) async {
    try {
      final p = await SharedPreferences.getInstance();
      String raw;
      try {
        raw = jsonEncode({'route': route, if (args is Map) 'args': args});
      } catch (_) {
        // Argumentos não serializáveis: guarda só a rota.
        raw = jsonEncode({'route': route});
      }
      await p.setString(_key, raw);
    } catch (_) {}
  }

  /// Descarta a rota pendente (evita retomar uma tela antiga).
  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }

  /// Lê e consome a rota pendente.
  static Future<({String route, Map<String, dynamic>? args})?> take() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return null;
      await p.remove(_key);
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final route = m['route'] as String?;
      if (route == null || route == Routes.login || route == Routes.splash) return null;
      return (route: route, args: (m['args'] as Map?)?.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Destino ao tocar numa notificação: usa o `link` gravado pelo servidor
/// e, para notificações antigas, o `type`.
({String route, Map<String, dynamic>? args})? notificationTarget(String? type, Map<String, dynamic>? link) {
  final r = link?['route'] as String?;
  final id = link?['id'] as String?;
  switch (r) {
    case 'resolveDetail':
      if (id != null) return (route: Routes.resolveDetail, args: {'id': id});
      return (route: Routes.myResolve, args: null);
    case 'resolveOpportunities':
      return (route: Routes.resolveOpportunities, args: null);
    case 'appointments':
      return (route: Routes.appointments, args: null);
    case 'bookings':
      return (route: Routes.bookings, args: null);
    case 'marketOrder':
      if (id != null) return (route: Routes.marketOrder, args: {'id': id});
      return (route: Routes.marketOrders, args: null);
    case 'storeOrders':
      return (route: Routes.storeOrders, args: null);
    case 'myOrders':
      return (route: Routes.myOrders, args: null);
    case 'supportTickets':
      return (route: Routes.supportTickets, args: null);
    case 'providerOrders':
      // Pedidos recebidos ficam no painel do prestador.
      return (route: Routes.providerHome, args: null);
  }
  return switch (type) {
    'order' => (route: Routes.myOrders, args: null),
    'resolve' => (route: Routes.myResolve, args: null),
    'health' => (route: Routes.appointments, args: null),
    'rental' => (route: Routes.bookings, args: null),
    'market' => (route: Routes.marketOrders, args: null),
    'chat' => (route: Routes.chatInbox, args: null),
    _ => null,
  };
}

/// Sessão expirada: se o usuário estava logado e a sessão cai sem ele
/// ter saído (token revogado, conta desativada, callable "unauthenticated"),
/// leva ao login com aviso e guarda a tela atual para retomar.
class SessionGuard {
  SessionGuard._();
  static final SessionGuard instance = SessionGuard._();

  bool _explicitSignOut = false;
  bool _handling = false;
  String? _lastUid;
  StreamSubscription<User?>? _sub;

  void start() {
    try {
      _lastUid = FirebaseAuth.instance.currentUser?.uid;
      _sub ??= FirebaseAuth.instance.authStateChanges().listen((u) {
        if (u == null && _lastUid != null && !_explicitSignOut) expired();
        if (u != null) _explicitSignOut = false;
        _lastUid = u?.uid;
      });
    } catch (_) {/* Firebase indisponível (testes) */}
  }

  /// Chamar antes de um "Sair" voluntário.
  void markExplicitSignOut() => _explicitSignOut = true;

  /// Desfaz [markExplicitSignOut] quando a saída não aconteceu (ex.: exclusão falhou).
  void clearExplicitSignOut() => _explicitSignOut = false;

  /// Leva ao login preservando a tela atual.
  Future<void> expired([String message = 'Sua sessão expirou. Entre novamente para continuar.']) async {
    final nav = rootNavigatorKey.currentState;
    if (_handling || nav == null) return;
    _handling = true;
    // Captura antes do await (o contexto pode mudar).
    final messenger = ScaffoldMessenger.maybeOf(nav.context);
    try {
      String? current;
      Object? args;
      nav.popUntil((r) {
        current ??= r.settings.name;
        args ??= r.settings.arguments;
        return true;
      });
      if (current != null && current != Routes.login && current != Routes.splash && current != Routes.onboarding) {
        await AuthResume.set(current!, args);
      }
      messenger?.showSnackBar(SnackBar(content: Text(message)));
      // Não aguardar: o Future só completa quando a rota de login sai.
      unawaited(nav.pushNamedAndRemoveUntil(Routes.login, (_) => false));
    } finally {
      _handling = false;
    }
  }

  void dispose() => _sub?.cancel();
}

/// Aviso discreto de conexão: o Firestore indica quando os dados vêm só
/// do cache (sem rede). Não bloqueia o uso; as telas mostram o próprio erro.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  const OfflineBanner({super.key, required this.child});
  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _offline = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    try {
      _sub = FirebaseFirestore.instance
          .collection('catalogMeta')
          .doc('current')
          .snapshots(includeMetadataChanges: true)
          .listen((s) => _set(s.metadata.isFromCache), onError: (_) {});
    } catch (_) {}
  }

  void _set(bool offline) {
    _debounce?.cancel();
    // Evita piscar na abertura (o primeiro snapshot costuma vir do cache).
    _debounce = Timer(Duration(seconds: offline ? 4 : 0), () {
      if (mounted && _offline != offline) setState(() => _offline = offline);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Expanded(child: widget.child),
        if (_offline)
          Material(
            color: const Color(0xFF5A4500),
            child: SafeArea(
              top: false,
              child: Semantics(
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(children: [
                    Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                        child: Text('Sem conexão. Mostrando dados salvos; ações que alteram dados aguardam a rede.',
                            style: TextStyle(color: Colors.white, fontSize: 12))),
                  ]),
                ),
              ),
            ),
          ),
      ]);
}
