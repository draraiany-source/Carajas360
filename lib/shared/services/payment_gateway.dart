/// Métodos de pagamento suportados pela plataforma.
///
/// A cobrança passa SEMPRE pelo backend (Fase 3): o pedido é criado antes
/// (createMarketOrder / createWalletRecharge) e o pagamento é iniciado por
/// `startPayment` com o id persistido. Ver lib/features/checkout/.
enum PaymentMethod { pix, creditCard, googlePay, applePay, wallet }

extension PaymentMethodX on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.pix => 'PIX',
        PaymentMethod.creditCard => 'Cartão de crédito',
        PaymentMethod.googlePay => 'Google Pay',
        PaymentMethod.applePay => 'Apple Pay',
        PaymentMethod.wallet => 'Carteira Carajás 360',
      };

  String get icon => switch (this) {
        PaymentMethod.pix => '⚡',
        PaymentMethod.creditCard => '💳',
        PaymentMethod.googlePay => '🟢',
        PaymentMethod.applePay => '',
        PaymentMethod.wallet => '👜',
      };

  /// Valor de `method` aceito por startPayment.
  String? get apiMethod => switch (this) {
        PaymentMethod.pix => 'pix',
        PaymentMethod.creditCard => 'card',
        PaymentMethod.wallet => 'wallet',
        _ => null,
      };
}

abstract class PaymentGateway {
  /// Métodos com integração efetiva (Mercado Pago sandbox + carteira
  /// interna). Apple Pay e Google Pay NÃO são oferecidos.
  static List<PaymentMethod> availableMethods({bool? isIOS}) => const [
        PaymentMethod.pix,
        PaymentMethod.creditCard,
        PaymentMethod.wallet,
      ];

  static bool isIntegrated(PaymentMethod m) => m.apiMethod != null;

  static bool needsDedicatedScreen(PaymentMethod method) =>
      method == PaymentMethod.creditCard || method == PaymentMethod.pix;
}
