import 'package:flutter/services.dart' show appFlavor;

/// Ambientes do Carajás 360. Sempre explícitos:
///
///   dev  → emuladores locais (projeto `demo-carajas360`), sem nuvem.
///   hml  → homologação (projeto Firebase próprio, pagamentos sandbox).
///   prod → produção (projeto `servicoconecta`; IDs preservados).
///
/// Selecione com `--dart-define=APP_ENV=hml` (ou
/// `--dart-define-from-file=config/env/hml.json`) e, no Android, com o
/// flavor correspondente (`--flavor hml`).
enum AppEnvironment { dev, hml, prod }

abstract final class AppEnv {
  /// Valor bruto do --dart-define (vazio se não informado).
  static const rawDefine = String.fromEnvironment('APP_ENV');

  /// Dados de demonstração só existem em dev, debug e quando pedidos
  /// explicitamente com --dart-define=DEMO_DATA=true.
  static const demoDataRequested =
      bool.fromEnvironment('DEMO_DATA', defaultValue: false);

  static AppEnvironment? parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'hml':
      case 'homolog':
      case 'staging':
        return AppEnvironment.hml;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
    }
    return null;
  }

  /// Ambiente resolvido: APP_ENV > flavor nativo > dev.
  static AppEnvironment get current =>
      resolve(define: rawDefine, flavor: appFlavor);

  static AppEnvironment resolve({String? define, String? flavor}) =>
      parse(define) ?? parse(flavor) ?? AppEnvironment.dev;

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isHml => current == AppEnvironment.hml;
  static bool get isProd => current == AppEnvironment.prod;

  static String get label => labelOf(current);

  static String labelOf(AppEnvironment e) => switch (e) {
        AppEnvironment.dev => 'Desenvolvimento',
        AppEnvironment.hml => 'Homologação',
        AppEnvironment.prod => 'Produção',
      };

  /// Verifica a coerência da configuração. Retorna a lista de problemas;
  /// vazia quando o app pode operar. Pura (testável).
  static List<String> configurationProblems({
    required bool releaseMode,
    required String define,
    required String? flavor,
    required bool firebasePlaceholder,
    required bool useEmulator,
  }) {
    final problems = <String>[];
    final fromDefine = parse(define);
    final fromFlavor = parse(flavor);
    final env = fromDefine ?? fromFlavor ?? AppEnvironment.dev;

    if (define.isNotEmpty && fromDefine == null) {
      problems.add('APP_ENV inválido: "$define" (use dev, hml ou prod).');
    }
    if (fromDefine != null && fromFlavor != null && fromDefine != fromFlavor) {
      problems.add('APP_ENV (${fromDefine.name}) diferente do flavor '
          '(${fromFlavor.name}).');
    }
    if (releaseMode) {
      if (fromDefine == null && fromFlavor == null) {
        problems.add('Build de release sem ambiente explícito '
            '(defina APP_ENV=hml ou APP_ENV=prod).');
      }
      if (env == AppEnvironment.dev) {
        problems.add('Ambiente dev não pode ser usado em release.');
      }
      if (useEmulator) {
        problems.add('Emuladores não podem ser usados em release.');
      }
    }
    if (env != AppEnvironment.dev && firebasePlaceholder && !useEmulator) {
      problems.add('Configuração Firebase de ${labelOf(env)} ausente '
          '(firebase_options_${env.name}.dart ainda com placeholders).');
    }
    return problems;
  }
}
