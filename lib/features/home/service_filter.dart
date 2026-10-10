import '../../core/constants/app_constants.dart';

/// Estado do filtro do hub Serviços: Categoria → Grupo → Serviço →
/// Profissionais compatíveis. Imutável e sem dependência de Flutter/
/// Firebase para ser testável.
class ServiceFilter {
  static const allGroups = 'Todos';

  final String group;
  final String? service;

  const ServiceFilter({this.group = allGroups, this.service});

  bool get isAll => group == allGroups;

  /// IDs de serviço do grupo atual (vazio em "Todos").
  List<String> get groupServiceIds => isAll
      ? const []
      : Categories.all
          .where((c) => c.group == group)
          .map((c) => c.id)
          .toList(growable: false);

  /// Troca o grupo, limpando o serviço se ele não pertencer ao novo grupo.
  ServiceFilter selectGroup(String newGroup) {
    final keep = service != null &&
        newGroup != allGroups &&
        Categories.byId(service!)?.group == newGroup;
    return ServiceFilter(group: newGroup, service: keep ? service : null);
  }

  /// Seleciona (ou desmarca) um serviço. Ajusta o grupo ao do serviço.
  ServiceFilter toggleService(String serviceId) {
    if (service == serviceId) return ServiceFilter(group: group);
    final g = Categories.byId(serviceId)?.group ?? group;
    return ServiceFilter(group: g, service: serviceId);
  }

  /// Parâmetros da consulta de prestadores.
  String? get queryCategory => service;
  List<String>? get queryCategories =>
      service == null && !isAll ? groupServiceIds : null;

  /// O prestador é compatível com o filtro atual?
  bool matches(List<String> providerCategories) {
    if (service != null) return providerCategories.contains(service);
    if (isAll) return true;
    final ids = groupServiceIds.toSet();
    return providerCategories.any(ids.contains);
  }

  /// Especialidade a levar para a contratação: o serviço escolhido; ou a
  /// primeira especialidade do prestador dentro do grupo; ou a primeira.
  String contractedCategory(List<String> providerCategories) {
    if (service != null && providerCategories.contains(service)) {
      return service!;
    }
    if (!isAll) {
      final ids = groupServiceIds.toSet();
      for (final c in providerCategories) {
        if (ids.contains(c)) return c;
      }
    }
    return providerCategories.isNotEmpty ? providerCategories.first : '';
  }

  /// Rótulo exibido no card do prestador.
  String roleLabel(List<String> providerCategories) {
    final id = contractedCategory(providerCategories);
    if (id.isEmpty) return 'Profissional';
    return Categories.byId(id)?.name ?? id;
  }

  /// Chave estável para recriar a consulta só quando o filtro muda.
  String get key => '$group|${service ?? ''}';

  @override
  bool operator ==(Object other) =>
      other is ServiceFilter && other.group == group && other.service == service;

  @override
  int get hashCode => Object.hash(group, service);
}
