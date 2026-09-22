import 'package:shared_preferences/shared_preferences.dart';

import '../catalog/homolog_catalog.dart';
import 'monetization_config.dart';
import '../../shared/services/cloud_fn.dart';

class UnlockLeadResult {
  final bool ok;
  final bool alreadyUnlocked;
  final int creditsUsed;
  final String? transactionId;
  final String? contactPhone;
  final String? contactName;
  final String? error;
  final String status;

  const UnlockLeadResult({
    required this.ok,
    this.alreadyUnlocked = false,
    this.creditsUsed = 0,
    this.transactionId,
    this.contactPhone,
    this.contactName,
    this.error,
    this.status = 'unlocked',
  });
}

/// Desbloqueio de contato por creditos — custo SEMPRE do servidor/config.
/// Homolog: simula com SharedPreferences (sem cobranca real).
abstract final class LeadUnlockService {
  static String _key(String providerId, String requestId) =>
      'lead_unlock_${providerId}_$requestId';

  static Future<bool> isUnlocked({
    required String providerId,
    required String requestId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(providerId, requestId)) == true;
  }

  static Future<UnlockLeadResult> unlock({
    required String requestId,
    required String providerId,
    required MonetizationConfig config,
  }) async {
    if (!config.creditsEnabled) {
      return const UnlockLeadResult(
          ok: false, error: 'Creditos desativados pelo Admin', status: 'disabled');
    }

    // Idempotencia local (homolog + reforco UX)
    if (await isUnlocked(providerId: providerId, requestId: requestId)) {
      return UnlockLeadResult(
        ok: true,
        alreadyUnlocked: true,
        creditsUsed: 0,
        transactionId: 'idem_$requestId',
        contactName: 'Cliente',
        contactPhone: HomologCatalog.enabled ? '(oculto ate autorizacao)' : null,
        status: 'already_unlocked',
      );
    }

    final cost = config.defaultLeadCreditCost;
    if (cost <= 0) {
      return const UnlockLeadResult(
          ok: false, error: 'Custo de lead invalido', status: 'invalid_cost');
    }

    // SEED/MOCK/HOMOLOGACAO — nunca cobra dinheiro real.
    if (HomologCatalog.enabled) {
      final prefs = await SharedPreferences.getInstance();
      final balKey = 'homolog_credits_$providerId';
      var bal = prefs.getInt(balKey) ?? 20; // welcome credits homolog
      if (bal < cost) {
        return UnlockLeadResult(
          ok: false,
          error: 'Saldo insuficiente ($bal creditos). Compre um pacote.',
          status: 'insufficient_credits',
        );
      }
      bal -= cost;
      await prefs.setInt(balKey, bal);
      await prefs.setBool(_key(providerId, requestId), true);
      final tx = 'htx_${DateTime.now().millisecondsSinceEpoch}';
      return UnlockLeadResult(
        ok: true,
        creditsUsed: cost,
        transactionId: tx,
        contactName: 'Cliente Homolog',
        contactPhone: '(94) 9XXXX-XXXX',
        status: 'unlocked',
      );
    }

    try {
      final raw = await CloudFn.call('unlockLeadContact', {
        'requestId': requestId,
        // cost NAO enviado — servidor define
      });
      final m = Map<String, dynamic>.from(raw as Map? ?? {});
      if (m['already'] == true) {
        return UnlockLeadResult(
          ok: true,
          alreadyUnlocked: true,
          creditsUsed: 0,
          transactionId: m['transactionId']?.toString(),
          contactName: m['contactName']?.toString(),
          contactPhone: m['contactPhone']?.toString(),
          status: 'already_unlocked',
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(providerId, requestId), true);
      return UnlockLeadResult(
        ok: m['ok'] == true,
        creditsUsed: (m['creditsUsed'] as num?)?.toInt() ?? cost,
        transactionId: m['transactionId']?.toString(),
        contactName: m['contactName']?.toString(),
        contactPhone: m['contactPhone']?.toString(),
        status: m['status']?.toString() ?? 'unlocked',
        error: m['error']?.toString(),
      );
    } catch (e) {
      return UnlockLeadResult(
          ok: false, error: e.toString(), status: 'error');
    }
  }

  static Future<int> homologCreditsBalance(String providerId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('homolog_credits_$providerId') ?? 20;
  }

  static Future<void> homologAddCredits(String providerId, int n) async {
    final prefs = await SharedPreferences.getInstance();
    final bal = await homologCreditsBalance(providerId);
    await prefs.setInt('homolog_credits_$providerId', bal + n);
  }
}
