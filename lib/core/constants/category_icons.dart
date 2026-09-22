import 'package:flutter/material.dart';

/// Linguagem visual única: Material Icons rounded.
abstract final class CategoryIcons {
  static IconData forId(String id) {
    switch (id) {
      case 'eletricista':
        return Icons.electrical_services_rounded;
      case 'encanador':
        return Icons.plumbing_rounded;
      case 'pedreiro':
        return Icons.foundation_rounded;
      case 'pintor':
        return Icons.format_paint_rounded;
      case 'marceneiro':
        return Icons.carpenter_rounded;
      case 'diarista':
      case 'limpeza':
        return Icons.cleaning_services_rounded;
      case 'jardineiro':
        return Icons.grass_rounded;
      case 'medico':
      case 'saude':
        return Icons.medical_services_rounded;
      case 'enfermagem':
        return Icons.local_hospital_rounded;
      case 'fisioterapia':
        return Icons.accessibility_new_rounded;
      case 'psicologo':
        return Icons.psychology_rounded;
      case 'nutricionista':
        return Icons.restaurant_rounded;
      case 'cuidador':
        return Icons.elderly_rounded;
      case 'cabeleireiro':
        return Icons.content_cut_rounded;
      case 'manicure':
        return Icons.spa_rounded;
      case 'estetica':
        return Icons.face_retouching_natural_rounded;
      case 'massagem':
        return Icons.self_improvement_rounded;
      case 'aulas':
      case 'educacao':
        return Icons.school_rounded;
      case 'ingles':
        return Icons.translate_rounded;
      case 'personal':
        return Icons.fitness_center_rounded;
      case 'ti':
      case 'informatica':
        return Icons.computer_rounded;
      case 'celular':
        return Icons.smartphone_rounded;
      case 'programador':
        return Icons.code_rounded;
      case 'mecanico':
        return Icons.build_rounded;
      case 'motorista':
        return Icons.drive_eta_rounded;
      case 'pets':
      case 'veterinario':
        return Icons.pets_rounded;
      case 'banho_tosa':
        return Icons.shower_rounded;
      case 'advogado':
        return Icons.gavel_rounded;
      case 'contador':
        return Icons.calculate_rounded;
      case 'fotografo':
        return Icons.camera_alt_rounded;
      case 'dj':
        return Icons.headphones_rounded;
      case 'mudancas':
      case 'entregas':
        return Icons.local_shipping_rounded;
      case 'geladeira':
      case 'ar_condicionado':
        return Icons.ac_unit_rounded;
      case 'agro':
      case 'agricultura':
        return Icons.agriculture_rounded;
      case 'baba':
        return Icons.child_care_rounded;
      case 'motoboy':
        return Icons.two_wheeler_rounded;
      case 'drones':
      case 'drone':
        return Icons.flight_rounded;
      case 'maquinas':
        return Icons.precision_manufacturing_rounded;
      case 'veiculos':
        return Icons.directions_car_rounded;
      case 'beleza':
        return Icons.brush_rounded;
      default:
        return Icons.handyman_rounded;
    }
  }

  static IconData forModule(String id) {
    switch (id) {
      case 'services':
        return Icons.handyman_rounded;
      case 'jobs':
        return Icons.work_outline_rounded;
      case 'freight':
        return Icons.local_shipping_rounded;
      case 'realty':
        return Icons.home_work_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'construction':
        return Icons.apartment_rounded;
      case 'auto':
        return Icons.car_repair_rounded;
      case 'kids':
        return Icons.child_care_rounded;
      case 'delivery':
        return Icons.inventory_2_rounded;
      case 'marketplace':
        return Icons.storefront_rounded;
      case 'rental':
        return Icons.key_rounded;
      case 'machines':
        return Icons.agriculture_rounded;
      case 'vehicles':
        return Icons.directions_car_rounded;
      case 'labor':
        return Icons.engineering_rounded;
      case 'drones':
        return Icons.flight_rounded;
      case 'pets':
        return Icons.pets_rounded;
      case 'beauty':
        return Icons.spa_rounded;
      case 'education':
        return Icons.menu_book_rounded;
      case 'agro':
        return Icons.eco_rounded;
      case 'ai':
        return Icons.auto_awesome_rounded;
      default:
        return Icons.apps_rounded;
    }
  }
}
