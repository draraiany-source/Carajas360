import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Ações de recepção → rotas reais existentes (sem inventar módulos).
class CarajasIaQuickAction {
  final String id;
  final String label;
  final IconData icon;
  final String? route;
  final String? chatPrompt;
  final String? unavailableMessage;
  final String? mode;

  const CarajasIaQuickAction({
    required this.id,
    required this.label,
    required this.icon,
    this.route,
    this.chatPrompt,
    this.unavailableMessage,
    this.mode,
  });
}

abstract final class CarajasIaReception {
  /// Texto oficial da referência aprovada (personagem Carajás IA).
  static const welcome =
      'Olá! 👋 Eu sou a Carajás IA, sua assistente inteligente no Carajás 360. '
      'Como posso te ajudar hoje?';

  static const statusLine = 'Online · 24 horas';

  /// Ações principais da referência visual (mapeadas a rotas reais).
  static const actions = <CarajasIaQuickAction>[
    CarajasIaQuickAction(
      id: 'find_pro',
      label: 'Encontrar um profissional',
      icon: Icons.build_rounded,
      route: Routes.universalSearch,
      chatPrompt: 'Quero encontrar um profissional na minha cidade',
    ),
    CarajasIaQuickAction(
      id: 'schedule',
      label: 'Agendar um atendimento',
      icon: Icons.calendar_month_outlined,
      route: Routes.health,
      mode: 'health',
      chatPrompt: 'Como solicito um horário de atendimento?',
    ),
    CarajasIaQuickAction(
      id: 'health',
      label: 'Serviços de saúde',
      icon: Icons.monitor_heart_outlined,
      route: Routes.health,
      mode: 'health',
      chatPrompt: 'Quero ver profissionais de saúde cadastrados',
    ),
    CarajasIaQuickAction(
      id: 'buy_rent',
      label: 'Comprar ou alugar',
      icon: Icons.storefront_outlined,
      route: Routes.marketplace,
      chatPrompt: 'Quero comprar ou alugar algo no marketplace',
    ),
    CarajasIaQuickAction(
      id: 'faq',
      label: 'Tirar dúvidas',
      icon: Icons.help_outline_rounded,
      chatPrompt: 'Como funciona a contratação de um serviço no Carajás 360?',
    ),
    CarajasIaQuickAction(
      id: 'budget',
      label: 'Solicitar um orçamento',
      icon: Icons.request_quote_outlined,
      route: Routes.assistedRequest,
      chatPrompt: 'Quero ajuda para solicitar um orçamento',
    ),
  ];
}
