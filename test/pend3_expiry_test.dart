import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/shared/models/models.dart';

// Prazo de aceite de pedidos pendentes: mesma regra do servidor
// (functions/orderPolicy.js expiresAtMs, 7 dias).
void main() {
  final created = DateTime(2026, 10, 1, 10);
  Map<String, dynamic> base(Map<String, dynamic> extra) => {
        'clientId': 'c',
        'providerId': 'p',
        'status': 'pending',
        'createdAt': Timestamp.fromDate(created),
        ...extra,
      };

  test('prazo é de 7 dias, igual ao servidor', () {
    expect(OrderModel.pendingExpiry, const Duration(days: 7));
  });

  test('usa expiresAt gravado; antigo sem o campo usa createdAt + 7 dias', () {
    final exp = DateTime(2026, 10, 3, 12);
    final withField = OrderModel.fromMap(
        'a', base({'expiresAt': Timestamp.fromDate(exp)}));
    expect(withField.expiresAt, exp);
    expect(withField.expiresAtOrDefault, exp);
    final legacy = OrderModel.fromMap('b', base({}));
    expect(legacy.expiresAt, isNull);
    expect(legacy.expiresAtOrDefault, created.add(const Duration(days: 7)));
    expect(OrderModel.expiryOf(created, null),
        DateTime(2026, 10, 8, 10));
  });

  test('isExpiredAt vale só para pendente, a partir do instante do prazo', () {
    final o = OrderModel.fromMap('a', base({}));
    final limit = created.add(const Duration(days: 7));
    expect(o.isExpiredAt(limit.subtract(const Duration(seconds: 1))), isFalse);
    expect(o.isExpiredAt(limit), isTrue);
    final accepted = OrderModel.fromMap('b', base({'status': 'accepted'}));
    expect(accepted.isExpiredAt(limit.add(const Duration(days: 30))), isFalse);
  });

  test('cancelado pela expiração mostra "Expirado"; cancelado comum não', () {
    final exp = OrderModel.fromMap(
        'a', base({'status': 'cancelled', 'expired': true}));
    expect(exp.statusLabel, contains('Expirado'));
    final legacyExp = OrderModel.fromMap('b',
        base({'status': 'cancelled', 'cancelReason': 'Expirado automaticamente'}));
    expect(legacyExp.statusLabel, contains('Expirado'));
    final cancelled = OrderModel.fromMap(
        'c', base({'status': 'cancelled', 'cancelReason': 'Desisti'}));
    expect(cancelled.statusLabel, contains('Cancelado'));
    // Pendente vencido (antes da tarefa rodar) também aparece como expirado.
    final stale = OrderModel.fromMap('d', base({}));
    expect(stale.statusLabel, contains('Expirado'));
    final fresh = OrderModel.fromMap(
        'e', {...base({}), 'createdAt': Timestamp.now()});
    expect(fresh.statusLabel, contains('Aguardando'));
  });

  test('texto "Expira em X"', () {
    final now = DateTime(2026, 10, 1, 10);
    expect(OrderModel.expiryLabel(now.add(const Duration(days: 6, hours: 5)), now),
        'Expira em 6 d 5 h');
    expect(OrderModel.expiryLabel(now.add(const Duration(days: 2)), now),
        'Expira em 2 d');
    expect(OrderModel.expiryLabel(now.add(const Duration(hours: 3, minutes: 20)), now),
        'Expira em 3 h 20 min');
    expect(OrderModel.expiryLabel(now.add(const Duration(seconds: 20)), now),
        'Expira em 1 min');
    expect(OrderModel.expiryLabel(now, now), 'Expirado');
  });
}
