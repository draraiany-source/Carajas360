import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../shared/services/firebase_service.dart';
import '../auth/access_control.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigation.dart';
import '../theme/app_colors.dart';

/// Modo manutenção ligado em config/platform?
bool maintenanceActive(Map<String, dynamic>? config) =>
    config?['maintenanceMode'] == true;

/// Rotas que ficam fora do bloqueio (abertura e autenticação).
const maintenanceExemptRoutes = {
  Routes.splash,
  Routes.onboarding,
  Routes.login,
  Routes.register,
};

/// Acompanha a página do topo do navegador e indica se ela está fora do
/// bloqueio de manutenção ([maintenanceExemptRoutes]). Diálogos e folhas
/// não contam: só [PageRoute].
class MaintenanceRouteObserver extends NavigatorObserver {
  final Set<String> exemptRoutes;
  MaintenanceRouteObserver({this.exemptRoutes = maintenanceExemptRoutes});

  /// true enquanto o topo é splash/login/cadastro (ou ainda não há rota).
  final ValueNotifier<bool> exempt = ValueNotifier<bool>(true);
  final List<Route<dynamic>> _pages = [];

  void _update() {
    final top = _pages.isEmpty ? null : _pages.last;
    exempt.value = top == null || exemptRoutes.contains(top.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _pages.add(route);
    _update();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _update();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.remove(route);
    _update();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _pages.indexOf(oldRoute);
    if (newRoute is PageRoute) {
      if (i >= 0) {
        _pages[i] = newRoute;
      } else {
        _pages.add(newRoute);
      }
    } else if (i >= 0) {
      _pages.removeAt(i);
    }
    _update();
  }
}

/// Modo manutenção (config/platform.maintenanceMode): usuários comuns veem
/// [MaintenanceScreen] no lugar do app; administradores continuam usando,
/// com um aviso fixo. No app, envolve o navegador inteiro (MaterialApp.builder)
/// e libera só as rotas de autenticação ([exempt]).
class MaintenanceGate extends StatefulWidget {
  final Widget child;

  /// true = rota atual fora do bloqueio (ver [MaintenanceRouteObserver]).
  final ValueListenable<bool>? exempt;

  /// Injeções para testes (padrão: Firestore e perfil do usuário logado).
  final Stream<Map<String, dynamic>>? config;
  final Future<bool> Function()? isAdmin;
  final String? Function()? currentUid;

  /// Sem resposta da configuração nesse prazo, libera (offline não bloqueia).
  final Duration configTimeout;
  const MaintenanceGate(
      {super.key,
      required this.child,
      this.exempt,
      this.config,
      this.isAdmin,
      this.currentUid,
      this.configTimeout = const Duration(seconds: 6)});

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _timeout;
  Map<String, dynamic>? _cfg;
  bool _loaded = false;
  Future<bool>? _admin;
  String? _adminUid;
  bool? _adminResult;

  String? get _uid {
    try {
      return (widget.currentUid ?? () => AuthService.uid)();
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.exempt?.addListener(_onRoute);
    try {
      _sub = (widget.config ?? FS.platformConfigStream()).listen(
          (c) => _setConfig(c),
          // Sem leitura da configuração (offline/erro): não bloqueia; o
          // servidor continua recusando as operações se estiver em manutenção.
          onError: (_) => _setConfig(_cfg));
    } catch (_) {
      _loaded = true;
    }
    if (!_loaded) {
      _timeout = Timer(widget.configTimeout, () {
        if (mounted && !_loaded) setState(() => _loaded = true);
      });
    }
  }

  void _setConfig(Map<String, dynamic>? c) {
    if (!mounted) return;
    _timeout?.cancel();
    setState(() {
      _cfg = c;
      _loaded = true;
    });
  }

  void _onRoute() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MaintenanceGate old) {
    super.didUpdateWidget(old);
    if (old.exempt != widget.exempt) {
      old.exempt?.removeListener(_onRoute);
      widget.exempt?.addListener(_onRoute);
    }
  }

