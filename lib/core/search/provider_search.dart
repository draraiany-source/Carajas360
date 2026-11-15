import '../../shared/models/models.dart';
import '../constants/app_constants.dart';
import 'universal_search.dart';

enum ProviderSort { relevance, rating, reviews, price }

const providerSortLabels = {
  ProviderSort.relevance: 'Mais relevantes',
  ProviderSort.rating: 'Melhor avaliados',
  ProviderSort.reviews: 'Mais avaliados',
  ProviderSort.price: 'Menor preço',
};

/// Critérios da busca de profissionais (Explorar Serviços).
///
/// [scopeIds] vem da categoria escolhida (ids estáveis de [Categories]);
/// [specialties] é um subconjunto opcional escolhido pelo usuário.
class ProviderSearchCriteria {
  final String query;
  final Set<String> scopeIds;
  final Set<String> specialties;
  final String? city;
  final double minRating;

  /// 'presential' | 'online' — modalidade de atendimento cadastrada.
  final String? modality;
  final double? maxPrice;

  /// `true`: só quem informou preço inicial; `false`: só "sob orçamento"
  /// (sem preço informado); `null`: ambos.
  final bool? priceInformed;
  final ProviderSort sort;

  const ProviderSearchCriteria({
    this.query = '',
    this.scopeIds = const {},
    this.specialties = const {},
    this.city,
    this.minRating = 0,
    this.modality,
    this.maxPrice,
    this.priceInformed,
    this.sort = ProviderSort.relevance,
  });

  /// Ids que um profissional precisa ter (ao menos um) para aparecer.
  Set<String> get effectiveIds => specialties.isNotEmpty ? specialties : scopeIds;

  bool get hasFilters =>
      scopeIds.isNotEmpty ||
      specialties.isNotEmpty ||
      city != null ||
      minRating > 0 ||
      modality != null ||
      maxPrice != null ||
      priceInformed != null ||
      sort != ProviderSort.relevance;
}

abstract final class ProviderSearch {
  static String norm(String s) => UniversalSearch.normalize(s);

  /// Ids de categoria ligados a um grupo (ex.: 'Casa').
  static Set<String> idsForGroup(String group) =>
      Categories.all.where((c) => c.group == group).map((c) => c.id).toSet();

  static String categoryName(String id) => Categories.byId(id)?.name ?? id;

  static String _haystack(ProviderModel p) => [
        p.name,
        for (final c in p.categories) ...[categoryName(c), c.replaceAll('_', ' ')],
        p.bio ?? '',
        p.city ?? '',
        ...p.serviceAreas,
      ].join(' ');

  /// Todas as palavras precisam casar (sem diferenciar acentos/maiúsculas).
  static bool matchesQuery(ProviderModel p, String query) {
    final q = norm(query);
    if (q.isEmpty) return true;
    final hay = _haystack(p);
    return q.split(' ').every((w) => UniversalSearch.fuzzyMatch(hay, w));
  }

  static bool matchesCity(ProviderModel p, String? city) {
    if (city == null || city.isEmpty) return true;
    final c = norm(city);
    if (p.city != null && norm(p.city!) == c) return true;
    return p.serviceAreas.any((a) => norm(a) == c);
  }

  /// Nota só conta quando há avaliações reais.
  static double effectiveRating(ProviderModel p) =>
      p.totalReviews > 0 ? p.rating : 0;

  static int _relevance(ProviderModel p, String query) {
    final q = norm(query);
    if (q.isEmpty) return 0;
    final name = norm(p.name);
    if (name.startsWith(q)) return 4;
    if (name.contains(q)) return 3;
    if (p.categories.any((c) => norm(categoryName(c)).contains(q))) return 2;
    return 1;
  }

  static bool matches(ProviderModel p, ProviderSearchCriteria c) {
    if (!p.active) return false;
    final ids = c.effectiveIds;
    if (ids.isNotEmpty && !p.categories.any(ids.contains)) return false;
    if (!matchesQuery(p, c.query)) return false;
    if (!matchesCity(p, c.city)) return false;
    if (c.minRating > 0 &&
        (p.totalReviews == 0 || p.rating < c.minRating)) {
      return false;
    }
    if (c.modality != null && !p.modalities.contains(c.modality)) return false;
    if (c.maxPrice != null &&
        (p.minPrice == null || p.minPrice! > c.maxPrice!)) {
      return false;
    }
    if (c.priceInformed == true && p.minPrice == null) return false;
    if (c.priceInformed == false && p.minPrice != null) return false;
    return true;
  }

  static List<ProviderModel> apply(
      List<ProviderModel> all, ProviderSearchCriteria c) {
    final list = all.where((p) => matches(p, c)).toList();
    int byRating(ProviderModel a, ProviderModel b) {
      final r = effectiveRating(b).compareTo(effectiveRating(a));
      if (r != 0) return r;
      final v = b.totalReviews.compareTo(a.totalReviews);
      return v != 0 ? v : a.name.compareTo(b.name);
    }

    switch (c.sort) {
      case ProviderSort.relevance:
        list.sort((a, b) {
          final r = _relevance(b, c.query).compareTo(_relevance(a, c.query));
          return r != 0 ? r : byRating(a, b);
        });
      case ProviderSort.rating:
        list.sort(byRating);
      case ProviderSort.reviews:
        list.sort((a, b) {
          final v = b.totalReviews.compareTo(a.totalReviews);
          return v != 0 ? v : byRating(a, b);
        });
      case ProviderSort.price:
        list.sort((a, b) {
          final pa = a.minPrice, pb = b.minPrice;
          if (pa == null && pb == null) return byRating(a, b);
          if (pa == null) return 1;
          if (pb == null) return -1;
          final v = pa.compareTo(pb);
          return v != 0 ? v : byRating(a, b);
        });
    }
    return list;
  }

  /// Especialidades da categoria que têm ao menos um profissional carregado.
  static List<String> availableSpecialties(
      List<ProviderModel> all, Set<String> scopeIds) {
    if (scopeIds.length < 2) return const [];
    final present = <String>{
      for (final p in all)
        if (p.active) ...p.categories.where(scopeIds.contains),
    };
    return scopeIds.where(present.contains).toList()
      ..sort((a, b) => categoryName(a).compareTo(categoryName(b)));
  }

  /// Especialidade mostrada no cartão: a que casou com o filtro ativo.
  static String specialtyLabel(ProviderModel p, {Set<String> prefer = const {}}) {
    if (p.categories.isEmpty) return 'Profissional';
    final hit = p.categories.firstWhere(prefer.contains,
        orElse: () => p.categories.first);
    return categoryName(hit);
  }

  static int pageCount(int total, int pageSize) =>
      total == 0 ? 0 : (total / pageSize).ceil();

  static List<T> pageSlice<T>(List<T> list, int page, int pageSize) {
    final pages = pageCount(list.length, pageSize);
    if (pages == 0) return const [];
    final p = page.clamp(0, pages - 1);
    return list.skip(p * pageSize).take(pageSize).toList();
  }
}
