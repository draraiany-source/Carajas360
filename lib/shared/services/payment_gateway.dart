import '../../core/utils/platform_info.dart';
import '../../shared/models/models.dart';
import 'firebase_service.dart';

/// Métodos de pagamento suportados pela plataforma.
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
}

/// Resultado padronizado, independente do provedor.
class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? error;
  final bool pending;
  final String? status;

  const PaymentResult(
      {required this.success,
      this.transactionId,
      this.error,
      this.pending = false,
      this.status});

  factory PaymentResult.ok(String id, {bool pending = false, String? status}) =>
      PaymentResult(
          success: true, transactionId: id, pending: pending, status: status);
  factory PaymentResult.fail(String error) =>
      PaymentResult(success: false, error: error);
}

class PlanChangeResult {
  final bool ok;
  final bool charged;
  final bool applied;
  final String status;
  final String message;
  final String? requestId;

  const PlanChangeResult({
    required this.ok,
    required this.charged,
    required this.applied,
    required this.status,
    required this.message,
    this.requestId,
  });
}

/// Contrato para trocar de gateway sem acoplar as telas.
abstract class PaymentGateway {
  Future<PaymentResult> createPayment({
    required PaymentMethod method,
    required double amount,
    required String description,
    required String orderId,
    String? email,
    String? cardToken,
    int installments = 1,
  });

  Future<PaymentResult> checkPayment(String paymentId);

  Future<PaymentResult> refundPayment({
    required String orderId,
    double? amount,
  });

  Future<PaymentResult> processPayout({required String orderId});
}

/// Mercado Pago (legado/atual). Não remover: é o único provedor ligado.
/// Staging: as callables recusam cobrança real se PAYMENTS_ENABLED=false.
/// Ver PAGAMENTOS_STAGING.md.
class MercadoPagoGateway implements PaymentGateway {
  @override
  Future<PaymentResult> createPayment({
    required PaymentMethod method,
    required double amount,
    required String description,
    required String orderId,
    String? email,
    String? cardToken,
    int installments = 1,
  }) async {
    switch (method) {
      case PaymentMethod.pix:
        final data = await PaySvc.generatePix(
            amount: amount,
            description: description,
            email: email ?? '',
            orderId: orderId);
        if (data == null) {
          return PaymentResult.fail(
              'Não foi possível gerar o PIX (staging: pagamentos reais desligados).');
        }
        return PaymentResult.ok(data['id']?.toString() ?? orderId,
            pending: true, status: data['status']?.toString());

      case PaymentMethod.wallet:
        final ok = await FS.payOrderWithWallet(orderId);
        return ok
            ? PaymentResult.ok(orderId)
            : PaymentResult.fail(
                'Não foi possível pagar com a carteira. Confira o saldo e o preço do pedido.');

      case PaymentMethod.creditCard:
        if (cardToken == null || cardToken.isEmpty) {
          return PaymentResult.fail(
              'Use a tela de cartão para tokenizar antes de cobrar.');
        }
        final data = await PaySvc.payWithCard(
          amount: amount,
          description: description,
          email: email ?? '',
          orderId: orderId,
          cardToken: cardToken,
          installments: installments,
        );
        if (data == null) {
          return PaymentResult.fail(
              'Não foi possível cobrar o cartão (staging: pagamentos reais desligados).');
        }
        final status = data['status']?.toString();
        final pending = status != 'approved';
        return PaymentResult.ok(data['id']?.toString() ?? orderId,
            pending: pending, status: status);

      case PaymentMethod.googlePay:
      case PaymentMethod.applePay:
        return PaymentResult.fail(
            '${method.label} ainda não está ativado. Configure as credenciais de merchant para habilitar.');
    }
  }

  @override
  Future<PaymentResult> checkPayment(String paymentId) async {
    final status = await PaySvc.checkPayment(paymentId);
    if (status == null) {
      return PaymentResult.fail('Não foi possível consultar o pagamento.');
    }
    final approved = status == 'approved';
    return PaymentResult(
      success: approved,
      pending: !approved && status != 'rejected' && status != 'cancelled',
      transactionId: paymentId,
      status: status,
    );
  }

