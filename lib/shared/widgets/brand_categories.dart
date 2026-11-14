import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Atalho de categoria ligado a grupo, categoria ou rota existentes.
class BrandCategory {
  final String label;
  final IconData icon;
  final String? group, category, route;

  /// Especialidades de outros grupos que também pertencem ao atalho.
  final List<String> extraCategories;
  const BrandCategory(this.label, this.icon,
      {this.group, this.category, this.route, this.extraCategories = const []});

  /// Ids estáveis de [Categories] cobertos pelo atalho.
  Set<String> get ids => {
        if (category != null) category!,
        if (group != null)
          ...Categories.all.where((c) => c.group == group).map((c) => c.id),
        ...extraCategories,
      };

  /// Atalho equivalente aos argumentos de rota `category`/`group`.
  static BrandCategory? fromArgs({String? category, String? group}) {
    if (category != null && category.isNotEmpty) {
      for (final c in brandCategories) {
        if (c.category == category) return c;
      }
      final cat = Categories.byId(category);
      if (cat == null) return null;
      return BrandCategory(cat.name, Icons.label_outline_rounded,
          category: category);
    }
    if (group != null && group.isNotEmpty && group != 'Todos') {
      for (final c in brandCategories) {
        if (c.group == group) return c;
      }
      if (!Categories.all.any((c) => c.group == group)) return null;
      return BrandCategory(group, Icons.label_outline_rounded, group: group);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is BrandCategory &&
      other.label == label &&
      other.group == group &&
      other.category == category &&
      other.route == route;

  @override
  int get hashCode => Object.hash(label, group, category, route);
}

const brandCategories = <BrandCategory>[
  BrandCategory('Construção e Reforma', Icons.foundation_rounded,
      group: 'Casa'),
  BrandCategory('Elétrica', Icons.bolt_rounded, category: 'eletricista'),
  BrandCategory('Hidráulica', Icons.plumbing_rounded, category: 'encanador'),
  BrandCategory('Limpeza', Icons.cleaning_services_rounded, group: 'Limpeza'),
  BrandCategory('Beleza e Estética', Icons.content_cut_rounded,
      group: 'Beleza'),
  BrandCategory('Saúde e Bem-estar', Icons.favorite_rounded,
      route: Routes.health),
  BrandCategory('Veículos e Oficinas', Icons.directions_car_rounded,
      group: 'Automóveis', extraCategories: ['mecanico']),
  BrandCategory('Agro e Rural', Icons.agriculture_rounded, group: 'Agro'),
  BrandCategory(
      'Máquinas e Equipamentos', Icons.precision_manufacturing_rounded,
      group: 'Máquinas'),
];
