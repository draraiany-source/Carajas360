/// Política oficial de pedidos / repasse.
/// Espelhada em `functions/orderPolicy.js` — testes cobrem os dois lados.
abstract final class OrderPolicy {
  static const commissionRate = 0.15;

  /// Campos que o client SDK NUNCA pode alterar após a criação.
  static const sensitiveFields = <String>{
    'price',
    'total',
    'amount',
    'providerId',
    'clientId',
    'status',
    'paymentStatus',
    'payoutStatus',
    'payoutProcessed',
    'payoutProcessedAt',
    'payoutTransactionId',
    'commission',
    'platformFee',
    'providerAmount',
    'transactionId',
    'gatewayTransactionId',
    'walletId',
    'cashbackGranted',
    'paidAt',
    'payoutAt',
    'refunded',
    'refundAmount',
  };

  /// Campos administrativos do perfil bloqueados no client.
  static const protectedUserFields = <String>{
    'type',
    'role',
    'roles',
    'adminRole',
    'verified',
    'active',
    'plan',
    'walletId',
    'financialStatus',
    'permissions',
    'createdAt',
    'xp',
    'status',
    'moderationStatus',
  };

  static const protectedProviderFields = <String>{
    'verified',
    'approved',
    'plan',
    'status',
    'rating',
    'totalReviews',
    'userId',
  };

  static const protectedCompanyFields = <String>{
    'verified',
    'approved',
    'plan',
    'ownerId',
    'active',
  };

  static const piiFields = <String>{'cpf', 'phone', 'address', 'fcmToken'};

  static const statusAliases = <String, String>{
    'created': 'pending',
    'in_progress': 'inProgress',
    'inprogress': 'inProgress',
    'awaiting_payment': 'awaitingPayment',
    'awaitingpayment': 'awaitingPayment',
  };

  /// Máquina de estados. pending ≈ created; inProgress ≈ in_progress.
  static const transitions = <String, Set<String>>{
    'pending': {'accepted', 'cancelled'},
    'accepted': {'inProgress', 'cancelled'},
    'inProgress': {'awaitingPayment', 'completed', 'cancelled', 'disputed'},
    'awaitingPayment': {'paid', 'completed', 'cancelled', 'disputed'},
    'paid': {'completed', 'refunded', 'disputed'},
    'completed': {'refunded'},
    'cancelled': {'refunded'},
    'disputed': {'cancelled', 'refunded'},
    'refunded': {},
  };

  static const actions = <String, String>{
    'accept': 'accepted',
    'start': 'inProgress',
    'requestPayment': 'awaitingPayment',
    'markPaid': 'paid',
    'complete': 'completed',
    'cancel': 'cancelled',
    'decline': 'cancelled',
    'dispute': 'disputed',
    'refund': 'refunded',
  };

  static String normalizeStatus(String status) {
    final raw = status.isEmpty ? 'pending' : status;
    return statusAliases[raw] ??
        statusAliases[raw.toLowerCase()] ??
        raw;
  }

  static bool isAllowedTransition(String from, String to) =>
      (transitions[normalizeStatus(from)] ?? const <String>{}).contains(
          normalizeStatus(to));

  static String? targetStatus(String action) => actions[action];

  static bool actorMayPerform({
    required String action,
    required String uid,
    required String clientId,
    required String? providerId,
    bool isAdmin = false,
  }) {
    if (isAdmin &&
        (action == 'refund' || action == 'cancel' || action == 'dispute')) {
      return true;
    }
    final isClient = uid == clientId;
    final isProvider =
        providerId != null && providerId.isNotEmpty && uid == providerId;
    switch (action) {
      case 'accept':
        return providerId == null ||
            providerId.isEmpty ||
            uid == providerId;
      case 'start':
      case 'decline':
      case 'requestPayment':
        return isProvider;
      case 'markPaid':
      case 'refund':
        return false;
      case 'complete':
      case 'dispute':
      case 'cancel':
        return isClient || isProvider;
      default:
        return false;
    }
  }

  static PayoutDecision canPayout({
    required String status,
    required String paymentStatus,
    required bool payoutProcessed,
    required String? providerId,
    required num? price,
    required String orderId,
    String? paymentOrderId,
    String? gatewayStatus,
    num? paidAmount,
    String? officialProviderId,
  }) {
    if (payoutProcessed) {
      return const PayoutDecision.deny('already_processed');
    }
    if (normalizeStatus(status) != 'completed') {
      return const PayoutDecision.deny('order_not_completed');
    }
    final paid = paymentStatus == 'paid' || gatewayStatus == 'approved';
    if (!paid) {
      return const PayoutDecision.deny('payment_not_confirmed');
    }
    if (providerId == null || providerId.isEmpty) {
      return const PayoutDecision.deny('missing_provider');
    }
    if (officialProviderId != null &&
        officialProviderId.isNotEmpty &&
        officialProviderId != providerId) {
      return const PayoutDecision.deny('provider_mismatch');
    }
    if (price == null || price <= 0) {
      return const PayoutDecision.deny('invalid_price');
    }
    if (paymentOrderId != null && paymentOrderId != orderId) {
      return const PayoutDecision.deny('payment_order_mismatch');
    }
    if (paidAmount != null && (paidAmount - price).abs() > 0.009) {
      return const PayoutDecision.deny('amount_mismatch');
    }
    final gross = price.toDouble();
    final commission = double.parse((gross * commissionRate).toStringAsFixed(2));
    final providerAmount =
        double.parse((gross - commission).toStringAsFixed(2));
    return PayoutDecision.allow(
      gross: gross,
      commission: commission,
      providerAmount: providerAmount,
    );
  }

  static String? completeBlockReason({
    required String currentStatus,
    required String paymentStatus,
  }) {
    final from = normalizeStatus(currentStatus);
    if (from != 'inProgress' &&
        from != 'awaitingPayment' &&
        from != 'paid') {
      return 'invalid_transition';
    }
    if (from != 'paid' && paymentStatus != 'paid') {
      return 'payment_not_confirmed';
    }
    if (!isAllowedTransition(from, 'completed')) {
      return 'invalid_transition';
    }
    return null;
  }

  static String? rejectDoubleCharge({required String paymentStatus}) {
    if (paymentStatus == 'paid') return 'already_paid';
    return null;
  }
}

class PayoutDecision {
  final bool ok;
  final String? reason;
  final double gross;
  final double commission;
  final double providerAmount;

  const PayoutDecision._({
    required this.ok,
    this.reason,
    this.gross = 0,
    this.commission = 0,
    this.providerAmount = 0,
  });

  const PayoutDecision.deny(String reason)
      : this._(ok: false, reason: reason);

  const PayoutDecision.allow({
    required double gross,
    required double commission,
    required double providerAmount,
  }) : this._(
          ok: true,
          gross: gross,
          commission: commission,
          providerAmount: providerAmount,
        );
}

class CloudCallException implements Exception {
  final String message;
  final String code;
  const CloudCallException(this.message, {this.code = 'internal'});
  @override
  String toString() => message;
}
