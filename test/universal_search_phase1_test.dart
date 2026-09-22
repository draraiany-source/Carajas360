import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/catalog/service_taxonomy.dart';
import 'package:carajas_360/core/catalog/taxonomy_repository.dart';
import 'package:carajas_360/core/search/universal_search.dart';
import 'package:carajas_360/shared/models/models.dart';

void main() {
  group('UniversalSearch', () {
    test('finds service freios by typo-ish query', () {
      final hits = UniversalSearch.search(query: 'freos');
      expect(hits.any((h) => h.kind == UniversalHitKind.service), isTrue);
      expect(
        hits.any((h) =>
            h.title.toLowerCase().contains('freio') ||
            (h.categoryId ?? '').contains('freios')),
        isTrue,
      );
    });

    test('finds vertical Automoveis', () {
      final hits = UniversalSearch.search(query: 'automoveis');
      expect(hits.any((h) => h.kind == UniversalHitKind.vertical), isTrue);
    });

    test('finds provider by name', () {
      final providers = [
        ProviderModel(
          id: 'x',
          userId: 'x',
          name: 'Joao Guincho Express',
          categories: const ['guincho'],
          city: 'Parauapebas',
          createdAt: DateTime(2025),
        ),
      ];
      final hits = UniversalSearch.search(
        query: 'guincho',
        providers: providers,
      );
      expect(hits.any((h) => h.kind == UniversalHitKind.provider), isTrue);
      expect(hits.any((h) => h.kind == UniversalHitKind.service), isTrue);
    });

    test('finds company', () {
      final companies = [
        CompanyModel(
          id: 'c1',
          ownerId: 'c1',
          name: 'Auto Center Carajas',
          cnpj: '1',
          categories: const ['mecanica_geral'],
          city: 'Parauapebas',
          createdAt: DateTime(2025),
        ),
      ];
      final hits = UniversalSearch.search(
        query: 'auto center',
        companies: companies,
      );
      expect(hits.any((h) => h.kind == UniversalHitKind.company), isTrue);
    });

    test('suggestions return titles', () {
      final s = UniversalSearch.suggest(query: 'diaris');
      expect(s, isNotEmpty);
    });

    test('normalize strips accents', () {
      expect(UniversalSearch.normalize('Canaã'), 'canaa');
    });
  });

  group('TaxonomyRepository', () {
    tearDown(() {
      ServiceTaxonomy.clearRemoteOverlay();
    });

    test('parseVerticalDocs builds overlay', () {
      final docs = ServiceTaxonomy.verticals.take(2).map((v) => v.toMap()).toList();
      final parsed = TaxonomyRepository.parseVerticalDocs(docs);
      expect(parsed.length, 2);
      TaxonomyRepository.applyDocs(docs);
      expect(ServiceTaxonomy.verticals.length, 2);
      ServiceTaxonomy.clearRemoteOverlay();
      expect(ServiceTaxonomy.verticals.length, greaterThan(2));
    });

    test('patchServiceActive toggles without losing tree', () {
      final before = ServiceTaxonomy.verticals.length;
      final svc = ServiceTaxonomy.serviceByCategoryId('guincho');
      expect(svc, isNotNull);
      TaxonomyRepository.patchServiceActive(svc!.id, false);
      expect(ServiceTaxonomy.serviceById(svc.id)?.active, isFalse);
      TaxonomyRepository.patchServiceActive(svc.id, true);
      expect(ServiceTaxonomy.serviceById(svc.id)?.active, isTrue);
      expect(ServiceTaxonomy.verticals.length, before);
      ServiceTaxonomy.clearRemoteOverlay();
    });
  });

  group('Filter regression Phase 1', () {
    test('juridico vertical has no casa services', () {
      final jur = ServiceTaxonomy.verticalById('juridico');
      expect(jur, isNotNull);
      final cats = jur!.groups
          .expand((g) => g.services)
          .map((s) => s.categoryId)
          .toSet();
      expect(cats.contains('eletricista'), isFalse);
      expect(cats.contains('advogado'), isTrue);
    });

    test('automoveis has mecanica and emergencia', () {
      final auto = ServiceTaxonomy.verticalById('automoveis');
      expect(auto, isNotNull);
      final gids = auto!.groups.map((g) => g.id).toSet();
      expect(gids.contains('mecanica'), isTrue);
      expect(gids.contains('emergencia_auto'), isTrue);
    });
  });
}
