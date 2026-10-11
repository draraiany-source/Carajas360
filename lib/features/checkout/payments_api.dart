import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/services/firebase_service.dart';

/// Formata centavos em reais (R$ 1.234,56).
String brl(int cents) {
  final neg = cents < 0;
  final v = cents.abs();
  final reais = (v ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buf.write('.');
    buf.write(reais[i]);
  }
  return '${neg ? '-' : ''}R\$ $buf,${(v % 100).toString().padLeft(2, '0')}';
}

/// Identificador estável de uma intenção (pedido/pagamento). Repetir a
/// chamada com o mesmo id devolve o mesmo resultado no servidor.
String newRequestId() {
  final r = Random.secure();
  return List.generate(20, (_) => r.nextInt(36).toRadixString(36)).join();
}

int _int(Object? v) => v is num ? v.toInt() : 0;
DateTime? _date(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is num && v > 0) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Status do pedido (separado do status do pagamento).
const orderStatusLabel = {
  'pending_payment': 'Aguardando pagamento',
  'paid': 'Pago — aguardando a loja',
  'preparing': 'Em preparação',
  'shipped': 'Saiu para entrega',
  'ready': 'Pronto para retirada',
  'delivered': 'Entregue',
  'cancellation_requested': 'Cancelamento solicitado',
  'cancelled': 'Cancelado',
  'expired': 'Expirado (reserva vencida)',
};

const paymentStatusLabel = {
  'unpaid': 'Não pago',
  'pending': 'Pagamento em andamento',
  'approved': 'Pagamento confirmado',
  'approved_late': 'Pago após cancelamento — reembolso em andamento',
  'refund_requested': 'Reembolso solicitado',
  'partially_refunded': 'Reembolsado parcialmente',
  'refunded': 'Reembolsado',
  'cancelled': 'Cobrança cancelada',
  'expired': 'Cobrança expirada',
};

const attemptStatusLabel = {
  'creating': 'Gerando cobrança…',
  'uncertain': 'Confirmando com o banco…',
  'pending': 'Aguardando pagamento',
  'challenge': 'Autenticação do cartão necessária',
  'approved': 'Pagamento confirmado',
  'rejected': 'Pagamento recusado',
  'cancelled': 'Cobrança cancelada',
  'expired': 'Cobrança expirada',
  'failed': 'Não foi possível concluir',
  'refunded': 'Reembolsado',
  'partially_refunded': 'Reembolsado parcialmente',
};

class OrderLine {
  final String productId, name;
  final int unitPriceCents, qty, subtotalCents;
  const OrderLine(this.productId, this.name, this.unitPriceCents, this.qty,
      this.subtotalCents);
}

/// Pedido do Mercado lido do Firestore (estado persistido no servidor).
class MarketOrder {
  final String id, clientId, storeId, storeName, status, paymentStatus;
  final String deliveryMode;
  final String? activeAttemptId, paidAttemptId, paymentMethod, cancelReason;
  final List<OrderLine> items;
  final int subtotalCents, discountCents, deliveryFeeCents, totalCents;
  final int refundedCents, refundPendingCents;
  final DateTime? reservedUntil, createdAt;
  final Map<String, dynamic> address;

  const MarketOrder({
    required this.id,
    required this.clientId,
    required this.storeId,
    required this.storeName,
    required this.status,
    required this.paymentStatus,
    required this.deliveryMode,
    this.activeAttemptId,
    this.paidAttemptId,
    this.paymentMethod,
    this.cancelReason,
    required this.items,
    required this.subtotalCents,
    required this.discountCents,
    required this.deliveryFeeCents,
    required this.totalCents,
    required this.refundedCents,
    required this.refundPendingCents,
    this.reservedUntil,
    this.createdAt,
    this.address = const {},
  });

  factory MarketOrder.fromMap(String id, Map<String, dynamic> m) => MarketOrder(
        id: id,
        clientId: (m['clientId'] ?? '').toString(),
        storeId: (m['storeId'] ?? '').toString(),
        storeName: (m['storeName'] ?? '').toString(),
        status: (m['status'] ?? 'pending_payment').toString(),
        paymentStatus: (m['paymentStatus'] ?? 'unpaid').toString(),
        deliveryMode: (m['deliveryMode'] ?? 'delivery').toString(),
        activeAttemptId: m['activeAttemptId'] as String?,
        paidAttemptId: m['paidAttemptId'] as String?,
        paymentMethod: m['paymentMethod'] as String?,
        cancelReason: m['cancelReason'] as String?,
        items: ((m['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((i) => OrderLine(
                (i['productId'] ?? '').toString(),
                (i['name'] ?? '').toString(),
                _int(i['unitPriceCents']),
                _int(i['qty']),
                _int(i['subtotalCents'])))
            .toList(),
        subtotalCents: _int(m['subtotalCents']),
        discountCents: _int(m['discountCents']),
        deliveryFeeCents: _int(m['deliveryFeeCents']),
        totalCents: _int(m['totalCents']),
        refundedCents: _int(m['refundedCents']),
        refundPendingCents: _int(m['refundPendingCents']),
        reservedUntil: _date(m['reservedUntil']),
        createdAt: _date(m['createdAt']),
        address: Map<String, dynamic>.from((m['address'] as Map?) ?? const {}),
      );

  bool get awaitingPayment => status == 'pending_payment';
  bool get isPaid => const [
        'approved',
        'refund_requested',
        'partially_refunded',
      ].contains(paymentStatus);
  bool get canCancel => awaitingPayment || status == 'paid' || status == 'preparing';
  bool reservationExpired(DateTime now) =>
      reservedUntil != null && !reservedUntil!.isAfter(now);
}

/// Tentativa de pagamento (estado persistido; nunca decidido no app).
class PaymentAttempt {
  final String id, status, method, targetKind, targetId;
  final int amountCents, installments;
  final String? statusDetail, pixCode, pixBase64, challengeUrl;
  final DateTime? pixExpiresAt;

