import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../utils/firebase_bootstrap.dart';

/// Modalidade comercial do serviço na plataforma.
enum ServicePricingMode { fixedPrice, requestQuote, both }

/// Tipo de pergunta do questionário dinâmico.
enum ServiceQuestionType { text, multiline, singleChoice, multiChoice, boolean, number, date }

/// Pergunta administrável vinculada a um [TaxonomyService].
class ServiceQuestion {
  final String id;
  final String label;
  final ServiceQuestionType type;
  final bool required;
  final List<String> options;
  final String? hint;

  const ServiceQuestion({
    required this.id,
    required this.label,
    this.type = ServiceQuestionType.text,
    this.required = false,
    this.options = const [],
    this.hint,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'type': type.name,
        'required': required,
        'options': options,
        'hint': hint,
      };

  factory ServiceQuestion.fromMap(Map<String, dynamic> m) => ServiceQuestion(
        id: m['id']?.toString() ?? '',
        label: m['label']?.toString() ?? '',
        type: ServiceQuestionType.values.firstWhere(
          (t) => t.name == (m['type'] ?? 'text'),
          orElse: () => ServiceQuestionType.text,
        ),
        required: m['required'] == true,
        options: List<String>.from(m['options'] ?? const []),
        hint: m['hint']?.toString(),
      );
}

/// Serviço concreto sob um grupo (ex.: "Troca de bateria").
class TaxonomyService {
  final String id;
  final String name;
  final String categoryId;
  final String groupId;
  final String description;
  final ServicePricingMode pricingMode;
  final double? suggestedFixedPrice;
  final List<ServiceQuestion> questions;
  final bool active;
  final List<String> requiredDocs;

