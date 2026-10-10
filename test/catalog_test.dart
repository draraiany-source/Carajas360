import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/catalog/catalog.dart';
import 'package:servico_conecta/core/catalog/catalog_text.dart';

/// Catálogo de teste a partir do MESMO seed usado pela migração.
Catalog seedCatalog({Map<String, bool> inactive = const {}}) {
  final seed = jsonDecode(File('functions/catalog/seed_v1.json').readAsStringSync())
      as Map<String, dynamic>;
  return Catalog((seed['nodes'] as List).map((raw) {
    final m = Map<String, dynamic>.from(raw as Map);
    final id = m['id'] as String;
    if (inactive.containsKey(id)) m['active'] = inactive[id];
    return CatalogNode.fromMap(id, m);
  }));
}

void main() {
  final vectors = jsonDecode(
          File('functions/catalog/normalization_vectors.json').readAsStringSync())
      as Map<String, dynamic>;
  final catalog = seedCatalog();

  test('normalização idêntica ao servidor (vetores compartilhados)', () {
    for (final v in vectors['normalize'] as List) {
      expect(CatalogText.normalize(v[0] as String), v[1], reason: v[0] as String);
    }
    for (final v in vectors['compact'] as List) {
      expect(CatalogText.compact(v[0] as String), v[1]);
    }
  });

  test('busca com acentos, hífens e sinônimos', () {
    for (final v in vectors['searchExpectations'] as List) {
      final r = catalog.search(v[0] as String);
      expect(r, isNotEmpty, reason: 'sem resultado para "${v[0]}"');
      expect(r.map((m) => m.node.id).take(3), contains(v[1]),
          reason: '"${v[0]}" deveria encontrar ${v[1]}; veio ${r.take(3).map((m) => m.node.id)}');
    }
  });

  test('IDs antigos preservados no catálogo', () {
    final seed = jsonDecode(File('functions/catalog/seed_v1.json').readAsStringSync());
    for (final id in seed['legacyIds'] as List) {
      expect(catalog.byId(id as String), isNotNull, reason: id);
    }
  });

  test('hierarquia: 18 categorias regionais na vertical Serviços', () {
    final cats = catalog.categories();
    expect(cats.length, 18);
    expect(cats.first.name, 'Casa e Reformas');
    expect(catalog.categories(vertical: CatalogVertical.health).single.id, 'cat_saude');
    expect(catalog.pathOf('svc_freios').map((n) => n.name),
        ['Automóveis', 'Mecânica', 'Freios']);
  });

  test('desativação de categoria tira a subárvore das seleções', () {
    final c = seedCatalog(inactive: {'cat_automoveis': false});
    expect(c.isActive('svc_freios'), isFalse);
    expect(c.categories().any((n) => n.id == 'cat_automoveis'), isFalse);
    expect(c.search('freios'), isEmpty);
    // histórico continua legível
    expect(c.nameOf('svc_freios'), 'Freios');
    expect(c.nameOf('id_que_nao_existe'), 'id_que_nao_existe');
  });
}
