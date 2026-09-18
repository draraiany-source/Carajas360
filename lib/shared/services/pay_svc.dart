import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/constants/runtime_config.dart';
import 'cloud_fn.dart';
import 'firestore_facade.dart';

class PaySvc {
  // Public Key do Mercado Pago via --dart-define=MERCADOPAGO_PUBLIC_KEY=...
  static String get _mpPublicKey => RuntimeConfig.mercadoPagoPublicKey;

  static Future<Map<String, dynamic>?> generatePix(
      {required double amount,
      required String description,
      required String email,
      required String orderId,
      String? userId,
      String purpose = 'order'}) async {
    try {
      return await CloudFn.call('generatePix', {
        'amount': amount,
        'description': description,
        'email': email,
        if (orderId.isNotEmpty) 'orderId': orderId,
        'purpose': purpose,
      });
    } catch (e) {
      debugPrint('PIX error: $e');
      return null;
    }
  }

  static Future<String?> checkPayment(String paymentId) async {
    try {
      final data = await CloudFn.call('checkPayment', {'id': paymentId});
      return data['status'] as String?;
    } catch (e) {
      debugPrint('checkPayment error: $e');
      return null;
    }
  }

  // ── Cartão de crédito (Vol.17: Pagamentos) ─────────────────────
  // Tokeniza o cartão direto com o Mercado Pago (nunca passa pelo
  // nosso backend em texto puro — exigência de PCI-DSS) e então
  // envia apenas o token para a Cloud Function processar a cobrança.
  static Future<String?> tokenizeCard({
    required String cardNumber,
    required String holderName,
    required String expMonth,
    required String expYear,
    required String cvv,
    required String docNumber,
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse(
                'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'card_number': cardNumber.replaceAll(' ', ''),
              'cardholder': {
                'name': holderName,
                'identification': {'type': 'CPF', 'number': docNumber}
              },
              'expiration_month': int.tryParse(expMonth) ?? 1,
              'expiration_year':
                  int.tryParse('20$expYear') ?? DateTime.now().year,
              'security_code': cvv,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200 || r.statusCode == 201)
        return (jsonDecode(r.body) as Map)['id'] as String?;
      debugPrint('Tokenização de cartão falhou: ${r.body}');
      return null;
    } catch (e) {
      debugPrint('Erro ao tokenizar cartão: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> payWithCard({
    required double amount,
    required String description,
    required String email,
    required String orderId,
    required String cardToken,
    int installments = 1,
    String? docNumber,
  }) async {
    try {
      return await CloudFn.call('processCardPayment', {
        'description': description,
        'email': email,
        'orderId': orderId,
        'cardToken': cardToken,
        'installments': installments,
        'payerDocNumber': docNumber,
      });
    } catch (e) {
      debugPrint('Erro no pagamento com cartão: $e');
      return null;
    }
  }

  static Future<bool> payWallet(double amount, String desc, String icon) =>
      FS.debit(amount, desc, icon);
  static double fee(double amount) => amount * AppConst.commission;
  static String fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}
