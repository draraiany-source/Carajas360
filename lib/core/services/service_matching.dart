import '../catalog/service_taxonomy.dart';
import '../../shared/models/models.dart';

/// Resultado ranqueado do matching técnico.
class MatchScore {
  final ProviderModel provider;
  final double score;
  final double distanceKm;
  final List<String> reasons;

  const MatchScore({
    required this.provider,
    required this.score,
    this.distanceKm = 0,
    this.reasons = const [],
  });
}

/// Matching estrito: só profissionais do serviço/categoria solicitada,
/// ativos, aprovados (verified quando exigido) e na região/raio.
abstract final class ServiceMatching {
  /// Raio padrão (km) quando o profissional não informa área.
  static const double defaultRadiusKm = 40;

  static List<MatchScore> rank({
    required List<ProviderModel> candidates,
    required String categoryId,
    String? city,
    String? modality,
    bool requireVerified = false,
    bool requireActive = true,
    double? clientLat,
    double? clientLng,
    double maxRadiusKm = defaultRadiusKm,
    Map<String, String>? answers,
  }) {
    final scores = <MatchScore>[];

    for (final p in candidates) {
      // 1) Adequação exata ao serviço/categoria — NUNCA fuzzy cross-domain
      if (!p.categories.contains(categoryId)) continue;
      if (requireActive && !p.active) continue;
      if (requireVerified && !p.verified) continue;

      // 2) Modalidade
      if (modality != null && modality.isNotEmpty) {
        final m = _normalizeModality(modality);
        if (m != null && p.modalities.isNotEmpty && !p.modalities.contains(m)) {
          // Remoto pode mapear para online
          if (!(m == 'online' && p.modalities.contains('online'))) {
            continue;
          }
        }
      }

      // 3) Região / cidade (quando informada)
      final cityOk = _cityCompatible(p, city);
      if (city != null && city.isNotEmpty && !cityOk) continue;

      final reasons = <String>[];
      double score = 0;

      // Adequação ao serviço
      score += 40;
      reasons.add('Atende o serviço');

      // Verificação
      if (p.verified) {
        score += 12;
        reasons.add('Verificado');
      }

      // Avaliação
      score += (p.rating.clamp(0, 5) / 5) * 20;
      if (p.rating >= 4.5) reasons.add('Alta avaliação');

      // Volume de histórico
      score += (p.totalReviews.clamp(0, 200) / 200) * 10;

      // Distância / cidade
      double dist = 0;
      if (city != null &&
          city.isNotEmpty &&
          p.city != null &&
          p.city!.toLowerCase().contains(city.toLowerCase())) {
        score += 12;
        reasons.add('Mesma cidade');
      } else if (p.serviceAreas.any((a) =>
          city != null && a.toLowerCase().contains(city.toLowerCase()))) {
        score += 8;
        reasons.add('Atende a região');
        dist = maxRadiusKm * 0.5;
      } else {
        dist = maxRadiusKm * 0.8;
      }

      if (dist > maxRadiusKm) continue;

      // Disponibilidade implícita (ativo)
      score += 6;

      // Respostas do questionário (ex.: urgência emergência prioriza quem tem guincho etc.)
      if (answers != null) {
        final urg = answers['urgency']?.toLowerCase() ?? '';
        if (urg.contains('emerg') &&
            (categoryId.contains('guincho') ||
                categoryId.contains('socorro') ||
                categoryId.contains('pane') ||
                categoryId.contains('bateria'))) {
          score += 5;
          reasons.add('Adequado a emergência');
        }
      }

      scores.add(MatchScore(
        provider: p,
        score: score,
        distanceKm: dist,
        reasons: reasons,
      ));
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores;
  }

  static bool _cityCompatible(ProviderModel p, String? city) {
    if (city == null || city.isEmpty) return true;
    final c = city.toLowerCase();
    if (p.city != null && p.city!.toLowerCase().contains(c)) return true;
    if (p.serviceAreas.any((a) => a.toLowerCase().contains(c))) return true;
    return false;
  }

  static String? _normalizeModality(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('remoto') || r.contains('online')) return 'online';
    if (r.contains('local') || r.contains('present') || r.contains('oficina')) {
      return 'presential';
    }
    if (r.contains('home')) return 'home_care';
    return null;
  }

  /// Valida se um serviço da taxonomia aceita o modo de preço escolhido.
  static bool pricingAllowed(TaxonomyService service, ServicePricingMode mode) {
    if (service.pricingMode == ServicePricingMode.both) return true;
    return service.pricingMode == mode;
  }
}
