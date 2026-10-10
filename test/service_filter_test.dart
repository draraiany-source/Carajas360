import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/core/constants/app_constants.dart';
import 'package:servico_conecta/features/home/service_filter.dart';

void main() {
  group('Catálogo de categorias', () {
    test('IDs únicos (preservam perfis e pedidos existentes)', () {
      final ids = Categories.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('todo grupo tem ao menos um serviço', () {
      for (final g in Categories.groups) {
        expect(Categories.all.where((c) => c.group == g), isNotEmpty,
            reason: g);
      }
    });

    test('atalhos do hub apontam para grupos existentes', () {
      for (final g in ['Agro', 'Drones', 'Mão de Obra', 'Pets', 'Beleza',
          'Educação', 'Casa', 'Veículos', 'Jurídico']) {
        expect(Categories.groups, contains(g));
      }
    });
  });

  group('ServiceFilter (Grupo → Serviço → Profissionais)', () {
    const f = ServiceFilter();

    test('"Todos" não filtra a consulta', () {
      expect(f.queryCategory, isNull);
      expect(f.queryCategories, isNull);
      expect(f.matches(['advogado']), isTrue);
    });

    test('Casa filtra pela lista de serviços do grupo', () {
      final casa = f.selectGroup('Casa');
      expect(casa.queryCategory, isNull);
      expect(casa.queryCategories,
          containsAll(['eletricista', 'encanador', 'pedreiro', 'pintor']));
      expect(casa.matches(['eletricista']), isTrue);
      expect(casa.matches(['advogado']), isFalse);
      expect(casa.matches(['mecanico']), isFalse);
    });

    test('Veículos e Jurídico nunca aceitam prestador de outro serviço', () {
      final vei = f.selectGroup('Veículos');
      expect(vei.matches(['mecanico']), isTrue);
      expect(vei.matches(['eletricista']), isFalse);
      final jur = f.selectGroup('Jurídico');
      expect(jur.matches(['advogado']), isTrue);
      expect(jur.matches(['diarista']), isFalse);
    });

    test('serviço escolhido vira array-contains e restringe a lista', () {
      final ele = f.selectGroup('Casa').toggleService('eletricista');
      expect(ele.queryCategory, 'eletricista');
      expect(ele.queryCategories, isNull);
      expect(ele.matches(['encanador']), isFalse);
      expect(ele.matches(['encanador', 'eletricista']), isTrue);
    });

    test('trocar de grupo limpa serviço incompatível', () {
      final ele = f.selectGroup('Casa').toggleService('eletricista');
      final jur = ele.selectGroup('Jurídico');
      expect(jur.service, isNull);
      expect(jur.group, 'Jurídico');
      expect(ele.selectGroup('Casa').service, 'eletricista');
      expect(ele.selectGroup(ServiceFilter.allGroups).service, isNull);
    });

    test('tocar no serviço de novo remove só o serviço', () {
      final ele = f.selectGroup('Casa').toggleService('eletricista');
      final off = ele.toggleService('eletricista');
      expect(off.service, isNull);
      expect(off.group, 'Casa');
    });

    test('especialidade levada para a contratação', () {
      final ele = f.selectGroup('Casa').toggleService('eletricista');
      expect(ele.contractedCategory(['pintor', 'eletricista']), 'eletricista');
      expect(f.selectGroup('Casa').contractedCategory(['advogado', 'pintor']),
          'pintor');
      expect(f.contractedCategory(['advogado', 'pintor']), 'advogado');
      expect(f.contractedCategory(const []), '');
    });

    test('grupo com mais de 30 serviços é dividido pela consulta', () {
      final agro = f.selectGroup('Agro');
      expect(agro.queryCategories!.length, greaterThan(30));
    });

    test('chave muda quando o filtro muda (recria consulta)', () {
      expect(f.key, isNot(f.selectGroup('Casa').key));
      expect(f.selectGroup('Casa'), f.selectGroup('Casa'));
    });
  });
}