  @override
  Future<PaymentResult> refundPayment({
    required String orderId,
    double? amount,
  }) async {
    try {
      final data = await CloudFn.call('processRefund', {
        'orderId': orderId,
        if (amount != null) 'amount': amount,
      });
      return PaymentResult.ok(orderId, status: data['status']?.toString());
    } on CloudCallException catch (e) {
      return PaymentResult.fail(e.message);
    } catch (e) {
      return PaymentResult.fail('Falha ao registrar estorno.');
    }
  }

  @override
  Future<PaymentResult> processPayout({required String orderId}) async {
    try {
      final data = await CloudFn.call('processPayout', {'orderId': orderId});
      return PaymentResult.ok(orderId,
          status: data['payoutProcessed'] == true ? 'done' : 'pending');
    } on CloudCallException catch (e) {
      return PaymentResult.fail(e.message);
    } catch (e) {
      return PaymentResult.fail('Falha ao processar o repasse.');
    }
  }
}

/// Fachada do app. Trocar de provedor = substituir [gateway].
abstract final class PaymentService {
  static PaymentGateway gateway = MercadoPagoGateway();

  static List<PaymentMethod> availableMethods({bool? isIOS}) {
    final apple = isIOS ?? PlatformInfo.isIOS;
    return [
      PaymentMethod.pix,
      PaymentMethod.creditCard,
      if (apple) PaymentMethod.applePay else PaymentMethod.googlePay,
      PaymentMethod.wallet,
    ];
  }

  static bool needsDedicatedScreen(PaymentMethod method) =>
      method == PaymentMethod.creditCard || method == PaymentMethod.pix;

  static Future<PaymentResult> createPayment({
    required PaymentMethod method,
    required double amount,
    required String description,
    required String orderId,
    String? email,
    String? cardToken,
    int installments = 1,
  }) =>
      gateway.createPayment(
        method: method,
        amount: amount,
        description: description,
        orderId: orderId,
        email: email,
        cardToken: cardToken,
        installments: installments,
      );

  static Future<PaymentResult> checkPayment(String paymentId) =>
      gateway.checkPayment(paymentId);

  static Future<PaymentResult> refundPayment({
    required String orderId,
    double? amount,
  }) =>
      gateway.refundPayment(orderId: orderId, amount: amount);

  static Future<PaymentResult> processPayout({required String orderId}) =>
      gateway.processPayout(orderId: orderId);

  /// Compatível com o ponto único antigo (`charge`).
  static Future<PaymentResult> charge({
    required PaymentMethod method,
    required double amount,
    required String description,
    required String orderId,
    String? email,
  }) =>
      createPayment(
        method: method,
        amount: amount,
        description: description,
        orderId: orderId,
        email: email,
      );

  /// Pedido de plano. Staging: nunca cobra e nunca aplica o plano.
  static Future<PlanChangeResult> requestPlanChange(PlanTier plan) async {
    try {
      final data = await CloudFn.call('requestPlanChange', {'plan': plan.name});
      return PlanChangeResult(
        ok: data['ok'] == true,
        charged: data['charged'] == true,
        applied: data['applied'] == true,
        status: data['status']?.toString() ?? 'pending_sandbox',
        message: data['message']?.toString() ??
            'Pedido registrado. Nenhuma cobrança foi feita.',
        requestId: data['requestId']?.toString(),
      );
    } on CloudCallException catch (e) {
      return PlanChangeResult(
        ok: false,
        charged: false,
        applied: false,
        status: 'error',
        message: e.message,
      );
    } catch (e) {
      return PlanChangeResult(
        ok: false,
        charged: false,
        applied: false,
        status: 'error',
        message: 'Não foi possível registrar o pedido de plano.',
      );
    }
  }
}
