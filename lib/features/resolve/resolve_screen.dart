import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/app_error.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Cliente: descreve necessidade e recebe propostas.
class ResolveScreen extends StatefulWidget {
  const ResolveScreen({super.key});
  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  final _desc = TextEditingController();
  final _city = TextEditingController(text: RegionCities.defaultCity);
  String? _category;
  bool _sending = false;

  @override
  void dispose() {
    _desc.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (AuthService.uid == null) {
      snack(context, 'Faca login para pedir orcamento');
      return;
    }
    if (_desc.text.trim().length < 10) {
      snack(context, 'Descreva melhor o que voce precisa (min. 10 caracteres)');
      return;
    }
    if (_category == null) {
      snack(context, 'Selecione uma categoria');
      return;
    }
    setState(() => _sending = true);
    try {
      final user = await FS.getUser();
      final id = await FS.createResolveRequest(
        description: _desc.text.trim(),
        category: _category!,
        city: _city.text.trim().isEmpty
            ? RegionCities.defaultCity
            : _city.text.trim(),
        clientName: user?.name,
      );
      if (!mounted) return;
      snack(context, 'Pedido enviado! Aguarde propostas.', bg: AppColors.secondary);
      Navigator.pushReplacementNamed(context, Routes.resolveDetail,
          arguments: {'id': id});
    } catch (e) {
      if (mounted) {
        snack(context, AppError.userMessage(e, message: 'Não foi possível enviar o pedido.'),
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CarajasAppBar(
        title: 'Resolve Carajas',
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, Routes.myResolve),
            child: const Text('Meus pedidos'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppGradients.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Descreva o que voce precisa. Profissionais compativeis da regiao enviam propostas com valor, prazo e avaliacao.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          const Text('O que voce precisa?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _desc,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Ex.: Preciso instalar 3 ar-condicionados no comercio.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Categoria',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: Categories.all.length.clamp(0, 30),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = Categories.all[i];
                return CatChip(
                  emoji: c.emoji,
                  name: c.name,
                  categoryId: c.id,
                  color: c.color,
                  selected: _category == c.id,
                  onTap: () => setState(() => _category = c.id),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text('Cidade',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              hintText: 'Canaa dos Carajas',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Pedir orcamento',
                      style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.assistedRequest),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Pedido assistido por IA',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, Routes.resolveOpportunities),
            child: const Text('Sou profissional — ver oportunidades'),
          ),
        ],
      ),
    );
  }
}

class ResolveDetailScreen extends StatefulWidget {
  final String requestId;
  const ResolveDetailScreen({super.key, required this.requestId});

  @override
  State<ResolveDetailScreen> createState() => _ResolveDetailScreenState();
}

class _ResolveDetailScreenState extends State<ResolveDetailScreen> {
  String _sort = 'price'; // price | rating | deadline

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Comparar propostas'),
      body: StreamBuilder<ResolveRequest?>(
        stream: FS.resolveRequestStream(widget.requestId),
        builder: (_, reqSnap) {
          final req = reqSnap.data;
          if (req == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.description,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, height: 1.35)),
                    const SizedBox(height: 8),
                    Text(
                        '${Categories.byId(req.category)?.emoji ?? '🛠️'} ${Categories.byId(req.category)?.name ?? req.category} · ${req.city}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                    if (req.urgency != null) ...[
                      const SizedBox(height: 4),
                      Text('Urgência: ${req.urgency}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                        req.status == ResolveStatus.matched
                            ? 'Status: contratado'
                            : 'Status: aguardando propostas (${req.proposalCount})',
                        style: TextStyle(
                            color: req.status == ResolveStatus.matched
                                ? AppColors.secondary
                                : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Menor preço'),
                      selected: _sort == 'price',
                      onSelected: (_) => setState(() => _sort = 'price'),
                    ),
                    ChoiceChip(
                      label: const Text('Melhor avaliação'),
                      selected: _sort == 'rating',
                      onSelected: (_) => setState(() => _sort = 'rating'),
                    ),
                    ChoiceChip(
                      label: const Text('Menor prazo'),
                      selected: _sort == 'deadline',
                      onSelected: (_) => setState(() => _sort = 'deadline'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<ResolveProposal>>(
                  stream: FS.resolveProposalsStream(widget.requestId),
                  builder: (_, snap) {
                    var list = List<ResolveProposal>.from(snap.data ?? []);
                    if (snap.connectionState == ConnectionState.waiting &&
                        list.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (list.isEmpty) {
                      return const EmptyState(
                        emoji: '⏳',
                        title: 'Aguardando propostas',
                        subtitle:
                            'Profissionais compatíveis da região foram notificados.',
                      );
                    }
                    list.sort((a, b) {
                      switch (_sort) {
                        case 'rating':
                          return b.rating.compareTo(a.rating);
                        case 'deadline':
                          return a.deadlineDays.compareTo(b.deadlineDays);
                        default:
                          return a.price.compareTo(b.price);
                      }
                    });
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return _ProposalTile(
                          proposal: p,
                          canAccept: req.status == ResolveStatus.open &&
                              (req.clientId == AuthService.uid ||
                                  widget.requestId.startsWith('hrq_')),
                          onAccept: () async {
                            final String? orderId;
                            try {
                              orderId = await FS.acceptResolveProposal(
                                requestId: widget.requestId,
                                proposalId: p.id,
                              );
                            } on CloudCallException catch (e) {
                              if (context.mounted) {
                                snack(context, e.message, bg: AppColors.error);
                              }
                              return;
                            }
                            if (!context.mounted) return;
                            if (orderId == null) {
                              snack(context,
                                  'Modo de demonstração: nenhum pedido foi criado.',
                                  bg: AppColors.warning);
                              return;
                            }
                            snack(context,
                                'Proposta aceita! O pedido está em Meus pedidos, pronto para pagamento.',
                                bg: AppColors.secondary);
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              Routes.myOrders,
                              (route) =>
                                  route.isFirst ||
                                  route.settings.name == Routes.main,
                            );
                          },
                          onChat: () => ChatNav.open(context,
                              otherUserId: p.providerId,
                              otherName: p.providerName,
                              otherPhoto: p.providerPhoto),
                          onDecline: () {
                            snack(context,
                                'Para recusar, ignore a proposta ou escolha outra. '
                                'A recusa definitiva será registrada na próxima versão.',
                                bg: AppColors.warning);
                          },
                          onProfile: () => Navigator.pushNamed(
                            context,
                            Routes.providerProfile,
                            arguments: {'providerId': p.providerId},
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProposalTile extends StatelessWidget {
  final ResolveProposal proposal;
  final bool canAccept;
  final VoidCallback onAccept, onChat;
  final VoidCallback? onDecline, onProfile;
  const _ProposalTile({
    required this.proposal,
    required this.canAccept,
    required this.onAccept,
    required this.onChat,
    this.onDecline,
    this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: proposal.accepted
                ? AppColors.secondary
                : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppAvatar(
              url: proposal.providerPhoto,
              name: proposal.providerName,
              size: 44,
              r: 12),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(proposal.providerName,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                    '⭐ ${proposal.rating.toStringAsFixed(1)} · ${proposal.totalServices} servicos',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight)),
              ],
            ),
          ),
          if (proposal.accepted)
            const AppTag('Aceita', bg: AppColors.secondary),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('R\$ ${proposal.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primary)),
          const SizedBox(width: 12),
          Text('Prazo: ${proposal.deadlineDays} dia(s)',
              style: const TextStyle(fontSize: 13)),
          if (proposal.available) ...[
            const SizedBox(width: 8),
            const Text('· Disponivel',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600)),
          ],
        ]),
        if (proposal.message != null && proposal.message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(proposal.message!,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMedium, height: 1.35)),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onProfile != null)
              OutlinedButton(
                  onPressed: onProfile, child: const Text('Ver perfil')),
            OutlinedButton(onPressed: onChat, child: const Text('Chat')),
            if (canAccept && onDecline != null && !proposal.accepted)
              OutlinedButton(
                  onPressed: onDecline,
                  child: const Text('Recusar',
                      style: TextStyle(color: AppColors.error))),
            if (canAccept && !proposal.accepted)
              ElevatedButton(
                  onPressed: onAccept, child: const Text('Aceitar')),
          ],
        ),
      ]),
    );
  }
}

class MyResolveScreen extends StatelessWidget {
  const MyResolveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Meus Resolve'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, Routes.resolve),
        label: const Text('Novo pedido'),
        icon: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<ResolveRequest>>(
        stream: FS.myResolveRequestsStream(),
        builder: (_, snap) {
          final list = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting &&
              list.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const EmptyState(
              emoji: '📋',
              title: 'Nenhum pedido ainda',
              subtitle: 'Peca um orcamento e receba propostas da regiao.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = list[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                title: Text(r.description,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${r.city} · ${r.proposalCount} proposta(s) · ${r.status.name}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(
                    context, Routes.resolveDetail,
                    arguments: {'id': r.id}),
              );
            },
          );
        },
      ),
    );
  }
}

