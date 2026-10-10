import 'catalog.dart';

/// Seleção Categoria → Grupo → Serviço (imutável, sem Flutter/Firebase).
/// Trocar o nível superior limpa os níveis inferiores incompatíveis.
class CatalogSelection {
  final String? categoryId;
  final String? groupId;
  final String? serviceId;

  const CatalogSelection({this.categoryId, this.groupId, this.serviceId});

  static const none = CatalogSelection();

  bool get isEmpty => categoryId == null;

  /// Item mais específico selecionado (o que vai para a contratação).
  String? get selectedId => serviceId ?? groupId ?? categoryId;

  CatalogSelection selectCategory(String? id) => id == categoryId
      ? this
      : CatalogSelection(categoryId: id);

  CatalogSelection selectGroup(Catalog c, String? id) {
    if (id == null) return CatalogSelection(categoryId: categoryId);
    final cat = c.byId(id)?.parentId;
    final keepService = serviceId != null && c.byId(serviceId)?.parentId == id;
    return CatalogSelection(
        categoryId: cat ?? categoryId,
        groupId: id,
        serviceId: keepService ? serviceId : null);
  }

  CatalogSelection selectService(Catalog c, String? id) {
    if (id == null) return CatalogSelection(categoryId: categoryId, groupId: groupId);
    final group = c.byId(id)?.parentId;
    final cat = group == null ? categoryId : c.byId(group)?.parentId;
    return CatalogSelection(categoryId: cat, groupId: group, serviceId: id);
  }

  /// Toggle (tocar de novo desmarca só aquele nível).
  CatalogSelection toggle(Catalog c, CatalogNode n) => switch (n.level) {
        CatalogLevel.category =>
          n.id == categoryId ? none : selectCategory(n.id),
        CatalogLevel.group => n.id == groupId
            ? CatalogSelection(categoryId: categoryId)
            : selectGroup(c, n.id),
        CatalogLevel.service => n.id == serviceId
            ? CatalogSelection(categoryId: categoryId, groupId: groupId)
            : selectService(c, n.id),
      };

  /// Seleção a partir de qualquer item (deep link / resultado de busca).
  static CatalogSelection forNode(Catalog c, String id) {
    final path = c.pathOf(id);
    String? of(CatalogLevel l) {
      for (final n in path) {
        if (n.level == l) return n.id;
      }
      return null;
    }

    return CatalogSelection(
        categoryId: of(CatalogLevel.category),
        groupId: of(CatalogLevel.group),
        serviceId: of(CatalogLevel.service));
  }

  /// Remove níveis que deixaram de existir/estar ativos no catálogo.
  CatalogSelection sanitize(Catalog c) {
    if (categoryId == null || !c.isActive(categoryId!)) return none;
    if (groupId == null || !c.isActive(groupId!)) {
      return CatalogSelection(categoryId: categoryId);
    }
    if (serviceId != null && !c.isActive(serviceId!)) {
      return CatalogSelection(categoryId: categoryId, groupId: groupId);
    }
    return this;
  }

  /// Token de busca de prestadores para a seleção.
  String? token(Catalog c) {
    final n = c.byId(selectedId);
    return n == null ? null : Catalog.tokenFor(n);
  }

  /// O prestador (categorias declaradas) é compatível com a seleção?
  /// Compara pelo caminho: declarar o grupo é compatível com o grupo e a
  /// categoria, mas NÃO com um serviço específico não declarado.
  bool matches(Catalog c, List<String> declared) {
    final sel = selectedId;
    if (sel == null) return true;
    final level = c.byId(sel)?.level;
    for (final id in declared) {
      if (id == sel) return true;
      if (level != CatalogLevel.service &&
          c.pathOf(id).any((n) => n.id == sel)) {
        return true;
      }
    }
    return false;
  }

  /// Especialidade levada para a contratação: a seleção, se o prestador a
  /// declarou; senão, a especialidade dele dentro da seleção; senão, a
  /// primeira declarada.
  String contractedCategory(Catalog c, List<String> declared) {
    final sel = selectedId;
    if (sel != null && declared.contains(sel)) return sel;
    if (sel != null) {
      for (final id in declared) {
        if (c.pathOf(id).any((n) => n.id == sel)) return id;
      }
    }
    return declared.isNotEmpty ? declared.first : '';
  }

  String get key => '${categoryId ?? ''}|${groupId ?? ''}|${serviceId ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is CatalogSelection &&
      other.categoryId == categoryId &&
      other.groupId == groupId &&
      other.serviceId == serviceId;

  @override
  int get hashCode => Object.hash(categoryId, groupId, serviceId);

  @override
  String toString() => 'CatalogSelection($key)';
}
