import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/models/models.dart';
import 'catalog_text.dart';

/// Ordenação disponível (somente campos reais do perfil).
enum ProviderSort { rating, reviews, priceAsc }

/// Filtros da busca de profissionais. Distância e disponibilidade NÃO
/// existem: ainda não há dados reais para isso.
class ProviderQuery {
  /// Token do catálogo: `c:<categoria>`, `g:<grupo>` ou `s:<serviço>`.
  final String? catalogToken;

  /// Texto livre aplicado ao nome do profissional (prefixo das palavras).
  final String nameText;
  final String? city;
  final String? modality;
  final double? minRating;
  final double? maxInitialPrice;
  final ProviderSort sort;

  const ProviderQuery({
    this.catalogToken,
    this.nameText = '',
    this.city,
    this.modality,
    this.minRating,
    this.maxInitialPrice,
    this.sort = ProviderSort.rating,
  });

  /// Tokens que TODO resultado precisa ter (ver providerIndex no servidor).
  List<String> get requiredTokens => [
        if (catalogToken != null) catalogToken!,
        for (final w in CatalogText.normalize(nameText).split(' '))
          if (w.length >= 2) 'n:${w.length > 15 ? w.substring(0, 15) : w}',
        if (modality != null) 'm:$modality',
      ];

  String? get cityKey {
    final c = CatalogText.normalize(city);
    return c.isEmpty ? null : c;
  }

  /// Chave estável: muda quando qualquer filtro muda.
  String get key => [
        catalogToken, nameText.trim(), cityKey, modality, minRating,
        maxInitialPrice, sort.name
      ].join('|');

  /// O prestador satisfaz os filtros aplicados no app?
  bool matches(ProviderModel p) {
    if (!p.verified || !p.active) return false;
    final tokens = p.searchTokens.toSet();
    if (!requiredTokens.every(tokens.contains)) return false;
    if (cityKey != null && p.cityKey != cityKey) return false;
    if (minRating != null && p.rating < minRating!) return false;
    if (maxInitialPrice != null &&
        (p.minPrice == null || p.minPrice! > maxInitialPrice!)) {
      return false;
    }
    return true;
  }
}

class ProviderPage {
  final List<ProviderModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hasMore;
  const ProviderPage(this.items, this.cursor, this.hasMore);
}

/// Busca paginada por cursor, no servidor. Usa UM filtro `array-contains`
/// (Firestore só permite um) sobre `searchTokens`, mais cidade, faixa e
/// ordenação; os demais tokens são conferidos no app enquanto pagina
/// (laço de preenchimento com limite de leituras).
class ProviderSearch {
  final FirebaseFirestore db;
  ProviderSearch([FirebaseFirestore? db])
      : db = db ?? FirebaseFirestore.instance;

  static const maxBatchesPerPage = 4;

  Query<Map<String, dynamic>> buildQuery(ProviderQuery q) {
    Query<Map<String, dynamic>> query = db
        .collection('providers')
        .where('active', isEqualTo: true)
        .where('verified', isEqualTo: true);
    if (q.cityKey != null) query = query.where('cityKey', isEqualTo: q.cityKey);
    final primary = q.requiredTokens.isEmpty ? null : q.requiredTokens.first;
    if (primary != null) {
      query = query.where('searchTokens', arrayContains: primary);
    }
    switch (q.sort) {
      case ProviderSort.rating:
        if (q.minRating != null) {
          query = query.where('rating', isGreaterThanOrEqualTo: q.minRating);
        }
        query = query.orderBy('rating', descending: true);
      case ProviderSort.reviews:
        query = query.orderBy('totalReviews', descending: true);
      case ProviderSort.priceAsc:
        if (q.maxInitialPrice != null) {
          query = query.where('minPrice', isLessThanOrEqualTo: q.maxInitialPrice);
        }
        // Atenção: ordenar por preço exclui quem não informou preço.
        query = query.orderBy('minPrice');
    }
    return query;
  }

  Future<ProviderPage> fetch(ProviderQuery q,
      {DocumentSnapshot<Map<String, dynamic>>? after, int pageSize = 20}) async {
    final out = <ProviderModel>[];
    var cursor = after;
    var hasMore = true;
    for (var i = 0; i < maxBatchesPerPage && out.length < pageSize && hasMore; i++) {
      var query = buildQuery(q).limit(pageSize * 2);
      if (cursor != null) query = query.startAfterDocument(cursor);
      final snap = await query.get();
      for (final d in snap.docs) {
        final p = ProviderModel.fromMap(d.id, d.data());
        if (q.matches(p)) out.add(p);
      }
      if (snap.docs.isNotEmpty) cursor = snap.docs.last;
      hasMore = snap.docs.length == pageSize * 2;
    }
    return ProviderPage(out, cursor, hasMore);
  }
}

/// Empresa com perfil público autorizado (verificada e ativa).
class CompanyHit {
  final String id, name, ownerId;
  final String? city, logoUrl;
  const CompanyHit(
      {required this.id,
      required this.name,
      required this.ownerId,
      this.city,
      this.logoUrl});
}

class CompanySearch {
  final FirebaseFirestore db;
  CompanySearch([FirebaseFirestore? db])
      : db = db ?? FirebaseFirestore.instance;

  Future<List<CompanyHit>> byName(String text, {int limit = 10}) async {
    final words = CatalogText.normalize(text)
        .split(' ')
        .where((w) => w.length >= 2)
        .map((w) => 'n:${w.length > 15 ? w.substring(0, 15) : w}')
        .toList();
    if (words.isEmpty) return const [];
    final snap = await db
        .collection('companies')
        .where('verified', isEqualTo: true)
        .where('active', isEqualTo: true)
        .where('searchTokens', arrayContains: words.first)
        .orderBy('name')
        .limit(limit * 2)
        .get();
    return snap.docs
        .where((d) {
          final t = List<String>.from(d.data()['searchTokens'] ?? const []);
          return words.every(t.contains);
        })
        .take(limit)
        .map((d) => CompanyHit(
              id: d.id,
              name: (d.data()['name'] ?? '') as String,
              ownerId: (d.data()['ownerId'] ?? '') as String,
              city: d.data()['city'] as String?,
              logoUrl: d.data()['logoUrl'] as String?,
            ))
        .toList();
  }
}
