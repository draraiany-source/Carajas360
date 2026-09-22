import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/catalog/service_taxonomy.dart';
import 'package:carajas_360/core/services/service_matching.dart';
import 'package:carajas_360/shared/models/models.dart';

void main() {
  group('ServiceTaxonomy', () {
    test('has Automóveis vertical with required groups', () {
      final auto = ServiceTaxonomy.verticalById('automoveis');
      expect(auto, isNotNull);
      final groupIds = auto!.groups.map((g) => g.id).toSet();
      expect(groupIds.contains('auto_eletrica'), isTrue);
      expect(groupIds.contains('funilaria_pintura'), isTrue);
      expect(groupIds.contains('mecanica'), isTrue);
      expect(groupIds.contains('emergencia_auto'), isTrue);
    });

    test('auto elétrica services include bateria and som', () {
      final g = ServiceTaxonomy.groupById('auto_eletrica');
      expect(g, isNotNull);
      final cats = g!.services.map((s) => s.categoryId).toSet();
      expect(cats.contains('bateria_auto'), isTrue);
      expect(cats.contains('som_automotivo'), isTrue);
      expect(cats.contains('ar_condicionado_auto'), isTrue);
    });

    test('serviceByCategoryId resolves questionnaire', () {
      final s = ServiceTaxonomy.serviceByCategoryId('guincho');
      expect(s, isNotNull);
      expect(s!.questions, isNotEmpty);
      expect(s.questions.any((q) => q.id == 'description'), isTrue);
      expect(s.questions.any((q) => q.id == 'vehicle_brand'), isTrue);
    });

    test('juridico and casa are separate verticals', () {
      final jur = ServiceTaxonomy.verticalById('juridico');
      final casa = ServiceTaxonomy.verticalById('casa_reformas');
      expect(jur, isNotNull);
      expect(casa, isNotNull);
      expect(jur!.id == casa!.id, isFalse);
    });

    test('pricing modes are enforced', () {
      final diag = ServiceTaxonomy.serviceByCategoryId('diagnostico_auto');
      expect(diag, isNotNull);
      expect(
        ServiceMatching.pricingAllowed(
            diag!, ServicePricingMode.fixedPrice),
        isTrue,
      );
      expect(
        ServiceMatching.pricingAllowed(
            diag, ServicePricingMode.requestQuote),
        isFalse,
      );
    });
  });

  group('ServiceMatching', () {
    final pool = [
      ProviderModel(
        id: '1',
        userId: '1',
        name: 'Eletricista Casa',
        categories: const ['eletricista'],
        city: 'Canaã dos Carajás',
        rating: 4.9,
        totalReviews: 100,
        verified: true,
        active: true,
        createdAt: DateTime(2025),
      ),
      ProviderModel(
        id: '2',
        userId: '2',
        name: 'Dra. Advogada',
        categories: const ['advogado'],
        city: 'Canaã dos Carajás',
        rating: 5.0,
        totalReviews: 200,
        verified: true,
        active: true,
        createdAt: DateTime(2025),
      ),
      ProviderModel(
        id: '3',
        userId: '3',
        name: 'Guincho Local',
        categories: const ['guincho', 'socorro_automotivo'],
        city: 'Parauapebas',
        rating: 4.6,
        totalReviews: 80,
        verified: true,
        active: true,
        serviceAreas: const ['Parauapebas', 'Canaã dos Carajás'],
        createdAt: DateTime(2025),
      ),
      ProviderModel(
        id: '4',
        userId: '4',
        name: 'Inativo',
        categories: const ['eletricista'],
        city: 'Canaã dos Carajás',
        active: false,
        createdAt: DateTime(2025),
      ),
    ];

    test('never returns eletricista for juridico', () {
      final ranked = ServiceMatching.rank(
        candidates: pool,
        categoryId: 'advogado',
        city: 'Canaã dos Carajás',
      );
      expect(ranked.every((m) => m.provider.categories.contains('advogado')),
          isTrue);
      expect(ranked.any((m) => m.provider.id == '1'), isFalse);
    });

    test('filters inactive providers', () {
      final ranked = ServiceMatching.rank(
        candidates: pool,
        categoryId: 'eletricista',
        city: 'Canaã dos Carajás',
      );
      expect(ranked.any((m) => m.provider.id == '4'), isFalse);
      expect(ranked.any((m) => m.provider.id == '1'), isTrue);
    });

    test('matches guincho in region via serviceAreas', () {
      final ranked = ServiceMatching.rank(
        candidates: pool,
        categoryId: 'guincho',
        city: 'Canaã dos Carajás',
        answers: const {'urgency': 'Emergência'},
      );
      expect(ranked, isNotEmpty);
      expect(ranked.first.provider.id, '3');
    });

    test('ranking prefers higher rating when other factors equal', () {
      final a = ProviderModel(
        id: 'a',
        userId: 'a',
        name: 'A',
        categories: const ['freios'],
        city: 'Marabá',
        rating: 4.2,
        totalReviews: 10,
        verified: true,
        createdAt: DateTime(2025),
      );
      final b = ProviderModel(
        id: 'b',
        userId: 'b',
        name: 'B',
        categories: const ['freios'],
        city: 'Marabá',
        rating: 4.9,
        totalReviews: 10,
        verified: true,
        createdAt: DateTime(2025),
      );
      final ranked = ServiceMatching.rank(
        candidates: [a, b],
        categoryId: 'freios',
        city: 'Marabá',
      );
      expect(ranked.first.provider.id, 'b');
    });
  });
}
