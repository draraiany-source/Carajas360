import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/config/app_env.dart';
import 'package:servico_conecta/core/utils/demo_data.dart';

void main() {
  group('AppEnv', () {
    test('resolve: APP_ENV > flavor > dev', () {
      expect(AppEnv.resolve(define: 'hml', flavor: 'prod'), AppEnvironment.hml);
      expect(AppEnv.resolve(define: '', flavor: 'prod'), AppEnvironment.prod);
      expect(AppEnv.resolve(define: '', flavor: null), AppEnvironment.dev);
      expect(AppEnv.parse('staging'), AppEnvironment.hml);
      expect(AppEnv.parse('xyz'), isNull);
    });

    List<String> problems({
      bool release = false,
      String define = '',
      String? flavor,
      bool placeholder = false,
      bool emulator = false,
    }) =>
        AppEnv.configurationProblems(
            releaseMode: release,
            define: define,
            flavor: flavor,
            firebasePlaceholder: placeholder,
            useEmulator: emulator);

    test('dev em debug com emulador é válido', () {
      expect(problems(define: 'dev', placeholder: true, emulator: true),
          isEmpty);
    });

    test('release exige ambiente explícito e nunca dev/emulador', () {
      expect(problems(release: true), isNotEmpty);
      expect(problems(release: true, define: 'dev'), isNotEmpty);
      expect(problems(release: true, define: 'hml', emulator: true),
          isNotEmpty);
      expect(problems(release: true, define: 'prod'), isEmpty);
    });

    test('hml/prod com placeholders mostram indisponibilidade', () {
      expect(problems(define: 'hml', placeholder: true), isNotEmpty);
      expect(problems(release: true, define: 'prod', placeholder: true),
          isNotEmpty);
    });

    test('APP_ENV divergente do flavor é recusado', () {
      expect(problems(define: 'prod', flavor: 'hml'), isNotEmpty);
      expect(problems(define: 'hml', flavor: 'hml'), isEmpty);
    });

    test('APP_ENV inválido é recusado', () {
      expect(problems(define: 'producao-x'), isNotEmpty);
    });
  });

  test('dados de demonstração desligados por padrão', () {
    // Sem --dart-define=DEMO_DATA=true nunca há lista fictícia.
    expect(DemoData.allow, isFalse);
    expect(DemoData.orEmpty<int>(null, [1, 2]), isEmpty);
    expect(DemoData.orEmpty<int>([3], [1, 2]), [3]);
  });
}
