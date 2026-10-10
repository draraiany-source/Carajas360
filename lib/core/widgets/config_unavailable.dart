import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_env.dart';
import '../constants/app_constants.dart';

/// Tela exibida quando a configuração do ambiente é inválida ou o
/// Firebase não inicia. Não oferece nenhuma ação que aparente operação
/// válida (login, pedidos, pagamentos).
class ConfigUnavailableApp extends StatelessWidget {
  final List<String> problems;
  const ConfigUnavailableApp({super.key, required this.problems});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        home: ConfigUnavailableScreen(problems: problems),
      );
}

class ConfigUnavailableScreen extends StatelessWidget {
  final List<String> problems;
  const ConfigUnavailableScreen({super.key, required this.problems});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 64, color: Colors.redAccent,
                        semanticLabel: 'Serviço indisponível'),
                    const SizedBox(height: 16),
                    const Text('Serviço temporariamente indisponível',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                        '${AppInfo.name} não pôde ser iniciado neste '
                        'ambiente (${AppEnv.label}). Nenhuma operação foi '
                        'realizada. Tente novamente mais tarde.',
                        textAlign: TextAlign.center),
                    // Detalhes técnicos apenas fora de release.
                    if (!kReleaseMode && problems.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text(problems.map((p) => '• $p').join('\n'),
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
