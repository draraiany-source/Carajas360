import 'package:flutter/material.dart';

import '../../shared/services/firebase_service.dart';
import '../constants/app_constants.dart';

/// Entrada "Cadastrar profissional": visitante cria conta já como prestador;
/// usuário logado segue para o envio de documentos do prestador.
void openProviderEntry(BuildContext context) {
  if (AuthService.uid == null) {
    Navigator.pushNamed(context, Routes.register,
        arguments: {'asProvider': true});
  } else {
    Navigator.pushNamed(context, Routes.providerOnboarding,
        arguments: {'allowBack': true});
  }
}
