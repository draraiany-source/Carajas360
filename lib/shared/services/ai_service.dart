import 'package:flutter/material.dart';
import 'cloud_fn.dart';

/// Resposta estruturada da Central Carajás IA (callable `aiAssistant`).
class AiTurnResult {
  final String reply;
  final List<AiProviderCard> providers;
  final String source;
  final String mode;
  final String? conversationId;
  final double? costUsd;
  final bool consentRequired;

  const AiTurnResult({
    required this.reply,
    this.providers = const [],
    this.source = 'unknown',
    this.mode = 'client',
    this.conversationId,
    this.costUsd,
    this.consentRequired = false,
  });

  factory AiTurnResult.fromMap(Map<String, dynamic> data) {
    final raw = data['providers'];
    final cards = <AiProviderCard>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          cards.add(AiProviderCard.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }
    final cost = data['cost'];
    double? usd;
    if (cost is Map && cost['usd'] != null) {
      usd = (cost['usd'] as num?)?.toDouble();
    }
    return AiTurnResult(
      reply: (data['reply'] as String?)?.trim() ?? '',
      providers: cards,
      source: (data['source'] as String?) ?? 'unknown',
      mode: (data['mode'] as String?) ?? 'client',
      conversationId: data['conversationId'] as String?,
      costUsd: usd,
      consentRequired: data['source'] == 'consent_required',
    );
  }
}

class AiProviderCard {
  final String id, name;
  final String? city;
  final double rating;
  final List<String> categories;
  final List<String> modalities;
  final bool isTestSeed;

  const AiProviderCard({
    required this.id,
    required this.name,
    this.city,
    this.rating = 0,
    this.categories = const [],
    this.modalities = const [],
    this.isTestSeed = false,
  });

  factory AiProviderCard.fromMap(Map<String, dynamic> m) => AiProviderCard(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        city: m['city'] as String?,
        rating: (m['rating'] as num?)?.toDouble() ?? 0,
        categories: List<String>.from(m['categories'] ?? const []),
        modalities: List<String>.from(m['modalities'] ?? const []),
        isTestSeed: m['isTestSeed'] == true,
      );
}

/// Cliente da Central Carajás IA. Sempre via Cloud Function (sem chave no app).
class AiSvc {
  /// Pedido completo com modo/consentimento/cidade.
  static Future<AiTurnResult?> askTurn({
    required String message,
    List<Map<String, dynamic>> history = const [],
    String mode = 'client',
    String? city,
    String? category,
    String? conversationId,
    bool healthConsent = false,
  }) async {
    try {
      final data = await CloudFn.call('aiAssistant', {
        'message': message,
        'history': history,
        'mode': mode,
        if (city != null && city.isNotEmpty) 'city': city,
        if (category != null && category.isNotEmpty) 'category': category,
        if (conversationId != null) 'conversationId': conversationId,
        'healthConsent': healthConsent,
      });
      return AiTurnResult.fromMap(Map<String, dynamic>.from(data));
    } on CloudCallException catch (e) {
      debugPrint('IA CloudCallException: ${e.message}');
      // Propaga mensagem amigável via reply sintética (UI trata source).
      return AiTurnResult(
        reply: e.message.isNotEmpty
            ? e.message
            : 'Assistente indisponível neste ambiente (Function/API). '
                'Use Explorar ou o suporte.',
        source: 'unavailable',
        mode: mode,
      );
    } catch (e) {
      debugPrint('IA error: $e');
      return null;
    }
  }

  /// Compatível com chamadas antigas (só texto).
  static Future<String?> ask(
      String message, List<Map<String, dynamic>> history) async {
    final turn = await askTurn(message: message, history: history);
    return turn?.reply;
  }

  static Future<String?> suggestDescription(
      {required String category, required String draft}) async {
    if (draft.trim().isEmpty) return null;
    final prompt =
        'Reescreva a seguinte descrição de um pedido de serviço de $category de forma clara, '
        'profissional e objetiva, em no máximo 3 frases, sem inventar detalhes que não foram mencionados: "$draft"';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  static Future<String?> suggestBudget(
      {required String category, required String description}) async {
    final prompt =
        'Com base nesta descrição de serviço de $category: "$description", '
        'oriente o usuário a pedir orçamento a profissionais cadastrados. '
        'NÃO invente valores em reais. Diga apenas que o preço vem da proposta do profissional.';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  /// Sugestão de descrição para orçamento com fotos.
  /// [imageNotes] = legendas/observações do cliente (não inventar diagnóstico).
  /// Multimodal completo depende da Function; aqui enviamos metadados seguros.
  static Future<String?> suggestOrderDescriptionFromPhotos({
    required String draft,
    required int photoCount,
    List<String> imageNotes = const [],
  }) async {
    final notes = imageNotes.where((e) => e.trim().isNotEmpty).take(10).join('; ');
    final prompt = 'Cliente anexou $photoCount foto(s) do ambiente'
        '${notes.isEmpty ? '' : ' e observou: "$notes"'}. '
        'Rascunho: "${draft.trim()}". '
        'Sugira só uma descrição clara do pedido de orçamento em português. '
        'PROIBIDO: inventar diagnóstico técnico, materiais, prazos ou preços.';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  static Future<Map<String, dynamic>?> assistServiceRequest({
    required String freeText,
    String? city,
    String? urgency,
    String? neighborhood,
    List<Map<String, dynamic>> catalog = const [],
  }) async {
    try {
      final data = await CloudFn.call('assistServiceRequest', {
        'freeText': freeText,
        if (city != null) 'city': city,
        if (urgency != null) 'urgency': urgency,
        if (neighborhood != null) 'neighborhood': neighborhood,
        if (catalog.isNotEmpty) 'catalog': catalog,
      });
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('assistServiceRequest: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> publishAssistedRequest({
    required String idempotencyKey,
    required bool confirmed,
    required Map<String, dynamic> draft,
    List<Map<String, dynamic>> catalog = const [],
  }) async {
    try {
      final data = await CloudFn.call('publishAssistedRequest', {
        'idempotencyKey': idempotencyKey,
        'confirmed': confirmed,
        'draft': draft,
        if (catalog.isNotEmpty) 'catalog': catalog,
      });
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('publishAssistedRequest: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> assistProposalDraft({
    required String requestId,
    required double price,
    required int deadlineDays,
    String? requestSummary,
    bool materialsIncluded = false,
    String? conditions,
    List<String> providerServices = const [],
  }) async {
    try {
      final data = await CloudFn.call('assistProposalDraft', {
        'requestId': requestId,
        'price': price,
        'deadlineDays': deadlineDays,
        if (requestSummary != null) 'requestSummary': requestSummary,
        'materialsIncluded': materialsIncluded,
        if (conditions != null) 'conditions': conditions,
        if (providerServices.isNotEmpty) 'providerServices': providerServices,
      });
      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugPrint('assistProposalDraft: $e');
      return null;
    }
  }

  static Future<String?> smartSearchCategory(
      String query, List<String> availableCategories) async {
    if (query.trim().isEmpty) return null;
    final prompt =
        'Dado o pedido do usuário: "$query", qual dessas categorias é a mais adequada? '
        'Responda APENAS com o nome exato de uma categoria da lista, nada mais: ${availableCategories.join(", ")}';
    final reply = await ask(prompt, const []);
    if (reply == null) return null;
    final cleaned = reply.trim().toLowerCase();
    return availableCategories
        .firstWhere((c) => cleaned.contains(c.toLowerCase()), orElse: () => '');
  }
}