  const TaxonomyService({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.groupId,
    this.description = '',
    this.pricingMode = ServicePricingMode.both,
    this.suggestedFixedPrice,
    this.questions = const [],
    this.active = true,
    this.requiredDocs = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'categoryId': categoryId,
        'groupId': groupId,
        'description': description,
        'pricingMode': pricingMode.name,
        'suggestedFixedPrice': suggestedFixedPrice,
        'questions': questions.map((q) => q.toMap()).toList(),
        'active': active,
        'requiredDocs': requiredDocs,
      };

  factory TaxonomyService.fromMap(Map<String, dynamic> m) => TaxonomyService(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        categoryId: m['categoryId']?.toString() ?? '',
        groupId: m['groupId']?.toString() ?? '',
        description: m['description']?.toString() ?? '',
        pricingMode: ServicePricingMode.values.firstWhere(
          (p) => p.name == (m['pricingMode'] ?? 'both'),
          orElse: () => ServicePricingMode.both,
        ),
        suggestedFixedPrice: (m['suggestedFixedPrice'] as num?)?.toDouble(),
        questions: (m['questions'] as List? ?? const [])
            .map((e) => ServiceQuestion.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        active: m['active'] != false,
        requiredDocs: List<String>.from(m['requiredDocs'] ?? const []),
      );
}

/// Grupo/subcategoria (ex.: Auto Elétrica).
class TaxonomyGroup {
  final String id;
  final String name;
  final String verticalId;
  final String emoji;
  final Color color;
  final List<TaxonomyService> services;
  final bool active;
  final int order;

  const TaxonomyGroup({
    required this.id,
    required this.name,
    required this.verticalId,
    this.emoji = '🛠️',
    this.color = const Color(0xFF1565C0),
    this.services = const [],
    this.active = true,
    this.order = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'verticalId': verticalId,
        'emoji': emoji,
        'color': color.toARGB32(),
        'services': services.map((s) => s.toMap()).toList(),
        'active': active,
        'order': order,
      };

  factory TaxonomyGroup.fromMap(Map<String, dynamic> m) => TaxonomyGroup(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        verticalId: m['verticalId']?.toString() ?? '',
        emoji: m['emoji']?.toString() ?? '🛠️',
        color: Color((m['color'] as num?)?.toInt() ?? 0xFF1565C0),
        services: (m['services'] as List? ?? const [])
            .map((e) => TaxonomyService.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        active: m['active'] != false,
        order: (m['order'] as num?)?.toInt() ?? 0,
      );
}

/// Vertical de marketplace (ex.: Automóveis, Casa/Reformas).
class TaxonomyVertical {
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final List<TaxonomyGroup> groups;
  final bool active;
  final int order;
  /// Se true, UI pode redirecionar para módulo independente (Saúde, Locação...).
  final String? independentRoute;

  const TaxonomyVertical({
    required this.id,
    required this.name,
    this.emoji = '📦',
    this.color = const Color(0xFF0D47A1),
    this.groups = const [],
    this.active = true,
    this.order = 0,
    this.independentRoute,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color.toARGB32(),
        'groups': groups.map((g) => g.toMap()).toList(),
        'active': active,
        'order': order,
        'independentRoute': independentRoute,
      };

  factory TaxonomyVertical.fromMap(Map<String, dynamic> m) => TaxonomyVertical(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        emoji: m['emoji']?.toString() ?? '📦',
        color: Color((m['color'] as num?)?.toInt() ?? 0xFF0D47A1),
        groups: (m['groups'] as List? ?? const [])
            .map((e) => TaxonomyGroup.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        active: m['active'] != false,
        order: (m['order'] as num?)?.toInt() ?? 0,
        independentRoute: m['independentRoute']?.toString(),
      );
}

/// Facade da taxonomia: seed local + overlay Firestore (admin).
/// Fonte única — telas NÃO devem hardcodar listas de serviços.
abstract final class ServiceTaxonomy {
  static List<TaxonomyVertical>? _remoteOverlay;

  /// SEED/MOCK/HOMOLOGAÇÃO — taxonomia completa embarcada.
  static bool get homologSeedActive => FirebaseBootstrap.hasPlaceholderKeys;

  static void applyRemoteOverlay(List<TaxonomyVertical> remote) {
    _remoteOverlay = remote.where((v) => v.active).toList();
  }

  static void clearRemoteOverlay() => _remoteOverlay = null;

  static List<TaxonomyVertical> get verticals {
    if (_remoteOverlay != null && _remoteOverlay!.isNotEmpty) {
      return List.unmodifiable(_remoteOverlay!);
    }
    return List.unmodifiable(_seedVerticals);
  }

  static TaxonomyVertical? verticalById(String id) {
    try {
      return verticals.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  static TaxonomyGroup? groupById(String id) {
    for (final v in verticals) {
      for (final g in v.groups) {
        if (g.id == id) return g;
      }
    }
    return null;
  }

  static TaxonomyService? serviceById(String id) {
    for (final v in verticals) {
      for (final g in v.groups) {
        for (final s in g.services) {
          if (s.id == id) return s;
        }
      }
    }
    return null;
  }

  static TaxonomyService? serviceByCategoryId(String categoryId) {
    for (final v in verticals) {
      for (final g in v.groups) {
        for (final s in g.services) {
          if (s.categoryId == categoryId) return s;
        }
      }
    }
    return null;
  }

  static List<TaxonomyService> servicesForCategory(String categoryId) {
    final out = <TaxonomyService>[];
    for (final v in verticals) {
      for (final g in v.groups) {
        for (final s in g.services) {
          if (s.categoryId == categoryId && s.active) out.add(s);
        }
      }
    }
    return out;
  }

  static List<TaxonomyGroup> groupsForVertical(String verticalId) {
    final v = verticalById(verticalId);
    if (v == null) return const [];
    return v.groups.where((g) => g.active).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  /// Compatibilidade: mapeia Categories.group → verticalId.
  static String? verticalIdForCategoryGroup(String group) {
    const map = {
      'Casa': 'casa_reformas',
      'Limpeza': 'limpeza',
      'Jardim': 'jardim',
      'Saúde': 'saude',
      'Beleza': 'beleza',
      'Educação': 'educacao',
      'Tech': 'tech',
      'Veículos': 'veiculos_legado',
      'Automóveis': 'automoveis',
      'Pets': 'pets',
      'Jurídico': 'juridico',
      'Eventos': 'eventos',
      'Transporte': 'transporte',
      'Agro': 'agro',
      'Máquinas': 'maquinas',
      'Drones': 'drones',
      'Mão de Obra': 'mao_obra',
      'Cuidados': 'cuidados',
      'Delivery': 'transporte',
      'Lojas': 'outros',
      'Equipamentos': 'assistencia',
    };
    return map[group];
  }

  static List<ServiceQuestion> defaultCommonQuestions() => const [
        ServiceQuestion(
          id: 'description',
          label: 'Descreva o que você precisa',
          type: ServiceQuestionType.multiline,
          required: true,
          hint: 'Quanto mais detalhe, melhor a proposta.',
        ),
        ServiceQuestion(
          id: 'urgency',
          label: 'Urgência',
          type: ServiceQuestionType.singleChoice,
          required: true,
          options: ['Hoje', 'Esta semana', 'Flexível', 'Emergência'],
        ),
        ServiceQuestion(
          id: 'modality',
          label: 'Modalidade',
          type: ServiceQuestionType.singleChoice,
          required: true,
          options: ['No local', 'Na oficina/empresa', 'Remoto', 'A combinar'],
        ),
        ServiceQuestion(
          id: 'desired_date',
          label: 'Data desejada',
          type: ServiceQuestionType.date,
          required: false,
        ),
        ServiceQuestion(
          id: 'notes',
          label: 'Observações',
          type: ServiceQuestionType.multiline,
          required: false,
        ),
      ];

  // ── Seed helpers ────────────────────────────────────────────
  static TaxonomyService _svc({
    required String id,
    required String name,
    required String categoryId,
    required String groupId,
    String description = '',
    ServicePricingMode pricing = ServicePricingMode.both,
    double? fixed,
    List<ServiceQuestion> extra = const [],
  }) =>
      TaxonomyService(
        id: id,
        name: name,
        categoryId: categoryId,
        groupId: groupId,
        description: description,
        pricingMode: pricing,
        suggestedFixedPrice: fixed,
        questions: [...defaultCommonQuestions(), ...extra],
      );

  static List<ServiceQuestion> get _autoExtra => const [
        ServiceQuestion(
          id: 'vehicle_brand',
          label: 'Marca do veículo',
          type: ServiceQuestionType.text,
          required: true,
        ),
        ServiceQuestion(
          id: 'vehicle_model',
          label: 'Modelo',
          type: ServiceQuestionType.text,
          required: true,
        ),
        ServiceQuestion(
          id: 'vehicle_year',
          label: 'Ano',
          type: ServiceQuestionType.number,
          required: false,
        ),
        ServiceQuestion(
          id: 'can_drive',
          label: 'O veículo anda até a oficina?',
          type: ServiceQuestionType.boolean,
          required: false,
        ),
      ];

  static final List<TaxonomyVertical> _seedVerticals = [
    TaxonomyVertical(
      id: 'casa_reformas',
      name: 'Casa / Reformas',
      emoji: '🏠',
      color: const Color(0xFF1565C0),
      order: 1,
      groups: [
        TaxonomyGroup(
          id: 'casa_geral',
          name: 'Reformas e manutenção',
          verticalId: 'casa_reformas',
          emoji: '🧱',
          color: const Color(0xFF5D4037),
          order: 1,
          services: [
            _svc(id: 'svc_eletricista', name: 'Serviço elétrico', categoryId: 'eletricista', groupId: 'casa_geral'),
            _svc(id: 'svc_encanador', name: 'Encanamento', categoryId: 'encanador', groupId: 'casa_geral'),
            _svc(id: 'svc_pedreiro', name: 'Alvenaria / pedreiro', categoryId: 'pedreiro', groupId: 'casa_geral'),
            _svc(id: 'svc_pintor', name: 'Pintura', categoryId: 'pintor', groupId: 'casa_geral'),
            _svc(id: 'svc_marceneiro', name: 'Marcenaria', categoryId: 'marceneiro', groupId: 'casa_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'limpeza',
      name: 'Limpeza / Domésticos',
      emoji: '🧹',
      color: const Color(0xFF2E7D32),
      order: 2,
      groups: [
        TaxonomyGroup(
          id: 'limpeza_dom',
          name: 'Limpeza doméstica',
          verticalId: 'limpeza',
          emoji: '🧽',
          order: 1,
          services: [
            _svc(id: 'svc_diarista', name: 'Diarista', categoryId: 'diarista', groupId: 'limpeza_dom', pricing: ServicePricingMode.both, fixed: 120),
            _svc(id: 'svc_faxineira', name: 'Faxina completa', categoryId: 'faxineira', groupId: 'limpeza_dom'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'jardim',
      name: 'Jardim',
      emoji: '🌿',
      color: const Color(0xFF2E7D32),
      order: 3,
      groups: [
        TaxonomyGroup(
          id: 'jardim_geral',
          name: 'Jardinagem',
          verticalId: 'jardim',
          emoji: '🌱',
          services: [
            _svc(id: 'svc_jardineiro', name: 'Jardinagem', categoryId: 'jardineiro', groupId: 'jardim_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'assistencia',
      name: 'Assistência Técnica',
      emoji: '🔌',
      color: const Color(0xFF4527A0),
      order: 4,
      groups: [
        TaxonomyGroup(
          id: 'assist_eletro',
          name: 'Eletrodomésticos e informática',
          verticalId: 'assistencia',
          emoji: '💻',
          services: [
            _svc(id: 'svc_informatica', name: 'Informática', categoryId: 'informatica', groupId: 'assist_eletro'),
            _svc(id: 'svc_celular', name: 'Técnico de celular', categoryId: 'tecnico_celular', groupId: 'assist_eletro'),
            _svc(id: 'svc_ar', name: 'Ar-condicionado (residencial)', categoryId: 'ar_condicionado', groupId: 'assist_eletro'),
          ],
        ),
      ],
    ),
    // ── AUTOMÓVEIS (grupos completos) ─────────────────────────
    TaxonomyVertical(
      id: 'automoveis',
      name: 'Automóveis',
      emoji: '🚗',
      color: const Color(0xFF37474F),
      order: 5,
      groups: [
        TaxonomyGroup(
          id: 'auto_eletrica',
          name: 'Auto Elétrica',
          verticalId: 'automoveis',
          emoji: '⚡',
          color: const Color(0xFFF9A825),
          order: 1,
          services: [
            _svc(id: 'svc_auto_eletrico', name: 'Autoelétrico', categoryId: 'auto_eletrico', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_bateria_auto', name: 'Bateria', categoryId: 'bateria_auto', groupId: 'auto_eletrica', pricing: ServicePricingMode.both, fixed: 180, extra: _autoExtra),
            _svc(id: 'svc_alternador', name: 'Alternador', categoryId: 'alternador', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_partida', name: 'Partida / motor de arranque', categoryId: 'partida', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_iluminacao_auto', name: 'Iluminação', categoryId: 'iluminacao_auto', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_alarme_auto', name: 'Alarme', categoryId: 'alarme_auto', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_som_automotivo', name: 'Som automotivo', categoryId: 'som_automotivo', groupId: 'auto_eletrica', extra: _autoExtra),
            _svc(id: 'svc_ar_auto', name: 'Ar-condicionado automotivo', categoryId: 'ar_condicionado_auto', groupId: 'auto_eletrica', extra: _autoExtra),
          ],
        ),
        TaxonomyGroup(
          id: 'funilaria_pintura',
          name: 'Funilaria / Pintura',
          verticalId: 'automoveis',
          emoji: '🎨',
          color: const Color(0xFFE65100),
          order: 2,
          services: [
            _svc(id: 'svc_funilaria', name: 'Funilaria', categoryId: 'funilaria', groupId: 'funilaria_pintura', extra: _autoExtra),
            _svc(id: 'svc_pintura_auto', name: 'Pintura automotiva', categoryId: 'pintura_auto', groupId: 'funilaria_pintura', extra: _autoExtra),
            _svc(id: 'svc_martelinho', name: 'Martelinho de ouro', categoryId: 'martelinho', groupId: 'funilaria_pintura', extra: _autoExtra),
            _svc(id: 'svc_polimento_auto', name: 'Polimento', categoryId: 'polimento_auto', groupId: 'funilaria_pintura', pricing: ServicePricingMode.both, fixed: 250, extra: _autoExtra),
            _svc(id: 'svc_higienizacao_auto', name: 'Higienização', categoryId: 'higienizacao_auto', groupId: 'funilaria_pintura', pricing: ServicePricingMode.fixedPrice, fixed: 200, extra: _autoExtra),
            _svc(id: 'svc_pequenos_reparos_auto', name: 'Pequenos reparos', categoryId: 'pequenos_reparos_auto', groupId: 'funilaria_pintura', extra: _autoExtra),
          ],
        ),
        TaxonomyGroup(
          id: 'mecanica',
          name: 'Mecânica',
          verticalId: 'automoveis',
          emoji: '🔧',
          color: const Color(0xFF455A64),
          order: 3,
          services: [
            _svc(id: 'svc_mecanica_geral', name: 'Mecânica geral', categoryId: 'mecanica_geral', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_freios', name: 'Freios', categoryId: 'freios', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_suspensao', name: 'Suspensão', categoryId: 'suspensao', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_motor', name: 'Motor', categoryId: 'motor', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_cambio', name: 'Câmbio', categoryId: 'cambio', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_injecao', name: 'Injeção eletrônica', categoryId: 'injecao', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_escapamento', name: 'Escapamento', categoryId: 'escapamento', groupId: 'mecanica', extra: _autoExtra),
            _svc(id: 'svc_pneus', name: 'Pneus / borracharia', categoryId: 'pneus_borracharia', groupId: 'mecanica', pricing: ServicePricingMode.both, fixed: 80, extra: _autoExtra),
            _svc(id: 'svc_diagnostico', name: 'Diagnóstico', categoryId: 'diagnostico_auto', groupId: 'mecanica', pricing: ServicePricingMode.fixedPrice, fixed: 120, extra: _autoExtra),
            // legado compatível
            _svc(id: 'svc_mecanico', name: 'Mecânico (geral)', categoryId: 'mecanico', groupId: 'mecanica', extra: _autoExtra),
          ],
        ),
        TaxonomyGroup(
          id: 'emergencia_auto',
          name: 'Emergência',
          verticalId: 'automoveis',
          emoji: '🚨',
          color: const Color(0xFFC62828),
          order: 4,
          services: [
            _svc(id: 'svc_guincho', name: 'Guincho', categoryId: 'guincho', groupId: 'emergencia_auto', pricing: ServicePricingMode.both, fixed: 250, extra: _autoExtra),
            _svc(id: 'svc_pane', name: 'Pane', categoryId: 'pane', groupId: 'emergencia_auto', extra: _autoExtra),
            _svc(id: 'svc_troca_pneu', name: 'Troca de pneu', categoryId: 'troca_pneu', groupId: 'emergencia_auto', pricing: ServicePricingMode.fixedPrice, fixed: 60, extra: _autoExtra),
            _svc(id: 'svc_bateria_emerg', name: 'Bateria (socorro)', categoryId: 'bateria_emergencia', groupId: 'emergencia_auto', pricing: ServicePricingMode.both, fixed: 150, extra: _autoExtra),
            _svc(id: 'svc_socorro', name: 'Socorro automotivo', categoryId: 'socorro_automotivo', groupId: 'emergencia_auto', extra: _autoExtra),
          ],
        ),
        TaxonomyGroup(
          id: 'outros_auto',
          name: 'Outros serviços automotivos',
          verticalId: 'automoveis',
          emoji: '🛠️',
          color: const Color(0xFF546E7A),
          order: 5,
          services: [
            _svc(id: 'svc_vidros_auto', name: 'Vidros / martelinho de vidro', categoryId: 'vidros_auto', groupId: 'outros_auto', extra: _autoExtra),
            _svc(id: 'svc_estetizacao', name: 'Estetização / detailing', categoryId: 'estetizacao_auto', groupId: 'outros_auto', extra: _autoExtra),
            _svc(id: 'svc_insulfilm', name: 'Insulfilm', categoryId: 'insulfilm', groupId: 'outros_auto', pricing: ServicePricingMode.both, fixed: 350, extra: _autoExtra),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'saude',
      name: 'Saúde',
      emoji: '🩺',
      color: const Color(0xFF006064),
      order: 6,
      independentRoute: Routes.health,
      groups: [
        TaxonomyGroup(
          id: 'saude_geral',
          name: 'Profissionais de saúde',
          verticalId: 'saude',
          emoji: '💉',
          services: [
            _svc(id: 'svc_medico', name: 'Médico', categoryId: 'medico', groupId: 'saude_geral'),
            _svc(id: 'svc_enfermeiro', name: 'Enfermeiro', categoryId: 'enfermeiro', groupId: 'saude_geral'),
            _svc(id: 'svc_fisio', name: 'Fisioterapeuta', categoryId: 'fisioterapeuta', groupId: 'saude_geral'),
            _svc(id: 'svc_psico', name: 'Psicólogo', categoryId: 'psicologo', groupId: 'saude_geral'),
            _svc(id: 'svc_nutri', name: 'Nutricionista', categoryId: 'nutricionista', groupId: 'saude_geral'),
            _svc(id: 'svc_home_care', name: 'Home Care', categoryId: 'home_care', groupId: 'saude_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'beleza',
      name: 'Beleza',
      emoji: '💅',
      color: const Color(0xFFAD1457),
      order: 7,
      groups: [
        TaxonomyGroup(
          id: 'beleza_geral',
          name: 'Beleza e estética',
          verticalId: 'beleza',
          emoji: '✂️',
          services: [
            _svc(id: 'svc_cabeleireiro', name: 'Cabeleireiro', categoryId: 'cabeleireiro', groupId: 'beleza_geral'),
            _svc(id: 'svc_manicure', name: 'Manicure/Pedicure', categoryId: 'manicure', groupId: 'beleza_geral'),
            _svc(id: 'svc_esteticista', name: 'Esteticista', categoryId: 'esteticista', groupId: 'beleza_geral'),
            _svc(id: 'svc_massagem', name: 'Massagem', categoryId: 'massagem', groupId: 'beleza_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'educacao',
      name: 'Educação / Aulas',
      emoji: '📚',
      color: const Color(0xFF1A237E),
      order: 8,
      groups: [
        TaxonomyGroup(
          id: 'edu_geral',
          name: 'Aulas e treinamento',
          verticalId: 'educacao',
          emoji: '🎓',
          services: [
            _svc(id: 'svc_professor', name: 'Professor particular', categoryId: 'professor', groupId: 'edu_geral'),
            _svc(id: 'svc_ingles', name: 'Inglês', categoryId: 'ingles', groupId: 'edu_geral'),
            _svc(id: 'svc_personal', name: 'Personal trainer', categoryId: 'personal_trainer', groupId: 'edu_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'tech',
      name: 'Tecnologia / Design',
      emoji: '💻',
      color: const Color(0xFF311B92),
      order: 9,
      groups: [
        TaxonomyGroup(
          id: 'tech_geral',
          name: 'Tech e design',
          verticalId: 'tech',
          emoji: '🖥️',
          services: [
            _svc(id: 'svc_dev', name: 'Desenvolvedor', categoryId: 'desenvolvedor', groupId: 'tech_geral'),
            _svc(id: 'svc_info', name: 'Informática', categoryId: 'informatica', groupId: 'tech_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'juridico',
      name: 'Jurídico / Consultoria',
      emoji: '⚖️',
      color: const Color(0xFF1A237E),
      order: 10,
      groups: [
        TaxonomyGroup(
          id: 'jur_geral',
          name: 'Consultoria',
          verticalId: 'juridico',
          emoji: '📋',
          services: [
            _svc(id: 'svc_advogado', name: 'Advogado', categoryId: 'advogado', groupId: 'jur_geral'),
            _svc(id: 'svc_contador', name: 'Contador', categoryId: 'contador', groupId: 'jur_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'eventos',
      name: 'Eventos',
      emoji: '🎉',
      color: const Color(0xFF6A1B9A),
      order: 11,
      groups: [
        TaxonomyGroup(
          id: 'evt_geral',
          name: 'Eventos',
          verticalId: 'eventos',
          emoji: '📷',
          services: [
            _svc(id: 'svc_foto', name: 'Fotógrafo', categoryId: 'fotografo', groupId: 'evt_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'pets',
      name: 'Pets',
      emoji: '🐾',
      color: const Color(0xFF2E7D32),
      order: 12,
      groups: [
        TaxonomyGroup(
          id: 'pets_geral',
          name: 'Pets',
          verticalId: 'pets',
          emoji: '🐶',
          services: [
            _svc(id: 'svc_vet', name: 'Veterinário', categoryId: 'veterinario', groupId: 'pets_geral'),
            _svc(id: 'svc_banho_tosa', name: 'Banho e tosa', categoryId: 'banho_tosa', groupId: 'pets_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'transporte',
      name: 'Transporte',
      emoji: '🚚',
      color: const Color(0xFF0D47A1),
      order: 13,
      groups: [
        TaxonomyGroup(
          id: 'trans_geral',
          name: 'Transporte local',
          verticalId: 'transporte',
          emoji: '🧑‍✈️',
          services: [
            _svc(id: 'svc_motorista', name: 'Motorista particular', categoryId: 'motorista', groupId: 'trans_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'agro',
      name: 'Agro',
      emoji: '🌾',
      color: const Color(0xFF558B2F),
      order: 14,
      groups: [
        TaxonomyGroup(
          id: 'agro_geral',
          name: 'Serviços agro',
          verticalId: 'agro',
          emoji: '🚜',
          services: [
            _svc(id: 'svc_tec_agricola', name: 'Técnico agrícola', categoryId: 'tecnico_agricola', groupId: 'agro_geral'),
            _svc(id: 'svc_zootecnista', name: 'Zootecnista', categoryId: 'zootecnista', groupId: 'agro_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'maquinas',
      name: 'Máquinas / Equipamentos',
      emoji: '🏗️',
      color: const Color(0xFF5D4037),
      order: 15,
      independentRoute: Routes.rental,
      groups: [
        TaxonomyGroup(
          id: 'maq_locacao',
          name: 'Locação de máquinas',
          verticalId: 'maquinas',
          emoji: '⚙️',
          services: [
            _svc(id: 'svc_op_maq', name: 'Operador de máquinas', categoryId: 'operador_maquinas', groupId: 'maq_locacao'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'drones',
      name: 'Drones',
      emoji: '🛸',
      color: const Color(0xFF37474F),
      order: 16,
      groups: [
        TaxonomyGroup(
          id: 'drones_geral',
          name: 'Serviços com drone',
          verticalId: 'drones',
          emoji: '📡',
          services: [
            _svc(id: 'svc_drone_obras', name: 'Monitoramento de obras', categoryId: 'drone_monitoramento_obras', groupId: 'drones_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'mao_obra',
      name: 'Mão de obra',
      emoji: '👷',
      color: const Color(0xFF6D4C41),
      order: 17,
      groups: [
        TaxonomyGroup(
          id: 'mao_geral',
          name: 'Mão de obra',
          verticalId: 'mao_obra',
          emoji: '🛠️',
          services: [
            _svc(id: 'svc_servente', name: 'Servente de obra', categoryId: 'servente', groupId: 'mao_geral'),
            _svc(id: 'svc_soldador', name: 'Soldador', categoryId: 'soldador', groupId: 'mao_geral'),
            _svc(id: 'svc_carpinteiro', name: 'Carpinteiro', categoryId: 'carpinteiro', groupId: 'mao_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'cuidados',
      name: 'Cuidados',
      emoji: '🧓',
      color: const Color(0xFFAD1457),
      order: 18,
      groups: [
        TaxonomyGroup(
          id: 'cuid_geral',
          name: 'Cuidados',
          verticalId: 'cuidados',
          emoji: '❤️',
          services: [
            _svc(id: 'svc_cuidador', name: 'Cuidador de idosos', categoryId: 'cuidador_idosos', groupId: 'cuid_geral'),
          ],
        ),
      ],
    ),
    
    TaxonomyVertical(
      id: 'design',
      name: 'Design',
      emoji: '🎨',
      color: const Color(0xFF6A1B9A),
      order: 9,
      groups: [
        TaxonomyGroup(
          id: 'design_geral',
          name: 'Design e criacao',
          verticalId: 'design',
          emoji: '✏️',
          services: [
            _svc(id: 'svc_designer', name: 'Design grafico', categoryId: 'desenvolvedor', groupId: 'design_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'mudancas',
      name: 'Mudancas',
      emoji: '📦',
      color: const Color(0xFF5D4037),
      order: 13,
      groups: [
        TaxonomyGroup(
          id: 'mud_geral',
          name: 'Mudancas e fretes',
          verticalId: 'mudancas',
          emoji: '🚚',
          services: [
            _svc(id: 'svc_mudanca', name: 'Mudanca residencial/comercial', categoryId: 'motorista', groupId: 'mud_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'entregas',
      name: 'Entregas',
      emoji: '🛵',
      color: const Color(0xFF0D47A1),
      order: 14,
      independentRoute: Routes.delivery,
      groups: [
        TaxonomyGroup(
          id: 'ent_geral',
          name: 'Entregas locais',
          verticalId: 'entregas',
          emoji: '📍',
          services: [
            _svc(id: 'svc_entrega', name: 'Entrega local', categoryId: 'motorista', groupId: 'ent_geral'),
          ],
        ),
      ],
    ),
    TaxonomyVertical(
      id: 'servicos_empresariais',
      name: 'Servicos empresariais',
      emoji: '🏢',
      color: const Color(0xFF37474F),
      order: 20,
      groups: [
        TaxonomyGroup(
          id: 'emp_geral',
          name: 'Para empresas',
          verticalId: 'servicos_empresariais',
          emoji: '💼',
          services: [
            _svc(id: 'svc_cont_emp', name: 'Contabilidade empresarial', categoryId: 'contador', groupId: 'emp_geral'),
            _svc(id: 'svc_jur_emp', name: 'Juridico empresarial', categoryId: 'advogado', groupId: 'emp_geral'),
          ],
        ),
      ],
    ),
TaxonomyVertical(
      id: 'outros',
      name: 'Outros serviços locais',
      emoji: '📍',
      color: const Color(0xFF607D8B),
      order: 19,
      groups: [
        TaxonomyGroup(
          id: 'outros_geral',
          name: 'Serviços locais',
          verticalId: 'outros',
          emoji: '🏪',
          services: [
            _svc(id: 'svc_vigilante', name: 'Vigilante', categoryId: 'vigilante', groupId: 'outros_geral'),
            _svc(id: 'svc_porteiro', name: 'Porteiro', categoryId: 'porteiro', groupId: 'outros_geral'),
          ],
        ),
      ],
    ),
  ];
}