  const PaymentAttempt({
    required this.id,
    required this.status,
    required this.method,
    required this.targetKind,
    required this.targetId,
    required this.amountCents,
    this.installments = 1,
    this.statusDetail,
    this.pixCode,
    this.pixBase64,
    this.challengeUrl,
    this.pixExpiresAt,
  });

  factory PaymentAttempt.fromMap(String id, Map<String, dynamic> m) {
    final pix = (m['pix'] as Map?) ?? const {};
    final ch = (m['challenge'] as Map?) ?? const {};
    return PaymentAttempt(
      id: (m['attemptId'] ?? id).toString(),
      status: (m['status'] ?? 'creating').toString(),
      method: (m['method'] ?? '').toString(),
      targetKind: (m['targetKind'] ?? '').toString(),
      targetId: (m['targetId'] ?? '').toString(),
      amountCents: _int(m['amountCents']),
      installments: _int(m['installments']) == 0 ? 1 : _int(m['installments']),
      statusDetail: m['statusDetail'] as String?,
      pixCode: pix['qrCode'] as String?,
      pixBase64: pix['qrCodeBase64'] as String?,
      challengeUrl: ch['url'] as String?,
      pixExpiresAt: _date(pix['expiresAt']) ?? _date(m['pixExpiresAt']),
    );
  }

  bool get approved => status == 'approved';
  bool get active => const ['creating', 'uncertain', 'pending', 'challenge']
      .contains(status);
  bool get failed =>
      const ['rejected', 'cancelled', 'expired', 'failed'].contains(status);
}

class PayTarget {
  final String kind; // market | recharge | service
  final String id;
  final int amountCents;
  final String description;
  const PayTarget(this.kind, this.id, this.amountCents, this.description);
}

/// Chamadas ao backend de pagamentos (Cloud Functions).
abstract final class PaymentsApi {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> quote(Map<String, dynamic> body) =>
      CloudFn.call('quoteMarketOrder', body);

  static Future<Map<String, dynamic>> createMarketOrder(
          Map<String, dynamic> body) =>
      CloudFn.call('createMarketOrder', body);

  static Future<Map<String, dynamic>> createRecharge(
          int amountCents, String requestId) =>
      CloudFn.call('createWalletRecharge',
          {'amountCents': amountCents, 'requestId': requestId});

  static Future<PaymentAttempt?> start(
      {required PayTarget target,
      required String method,
      required String requestId,
      Map<String, dynamic>? card}) async {
    final r = await CloudFn.call('startPayment', {
      'targetKind': target.kind,
      'targetId': target.id,
      'method': method,
      'requestId': requestId,
      if (card != null) 'card': card,
    });
    if (r['already'] == true) {
      return PaymentAttempt(
          id: (r['attemptId'] ?? '').toString(),
          status: 'approved',
          method: method,
          targetKind: target.kind,
          targetId: target.id,
          amountCents: target.amountCents);
    }
    return PaymentAttempt.fromMap((r['attemptId'] ?? '').toString(), r);
  }

  static Future<void> refresh(String attemptId) =>
      CloudFn.call('refreshPayment', {'attemptId': attemptId});

  static Future<void> cancelAttempt(String attemptId) =>
      CloudFn.call('cancelPaymentAttempt', {'attemptId': attemptId});

  static Future<Map<String, dynamic>> cancelOrder(String orderId,
          {String reason = 'Cancelado pelo cliente'}) =>
      CloudFn.call('cancelMarketOrder', {'orderId': orderId, 'reason': reason});

  static Future<void> updateStatus(String orderId, String status) =>
      CloudFn.call('marketOrderUpdateStatus', {'orderId': orderId, 'status': status});

  static Stream<MarketOrder?> orderStream(String id) => _db
      .collection('marketOrders')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? MarketOrder.fromMap(s.id, s.data()!) : null);

  static Stream<PaymentAttempt?> attemptStream(String id) => _db
      .collection('paymentAttempts')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? PaymentAttempt.fromMap(s.id, s.data()!) : null);

  static Stream<List<MarketOrder>> myOrders(String uid) => _db
      .collection('marketOrders')
      .where('clientId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => MarketOrder.fromMap(d.id, d.data())).toList());

  static Stream<List<MarketOrder>> storeOrders(String ownerUid) => _db
      .collection('marketOrders')
      .where('storeOwnerId', isEqualTo: ownerUid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map((d) => MarketOrder.fromMap(d.id, d.data())).toList());

  static Stream<List<Map<String, dynamic>>> orderEvents(String id) => _db
      .collection('marketOrders')
      .doc(id)
      .collection('events')
      .orderBy('at')
      .snapshots()
      .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
}
