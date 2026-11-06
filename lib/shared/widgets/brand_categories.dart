import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Atalho de categoria ligado a grupo, categoria ou rota existentes.
class BrandCategory {
  final String label;
  final IconData icon;
  final String? group, category, route;
  const BrandCategory(this.label, this.icon,
      {this.group, this.category, this.route});
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
      group: 'Automóveis'),
  BrandCategory('Agro e Rural', Icons.agriculture_rounded, group: 'Agro'),
  BrandCategory(
      'Máquinas e Equipamentos', Icons.precision_manufacturing_rounded,
      group: 'Máquinas'),
];
