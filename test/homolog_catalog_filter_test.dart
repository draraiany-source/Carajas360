import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/catalog/homolog_catalog.dart';
import 'package:carajas_360/shared/models/models.dart';

ProviderModel _p(String id, List<String> cats) => ProviderModel(
      id: id,
      userId: id,
      name: id,
      categories: cats,
      createdAt: DateTime(2025, 1, 1),
    );

void main() {
  final all = [
    _p('e1', ['eletricista']),
    _p('p1', ['pintor']),
    _p('m1', ['mecanico']),
    _p('a1', ['advogado']),
    _p('c1', ['contador']),
    _p('d1', ['diarista']),
  ];

  Set<String> idsForGroup(String group) {
    const map = {
      'Casa': {'eletricista', 'pintor', 'encanador', 'pedreiro', 'marceneiro'},
      'Veículos': {'mecanico', 'motorista', 'aluguel_carro'},
      'Jurídico': {'advogado', 'contador'},
      'Limpeza': {'diarista', 'faxineira'},
    };
    return map[group] ?? {};
  }

  test('exact category match only', () {
    final list = HomologCatalog.matchProviders(
      all,
      category: 'eletricista',
      groupIds: const {},
    );
    expect(list.map((p) => p.id), ['e1']);
    expect(list.every((p) => p.categories.contains('eletricista')), isTrue);
  });

  test('fuzzy substring must not match', () {
    final list = HomologCatalog.matchProviders(
      all,
      category: 'eletr',
      groupIds: const {},
    );
    expect(list, isEmpty);
  });

  test('veiculos group never includes eletricista', () {
    final list = HomologCatalog.matchProviders(
      all,
      group: 'Veículos',
      groupIds: idsForGroup('Veículos'),
    );
    expect(list.any((p) => p.categories.contains('eletricista')), isFalse);
    expect(list.map((p) => p.id), ['m1']);
  });

  test('juridico group never includes pintor', () {
    final list = HomologCatalog.matchProviders(
      all,
      group: 'Jurídico',
      groupIds: idsForGroup('Jurídico'),
    );
    expect(list.any((p) => p.categories.contains('pintor')), isFalse);
    expect(list.map((p) => p.id).toSet(), {'a1', 'c1'});
  });

  test('category takes precedence over group', () {
    final list = HomologCatalog.matchProviders(
      all,
      category: 'pintor',
      group: 'Veículos',
      groupIds: idsForGroup('Veículos'),
    );
    expect(list.map((p) => p.id), ['p1']);
  });
}
