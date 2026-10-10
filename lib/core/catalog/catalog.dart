import 'catalog_text.dart';

/// Nível do item do catálogo: categoria → grupo → serviço.
enum CatalogLevel { category, group, service }

/// Vertical a que o item pertence. Itens de vertical diferente de
/// `services` só aparecem nas telas da própria vertical.
enum CatalogVertical { services, health, market, rental, delivery }

/// Modalidade comercial: orçamento, preço fixo ou ambos.
enum CommercialModel { quote, fixed, both }

class CatalogNode {
  final String id;
  final CatalogLevel level;
  final String name;
  final String description;
  final String? parentId;
  final String slug;
  final String icon;
  final String? color;
  final int order;
  final bool active;
  final CatalogVertical vertical;
  final List<String> keywords;
  final List<String> synonyms;
  final List<String> modalities;
  final CommercialModel commercialModel;
  final String? questionnaireId;
  final int? questionnaireVersion;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CatalogNode({
    required this.id,
    required this.level,
    required this.name,
    this.description = '',
    this.parentId,
    this.slug = '',
    this.icon = '🔧',
    this.color,
    this.order = 0,
    this.active = true,
    this.vertical = CatalogVertical.services,
    this.keywords = const [],
    this.synonyms = const [],
    this.modalities = const [],
    this.commercialModel = CommercialModel.quote,
    this.questionnaireId,
    this.questionnaireVersion,
    this.createdAt,
    this.updatedAt,
  });

  static T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }

  static DateTime? _date(Object? v) {
    if (v == null) return null;
    try {
      // Timestamp do Firestore expõe toDate(); evita dependência aqui.
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return v is DateTime ? v : null;
    }
  }

  factory CatalogNode.fromMap(String id, Map<String, dynamic> m) => CatalogNode(
        id: id,
        level: _enum(CatalogLevel.values, m['level'], CatalogLevel.service),
        name: (m['name'] ?? id) as String,
        description: (m['description'] ?? '') as String,
        parentId: m['parentId'] as String?,
        slug: (m['slug'] ?? '') as String,
        icon: (m['icon'] ?? '🔧') as String,
        color: m['color'] as String?,
        order: (m['order'] as num?)?.toInt() ?? 0,
        active: m['active'] != false,
        vertical:
            _enum(CatalogVertical.values, m['vertical'], CatalogVertical.services),
        keywords: List<String>.from(m['keywords'] ?? const []),
        synonyms: List<String>.from(m['synonyms'] ?? const []),
        modalities: List<String>.from(m['modalities'] ?? const []),
        commercialModel: _enum(
            CommercialModel.values, m['commercialModel'], CommercialModel.quote),
        questionnaireId: m['questionnaireId'] as String?,
        questionnaireVersion: (m['questionnaireVersion'] as num?)?.toInt(),
        createdAt: _date(m['createdAt']),
        updatedAt: _date(m['updatedAt']),
      );

  /// Mapa para a callable `catalogUpsert`.
  Map<String, dynamic> toUpsert() => {
        'id': id,
        'level': level.name,
        'name': name,
        'description': description,
        'parentId': parentId,
        'icon': icon,
        'color': color,
        'order': order,
        'active': active,
        'vertical': vertical.name,
        'keywords': keywords,
        'synonyms': synonyms,
        'modalities': modalities,
        'commercialModel': commercialModel.name,
      };

  CatalogNode copyWith({
    String? name,
    String? description,
    String? icon,
    int? order,
    bool? active,
    List<String>? keywords,
    List<String>? synonyms,
    List<String>? modalities,
    CommercialModel? commercialModel,
    CatalogVertical? vertical,
  }) =>
      CatalogNode(
        id: id,
        level: level,
        name: name ?? this.name,
        description: description ?? this.description,
        parentId: parentId,
        slug: slug,
        icon: icon ?? this.icon,
        color: color,
        order: order ?? this.order,
        active: active ?? this.active,
        vertical: vertical ?? this.vertical,
        keywords: keywords ?? this.keywords,
        synonyms: synonyms ?? this.synonyms,
        modalities: modalities ?? this.modalities,
        commercialModel: commercialModel ?? this.commercialModel,
        questionnaireId: questionnaireId,
        questionnaireVersion: questionnaireVersion,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  String get levelLabel => switch (level) {
        CatalogLevel.category => 'Categoria',
        CatalogLevel.group => 'Grupo',
        CatalogLevel.service => 'Serviço',
      };
}

/// Resultado de busca no catálogo.
class CatalogMatch {
  final CatalogNode node;
  final int score;
  const CatalogMatch(this.node, this.score);
}

/// Catálogo imutável carregado da fonte única (catalogNodes).
class Catalog {
  final Map<String, CatalogNode> _byId;
  final Map<String?, List<CatalogNode>> _children;

