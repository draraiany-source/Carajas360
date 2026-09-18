import 'package:flutter/material.dart';
import 'cloud_fn.dart';

// ── Assistente de IA (Vol.28: IA e Automações) ────────────────
// Usa a Cloud Function `aiAssistant` (Claude API). Se o backend não
// estiver configurado ou a chamada falhar, retorna null e a tela de
// IA cai automaticamente no modo de respostas locais (fallback),
// garantindo que o assistente nunca trave para o usuário.
class AiSvc {
  static Future<String?> ask(
      String message, List<Map<String, dynamic>> history) async {
    try {
      final data = await CloudFn.call('aiAssistant', {
        'message': message,
        'history': history,
      });
      return data['reply'] as String?;
    } catch (e) {
      debugPrint('IA error: $e');
      return null;
    }
  }

  // ── Sugestão automática de descrição (Vol.11: IA) ──────────────
  // Usado em RequestServiceScreen: o cliente digita algumas palavras
  // soltas e a IA transforma em uma descrição profissional e clara
  // para o prestador entender o pedido.
  static Future<String?> suggestDescription(
      {required String category, required String draft}) async {
    if (draft.trim().isEmpty) return null;
    final prompt =
        'Reescreva a seguinte descrição de um pedido de serviço de $category de forma clara, '
        'profissional e objetiva, em no máximo 3 frases, sem inventar detalhes que não foram mencionados: "$draft"';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  // ── Sugestão de orçamento (Vol.11: IA) ──────────────────────────
  // Estima uma faixa de preço razoável com base na categoria e na
  // descrição do serviço, para orientar o cliente antes de negociar
  // com o prestador. Sempre deixa claro que é uma estimativa.
  static Future<String?> suggestBudget(
      {required String category, required String description}) async {
    final prompt =
        'Com base nesta descrição de serviço de $category: "$description", '
        'sugira uma faixa de preço razoável em reais para o mercado brasileiro atual. '
        'Responda em uma única frase curta, no formato "Entre R\$ X e R\$ Y", sem explicações adicionais.';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  // ── Busca inteligente (Vol.11: IA) ──────────────────────────────
  // Interpreta uma busca em linguagem natural (ex.: "preciso de
  // alguém pra consertar vazamento no banheiro amanhã") e devolve a
  // categoria mais próxima do catálogo do app, para pré-filtrar a
  // busca em vez do usuário navegar pelas categorias manualmente.
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
