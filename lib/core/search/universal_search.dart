import 'dart:math';

import '../catalog/service_taxonomy.dart';
import '../../shared/models/models.dart';

enum UniversalHitKind {
  vertical,
  group,
  service,
  category,
  provider,
  company,
}

class UniversalHit {
  final UniversalHitKind kind;
  final String id;
  final String title;
  final String subtitle;
  final double score;
  final String? categoryId;
  final String? serviceId;
  final String? verticalId;
  final String? groupId;
  final String? routeHint;

  const UniversalHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.score,
    this.categoryId,
    this.serviceId,
    this.verticalId,
    this.groupId,
    this.routeHint,
  });
}

/// Busca universal multi-entidade (FASE 1).
/// Pura / testável — sem Firebase.
abstract final class UniversalSearch {
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    return s.replaceAll(RegExp(r'\s+'), ' ');
  }

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) {
      m[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      m[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        m[i][j] = [
          m[i - 1][j] + 1,
          m[i][j - 1] + 1,
          m[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return m[a.length][b.length];
  }

  static bool fuzzyMatch(String haystack, String needle) {
    final h = normalize(haystack);
    final n = normalize(needle);
    if (n.isEmpty) return true;
    if (h.contains(n)) return true;
    for (final token in h.split(' ')) {
      if (token.isEmpty) continue;
      if (token.startsWith(n) || n.startsWith(token)) return true;
      final maxDist = n.length <= 4 ? 1 : 2;
      if ((token.length - n.length).abs() <= maxDist &&
          levenshtein(token, n) <= maxDist) {
        return true;
      }
    }
    return false;
  }

  static double _score(String title, String query) {
    final t = normalize(title);
    final q = normalize(query);
    if (t == q) return 100;
    if (t.startsWith(q)) return 90;
    if (t.contains(q)) return 75;
    if (fuzzyMatch(title, query)) return 55;
    return 0;
  }

  static List<UniversalHit> search({
    required String query,
    List<TaxonomyVertical>? verticals,
    List<ProviderModel> providers = const [],
    List<CompanyModel> companies = const [],
    int limit = 40,
  }) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final verts = verticals ?? ServiceTaxonomy.verticals;
    final hits = <UniversalHit>[];

    for (final v in verts) {
      if (!v.active) continue;
      final vs = _score(v.name, q);
      if (vs > 0) {
        hits.add(UniversalHit(
          kind: UniversalHitKind.vertical,
          id: v.id,
          title: v.name,
          subtitle: 'Categoria',
          score: vs + 5,
          verticalId: v.id,
          routeHint: v.independentRoute,
        ));
      }
      for (final g in v.groups) {
        if (!g.active) continue;
        final gs = _score(g.name, q);
        if (gs > 0) {
          hits.add(UniversalHit(
            kind: UniversalHitKind.group,
            id: g.id,
            title: g.name,
            subtitle: 'Subcategoria · ${v.name}',
            score: gs + 3,
            verticalId: v.id,
            groupId: g.id,
          ));
        }
        for (final s in g.services) {
          if (!s.active) continue;
          final ss = max(_score(s.name, q), _score(s.categoryId.replaceAll('_', ' '), q));
          if (ss > 0) {
            hits.add(UniversalHit(
              kind: UniversalHitKind.service,
              id: s.id,
              title: s.name,
              subtitle: 'Serviço · ${g.name}',
              score: ss + 8,
              categoryId: s.categoryId,
              serviceId: s.id,
              verticalId: v.id,
              groupId: g.id,
            ));
          }
        }
      }
    }

    for (final p in providers) {
      if (!p.active) continue;
      var best = _score(p.name, q);
      best = max(best, _score(p.bio ?? '', q));
      best = max(best, _score(p.city ?? '', q));
      for (final c in p.categories) {
        best = max(best, _score(c.replaceAll('_', ' '), q));
      }
      if (best > 0) {
        hits.add(UniversalHit(
          kind: UniversalHitKind.provider,
          id: p.id,
          title: p.name,
          subtitle: 'Profissional · ${p.city ?? ''}'.trim(),
          score: best + 2,
          categoryId: p.categories.isNotEmpty ? p.categories.first : null,
        ));
      }
    }

    for (final c in companies) {
      if (!c.active) continue;
      var best = _score(c.name, q);
      best = max(best, _score(c.city ?? '', q));
      for (final cat in c.categories) {
        best = max(best, _score(cat.replaceAll('_', ' '), q));
      }
      if (best > 0) {
        hits.add(UniversalHit(
          kind: UniversalHitKind.company,
          id: c.id,
          title: c.name,
          subtitle: 'Empresa · ${c.city ?? ''}'.trim(),
          score: best + 1,
        ));
      }
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  /// Sugestões leves enquanto digita (prefixo / fuzzy curto).
  static List<String> suggest({
    required String query,
    List<TaxonomyVertical>? verticals,
    int limit = 8,
  }) {
    final q = query.trim();
    if (q.length < 2) return const [];
    final hits = search(query: q, verticals: verticals, limit: limit * 2);
    final seen = <String>{};
    final out = <String>[];
    for (final h in hits) {
      if (seen.add(h.title)) out.add(h.title);
      if (out.length >= limit) break;
    }
    return out;
  }
}