  Catalog(Iterable<CatalogNode> nodes)
      : _byId = {for (final n in nodes) n.id: n},
        _children = {} {
    for (final n in _byId.values) {
      _children.putIfAbsent(n.parentId, () => []).add(n);
    }
    for (final list in _children.values) {
      list.sort((a, b) {
        final c = a.order.compareTo(b.order);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    }
  }

  static final empty = Catalog(const []);

  bool get isEmpty => _byId.isEmpty;
  int get length => _byId.length;
  Iterable<CatalogNode> get all => _byId.values;

  CatalogNode? byId(String? id) => id == null ? null : _byId[id];

  /// Nome legível; para IDs desconhecidos devolve o próprio ID (nunca
  /// some do histórico).
  String nameOf(String? id) => byId(id)?.name ?? (id ?? '');

  /// Caminho [categoria, grupo?, serviço?].
  List<CatalogNode> pathOf(String id) {
    final out = <CatalogNode>[];
    var cur = _byId[id];
    var guard = 0;
    while (cur != null && guard < 5) {
      out.insert(0, cur);
      cur = cur.parentId == null ? null : _byId[cur.parentId];
      guard++;
    }
    return out;
  }

  CatalogNode? rootOf(String id) {
    final p = pathOf(id);
    return p.isEmpty ? null : p.first;
  }

  /// Ativo efetivo: o item e todos os ancestrais ativos.
  bool isActive(String id) {
    final p = pathOf(id);
    return p.isNotEmpty && p.every((n) => n.active);
  }

  List<CatalogNode> children(String? parentId, {bool activeOnly = true}) =>
      (_children[parentId] ?? const [])
          .where((n) => !activeOnly || isActive(n.id))
          .toList(growable: false);

  List<CatalogNode> categories(
          {CatalogVertical? vertical = CatalogVertical.services,
          bool activeOnly = true}) =>
      children(null, activeOnly: activeOnly)
          .where((c) => vertical == null || c.vertical == vertical)
          .toList(growable: false);

  /// Todos os grupos de uma vertical (ex.: especialidades de Saúde).
  List<CatalogNode> groupsOfVertical(CatalogVertical v,
          {bool activeOnly = true}) =>
      [
        for (final c in categories(vertical: v, activeOnly: activeOnly))
          ...children(c.id, activeOnly: activeOnly)
      ];

  /// IDs da subárvore (o próprio + descendentes).
  Set<String> subtreeIds(String id, {bool activeOnly = true}) {
    final out = <String>{id};
    final stack = [id];
    while (stack.isNotEmpty) {
      for (final c in children(stack.removeLast(), activeOnly: activeOnly)) {
        if (out.add(c.id)) stack.add(c.id);
      }
    }
    return out;
  }

  /// Itens contratáveis (grupos e serviços ativos) de uma vertical.
  List<CatalogNode> selectable({CatalogVertical vertical = CatalogVertical.services}) =>
      all
          .where((n) =>
              n.level != CatalogLevel.category &&
              n.vertical == vertical &&
              isActive(n.id))
          .toList();

  /// Busca por nome, sinônimos e palavras-chave, tolerante a acentos,
  /// hífens e espaços ("ar-condicionado" = "ar condicionado" =
  /// "arcondicionado"). Todas as palavras da consulta precisam casar.
  List<CatalogMatch> search(String query,
      {Set<CatalogVertical>? verticals, bool activeOnly = true, int limit = 20}) {
    final q = CatalogText.normalize(query);
    if (q.isEmpty) return const [];
    final qCompact = q.replaceAll(' ', '');
    final qWords = q.split(' ');
    final out = <CatalogMatch>[];
    for (final n in all) {
      if (activeOnly && !isActive(n.id)) continue;
      if (verticals != null && !verticals.contains(n.vertical)) continue;
      final terms = <String>[n.name, ...n.synonyms, ...n.keywords];
      var best = 0;
      for (final t in terms) {
        final tn = CatalogText.normalize(t);
        if (tn.isEmpty) continue;
        final tc = tn.replaceAll(' ', '');
        final isName = identical(t, n.name);
        int s = 0;
        if (tn == q || tc == qCompact) {
          s = 100;
        } else if (tn.startsWith(q) || tc.startsWith(qCompact)) {
          s = 80;
        } else {
          final words = tn.split(' ');
          final allWords = qWords.every(
              (w) => words.any((tw) => tw.startsWith(w)));
          if (allWords) {
            s = 60;
          } else if (qCompact.length >= 4 && tc.contains(qCompact)) {
            s = 40;
          }
        }
        if (s > 0 && isName) s += 5;
        if (s > best) best = s;
      }
      if (best > 0) {
        // Serviço/grupo mais específico ganha desempate.
        best += switch (n.level) {
          CatalogLevel.service => 2,
          CatalogLevel.group => 1,
          CatalogLevel.category => 0,
        };
        out.add(CatalogMatch(n, best));
      }
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.node.name.compareTo(b.node.name);
    });
    return out.take(limit).toList();
  }

  /// Resolve o primeiro filtro de busca de prestadores para um item:
  /// categoria → c:, grupo → g:, serviço → s:.
  static String tokenFor(CatalogNode n) => switch (n.level) {
        CatalogLevel.category => 'c:${n.id}',
        CatalogLevel.group => 'g:${n.id}',
        CatalogLevel.service => 's:${n.id}',
      };
}
