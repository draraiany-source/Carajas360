import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/shared/models/models.dart';

OrderModel _order(Map<String, dynamic> m) => OrderModel.fromMap('o1', {
      'clientId': 'c1',
      'category': 'eletricista',
      'title': 'Tomadas',
      'description': 'Instalar',
      'address': 'Rua A',
      ...m,
    });

void main() {
  group('pagamento ligado ao pedido', () {
    test('pode pagar depois de aceito com valor', () {
      final o = _order({'providerId': 'p1', 'status': 'accepted', 'price': 180});
      expect(o.canPay, isTrue);
    });

    test('não paga sem profissional, sem valor, já pago ou pendente', () {
      expect(_order({'status': 'accepted', 'price': 180}).canPay, isFalse);
      expect(_order({'providerId': 'p1', 'status': 'accepted'}).canPay, isFalse);
      expect(
          _order({
            'providerId': 'p1',
            'status': 'inProgress',
            'price': 180,
            'paymentStatus': 'paid'
          }).canPay,
          isFalse);
      expect(_order({'providerId': 'p1', 'status': 'pending', 'price': 180}).canPay,
          isFalse);
    });
  });

  group('confirmação do cliente e custódia', () {
    test('concluído pelo profissional aguarda o cliente', () {
      final o = _order({
        'providerId': 'p1',
        'status': 'completed',
        'price': 180,
        'paymentStatus': 'paid',
        'completedBy': 'provider',
        'escrowStatus': 'releasePending',
      });
      expect(o.awaitingClientConfirmation, isTrue);
    });

    test('não pede confirmação após repasse, confirmação ou contestação', () {
      final base = {
        'providerId': 'p1',
        'status': 'completed',
        'price': 180,
        'paymentStatus': 'paid',
      };
      expect(_order({...base, 'payoutProcessed': true}).awaitingClientConfirmation,
          isFalse);
      expect(
          _order({...base, 'clientConfirmedAt': DateTime(2026)})
              .awaitingClientConfirmation,
          isFalse);
      expect(
          _order({...base, 'escrowStatus': 'disputed'})
              .awaitingClientConfirmation,
          isFalse);
    });
  });
}
