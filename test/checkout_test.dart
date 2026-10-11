import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:servico_conecta/features/checkout/cart.dart';
import 'package:servico_conecta/features/checkout/cart_service.dart';
import 'package:servico_conecta/features/checkout/payments_api.dart';

CartLine line(String id, int qty, {String store = 's1', int price = 1000}) =>
    CartLine(
        productId: id,
        storeId: store,
        storeName: 'Loja $store',
        name: 'Produto $id',
        unitPriceCents: price,
        qty: qty);

void main() {
  group('Teste 14 — carrinho preservado após login/fechamento', () {
    test('merge visitante × conta: une itens e fica com a maior quantidade', () {
      final local = Cart([line('a', 2), line('b', 1)]);
      final remote = Cart([line('a', 1), line('c', 3, store: 's2')]);
      final m = Cart.merge(local, remote);
      expect(m.qtyOf('a'), 2);
      expect(m.qtyOf('b'), 1);
      expect(m.qtyOf('c'), 3);
      expect(m.totalItems, 6);
      // Mesclar de novo (sincronização repetida) não duplica.
      expect(Cart.merge(m, m).totalItems, 6);
    });

    test('serialização sobrevive a fechar/atualizar e ignora dados inválidos', () {
      final c = Cart([line('a', 2), line('b', 120)]);
      final back = Cart.decode(c.encode());
      expect(back.qtyOf('a'), 2);
      expect(back.qtyOf('b'), CartLine.maxQty, reason: 'quantidade limitada');
      expect(Cart.decode('lixo').isEmpty, isTrue);
      expect(
          Cart.fromList([
            {'productId': 'x', 'storeId': 's', 'qty': 0},
            {'productId': '', 'storeId': 's', 'qty': 1},
            {'productId': 'y', 'storeId': 's', 'qty': 1},
            {'productId': 'y', 'storeId': 's', 'qty': 5},
          ]).lines.map((l) => '${l.productId}:${l.qty}'),
          ['y:1']);
    });

    test('CartService restaura do aparelho e guarda a ação pendente do login', () async {
      SharedPreferences.setMockInitialValues(
          {'cart_v1': Cart([line('a', 3)]).encode()});
      await CartService.instance.start();
      expect(CartService.instance.cart.qtyOf('a'), 3);
      await CartService.setPendingCheckout('s1');
      expect(await CartService.takePendingCheckout(), 's1');
      expect(await CartService.takePendingCheckout(), isNull, reason: 'consumida');
    });
  });

  group('Carrinho multi-loja', () {
    test('agrupa por loja; remover itens pagos preserva outras lojas', () {
      final c = Cart([line('a', 1), line('b', 2, store: 's2'), line('c', 1)]);
      final g = c.byStore();
      expect(g.keys.toSet(), {'s1', 's2'});
      expect(g['s1']!.length, 2);
      final after = c.removeProducts(['a', 'c']);
      expect(after.byStore().keys, ['s2']);
    });

    test('setQty 0 remove; nunca negativo', () {
      final c = Cart([line('a', 1)]).setQty(line('a', 1), 0);
      expect(c.isEmpty, isTrue);
      expect(Cart.empty.setQty(line('z', 1), -5).isEmpty, isTrue);
    });
  });

  group('Estados persistidos (nunca decididos no app)', () {
    test('brl formata centavos', () {
      expect(brl(0), r'R$ 0,00');
      expect(brl(5500), r'R$ 55,00');
      expect(brl(123456789), r'R$ 1.234.567,89');
      expect(brl(-150), r'-R$ 1,50');
    });

    test('pedido: status do pedido e do pagamento são independentes', () {
      final o = MarketOrder.fromMap('mo1', {
        'status': 'cancellation_requested',
        'paymentStatus': 'refund_requested',
        'totalCents': 5500,
        'items': [
          {'productId': 'p', 'name': 'P', 'unitPriceCents': 2500, 'qty': 2, 'subtotalCents': 5000}
        ],
      });
      expect(o.awaitingPayment, isFalse);
      expect(o.isPaid, isTrue, reason: 'reembolso ainda não confirmado');
      expect(paymentStatusLabel[o.paymentStatus], 'Reembolso solicitado');
      final refunded = MarketOrder.fromMap('mo1', {'status': 'cancelled', 'paymentStatus': 'refunded'});
      expect(refunded.isPaid, isFalse);
      expect(refunded.canCancel, isFalse);
    });

    test('tentativa: aprovado só com status do servidor', () {
      final pending = PaymentAttempt.fromMap('pa', {
        'status': 'pending',
        'method': 'pix',
        'amountCents': 100,
        'pix': {'qrCode': '000201', 'expiresAt': '2030-01-01T00:00:00Z'},
      });
      expect(pending.approved, isFalse);
      expect(pending.active, isTrue);
      expect(pending.pixCode, '000201');
      expect(pending.pixExpiresAt, DateTime.utc(2030));
      for (final s in ['rejected', 'cancelled', 'expired', 'failed']) {
        expect(PaymentAttempt.fromMap('pa', {'status': s}).failed, isTrue);
      }
      expect(PaymentAttempt.fromMap('pa', {'status': 'uncertain'}).active, isTrue,
          reason: 'incerto bloqueia nova cobrança');
    });

    test('requestId estável e não previsível', () {
      final a = newRequestId();
      expect(a.length, 20);
      expect(RegExp(r'^[a-z0-9]+$').hasMatch(a), isTrue);
      expect(newRequestId(), isNot(a));
    });
  });
}
