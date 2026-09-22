import '../utils/firebase_bootstrap.dart';
import 'service_taxonomy.dart';

/// Carrega taxonomia remota (Firestore) e aplica overlay sem precisar
/// de nova versao do app. Em homologacao com placeholders, mantem seed.
abstract final class TaxonomyRepository {
  static bool _bootstrapped = false;

  static bool get bootstrapped => _bootstrapped;

  /// Parse documentos Firestore no formato TaxonomyVertical.toMap().
  static List<TaxonomyVertical> parseVerticalDocs(
      List<Map<String, dynamic>> docs) {
    final list = docs
        .map((m) => TaxonomyVertical.fromMap(m))
        .where((v) => v.id.isNotEmpty)
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Aplica overlay remoto. Docs vazios = limpa overlay (volta ao seed).
  static void applyDocs(List<Map<String, dynamic>> docs) {
    if (docs.isEmpty) {
      ServiceTaxonomy.clearRemoteOverlay();
      _bootstrapped = true;
      return;
    }
    final verts = parseVerticalDocs(docs);
    if (verts.isEmpty) {
      ServiceTaxonomy.clearRemoteOverlay();
    } else {
      ServiceTaxonomy.applyRemoteOverlay(verts);
    }
    _bootstrapped = true;
  }

  /// Homologacao: nunca sobrescreve seed com remoto vazio/incompleto.
  static bool get shouldPreferSeed =>
      FirebaseBootstrap.hasPlaceholderKeys;

  /// Mescla patches admin (ativar/desativar/ordem) sobre o seed em memoria.
  /// Usado quando Firestore ainda nao tem documento completo.
  static void patchGroupActive(String groupId, bool active) {
    final verts = ServiceTaxonomy.verticals.map((v) {
      final groups = v.groups.map((g) {
        if (g.id != groupId) return g;
        return TaxonomyGroup(
          id: g.id,
          name: g.name,
          verticalId: g.verticalId,
          emoji: g.emoji,
          color: g.color,
          services: g.services,
          active: active,
          order: g.order,
        );
      }).toList();
      return TaxonomyVertical(
        id: v.id,
        name: v.name,
        emoji: v.emoji,
        color: v.color,
        groups: groups,
        active: v.active,
        order: v.order,
        independentRoute: v.independentRoute,
      );
    }).toList();
    ServiceTaxonomy.applyRemoteOverlay(verts);
  }

  static void patchVerticalActive(String verticalId, bool active) {
    final verts = ServiceTaxonomy.verticals.map((v) {
      if (v.id != verticalId) return v;
      return TaxonomyVertical(
        id: v.id,
        name: v.name,
        emoji: v.emoji,
        color: v.color,
        groups: v.groups,
        active: active,
        order: v.order,
        independentRoute: v.independentRoute,
      );
    }).toList();
    ServiceTaxonomy.applyRemoteOverlay(verts);
  }

  static void patchServiceActive(String serviceId, bool active) {
    final verts = ServiceTaxonomy.verticals.map((v) {
      final groups = v.groups.map((g) {
        final services = g.services.map((s) {
          if (s.id != serviceId) return s;
          return TaxonomyService(
            id: s.id,
            name: s.name,
            categoryId: s.categoryId,
            groupId: s.groupId,
            description: s.description,
            pricingMode: s.pricingMode,
            suggestedFixedPrice: s.suggestedFixedPrice,
            questions: s.questions,
            active: active,
            requiredDocs: s.requiredDocs,
          );
        }).toList();
        return TaxonomyGroup(
          id: g.id,
          name: g.name,
          verticalId: g.verticalId,
          emoji: g.emoji,
          color: g.color,
          services: services,
          active: g.active,
          order: g.order,
        );
      }).toList();
      return TaxonomyVertical(
        id: v.id,
        name: v.name,
        emoji: v.emoji,
        color: v.color,
        groups: groups,
        active: v.active,
        order: v.order,
        independentRoute: v.independentRoute,
      );
    }).toList();
    ServiceTaxonomy.applyRemoteOverlay(verts);
  }

  /// Snapshot serializavel para persistir no backend.
  static List<Map<String, dynamic>> exportSeedMaps() =>
      ServiceTaxonomy.verticals.map((v) => v.toMap()).toList();
}
