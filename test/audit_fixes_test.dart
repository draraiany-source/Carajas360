import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/checkout/payments_api.dart';
import 'package:servico_conecta/features/provider/provider_home_screen.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/services/firebase_service.dart';

void main() {
  test('favoritos de produto (sem providerId) são ignorados', () {
    final ids = FS.favoriteProviderIds([
      {'userId': 'u', 'providerId': 'p1'},
      {'userId': 'u', 'productId': 'x'},
      {'userId': 'u', 'providerId': null},
      {'userId': 'u', 'providerId': ''},
      {'userId': 'u', 'providerId': 'p2'},
    ]);
    expect(ids, ['p1', 'p2']);
  });

  test('OrderModel.awaitingClientConfirmation', () {
    final base = {'clientId': 'c', 'status': 'inProgress'};
    expect(OrderModel.fromMap('o', base).awaitingClientConfirmation, isFalse);
    expect(
        OrderModel.fromMap('o', {...base, 'awaitingClientConfirmation': true})
            .awaitingClientConfirmation,
        isTrue);
  });

  test('checkCoupon → CouponModel', () {
    expect(FS.couponFromCheck({'valid': false, 'code': 'X'}), isNull);
    final c = FS.couponFromCheck({
      'valid': true,
      'code': 'PROMO10',
      'description': '10% off',
      'discount': 10,
      'isPercentage': true,
      'minValue': 50,
      'expiresAtMs': null,
    })!;
    expect(c.code, 'PROMO10');
    expect(c.discount, 10);
    expect(c.minValue, 50);
    expect(c.isValid, isTrue);
    final expired = FS.couponFromCheck({
      'valid': true,
      'code': 'OLD',
      'discount': 5,
      'isPercentage': false,
      'expiresAtMs': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
    })!;
    expect(expired.isValid, isFalse);
  });

  test('orçamento do prestador: 1..1.000.000', () {
    expect(parseQuote('150'), 150);
    expect(parseQuote('1.234,56'), 1234.56);
    expect(parseQuote('99.9'), 99.9);
    expect(parseQuote('0,50'), isNull);
    expect(parseQuote('2000000'), isNull);
    expect(parseQuote('abc'), isNull);
  });

  test('saves não enviam campos de reputação/comissão', () {
    final m = FS.stripServerFields({
      'name': 'Loja',
      'rating': 5,
      'totalReviews': 10,
      'verified': true,
      'commissionRate': 0,
    });
    expect(m, {'name': 'Loja'});
  });

  test('pedido do Mercado aguardando confirmação de recebimento', () {
    final o = MarketOrder.fromMap('m', {'status': 'delivered'});
    expect(o.awaitingReceipt, isTrue);
    final r = MarketOrder.fromMap('m', {'status': 'delivered', 'released': true});
    expect(r.awaitingReceipt, isFalse);
  });
}
