import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/widgets/brand_provider_card.dart';

ProviderModel _p(int i, {double? price, int reviews = 0}) => ProviderModel(
      id: 'p$i',
      userId: 'p$i',
      name: 'Profissional com um nome bastante comprido número $i',
      categories: const ['eletricista', 'encanador'],
      city: 'Canaã dos Carajás',
      serviceAreas: const ['Parauapebas', 'Marabá'],
      bio: 'Instalações elétricas residenciais e comerciais, manutenção '
          'preventiva, quadros de distribuição e atendimento de urgência.',
      rating: 4.7,
      totalReviews: reviews,
      minPrice: price,
      createdAt: DateTime(2025),
    );

void main() {
  final list = [
    _p(1, price: 80, reviews: 12),
    _p(2),
    _p(3, price: 99.5, reviews: 1),
    _p(4, price: 150, reviews: 230),
  ];

  test('colunas acompanham a largura', () {
    expect(BrandProviderGrid.columnsFor(358), 1);
    expect(BrandProviderGrid.columnsFor(700), 2);
    expect(BrandProviderGrid.columnsFor(1200), 4);
    expect(BrandProviderGrid.columnsFor(1200, max: 3), 3);
  });

  for (final w in const [320.0, 390.0, 768.0, 1280.0]) {
    for (final asList in const [false, true]) {
      testWidgets(
          'cartões sem overflow em ${w}px (${asList ? 'lista' : 'grade'})',
          (tester) async {
        tester.view.physicalSize = Size(w, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: BrandProviderGrid(list: list, asList: asList),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull);
        expect(find.text('Preço sob consulta'), findsOneWidget);
        expect(find.text('A partir de R\$ 80'), findsOneWidget);
        expect(find.textContaining('Sem avaliações'), findsOneWidget);
        expect(find.text('Ver perfil'), findsNWidgets(4));
        for (final b in tester.widgetList<IconButton>(find.byType(IconButton))) {
          expect(b.tooltip, isNotNull);
        }
      });
    }
  }
}
