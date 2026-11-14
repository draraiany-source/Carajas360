import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/constants/app_constants.dart';
import 'dev_bypass_auth.dart';
import 'sign_in_gate.dart';

/// Autorização de rotas/telas sensíveis (claims + perfil).
abstract final class AccessControl {
  static bool _adminAccessLogged = false;

  static Future<bool> isAdmin() async {
    // Mock de smoke nunca é admin (sem claims, type=client).
    if (DevBypassAuth.enabled && AuthService.current == null) return false;
    final user = AuthService.current;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      if (claims['admin'] == true || claims['role'] == 'admin') {
        await _logAdminLoginOnce();
        return true;
      }
    } on FirebaseAuthException {
      return false;
    }
    // Papel admin no documento (claim é a fonte preferencial).
    // adminRole sozinho NÃO libera o painel.
    final profile = await FS.getUser();
    final ok = profile?.type == UserType.admin;
    if (ok) await _logAdminLoginOnce();
    return ok;
  }

  static Future<void> _logAdminLoginOnce() async {
    if (_adminAccessLogged) return;
    final uid = AuthService.uid;
    if (uid == null) return;
    _adminAccessLogged = true;
    try {
      await FS.logAdminAction('admin_login', target: uid);
    } catch (_) {}
  }
}

class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAuth) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: EmptyState(
          emoji: '🔐',
          title: 'Faça login',
          subtitle: 'O painel administrativo exige uma conta com permissão.',
          actionLabel: 'Entrar',
          onAction: () => Navigator.pushNamed(context, Routes.login),
        ),
      );
    }
    return FutureBuilder<bool>(
      future: AccessControl.isAdmin(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == true) return child;
        return Scaffold(
          appBar: AppBar(title: const Text('Acesso negado')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('⛔', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('Você não tem permissão para abrir o painel admin.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, Routes.main),
                  child: const Text('Voltar ao início'),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class RequireAuth extends StatefulWidget {
  final Widget child;
  final String title;
  final String? subtitle;
  const RequireAuth({
    super.key,
    required this.child,
    this.title = 'Área protegida',
    this.subtitle,
  });

  @override
  State<RequireAuth> createState() => _RequireAuthState();
}

class _RequireAuthState extends State<RequireAuth> {
  Future<void> _signIn() async {
    await ensureSignedIn(context);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.isAuth) return widget.child;
    return Scaffold(
      appBar: CarajasAppBar(title: widget.title, implyLeading: true),
      body: EmptyState(
        emoji: '🔐',
        title: 'Faça login para continuar',
        subtitle: widget.subtitle ??
            'Esta área precisa de uma conta. Seus dados não são exibidos sem autenticação.',
        actionLabel: 'Entrar',
        onAction: _signIn,
      ),
    );
  }
}
