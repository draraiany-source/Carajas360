import 'package:flutter/material.dart';
import 'package:servico_conecta/core/theme/app_theme.dart';
import 'package:servico_conecta/features/home/provider_profile_screen.dart';
import 'package:servico_conecta/features/provider/provider_home_screen.dart';
import 'package:servico_conecta/shared/widgets/c360_nav.dart';
import 'package:servico_conecta/shared/widgets/c360_shell.dart';

/// Entrada só para capturar as telas redesenhadas no navegador.
/// Não entra no fluxo de produção.
void main() {
  final page = Uri.base.queryParameters['page'] ?? 'home';
  if (page != 'provider' && page != 'service' && page != 'profile') {
    C360Memory.next = switch (page) {
      'explore' => C360Dest.explore,
      'professionals' => C360Dest.professionals,
      'orders' => C360Dest.orders,
      'messages' => C360Dest.messages,
      'favorites' => C360Dest.favorites,
      'account' => C360Dest.account,
      _ => C360Dest.home,
    };
  }
  runApp(PreviewApp(page: page));
}

class PreviewApp extends StatelessWidget {
  final String page;
  const PreviewApp({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final Widget home = switch (page) {
      'provider' => const C360Shell(singlePage: ProviderHomeScreen()),
      'service' => const C360Shell(
          singlePage: ProviderProfileScreen(
            providerId: '',
            providerName: 'Profissional',
            category: 'eletricista',
            style: ProviderDetailStyle.service,
          ),
        ),
      'profile' => const C360Shell(
          singlePage: ProviderProfileScreen(
            providerId: '',
            providerName: 'Profissional',
            category: 'eletricista',
            style: ProviderDetailStyle.profile,
          ),
        ),
      _ => const C360Shell(),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}
