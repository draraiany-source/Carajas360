import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/catalog/homolog_catalog.dart';
import 'package:carajas_360/shared/models/models.dart';

RentalModel _r({
  required String id,
  required RentalKind kind,
  required String category,
  String title = 'Item',
  String city = 'Canaã dos Carajás',
  bool available = true,
}) =>
    RentalModel(
      id: id,
      ownerId: 'homolog_owner',
      ownerName: 'Empresa',
      title: title,
      category: category,
      kind: kind,
      city: city,
      available: available,
      isHomologSeed: true,
      createdAt: DateTime(2025, 8, 1),
    );

void main() {
  final all = [
    _r(id: 'hr_v1', kind: RentalKind.vehicle, category: 'aluguel_carro', title: 'Onix'),
    _r(id: 'hr_v2', kind: RentalKind.vehicle, category: 'aluguel_moto', title: 'CG 160'),
    _r(
        id: 'hr_m1',
        kind: RentalKind.machine,
        category: 'aluguel_trator',
        title: 'Trator MF',
        city: 'Parauapebas'),
    _r(
        id: 'hr_m2',
        kind: RentalKind.machine,
        category: 'aluguel_escavadeira',
        title: 'Escavadeira',
        available: false),
  ];

  test('filter by kind vehicle', () {
    final list = HomologCatalog.filterRentals(all, kind: RentalKind.vehicle);
    expect(list.map((r) => r.id).toList(), ['hr_v1', 'hr_v2']);
  });

  test('filter by kind machine', () {
    final list = HomologCatalog.filterRentals(all, kind: RentalKind.machine);
    expect(list.every((r) => r.kind == RentalKind.machine), isTrue);
    expect(list.length, 2);
  });

  test('filter by exact category', () {
    final list =
        HomologCatalog.filterRentals(all, category: 'aluguel_trator');
    expect(list.map((r) => r.id), ['hr_m1']);
  });

  test('query matches title and city', () {
    final byTitle =
        HomologCatalog.filterRentals(all, query: 'onix');
    expect(byTitle.map((r) => r.id), ['hr_v1']);
    final byCity =
        HomologCatalog.filterRentals(all, query: 'parauapebas');
    expect(byCity.map((r) => r.id), ['hr_m1']);
  });

  test('availableOnly excludes unavailable', () {
    final list = HomologCatalog.filterRentals(all, availableOnly: true);
    expect(list.any((r) => r.id == 'hr_m2'), isFalse);
    expect(list.length, 3);
  });

  test('combined kind + category', () {
    final list = HomologCatalog.filterRentals(
      all,
      kind: RentalKind.vehicle,
      category: 'aluguel_moto',
    );
    expect(list.map((r) => r.id), ['hr_v2']);
  });
}
