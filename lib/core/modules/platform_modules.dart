import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Status de disponibilidade de um módulo da plataforma.
enum ModuleStatus { available, comingSoon }

/// Descritor de módulo Carajás 360 (Home / busca global).
class PlatformModule {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final ModuleStatus status;
  final String? route;
  final Color accent;

  const PlatformModule({
    required this.id,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.status,
    this.route,
    required this.accent,
  });

  bool get isAvailable => status == ModuleStatus.available;
}

/// Catálogo de módulos da plataforma.
abstract class PlatformModules {
  static const all = <PlatformModule>[
    PlatformModule(
      id: 'services',
      icon: Icons.handyman_rounded,
      label: 'Serviços',
      subtitle: 'Profissionais da região',
      status: ModuleStatus.available,
      route: Routes.servicesHub,
      accent: Color(0xFF0B3D91),
    ),
    PlatformModule(
      id: 'jobs',
      icon: Icons.work_outline_rounded,
      label: 'Vagas',
      subtitle: 'Emprego e oportunidades',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFF1565C0),
    ),
    PlatformModule(
      id: 'freight',
      icon: Icons.local_shipping_rounded,
      label: 'Fretes',
      subtitle: 'Cargas e mudanças',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFFD4550A),
    ),
    PlatformModule(
      id: 'realty',
      icon: Icons.home_work_rounded,
      label: 'Imóveis',
      subtitle: 'Aluguel e venda',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFF5D4037),
    ),
    PlatformModule(
      id: 'health',
      icon: Icons.health_and_safety_rounded,
      label: 'Saúde',
      subtitle: 'Clínicas e profissionais',
      status: ModuleStatus.available,
      route: Routes.health,
      accent: Color(0xFF0F6B5C),
    ),
    PlatformModule(
      id: 'construction',
      icon: Icons.apartment_rounded,
      label: 'Obras',
      subtitle: 'Materiais e equipamentos',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFF6D4C41),
    ),
    PlatformModule(
      id: 'auto',
      icon: Icons.car_repair_rounded,
      label: 'Auto',
      subtitle: 'Oficinas e socorro',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFF37474F),
    ),
    PlatformModule(
      id: 'kids',
      icon: Icons.child_care_rounded,
      label: 'Kids',
      subtitle: 'Família e infância',
      status: ModuleStatus.comingSoon,
      accent: Color(0xFFAD1457),
    ),
  ];

  static PlatformModule? byId(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Cidades prioritárias da região.
abstract class RegionCities {
  static const priority = <String>[
    'Canaã dos Carajás',
    'Parauapebas',
    'Marabá',
  ];

  static const nearby = <String>[
    'Ourilândia do Norte',
    'Água Azul do Norte',
    'Curionópolis',
    'Eldorado dos Carajás',
  ];

  static const defaultCity = 'Canaã dos Carajás';
}
