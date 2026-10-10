import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/catalog/catalog.dart';
import 'package:servico_conecta/core/catalog/catalog_selection.dart';
import 'package:servico_conecta/core/catalog/catalog_service.dart';
import 'package:servico_conecta/core/catalog/catalog_widgets.dart';

import 'catalog_test.dart' show seedCatalog;

Widget _app(Widget child, {Size size = const Size(390, 844)}) => MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(home: Scaffold(body: SizedBox.fromSize(size: size, child: child))));

void main() {
  final catalog = seedCatalog();

  group('CatalogBuilder: estados explícitos', () {
    testWidgets('carregando', (t) async {
      final src = ValueNotifier(CatalogState.initial);
      await t.pumpWidget(_app(CatalogBuilder(source: src, builder: (_, __) => const Text('OK'))));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    testWidgets('erro mostra mensagem e "Tentar novamente" (sem dados fictícios)', (t) async {
      var retried = 0;
      final src = ValueNotifier(CatalogState(catalog: Catalog.empty, error: Exception('falha')));
      await t.pumpWidget(_app(CatalogBuilder(
          source: src, onRetry: () => retried++, builder: (_, __) => const Text('OK'))));
      expect(find.text('Catálogo indisponível'), findsOneWidget);
      expect(find.text('OK'), findsNothing);
      await t.tap(find.text('Tentar novamente'));
      expect(retried, 1);
      // Após retry com sucesso, o conteúdo aparece.
      src.value = CatalogState(catalog: catalog);
      await t.pump();
      expect(find.text('OK'), findsOneWidget);
    });

    testWidgets('vazio = catálogo não configurado', (t) async {
      final src = ValueNotifier(CatalogState(catalog: Catalog.empty));
      await t.pumpWidget(_app(CatalogBuilder(source: src, builder: (_, __) => const Text('OK'))));
      expect(find.text('Catálogo não configurado'), findsOneWidget);
    });

    testWidgets('offline: cache identificado', (t) async {
      final src = ValueNotifier(CatalogState(catalog: catalog, fromCache: true));
      await t.pumpWidget(_app(CatalogBuilder(source: src, builder: (_, __) => const Text('OK'))));
      expect(find.text('OK'), findsOneWidget);
      expect(find.textContaining('Offline: exibindo o catálogo salvo'), findsOneWidget);
    });
  });

  group('CatalogChipSelector', () {
    testWidgets('trocar categoria limpa grupo e serviço', (t) async {
      var sel = CatalogSelection.none.selectService(catalog, 'svc_freios');
      await t.pumpWidget(_app(StatefulBuilder(
          builder: (_, set) => CatalogChipSelector(
              catalog: catalog, selection: sel, onChanged: (s) => set(() => sel = s)))));
      expect(find.textContaining('Freios'), findsOneWidget);
      final jur = find.textContaining('Jurídico e Contabilidade');
      await t.scrollUntilVisible(jur, 150,
          scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(jur);
      await t.pumpAndSettle();
      await t.tap(jur);
      await t.pump();
      expect(sel, const CatalogSelection(categoryId: 'cat_juridico_contabil'));
      expect(find.textContaining('Freios'), findsNothing);
      expect(find.textContaining('Advogado'), findsOneWidget);
    }, skip: false);

    testWidgets('item desativado não aparece para seleção', (t) async {
      final inactive = seedCatalog(inactive: {'cat_automoveis': false});
      await t.pumpWidget(_app(CatalogChipSelector(
          catalog: inactive, selection: CatalogSelection.none, onChanged: (_) {})));
      expect(find.textContaining('Automóveis'), findsNothing);
      expect(find.textContaining('Casa e Reformas'), findsOneWidget);
    });

    for (final size in const [Size(360, 740), Size(768, 1024), Size(1280, 800)]) {
      testWidgets('responsivo em ${size.width.toInt()}px sem overflow', (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_app(
            SingleChildScrollView(
              child: Column(children: [
                CatalogChipSelector(
                    catalog: catalog,
                    selection: CatalogSelection.none.selectService(catalog, 'svc_ar_limpeza'),
                    onChanged: (_) {}),
                CatalogDropdownSelector(
                    catalog: catalog,
                    selection: CatalogSelection.none.selectService(catalog, 'svc_ar_limpeza'),
                    onChanged: (_) {}),
              ]),
            ),
            size: size));
        expect(t.takeException(), isNull);
      });
    }
  });

  group('CatalogMultiSelect (prestador)', () {
    testWidgets('preserva especialidade antiga/desativada e não adiciona nada sozinho', (t) async {
      var selected = <String>{'id_antigo_x', 'eletricista'};
      await t.pumpWidget(_app(StatefulBuilder(
          builder: (_, set) => SingleChildScrollView(
                child: CatalogMultiSelect(
                    catalog: catalog,
                    selected: selected,
                    onChanged: (v) => set(() => selected = v)),
              ))));
      expect(find.text('id_antigo_x'), findsOneWidget);
      expect(selected, {'id_antigo_x', 'eletricista'});
      await t.tap(find.text('Casa e Reformas'));
      await t.pumpAndSettle();
      await t.tap(find.text('🔧  Encanador'));
      await t.pump();
      expect(selected, {'id_antigo_x', 'eletricista', 'encanador'});
    });
  });

  test('CatalogState.copyWith mantém dados ao registrar erro', () {
    final s = CatalogState(catalog: catalog).copyWith(error: Exception('x'));
    expect(s.hasData, isTrue);
    expect(s.error, isNotNull);
    expect(kReleaseMode, isFalse);
  });
}