  @override
  void dispose() {
    widget.exempt?.removeListener(_onRoute);
    _sub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  /// null = ainda verificando. Visitante nunca é admin (sem consulta).
  bool? _isAdmin(String? uid) {
    if (uid == null) return false;
    if (_admin == null || _adminUid != uid) {
      _adminUid = uid;
      _adminResult = null;
      final f =
          (widget.isAdmin ?? AccessControl.isAdmin)().catchError((_) => false);
      _admin = f;
      f.then((v) {
        if (mounted && identical(_admin, f)) setState(() => _adminResult = v);
      });
    }
    return _adminResult;
  }

  @override
  Widget build(BuildContext context) {
    final exempt = widget.exempt?.value ?? false;
    final active = !exempt && maintenanceActive(_cfg);
    final uid = _uid;
    final admin = active ? _isAdmin(uid) : null;
    final loading = !exempt && (!_loaded || (active && admin == null));
    final blocked = !loading && active && admin == false;
    final banner = !loading && active && admin == true;
    final hidden = loading || blocked;
    // Estrutura fixa: o filho (navegador/MainNav) não perde o estado quando
    // o aviso ou o bloqueio aparecem/somem.
    return Column(children: [
      banner ? const _AdminMaintenanceBanner() : const SizedBox.shrink(),
      Expanded(
        child: Stack(fit: StackFit.expand, children: [
          Offstage(
            offstage: hidden,
            child: TickerMode(
              enabled: !hidden,
              child: MediaQuery.removePadding(
                  context: context, removeTop: banner, child: widget.child),
            ),
          ),
          if (loading)
            const Material(child: Center(child: CircularProgressIndicator())),
          if (blocked)
            MaintenanceScreen(
              message: (_cfg?['maintenanceMessage'] as String?)?.trim(),
              supportEmail: (_cfg?['supportEmail'] as String?)?.trim(),
              supportPhone: (_cfg?['supportPhone'] as String?)?.trim(),
              signedIn: uid != null,
              onRetry: () => setState(() => _admin = null),
            ),
        ]),
      ),
    ]);
  }
}

class _AdminMaintenanceBanner extends StatelessWidget {
  const _AdminMaintenanceBanner();

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.error,
        child: SafeArea(
          bottom: false,
          child: Semantics(
            liveRegion: true,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                Icon(Icons.build_rounded, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Modo manutenção ativo',
                        key: Key('maintenance-banner'),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700))),
              ]),
            ),
          ),
        ),
      );
}

class MaintenanceScreen extends StatelessWidget {
  final String? message, supportEmail, supportPhone;
  final bool signedIn;
  final VoidCallback onRetry;
  const MaintenanceScreen(
      {super.key,
      this.message,
      this.supportEmail,
      this.supportPhone,
      required this.signedIn,
      required this.onRetry});

  // No app a tela fica acima do navegador (MaterialApp.builder): usa o raiz.
  static NavigatorState? _nav(BuildContext context) =>
      Navigator.maybeOf(context) ?? rootNavigatorKey.currentState;

  Future<void> _logout(BuildContext context) async {
    SessionGuard.instance.markExplicitSignOut();
    final nav = _nav(context);
    await AuthService.signOut();
    nav?.pushNamedAndRemoveUntil(Routes.login, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final contacts = [
      if (supportEmail != null && supportEmail!.isNotEmpty) supportEmail!,
      if (supportPhone != null && supportPhone!.isNotEmpty) supportPhone!,
    ];
    return Scaffold(
      key: const Key('maintenance-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const ExcludeSemantics(
                    child: Text('🛠️', style: TextStyle(fontSize: 56))),
                const SizedBox(height: 16),
                Text('Estamos em manutenção',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                    message == null || message!.isEmpty
                        ? 'O ${AppInfo.name} está passando por uma manutenção rápida. Tente novamente em alguns minutos.'
                        : message!,
                    textAlign: TextAlign.center),
                if (contacts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Contato: ${contacts.join(' · ')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                    onPressed: onRetry, child: const Text('Tentar novamente')),
                const SizedBox(height: 8),
                if (signedIn)
                  TextButton(
                      onPressed: () => _logout(context),
                      child: const Text('Sair da conta'))
                else
                  // Administrador entra para operar durante a manutenção.
                  TextButton(
                      onPressed: () => _nav(context)?.pushNamed(Routes.login),
                      child: const Text('Entrar')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
