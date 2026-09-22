/// Valores monetarios em centavos (evita erro de ponto flutuante).
class MoneyCents {
  final int cents;
  const MoneyCents(this.cents);
  factory MoneyCents.fromReais(num reais) =>
      MoneyCents(((reais * 100).round()));
  double get reais => cents / 100.0;
  String get formatted {
    final r = reais.toStringAsFixed(2).replaceAll('.', ',');
    return 'R\$ $r';
  }
  MoneyCents operator +(MoneyCents o) => MoneyCents(cents + o.cents);
  MoneyCents operator -(MoneyCents o) => MoneyCents(cents - o.cents);
  bool operator >(MoneyCents o) => cents > o.cents;
  bool operator <(MoneyCents o) => cents < o.cents;
  bool get isNegative => cents < 0;
  bool get isZero => cents == 0;
}

/// Calculadora de comissao / split (server e client — client so para exibir).
class CommissionSplit {
  final MoneyCents gross;
  final MoneyCents gatewayFee;
  final MoneyCents platformCommission;
  final MoneyCents professionalAmount;
  final double commissionRate;

  const CommissionSplit({
    required this.gross,
    required this.gatewayFee,
    required this.platformCommission,
    required this.professionalAmount,
    required this.commissionRate,
  });

  /// base = gross - gatewayFee (quando configured); comissao sobre base.
  static CommissionSplit calculate({
    required MoneyCents gross,
    required double commissionRate,
    MoneyCents gatewayFee = const MoneyCents(0),
  }) {
    final rate = commissionRate.clamp(0.0, 0.30);
    final baseCents = (gross.cents - gatewayFee.cents).clamp(0, 1 << 62);
    final platform = MoneyCents((baseCents * rate).round());
    final pro = MoneyCents(baseCents - platform.cents);
    return CommissionSplit(
      gross: gross,
      gatewayFee: gatewayFee,
      platformCommission: platform,
      professionalAmount: pro,
      commissionRate: rate,
    );
  }

  Map<String, dynamic> toAuditMap() => {
        'grossCents': gross.cents,
        'gatewayFeeCents': gatewayFee.cents,
        'platformCommissionCents': platformCommission.cents,
        'professionalAmountCents': professionalAmount.cents,
        'commissionRate': commissionRate,
      };
}
