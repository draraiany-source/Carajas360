import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carajas_360/core/catalog/homolog_catalog.dart';
import 'package:carajas_360/core/constants/app_constants.dart';
import 'package:carajas_360/core/search/provider_search.dart';
import 'package:carajas_360/features/search/universal_search_screen.dart';

Widget _app(Widget home) => MaterialApp(
      home: home,
      onGenerateRoute: (s) => MaterialPageRoute(
        settings: s,
        builder: (_) => Scaffold(
          appBar: AppBar(),
          body: Text('route:${s.name}'),
        ),
      ),
    );

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _reveal(WidgetTester tester, Finder f) async {
  final vertical = find.byWidgetPredicate((w) =>
      w is Scrollable && w.axisDirection == AxisDirection.down);
  await tester.scrollUntilVisible(f, 200, scrollable: vertical.first);
  await tester.pump(const Duration(milliseconds: 100));
}

int _casaCount() => ProviderSearch.apply(
        HomologCatalog.providers(),
        ProviderSearchCriteria(scopeIds: ProviderSearch.idsForGroup('Casa')))
    .length;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ambiente de teste usa o catálogo de demonstração isolado', () {
    expect(HomologCatalog.enabled, isTrue);
    expect(HomologCatalog.isDemoProvider('h1'), isTrue);
    expect(HomologCatalog.isDemoProvider('uid-real-28-caracteres-xxxxx'),
        isFalse);
  });

  for (final size in const [Size(390, 844), Size(1280, 900)]) {
    testWidgets('categoria ativa e contagem sem overflow em ${size.width}px',
        (tester) async {
      await _setSize(tester, size);
      await tester.pumpWidget(
          _app(const UniversalSearchScreen(initialGroup: 'Casa')));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      final n = _casaCount();
      expect(n, greaterThan(0));
      expect(
          find.textContaining(
              '$n profissionais encontrados em Construção e Reforma'),
          findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('categoria selecionada')),
          findsWidgets);
    });
  }

  testWidgets('tocar categoria filtra e "Todas" restaura', (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(_app(const UniversalSearchScreen()));
    await _settle(tester);
    final total = ProviderSearch.apply(
            HomologCatalog.providers(), const ProviderSearchCriteria())
        .length;
    expect(find.textContaining('$total profissionais encontrados'),
        findsOneWidget);

    await tester.tap(find.text('Construção e Reforma'));
    await _settle(tester);
    expect(
        find.textContaining(
            '${_casaCount()} profissionais encontrados em Construção e Reforma'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Construção e Reforma, categoria selecionada'),
        findsOneWidget);

    await tester.tap(find.text('Todas').first);
    await _settle(tester);
    expect(find.textContaining('$total profissionais encontrados'),
        findsOneWidget);
  });

  testWidgets('busca sem resultados mostra estado vazio', (tester) async {
    await _setSize(tester, const Size(390, 844));
    await tester.pumpWidget(_app(const UniversalSearchScreen(
        initialQuery: 'zzzqqqxxx', initialGroup: 'Casa')));
    await _settle(tester);
    expect(find.textContaining('0 profissionais encontrados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar do perfil preserva categoria e contagem',
      (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(
        _app(const UniversalSearchScreen(initialGroup: 'Casa')));
    await _settle(tester);
    final label = '${_casaCount()} profissionais encontrados em '
        'Construção e Reforma';
    expect(find.textContaining(label), findsOneWidget);

    final verPerfil = find.text('Ver perfil').first;
    await _reveal(tester, verPerfil);
    await tester.tap(verPerfil);
    await _settle(tester);
    expect(find.text('route:${Routes.providerProfile}'), findsOneWidget);

    Navigator.of(tester.element(find.text('route:${Routes.providerProfile}')))
        .pop();
    await _settle(tester);
    expect(find.textContaining(label), findsOneWidget);
  });

  testWidgets('favoritar como visitante pede login e não abre o perfil',
      (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(
        _app(const UniversalSearchScreen(initialGroup: 'Casa')));
    await _settle(tester);

    final fav = find.byTooltip('Favoritar').first;
    await _reveal(tester, fav);
    await tester.tap(fav);
    await _settle(tester);
    expect(find.text('route:${Routes.login}'), findsOneWidget);
    expect(find.text('route:${Routes.providerProfile}'), findsNothing);
  });

  testWidgets('pedir orçamento abre a solicitação do profissional',
      (tester) async {
    await _setSize(tester, const Size(1280, 900));
    await tester.pumpWidget(
        _app(const UniversalSearchScreen(initialGroup: 'Casa')));
    await _settle(tester);

    final pedir = find.text('Pedir orçamento').first;
    await _reveal(tester, pedir);
    await tester.tap(pedir);
    await _settle(tester);
    expect(find.text('route:${Routes.requestService}'), findsOneWidget);
  });
}
