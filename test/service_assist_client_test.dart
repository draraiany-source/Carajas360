import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/catalog/homolog_catalog.dart';
import 'package:carajas_360/core/services/service_matching.dart';
import 'package:carajas_360/shared/models/models.dart';

void main() {
  group('ServiceMatching (pedido assistido)', () {
    test('nao inventa profissionais fora do pool real', () {
      final pool = HomologCatalog.providers(category: 'eletricista');
      final ranked = ServiceMatching.rank(
        candidates: pool,
        categoryId: 'eletricista',
        city: 'Canaa dos Carajas',
      );
      for (final m in ranked) {
        expect(m.provider.categories.contains('eletricista'), isTrue);
      }
    });

    test('categoria sem candidatos retorna lista vazia', () {
      final ranked = ServiceMatching.rank(
        candidates: const <ProviderModel>[],
        categoryId: 'eletricista',
      );
      expect(ranked, isEmpty);
    });

    test('filtra categoria incompativel', () {
      final pool = HomologCatalog.providers();
      final ranked = ServiceMatching.rank(
        candidates: pool,
        categoryId: 'categoria_inexistente_xyz',
      );
      expect(ranked, isEmpty);
    });
  });
}
