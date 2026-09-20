/// Política oficial de pedidos / repasse / escrow (staging).
/// Espelhada em `functions/orderPolicy.js` — testes cobrem os dois lados.
///
/// **Escrow (staging):** fundos ficam retidos até liberação pelo backend.
/// O client Flutter MUST NOT chamar [releaseEscrow] nem alterar campos de escrow.
abstract final class OrderPolicy {
  static const commissionRate = 0.08;

  /// Dias de custódia após pagamento/conclusão antes de liberação automática.
  static const escrowHoldDays = 3;

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
    'escrowStatus',
    'heldAmount',
    'releaseAt',
    'releasedAt',
    'clientConfirmedAt',
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
    'anonymized',
    'deletedAt',
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

  static const escrowStatusAliases = <String, String>{
    'service_in_progress': 'serviceInProgress',
    'serviceinprogress': 'serviceInProgress',
    'release_pending': 'releasePending',
    'releasepending': 'releasePending',
  };

  /// Máquina de estados. pending ≈ created; inProgress ≈ in_progress.
  static const transitions = <String, Set<String>>{
    'pending': {'accepted', 'cancelled'},
    'accepted': {'inProgress', 'cancelled'},
    'inProgress': {'awaitingPayment', 'completed', 'cancelled', 'disputed'},
    'awaitingPayment': {'paid', 'completed', 'cancelled', 'disputed'},
    'paid': {'completed', 'refunded', 'disputed', 'cancelled'},
    'completed': {'refunded', 'cancelled'},
    'cancelled': {'refunded', 'pending', 'accepted'},
    'disputed': {'cancelled', 'refunded'},
    'refunded': {},
  };

  /// Fluxo escrow paralelo ao status do pedido (staging — sem gateway real).
  /// paid → held; serviço → serviceInProgress → releasePending → released.
  static const escrowTransitions = <String, Set<String>>{
    'held': {'serviceInProgress', 'disputed', 'refunded', 'cancelled'},
    'serviceInProgress': {'releasePending', 'disputed', 'refunded'},
    'releasePending': {'released', 'disputed', 'refunded'},
    'released': {},
    'disputed': {'refunded', 'cancelled'},
    'refunded': {},
    'cancelled': {},
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
    'cancelDefinitive': 'cancelled',
  };

  static const escrowActions = <String>{'hold', 'releaseEscrow'};
  static const adminOnlyActions = <String>{'reopen', 'cancelDefinitive'};

  static String normalizeStatus(String status) {
    final raw = status.isEmpty ? 'pending' : status;
    return statusAliases[raw] ??
        statusAliases[raw.toLowerCase()] ??
        raw;
  }

  static String normalizeEscrowStatus(String status) {
    final raw = status.isEmpty ? 'held' : status;
    return escrowStatusAliases[raw] ??
        escrowStatusAliases[raw.toLowerCase()] ??
        raw;
  }

  static bool isAllowedTransition(String from, String to) =>
      (transitions[normalizeStatus(from)] ?? const <String>{}).contains(
          normalizeStatus(to));

  static bool isAllowedEscrowTransition(String from, String to) =>
      (escrowTransitions[normalizeEscrowStatus(from)] ?? const <String>{})
          .contains(normalizeEscrowStatus(to));

  static String? targetStatus(String action) => actions[action];

  static bool isKnownAction(String action) =>
      actions.containsKey(action) ||
      action == 'reopen' ||
      escrowActions.contains(action);

  /// Admin reabre pedido cancelado → pending (sem prestador) ou accepted.
  static bool adminReopenAllowed(String fromStatus) =>
      normalizeStatus(fromStatus) == 'cancelled';

  static String adminReopenTarget({String? providerId}) {
    if (providerId != null && providerId.isNotEmpty) return 'accepted';
    return 'pending';
  }

  /// Cancelamento definitivo — bloqueado se já cancelado/reembolsado/liberado.
  static bool adminCancelDefinitiveAllowed({
    required String fromStatus,
    String? escrowStatus,
  }) {
    final st = normalizeStatus(fromStatus);
    if (st == 'cancelled' || st == 'refunded') return false;
    if (escrowStatus != null &&
        normalizeEscrowStatus(escrowStatus) == 'released') {
      return false;
    }
    return true;
  }

  /// Ao confirmar pagamento: retém valor e calcula releaseAt = paidAt + 3 dias.
  /// Trata `paid` como `held` para fundos do prestador (staging).
  static EscrowHoldResult escrowHoldOnPaid({
    required num amount,
    required DateTime paidAt,
  }) {
    return EscrowHoldResult(
      escrowStatus: 'held',
      heldAmount: amount,
      releaseAt: paidAt.add(const Duration(days: escrowHoldDays)),
    );
  }

  /// Liberação de escrow — SOMENTE backend/admin (Cloud Functions).
  /// Flutter client MUST NOT release funds.
  static EscrowReleaseDecision canReleaseEscrow({
    required String status,
    required String paymentStatus,
    required bool payoutProcessed,
    DateTime? completedAt,
    bool clientConfirmed = false,
    DateTime? now,
    DateTime? paidAt,
    DateTime? releaseAt,
    String? escrowStatus,
  }) {
    final es =
        escrowStatus != null ? normalizeEscrowStatus(escrowStatus) : null;
    if (es == 'released' || payoutProcessed) {
      return const EscrowReleaseDecision.deny('already_released');
    }
    if (es == 'disputed' || normalizeStatus(status) == 'disputed') {
      return const EscrowReleaseDecision.deny('disputed');
    }
    if (paymentStatus != 'paid') {
      return const EscrowReleaseDecision.deny('not_paid');
    }
    final st = normalizeStatus(status);
    if (st == 'refunded' || st == 'cancelled') {
      return const EscrowReleaseDecision.deny('order_closed');
    }

    if (clientConfirmed) {
      return const EscrowReleaseDecision.allow();
    }

    final clock = now ?? DateTime.now();
    if (releaseAt != null && !clock.isBefore(releaseAt)) {
      return const EscrowReleaseDecision.allow();
    }

    // Regra: após conclusão / 3 dias sem contestação (fallback paidAt+3d).
    final autoBase = completedAt ?? paidAt;
    if (autoBase != null) {
      final due = autoBase.add(const Duration(days: escrowHoldDays));
      if (!clock.isBefore(due)) {
        return const EscrowReleaseDecision.allow();
      }
    }

    return const EscrowReleaseDecision.deny('release_not_due');
  }

  static bool actorMayPerform({
    required String action,
    required String uid,
    required String clientId,
    required String? providerId,
    bool isAdmin = false,
  }) {
    if (isAdmin &&
        (action == 'refund' ||
            action == 'cancel' ||
            action == 'dispute' ||
            action == 'reopen' ||
            action == 'cancelDefinitive')) {
      return true;
    }
    if (action == 'hold' || action == 'releaseEscrow') {
      return isAdmin;
    }
    if (action == 'reopen' || action == 'cancelDefinitive') {
      return isAdmin;
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

class EscrowHoldResult {
  final String escrowStatus;
  final num heldAmount;
  final DateTime releaseAt;

  const EscrowHoldResult({
    required this.escrowStatus,
    required this.heldAmount,
    required this.releaseAt,
  });
}

class EscrowReleaseDecision {
  final bool ok;
  final String? reason;

  const EscrowReleaseDecision._({required this.ok, this.reason});

  const EscrowReleaseDecision.deny(String reason)
      : this._(ok: false, reason: reason);

  const EscrowReleaseDecision.allow() : this._(ok: true);
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
