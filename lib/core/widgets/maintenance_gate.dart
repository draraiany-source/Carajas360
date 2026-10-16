import 'package:flutter/material.dart';
import '../../shared/services/firebase_service.dart';
import '../auth/access_control.dart';
import '../constants/app_constants.dart';
import '../navigation/app_navigation.dart';
import '../theme/app_colors.dart';

/// Modo manutenção ligado em config/platform?
bool maintenanceActive(Map<String, dynamic>? config) =>
    config?['maintenanceMode'] == true;

/// Modo manutenção (config/platform.maintenanceMode): usuários comuns veem
/// [MaintenanceScreen] no lugar do app; administradores continuam usando,
/// com um aviso fixo. O login fica fora do bloqueio (rota própria).
class MaintenanceGate extends StatefulWidget {
  final Widget child;

  /// Injeções para testes (padrão: Firestore e perfil do usuário logado).
  final Stream<Map<String, dynamic>>? config;
  final Future<bool> Function()? isAdmin;
  final String? Function()? currentUid;
  const MaintenanceGate(
      {super.key,
      required this.child,
      this.config,
      this.isAdmin,
      this.currentUid});

  @override
  State<MaintenanceGate> createState() => _MaintenanceGateState();
}

class _MaintenanceGateState extends State<MaintenanceGate> {
  late final Stream<Map<String, dynamic>> _config =
      widget.config ?? FS.platformConfigStream();
  Future<bool>? _admin;
  String? _adminUid;

  String? get _uid => (widget.currentUid ?? () => AuthService.uid)();

  Future<bool> _isAdmin() {
    final uid = _uid;
    if (uid == null) return Future.value(false);
    if (_admin == null || _adminUid != uid) {
      _adminUid = uid;
      _admin =
          (widget.isAdmin ?? AccessControl.isAdmin)().catchError((_) => false);
    }
    return _admin!;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: _config,
        builder: (context, snap) {
          // Sem leitura da configuração (offline/erro): não bloqueia; o
          // servidor continua recusando as operações se estiver em manutenção.
          if (!maintenanceActive(snap.data)) return widget.child;
          final cfg = snap.data!;
          return FutureBuilder<bool>(
            future: _isAdmin(),
            builder: (context, a) {
              if (a.connectionState != ConnectionState.done) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (a.data == true) {
                return Column(children: [
                  Material(
                    color: AppColors.error,
                    child: SafeArea(
                      bottom: false,
                      child: Semantics(
                        liveRegion: true,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: Row(children: [
                            Icon(Icons.build_rounded,
                                color: Colors.white, size: 16),
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
                  ),
                  Expanded(
                      child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: widget.child)),
                ]);
              }
              return MaintenanceScreen(
                message: (cfg['maintenanceMessage'] as String?)?.trim(),
                supportEmail: (cfg['supportEmail'] as String?)?.trim(),
                supportPhone: (cfg['supportPhone'] as String?)?.trim(),
                signedIn: _uid != null,
                onRetry: () => setState(() => _admin = null),
              );
            },
          );
        },
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

  Future<void> _logout(BuildContext context) async {
    SessionGuard.instance.markExplicitSignOut();
    await AuthService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil(Routes.login, (_) => false);
    }
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
                const Text('🛠️', style: TextStyle(fontSize: 56)),
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
                      onPressed: () =>
                          Navigator.of(context).pushNamed(Routes.login),
                      child: const Text('Entrar')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
