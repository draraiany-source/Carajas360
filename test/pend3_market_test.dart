import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/checkout/cart.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/services/firebase_service.dart';

// Mercado: item de loja desativada/não aprovada (ou produto removido)
// aparece como indisponível no carrinho e bloqueia a finalização.
void main() {
  const a = CartLine(
      productId: 'p1', storeId: 's1', storeName: 'Loja', name: 'Arroz', unitPriceCents: 1000, qty: 1);
  const b = CartLine(
      productId: 'p2', storeId: 's1', storeName: 'Loja', name: 'Feijão', unitPriceCents: 500, qty: 2);
  final okStore = {'active': true, 'verified': true};
  final okProduct = {'active': true, 'storeActive': true, 'storeId': 's1'};

  test('loja ativa e aprovada: nada indisponível', () {
    expect(storeUnavailableReason(okStore), isNull);
    expect(unavailableProductIds([a, b], okStore, {'p1': okProduct, 'p2': okProduct}), isEmpty);
  });

  test('loja desativada, não aprovada ou excluída: todos os itens indisponíveis', () {
    for (final store in [
      {'active': false, 'verified': true},
      {'verified': true}, // sem o campo active
      {'active': true, 'verified': false},
      {'active': true}, // sem o campo verified
      null, // loja excluída
    ]) {
      expect(storeUnavailableReason(store), isNotNull, reason: '$store');
      expect(unavailableProductIds([a, b], store, const {}), {'p1', 'p2'}, reason: '$store');
    }
    expect(storeUnavailableReason({'active': false, 'verified': true}), contains('desativada'));
    expect(storeUnavailableReason({'active': true, 'verified': false}), contains('aprovada'));
  });

  test('produto removido, inativo, de loja oculta ou de outra loja', () {
    final ids = unavailableProductIds([a, b], okStore, {
      'p1': null, // excluído
      'p2': {...okProduct, 'active': false},
    });
    expect(ids, {'p1', 'p2'});
    expect(unavailableProductIds([a], okStore, {'p1': {...okProduct, 'storeActive': false}}), {'p1'});
    expect(unavailableProductIds([a], okStore, {'p1': {...okProduct, 'storeId': 'outra'}}), {'p1'});
    // Produto antigo sem storeActive (antes da reconciliação) segue disponível.
    expect(unavailableProductIds([a], okStore, {'p1': {'active': true, 'storeId': 's1'}}), isEmpty);
    // Ainda não carregado: não marca (o servidor valida no pedido).
    expect(unavailableProductIds([a], okStore, const {}), isEmpty);
  });

  test('ProductModel.storeAvailable e campos do servidor fora do app', () {
    expect(ProductModel.fromMap('p', {'storeActive': false}).storeAvailable, isFalse);
    expect(ProductModel.fromMap('p', {'storeActive': true}).storeAvailable, isTrue);
    expect(ProductModel.fromMap('p', const {}).storeAvailable, isTrue);
    final p = ProductModel.fromMap('p', {'storeId': 's1', 'name': 'X', 'storeActive': true});
    expect(p.toMap().containsKey('storeActive'), isFalse);
    final m = FS.stripServerFields({'name': 'L', 'totalProducts': 9, 'storeActive': true, 'active': true});
    expect(m.containsKey('totalProducts'), isFalse);
    expect(m.containsKey('storeActive'), isFalse);
    expect(m['active'], isTrue);
  });
}