class ResolveOpportunitiesScreen extends StatefulWidget {
  const ResolveOpportunitiesScreen({super.key});
  @override
  State<ResolveOpportunitiesScreen> createState() =>
      _ResolveOpportunitiesState();
}

class _ResolveOpportunitiesState extends State<ResolveOpportunitiesScreen> {
  Future<void> _propose(ResolveRequest req) async {
    if (AuthService.uid == null) {
      snack(context, 'Faca login para enviar propostas');
      return;
    }
    final prov = await FS.myProviderStream().first;
    if (!mounted) return;
    if (prov == null) {
      snack(context,
          'Cadastre-se como profissional para enviar propostas.',
          bg: AppColors.error);
      return;
    }
    final priceCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '3');
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Proposta (rascunho)'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Valor (R\$)')),
            TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Prazo (dias)')),
            TextField(
                controller: msgCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Mensagem')),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final price = double.tryParse(
                        priceCtrl.text.replaceAll(',', '.')) ??
                    0;
                final days = int.tryParse(daysCtrl.text) ?? 0;
                if (price <= 0 || days < 1) {
                  snack(ctx, 'Informe valor e prazo primeiro',
                      bg: AppColors.error);
                  return;
                }
                final res = await AiSvc.assistProposalDraft(
                  requestId: req.id,
                  price: price,
                  deadlineDays: days,
                  requestSummary: req.description,
                  conditions: msgCtrl.text.trim(),
                  providerServices: prov.categories,
                );
                if (res != null) {
                  final draft = Map<String, dynamic>.from(
                      res['draft'] as Map? ?? {});
                  msgCtrl.text = '${draft['message'] ?? ''}'.trim();
                }
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Gerar rascunho IA'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Revisar')),
        ],
      ),
    );
    if (ok != true || !mounted) {
      priceCtrl.dispose();
      daysCtrl.dispose();
      msgCtrl.dispose();
      return;
    }
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final days = int.tryParse(daysCtrl.text) ?? 1;
    final message =
        msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim();
    priceCtrl.dispose();
    daysCtrl.dispose();
    msgCtrl.dispose();
    if (price <= 0) {
      snack(context, 'Informe um valor valido');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Aprovar envio?'),
        content: Text(
          'Valor R\$ ${price.toStringAsFixed(2)} · $days dia(s)\n\n'
          '${message ?? '(sem mensagem)'}\n\n'
          'A IA nao inventa precos — estes valores sao os seus.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Editar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('Aprovar e enviar')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await FS.submitResolveProposal(
        requestId: req.id,
        providerName: prov.name,
        providerPhoto: prov.photoUrl,
        price: price,
        deadlineDays: days,
        message: message,
        rating: prov.rating,
        totalServices: prov.totalReviews,
      );
      if (!mounted) return;
      snack(context, 'Proposta enviada!', bg: AppColors.secondary);
    } catch (e) {
      if (!mounted) return;
      snack(context, AppError.userMessage(e, message: 'Não foi possível enviar a proposta.'),
          bg: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Oportunidades Resolve'),
      body: StreamBuilder<ProviderModel?>(
        stream: FS.myProviderStream(),
        builder: (_, provSnap) {
          final prov = provSnap.data;
          return StreamBuilder<List<ResolveRequest>>(
            stream: FS.resolveOpportunitiesStream(),
            builder: (_, snap) {
              var list = snap.data ?? [];
              if (prov != null && prov.categories.isNotEmpty) {
                list = list
                    .where((r) => prov.categories.contains(r.category))
                    .toList();
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  list.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (prov == null) {
                return const EmptyState(
                  emoji: '👷',
                  title: 'Area do profissional',
                  subtitle:
                      'Cadastre-se como prestador para ver oportunidades Resolve.',
                );
              }
              if (list.isEmpty) {
                return const EmptyState(
                  emoji: '📍',
                  title: 'Nenhuma oportunidade agora',
                  subtitle:
                      'Quando clientes pedirem orcamentos na sua categoria, eles aparecem aqui.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final r = list[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      color: AppColors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.description,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, height: 1.35)),
                        const SizedBox(height: 6),
                        Text(
                            '📍 ${r.city} · ${Categories.byId(r.category)?.name ?? r.category}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textLight)),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton(
                            onPressed: () => _propose(r),
                            child: const Text('Enviar proposta'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
