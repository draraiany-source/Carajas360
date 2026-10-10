import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/catalog/catalog.dart';
import 'package:servico_conecta/core/catalog/catalog_selection.dart';

import 'catalog_test.dart' show seedCatalog;

void main() {
  final c = seedCatalog();
  const none = CatalogSelection.none;

  test('"Todos" não filtra', () {
    expect(none.token(c), isNull);
    expect(none.matches(c, ['advogado']), isTrue);
  });

  test('Casa → Automóveis → Jurídico: nunca aceita prestador incompatível', () {
    final casa = none.selectCategory('cat_casa_reformas');
    expect(casa.token(c), 'c:cat_casa_reformas');
    expect(casa.matches(c, ['eletricista']), isTrue);
    expect(casa.matches(c, ['mecanico']), isFalse);
    expect(casa.matches(c, ['advogado']), isFalse);

    final auto = casa.selectCategory('cat_automoveis');
    expect(auto.groupId, isNull, reason: 'grupo incompatível limpo');
    expect(auto.matches(c, ['mecanico']), isTrue);
    expect(auto.matches(c, ['svc_freios']), isTrue);
    expect(auto.matches(c, ['eletricista']), isFalse);

    final jur = auto.selectCategory('cat_juridico_contabil');
    expect(jur.matches(c, ['advogado']), isTrue);
    expect(jur.matches(c, ['contador']), isTrue);
    expect(jur.matches(c, ['mecanico', 'eletricista']), isFalse);
  });

  test('trocar categoria limpa grupo e serviço; trocar grupo limpa serviço', () {
    final freios = none.selectService(c, 'svc_freios');
    expect([freios.categoryId, freios.groupId, freios.serviceId],
        ['cat_automoveis', 'mecanico', 'svc_freios']);
    expect(freios.selectCategory('cat_casa_reformas'),
        const CatalogSelection(categoryId: 'cat_casa_reformas'));
    final otherGroup = freios.selectGroup(c, 'grp_auto_eletrica');
    expect(otherGroup.serviceId, isNull);
    expect(otherGroup.groupId, 'grp_auto_eletrica');
    expect(freios.selectGroup(c, 'mecanico').serviceId, 'svc_freios');
  });

  test('grupo declarado não vira serviço específico não declarado', () {
    final freios = none.selectService(c, 'svc_freios');
    expect(freios.matches(c, ['mecanico']), isFalse);
    final mecanica = none.selectGroup(c, 'mecanico');
    expect(mecanica.matches(c, ['mecanico']), isTrue);
    expect(mecanica.matches(c, ['svc_freios']), isTrue);
  });

  test('prestador com múltiplas especialidades: especialidade certa na contratação', () {
    const declared = ['pintor', 'svc_freios', 'advogado'];
    expect(none.selectCategory('cat_automoveis').contractedCategory(c, declared), 'svc_freios');
    expect(none.selectCategory('cat_juridico_contabil').contractedCategory(c, declared), 'advogado');
    expect(none.selectCategory('cat_casa_reformas').contractedCategory(c, declared), 'pintor');
    expect(none.contractedCategory(c, declared), 'pintor');
  });

  test('item desativado sai da seleção (sanitize)', () {
    final inactive = seedCatalog(inactive: {'mecanico': false});
    final sel = none.selectService(c, 'svc_freios');
    expect(sel.sanitize(inactive), const CatalogSelection(categoryId: 'cat_automoveis'));
    expect(inactive.children('cat_automoveis').any((n) => n.id == 'mecanico'), isFalse);
  });

  test('seleção a partir de resultado de busca/deep link', () {
    final s = CatalogSelection.forNode(c, 'svc_ar_limpeza');
    expect([s.categoryId, s.groupId, s.serviceId],
        ['cat_assistencia_tecnica', 'ar_condicionado', 'svc_ar_limpeza']);
    expect(Catalog.tokenFor(c.byId('svc_ar_limpeza')!), 's:svc_ar_limpeza');
  });
}
