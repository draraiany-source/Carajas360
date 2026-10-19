import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/checkout/market_order_screen.dart';
import 'package:servico_conecta/features/checkout/payment_screens.dart';
import 'package:servico_conecta/features/checkout/payments_api.dart';
import 'package:servico_conecta/features/marketplace/marketplace_screen.dart';
import 'package:servico_conecta/features/marketplace/store_screen.dart';

MarketProduct prod(String id, String cat,
        {String name = 'Produto', String store = 'Loja'}) =>
    MarketProduct(
        id: id, name: name, emoji: '📦', category: cat, price: 10, store: store, rating: 0);

void main() {
  group('Preço digitado pelo lojista', () {
    test('aceita formato brasileiro com milhar', () {
      expect(parseBrlNumber('1.234,56'), 1234.56);
      expect(parseBrlNumber('12,5'), 12.5);
      expect(parseBrlNumber('R\$ 2.000'), 2000);
      expect(parseBrlNumber('12.50'), 12.5);
      expect(parseBrlNumber('1.234.567,00'), 1234567);
      expect(parseBrlNumber(''), isNull);
      expect(parseBrlNumber('abc'), isNull);
    });

    test('estoque negativo ou inválido é recusado', () {
      expect(parseStock(''), 0);
      expect(parseStock('15'), 15);
      expect(parseStock('-1'), isNull);
      expect(parseStock('1,5'), isNull);
    });
  });

  group('Parcelamento', () {
    test('soma das parcelas é igual ao total', () {
      for (final total in [1000, 9999, 12345, 100001]) {
        for (var n = 1; n <= 12; n++) {
          final parts = installmentAmounts(total, n);
          expect(parts.length, n);
          expect(parts.fold<int>(0, (s, v) => s + v), total);
        }
      }
    });

    test('rótulo indica aproximação quando não divide exato', () {
      expect(installmentLabel(1000, 1), 'À vista — ${brl(1000)}');
      expect(installmentLabel(1000, 2), '2x de ${brl(500)}');
      expect(installmentLabel(1000, 3), '3x de aprox. ${brl(333)}');
    });
  });

  group('Vitrine', () {
    test('nota escondida sem avaliações', () {
      expect(ratingLabel(4.8, 0), isNull);
      expect(ratingLabel(4.75, 3), '4.8');
    });

    test('chips vêm das categorias presentes nos produtos', () {
      final cats = marketCategories(
          [prod('a', 'loja_mercado'), prod('b', 'loja_pet'), prod('c', 'loja_mercado'), prod('d', '')]);
      expect(cats, ['loja_mercado', 'loja_pet']);
    });

    test('busca por nome do produto ou da loja', () {
      final p = prod('a', 'x', name: 'Arroz Tipo 1', store: 'SuperMarket');
      expect(marketMatches(p, ''), isTrue);
      expect(marketMatches(p, 'arroz'), isTrue);
      expect(marketMatches(p, 'SUPER'), isTrue);
      expect(marketMatches(p, 'feijão'), isFalse);
    });
  });

  group('Pedido do Mercado', () {
    test('evento de repasse tem rótulo', () {
      expect(marketEventLabel('released'), 'Pagamento liberado à loja');
      expect(marketEventLabel('paid'), 'Pagamento confirmado');
      expect(marketEventLabel('desconhecido'), 'desconhecido');
    });

    test('endereço em uma linha ignora campos vazios', () {
      expect(
          marketAddressLine(
              {'street': 'Rua A', 'number': '10', 'district': 'Centro', 'city': 'Marabá'}),
          'Rua A, 10 — Centro — Marabá');
      expect(marketAddressLine({'street': 'Rua A', 'city': 'Parauapebas'}),
          'Rua A — Parauapebas');
    });
  });
}
