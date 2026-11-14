import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/search/provider_search.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/widgets/brand_categories.dart';

ProviderModel _p(
  String id, {
  String? name,
  List<String> cats = const [],
  String? city,
  List<String> areas = const [],
  String? bio,
  double rating = 0,
  int reviews = 0,
  double? price,
  List<String> modalities = const ['presential'],
  bool active = true,
}) =>
    ProviderModel(
      id: id,
      userId: id,
      name: name ?? id,
      categories: cats,
      city: city,
      serviceAreas: areas,
      bio: bio,
      rating: rating,
      totalReviews: reviews,
      minPrice: price,
      modalities: modalities,
      active: active,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  final all = [
    _p('e1',
        name: 'Carlos Eletricista',
        cats: ['eletricista'],
        city: 'Parauapebas',
        rating: 4.9,
        reviews: 120,
        price: 80),
    _p('e2',
        name: 'José Elétrica',
        cats: ['eletricista', 'encanador'],
        city: 'Canaã dos Carajás',
        rating: 4.5,
        reviews: 10,
        price: 120),
    _p('p1',
        name: 'Marcos Pinturas',
        cats: ['pintor'],
        city: 'Marabá',
        areas: ['Parauapebas'],
        bio: 'Pintura residencial e textura',
        rating: 5,
        reviews: 0),
    _p('m1',
        name: 'Oficina Serra',
        cats: ['mecanico'],
        city: 'Parauapebas',
        rating: 4.2,
        reviews: 30,
        price: 150,
        modalities: ['presential', 'online']),
    _p('d1',
        name: 'Ana Diarista',
        cats: ['diarista'],
        city: 'Parauapebas',
        rating: 4.8,
        reviews: 55,
        price: 100),
    _p('x1', name: 'Inativo', cats: ['eletricista'], active: false),
  ];

  List<String> ids(List<ProviderModel> l) => l.map((p) => p.id).toList();
  List<ProviderModel> run(ProviderSearchCriteria c) =>
      ProviderSearch.apply(all, c);

  group('busca por texto', () {
    test('ignora acentos e maiúsculas no nome', () {
      expect(ids(run(const ProviderSearchCriteria(query: 'JOSE ELETRICA'))),
          ['e2']);
    });

    test('encontra pela especialidade (nome da categoria)', () {
      final r = ids(run(const ProviderSearchCriteria(query: 'encanador')));
      expect(r, ['e2']);
    });

    test('encontra pela descrição', () {
      expect(ids(run(const ProviderSearchCriteria(query: 'textura'))), ['p1']);
    });

    test('sem resultados devolve lista vazia', () {
      expect(run(const ProviderSearchCriteria(query: 'astronauta')), isEmpty);
    });

    test('nunca mostra perfis inativos', () {
      expect(ids(run(const ProviderSearchCriteria())), isNot(contains('x1')));
    });
  });

  group('categoria e especialidade', () {
    test('escopo por grupo usa ids estáveis', () {
      final casa = ProviderSearch.idsForGroup('Casa');
      final r = ids(run(ProviderSearchCriteria(scopeIds: casa)));
      expect(r.toSet(), {'e1', 'e2', 'p1'});
    });

    test('especialidade restringe dentro do escopo', () {
      final casa = ProviderSearch.idsForGroup('Casa');
      final r = run(ProviderSearchCriteria(
          scopeIds: casa, specialties: const {'encanador'}));
      expect(ids(r), ['e2']);
    });

    test('profissional com várias especialidades aparece em cada uma', () {
      expect(ids(run(const ProviderSearchCriteria(scopeIds: {'eletricista'}))),
          containsAll(['e1', 'e2']));
      expect(ids(run(const ProviderSearchCriteria(scopeIds: {'encanador'}))),
          ['e2']);
    });

    test('Veículos e Oficinas inclui mecânico', () {
      final veic =
          brandCategories.firstWhere((c) => c.label == 'Veículos e Oficinas');
      expect(veic.ids, contains('mecanico'));
      expect(ids(run(ProviderSearchCriteria(scopeIds: veic.ids))), ['m1']);
    });

    test('especialidades disponíveis só listam ids com profissionais', () {
      final casa = ProviderSearch.idsForGroup('Casa');
      final spec = ProviderSearch.availableSpecialties(all, casa);
      expect(spec.toSet(), {'eletricista', 'encanador', 'pintor'});
      expect(ProviderSearch.availableSpecialties(all, const {'pintor'}),
          isEmpty);
    });

    test('rótulo do cartão prefere a especialidade filtrada', () {
      final e2 = all.firstWhere((p) => p.id == 'e2');
      expect(ProviderSearch.specialtyLabel(e2, prefer: const {'encanador'}),
          isNot(ProviderSearch.categoryName('eletricista')));
    });

    test('fromArgs devolve o atalho existente', () {
      expect(BrandCategory.fromArgs(category: 'eletricista')?.label,
          'Elétrica');
      expect(BrandCategory.fromArgs(group: 'Casa')?.label,
          'Construção e Reforma');
      expect(BrandCategory.fromArgs(group: 'Todos'), isNull);
      expect(BrandCategory.fromArgs(category: 'nao_existe'), isNull);
    });
  });

  group('filtros combinados', () {
    test('cidade considera área de atendimento e acentos', () {
      final r = ids(run(const ProviderSearchCriteria(city: 'parauapebas')));
      expect(r.toSet(), {'e1', 'p1', 'm1', 'd1'});
      expect(ids(run(const ProviderSearchCriteria(city: 'Canaa dos Carajas'))),
          ['e2']);
    });

    test('nota mínima exige avaliações reais', () {
      final r = ids(run(const ProviderSearchCriteria(minRating: 4.5)));
      expect(r, isNot(contains('p1')));
      expect(r.toSet(), {'e1', 'e2', 'd1'});
    });

    test('preço máximo exclui quem não informou preço', () {
      final r = ids(run(const ProviderSearchCriteria(maxPrice: 100)));
      expect(r.toSet(), {'e1', 'd1'});
    });

    test('atendimento online usa a modalidade cadastrada', () {
      expect(ids(run(const ProviderSearchCriteria(modality: 'online'))),
          ['m1']);
    });

    test('texto + categoria + cidade + preço + nota', () {
      final r = run(ProviderSearchCriteria(
        query: 'eletric',
        scopeIds: ProviderSearch.idsForGroup('Casa'),
        city: 'Parauapebas',
        maxPrice: 100,
        minRating: 4,
      ));
      expect(ids(r), ['e1']);
    });

    test('limpar filtros restaura todos os ativos', () {
      const cleared = ProviderSearchCriteria();
      expect(cleared.hasFilters, isFalse);
      expect(run(cleared).length, 5);
    });
  });

  group('ordenação e paginação', () {
    test('melhor avaliados ignora nota sem avaliações', () {
      final r = ids(run(const ProviderSearchCriteria(sort: ProviderSort.rating)));
      expect(r.first, 'e1');
      expect(r.last, 'p1');
    });

    test('mais avaliados', () {
      expect(
          ids(run(const ProviderSearchCriteria(sort: ProviderSort.reviews)))
              .first,
          'e1');
    });

    test('menor preço deixa sem preço no fim', () {
      final r = ids(run(const ProviderSearchCriteria(sort: ProviderSort.price)));
      expect(r, ['e1', 'd1', 'e2', 'm1', 'p1']);
    });

    test('relevância prioriza nome que começa com o termo', () {
      final r = ids(run(const ProviderSearchCriteria(query: 'ana')));
      expect(r.first, 'd1');
    });

    test('contagem e fatias de página', () {
      final list = List.generate(25, (i) => i);
      expect(ProviderSearch.pageCount(25, 12), 3);
      expect(ProviderSearch.pageCount(0, 12), 0);
      expect(ProviderSearch.pageSlice(list, 0, 12).length, 12);
      expect(ProviderSearch.pageSlice(list, 2, 12), [24]);
      expect(ProviderSearch.pageSlice(list, 9, 12), [24]);
      expect(ProviderSearch.pageSlice(<int>[], 0, 12), isEmpty);
    });
  });
}
