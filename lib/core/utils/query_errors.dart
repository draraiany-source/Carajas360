import 'package:cloud_firestore/cloud_firestore.dart';

/// Mensagem amigável para falhas de consulta. Nunca substitui a falha
/// por dados fictícios: a UI mostra o erro com opção de tentar de novo.
String friendlyQueryError(Object? error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'failed-precondition':
        return 'Consulta indisponível no momento (índice do banco pendente). '
            'Tente novamente em alguns minutos.';
      case 'permission-denied':
        return 'Você não tem permissão para ver estes dados.';
      case 'unavailable':
        return 'Sem conexão com o servidor. Verifique a internet.';
      case 'unauthenticated':
        return 'Sua sessão expirou. Entre novamente.';
    }
  }
  return 'Não foi possível carregar. Tente novamente.';
}
