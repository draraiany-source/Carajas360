import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../core/constants/app_constants.dart';
import '../navigation/app_navigation.dart';

/// Leva ao login guardando a rota atual para voltar a ela depois.
Future<void> loginAndResume(BuildContext context) async {
  final s = ModalRoute.of(context)?.settings;
  if (s?.name != null) await AuthResume.set(s!.name!, s.arguments);
  if (context.mounted) await Navigator.pushNamed(context, Routes.login);
}

/// Autorização de rotas/telas sensíveis (claims + perfil).
abstract final class AccessControl {
  static Future<bool> isAdmin() async {
    final user = AuthService.current;
    if (user == null) return false;
    try {
      final token = await user.getIdTokenResult();
      final claims = token.claims ?? const <String, dynamic>{};
      if (claims['admin'] == true || claims['role'] == 'admin') {
        return true;
      }
    } on FirebaseAuthException {
      return false;
    }
    final profile = await FS.getUser();
    // Mesmo critério das regras: claim ou users.type == 'admin'.
    return profile?.type == UserType.admin;
  }
}

class AdminGate extends StatelessWidget {
  final Widget child;
  const AdminGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) loginAndResume(context);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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

class RequireAuth extends StatelessWidget {
  final Widget child;
  final String title;
  const RequireAuth({super.key, required this.child, this.title = 'Área protegida'});

  @override
  Widget build(BuildContext context) {
    if (AuthService.isAuth) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Faça login para continuar.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => loginAndResume(context),
              child: const Text('Entrar'),
            ),
          ]),
        ),
      ),
    );
  }
}
