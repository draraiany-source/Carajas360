import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/services/ai_service.dart';
import '../../shared/services/auth_service.dart';
import '../../shared/widgets/brand_shell.dart';
import 'carajas_ia_actions.dart';
import 'carajas_ia_character.dart';

/// Central Carajás IA — personagem oficial + chat (cliente / saúde / profissional / admin).
class AiAssistantScreen extends StatefulWidget {
  /// Painel lateral Web (sem rota cheia).
  final bool embedded;
  /// Mensagem inicial (ex.: texto vindo de Explorar).
  final String? initialMessage;
  const AiAssistantScreen({
    super.key,
    this.embedded = false,
    this.initialMessage,
  });

  @override
  State<AiAssistantScreen> createState() => _AiState();
}

class _AiMsg {
  final String text;
  final bool isAi;
  final DateTime time;
  final List<AiProviderCard> providers;
  final String? source;
  final bool canRetry;
  final String? retryText;

  _AiMsg({
    required this.text,
    required this.isAi,
    required this.time,
    this.providers = const [],
    this.source,
    this.canRetry = false,
    this.retryText,
  });
}

class _AiState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_AiMsg>[];
  bool _typing = false;
  String _mode = 'client';
  bool _healthConsent = false;
  String? _conversationId;
  bool _showReception = true;

  static const _modes = [
    ('client', 'Cliente', Icons.person_search_rounded),
    ('health', 'Saúde', Icons.health_and_safety_outlined),
    ('provider', 'Profissional', Icons.handyman_outlined),
    ('admin', 'Admin', Icons.analytics_outlined),
  ];

  List<String> get _suggestions {
    switch (_mode) {
      case 'health':
        return const [
          'Diferença entre clínico e especialista',
          'Quero atendimento online',
          'Como solicitar um horário',
          'É emergência — o que fazer?',
        ];
      case 'provider':
        return const [
          'Como organizar minhas solicitações',
          'Sugestão de resposta a um pedido',
          'Boas práticas de orçamento',
        ];
      case 'admin':
        return const [
          'Resumo de demanda por categoria',
          'Cidades com poucos profissionais',
          'Falhas e reclamações recentes',
        ];
      default:
        return const [
          'Preciso de um eletricista',
          'Como acompanho meus pedidos?',
          'Quero um orçamento de reforma',
          'Falar com atendimento humano',
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    _msgs.add(_AiMsg(
      text: CarajasIaReception.welcome,
      isAi: true,
      time: DateTime.now(),
    ));
    final seed = widget.initialMessage?.trim();
    if (seed != null && seed.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(seed);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onQuickAction(CarajasIaQuickAction a) async {
    if (a.mode != null) {
      setState(() {
        _mode = a.mode!;
        if (_mode != 'health') _healthConsent = false;
      });
    }
    if (a.unavailableMessage != null) {
      setState(() {
        _showReception = false;
        _msgs.add(_AiMsg(
          text: a.unavailableMessage!,
          isAi: true,
          time: DateTime.now(),
        ));
      });
      _scrollBottom();
      return;
    }
    if (a.route != null) {
      if (widget.embedded) Navigator.of(context).maybePop();
      await Navigator.pushNamed(context, a.route!);
      return;
    }
    if (a.chatPrompt != null) {
      setState(() => _showReception = false);
      await _send(a.chatPrompt);
    }
  }

  Future<void> _send([String? override]) async {
    final text = override ?? _ctrl.text.trim();
    if (text.isEmpty || _typing) return;
    _ctrl.clear();
    setState(() {
      _showReception = false;
      _msgs.add(_AiMsg(text: text, isAi: false, time: DateTime.now()));
      _typing = true;
    });
    _scrollBottom();

    if (AuthService.current == null) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_AiMsg(
          text:
              'Para consultar profissionais reais e usar a Carajás 360 IA com segurança, '
              'entre na sua conta. Depois disso, envie de novo a mesma pergunta.',
          isAi: true,
          time: DateTime.now(),
          canRetry: true,
          retryText: text,
        ));
      });
      _scrollBottom();
      return;
    }

    final history = _msgs
        .take(_msgs.length - 1)
        .map((m) => {'text': m.text, 'isAi': m.isAi})
        .toList();

    final turn = await AiSvc.askTurn(
      message: text,
      history: history,
      mode: _mode,
      city: null,
      conversationId: _conversationId,
      healthConsent: _healthConsent,
    );

    if (!mounted) return;

    String response;
    var providers = <AiProviderCard>[];
    String? source;
    var canRetry = false;
    if (turn == null) {
      response =
          'Não consegui falar com o assistente agora (rede, autenticação ou Function indisponível). '
          'Tente novamente ou use Explorar / Saúde / suporte humano.';
      canRetry = true;
    } else if (turn.consentRequired) {
      response = turn.reply;
    } else if (turn.reply.isNotEmpty) {
      response = turn.reply;
      providers = turn.providers;
      source = turn.source;
      _conversationId = turn.conversationId ?? _conversationId;
    } else {
      response =
          'Sem resposta fundamentada neste ambiente. Tente Explorar serviços ou o suporte.';
      canRetry = true;
    }

    setState(() {
      _typing = false;
      _msgs.add(_AiMsg(
        text: response,
        isAi: true,
        time: DateTime.now(),
        providers: providers,
        source: source,
        canRetry: canRetry,
        retryText: canRetry ? text : null,
      ));
    });
    _scrollBottom();
  }

  void _scrollBottom() => Future.delayed(const Duration(milliseconds: 80), () {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut);
        }
      });

  @override
  Widget build(BuildContext context) {
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final body = Column(
      children: [
        _header(ink, muted),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _modes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (id, label, icon) = _modes[i];
              final sel = _mode == id;
              return ChoiceChip(
                avatar: Icon(icon,
                    size: 16, color: sel ? Brand.greenDark : muted),
                label: Text(label),
                selected: sel,
                selectedColor: Brand.greenLight,
                onSelected: (_) => setState(() {
                  _mode = id;
                  if (id != 'health') _healthConsent = false;
                }),
              );
            },
          ),
        ),
        if (_mode == 'health')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: BrandSoftCard(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _healthConsent,
                activeColor: Brand.green,
                onChanged: (v) => setState(() => _healthConsent = v == true),
                title: Text(
                  'Consentimento educativo: sem diagnóstico/prescrição; '
                  'não enviarei dados clínicos sensíveis neste chat.',
                  style: TextStyle(fontSize: 12.5, color: ink),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            itemCount: (_showReception ? 1 : 0) +
                _msgs.length +
                (_typing ? 1 : 0),
            itemBuilder: (_, i) {
              var idx = i;
              if (_showReception) {
                if (idx == 0) return _reception(wide);
                idx -= 1;
              }
              if (_typing && idx == _msgs.length) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CarajasIaTypingIndicator(),
                  ),
                );
              }
              return _bubble(_msgs[idx]);
            },
          ),
        ),
        if (!_showReception && _msgs.length <= 3)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_suggestions[i], style: const TextStyle(fontSize: 12)),
                backgroundColor: Brand.greenLight,
                onPressed: () => _send(_suggestions[i]),
              ),
            ),
          ),
        _composer(),
      ],
    );

    if (widget.embedded) {
      return ColoredBox(
        color: Brand.isDark(context) ? Brand.surface(context) : Brand.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: Brand.isDark(context) ? null : Brand.background,
      body: SafeArea(
        child: BrandContentWidth(child: body),
      ),
    );
  }

  Widget _header(Color ink, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded)
            BrandBreadcrumb(items: [
              (
                'Início',
                () => Navigator.pushNamedAndRemoveUntil(
                    context, Routes.main, (_) => false)
              ),
              ('Carajás IA', null),
            ]),
          Row(children: [
            const CarajasIaAvatar(size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carajás IA',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: ink)),
                  Text(CarajasIaReception.statusLine,
                      style: TextStyle(fontSize: 11.5, color: muted)),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, Routes.support),
              child: const Text('Humano'),
            ),
            if (widget.embedded)
              IconButton(
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              )
            else
              BrandBackLink(onTap: () => AppNav.safeBack(context)),
          ]),
        ],
      ),
    );
  }

  Widget _reception(bool wide) {
    final showHero = !widget.embedded;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: BrandSoftCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHero)
              Center(
                child: CarajasIaReceptionHero(
                  compact: !wide,
                  webWide: wide && !widget.embedded,
                ),
              ),
            if (showHero) const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in CarajasIaReception.actions)
                  ActionChip(
                    avatar: Icon(a.icon, size: 16, color: Brand.green),
                    label:
                        Text(a.label, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Brand.greenLight,
                    onPressed: () => _onQuickAction(a),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            onSubmitted: (_) => _send(),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.send,
            decoration: InputDecoration(
              hintText: 'Escreva sua dúvida…',
              filled: true,
              fillColor: Brand.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide(color: Brand.line(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: const BorderSide(color: Brand.green),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        BrandPrimaryButton(
          label: 'Enviar',
          icon: Icons.send_rounded,
          expanded: false,
          onPressed: _typing ? null : () => _send(),
        ),
      ]),
    );
  }

  Widget _bubble(_AiMsg m) {
    final ai = m.isAi;
    final bg = ai ? Brand.surface(context) : Brand.green;
    final fg = ai ? Brand.ink(context) : Colors.white;
    return Align(
      alignment: ai ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width *
                (widget.embedded ? 0.92 : 0.86)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              ai ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (ai) ...[
              const CarajasIaAvatar(size: 32, showRing: false),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: ai ? Border.all(color: Brand.line(context)) : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.text.replaceAll('**', ''),
                        style:
                            TextStyle(color: fg, height: 1.35, fontSize: 14)),
                    if (m.providers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final p in m.providers.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Brand.greenLight,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              dense: true,
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              subtitle: Text(
                                [
                                  if (p.categories.isNotEmpty)
                                    p.categories.first,
                                  if ((p.city ?? '').isNotEmpty) p.city!,
                                  if (p.isTestSeed) 'teste',
                                ].join(' · '),
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing:
                                  const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.pushNamed(
                                context,
                                Routes.providerProfile,
                                arguments: {'providerId': p.id},
                              ),
                            ),
                          ),
                        ),
                    ],
                    if (m.source != null && ai)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Fonte: ${m.source}',
                            style: TextStyle(
                                fontSize: 10,
                                color: Brand.inkMuted(context))),
                      ),
                    if (m.canRetry &&
                        ai &&
                        (m.retryText ?? '').isNotEmpty)
                      TextButton.icon(
                        onPressed: _typing
                            ? null
                            : () => _send(m.retryText),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Tentar novamente'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
