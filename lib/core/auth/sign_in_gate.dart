import 'package:flutter/material.dart';

import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../constants/app_constants.dart';

/// Argumento de [Routes.login]: ao autenticar, volta para a tela de origem
/// em vez de recriar a pilha (preserva busca, filtros e perfil abertos).
const loginPopOnSuccessArg = 'popOnSuccess';

/// Garante sessão antes de uma ação. Retorna `true` se o usuário já está
/// ou acabou de ficar autenticado, mantendo a tela atual na pilha.
Future<bool> ensureSignedIn(BuildContext context, {String? message}) async {
  if (AuthService.uid != null) return true;
  if (message != null) snack(context, message);
  await Navigator.pushNamed(context, Routes.login,
      arguments: {loginPopOnSuccessArg: true});
  return AuthService.uid != null;
}
