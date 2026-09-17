import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/services/firebase_service.dart';

// ─────────────────────────────────────────────────────────────
// AI ASSISTANT SCREEN (Vol.28 – IA e Automações)
// ─────────────────────────────────────────────────────────────
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});
  @override
  State<AiAssistantScreen> createState() => _AiState();
}

class _AiState extends State<AiAssistantScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _msgs = <_AiMsg>[];
  bool _typing = false;

  static const _suggestions = [
    'Quanto custa um eletricista?',
    'Quero agendar uma consulta médica',
    'Melhores diaristas da cidade',
    'Como funciona o pagamento?',
    'Tenho um vazamento urgente!',
  ];

  static const _responses = {
    'eletricista':
        '⚡ Para serviços de eletricista, o valor médio na sua região é **R\$ 80 a R\$ 150/hora**. Fatores que influenciam: complexidade, materiais e horário. Posso te mostrar profissionais disponíveis agora?',
    'médic':
        '🏥 Temos médicos disponíveis para consulta online a partir de **R\$ 120**. Clínicos gerais, cardiologistas, dermatologistas e mais. Quer agendar agora?',
    'diarista':
        '🧹 As diaristas mais bem avaliadas na sua cidade cobram entre **R\$ 100 e R\$ 180/dia**. Ana Oliveira (4.9⭐) e Maria Silva (4.8⭐) têm disponibilidade hoje!',
    'pagamento':
        '💳 No ServiçoConecta você pode pagar via **PIX** (confirmação imediata), **cartão de crédito** (até 12x) ou **carteira digital**. O valor só é liberado após conclusão do serviço.',
    'vazamento':
        '🚨 Situação urgente! Encontrei **3 encanadores disponíveis agora** na sua área. Carlos (4.9⭐) pode chegar em ~20 min. Deseja que eu acione imediatamente?',
    'default':
        '🤖 Entendi! Vou buscar a melhor solução para você. Com base nas suas preferências e localização, posso recomendar profissionais verificados, sugerir preços justos e agendar tudo em segundos. O que você precisa?',
  };

  @override
  void initState() {
    super.initState();
    _msgs.add(_AiMsg(
        text:
            '👋 Olá! Sou o assistente inteligente do **ServiçoConecta**.\n\nPosso ajudar com:\n• Encontrar profissionais\n• Sugerir preços justos\n• Agendar serviços\n• Responder dúvidas\n\nComo posso te ajudar hoje?',
        isAi: true,
        time: DateTime.now()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? override]) async {
    final text = override ?? _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _msgs.add(_AiMsg(text: text, isAi: false, time: DateTime.now()));
      _typing = true;
    });
    _scrollBottom();

    // Tenta a IA real (Cloud Function + Claude API) primeiro.
    final history = _msgs
        .take(_msgs.length - 1)
        .map((m) => {'text': m.text, 'isAi': m.isAi})
        .toList();
    final aiReply = await AiSvc.ask(text, history);

    if (!mounted) return;

    String response;
    if (aiReply != null && aiReply.trim().isNotEmpty) {
      response = aiReply;
    } else {
      // Fallback local por palavra-chave — usado quando a Cloud Function
      // ainda não foi configurada/implantada ou está indisponível.
      await Future.delayed(const Duration(milliseconds: 400));
      final lower = text.toLowerCase();
      response = _responses['default']!;
      for (final key in _responses.keys) {
        if (lower.contains(key)) {
          response = _responses[key]!;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _typing = false;
      _msgs.add(_AiMsg(text: response, isAi: true, time: DateTime.now()));
    });
    _scrollBottom();
  }

  void _scrollBottom() => Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients)
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Container(
                width: 36,
                height: 36,
                decoration: AppDecorations.gradient(AppGradients.purple, r: 10),
                alignment: Alignment.center,
                child: const Text('🤖', style: TextStyle(fontSize: 18))),
            const SizedBox(width: 10),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IA Assistente',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text('Sempre disponível',
                      style: TextStyle(fontSize: 10, color: Colors.white70)),
                ]),
          ]),
        ),
        body: Column(children: [
          Expanded(
              child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) {
              if (_typing && i == _msgs.length) return _typingBubble();
              return _bubble(_msgs[i]);
            },
          )),

          // Suggestions
          if (_msgs.length <= 1)
            SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _suggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _send(_suggestions[i]),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.purple.withOpacity(0.3))),
                        child: Text(_suggestions[i],
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.purple)),
                      )),
                )),

          // Input
          Container(
              color: AppColors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
              child: Row(children: [
                Expanded(
                    child: TextField(
                  controller: _ctrl,
                  onSubmitted: _send,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Pergunte qualquer coisa...',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.purple)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                    onTap: () => _send(),
                    child: Container(
                        width: 44,
                        height: 44,
                        decoration:
                            AppDecorations.gradient(AppGradients.purple, r: 22),
                        child: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20))),
              ])),
        ]),
      );

  Widget _bubble(_AiMsg msg) {
    final isAi = msg.isAi;
    return Padding(
      padding: EdgeInsets.only(
          bottom: 12, left: isAi ? 0 : 48, right: isAi ? 48 : 0),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment:
              isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isAi) ...[
              Container(
                  width: 32,
                  height: 32,
                  decoration:
                      AppDecorations.gradient(AppGradients.purple, r: 10),
                  alignment: Alignment.center,
                  child: const Text('🤖', style: TextStyle(fontSize: 16))),
              const SizedBox(width: 8),
            ],
            Flexible(
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isAi ? AppColors.surface : AppColors.purple,
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isAi ? 4 : 18),
                    bottomRight: Radius.circular(isAi ? 18 : 4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07), blurRadius: 8)
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(msg.text.replaceAll('**', ''),
                        style: TextStyle(
                            color: isAi ? AppColors.textDark : Colors.white,
                            fontSize: 14,
                            height: 1.5)),
                    const SizedBox(height: 4),
                    Text(fmtTime(msg.time),
                        style: TextStyle(
                            color: isAi ? AppColors.textLight : Colors.white54,
                            fontSize: 10)),
                  ]),
            )),
          ]),
    );
  }

  Widget _typingBubble() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
              width: 32,
              height: 32,
              decoration: AppDecorations.gradient(AppGradients.purple, r: 10),
              alignment: Alignment.center,
              child: const Text('🤖', style: TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.07), blurRadius: 8)
                ]),
            child: Row(
                children: List.generate(
                    3,
                    (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: AppColors.purple.withOpacity(0.5),
                            shape: BoxShape.circle)))),
          ),
        ]),
      );
}

class _AiMsg {
  final String text;
  final bool isAi;
  final DateTime time;
  const _AiMsg({required this.text, required this.isAi, required this.time});
}
