import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/utils/chat_nav.dart';
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
      if (mounted) snack(context, 'Erro ao enviar: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Carajas'),
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

class ResolveDetailScreen extends StatelessWidget {
  final String requestId;
  const ResolveDetailScreen({super.key, required this.requestId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Propostas recebidas')),
      body: StreamBuilder<ResolveRequest?>(
        stream: FS.resolveRequestStream(requestId),
        builder: (_, reqSnap) {
          if (reqSnap.hasError) {
            return const EmptyState(
              emoji: '🔒',
              title: 'Solicitação indisponível',
              subtitle:
                  'Você não tem acesso a esta solicitação ou ela foi removida.',
            );
          }
          if (reqSnap.connectionState == ConnectionState.waiting &&
              !reqSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final req = reqSnap.data;
          if (req == null) {
            return const EmptyState(
              emoji: '🔍',
              title: 'Solicitação não encontrada',
              subtitle: 'Ela pode ter sido removida.',
            );
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
                        '${Categories.byId(req.category)?.emoji ?? '🛠️'} ${Categories.byId(req.category)?.name ?? req.category} · 📍 ${req.city}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                        req.status == ResolveStatus.matched
                            ? 'Status: combinado'
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
              Expanded(
                child: StreamBuilder<List<ResolveProposal>>(
                  stream: FS.resolveProposalsStream(requestId),
                  builder: (_, snap) {
                    final list = snap.data ?? [];
                    if (snap.hasError) {
                      return const EmptyState(
                        emoji: '⚠️',
                        title: 'Não foi possível carregar as propostas',
                        subtitle: 'Verifique sua conexão e tente novamente.',
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting &&
                        list.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (list.isEmpty) {
                      return const EmptyState(
                        emoji: '⏳',
                        title: 'Aguardando propostas',
                        subtitle:
                            'Profissionais da regiao foram notificados. Volte em breve.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final p = list[i];
                        return _ProposalTile(
                          proposal: p,
                          canAccept: req.status == ResolveStatus.open &&
                              req.clientId == AuthService.uid,
                          onAccept: () async {
                            try {
                              await FS.acceptResolveProposal(
                                requestId: requestId,
                                proposalId: p.id,
                                providerId: p.providerId,
                                providerName: p.providerName,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                snack(context,
                                    'Não foi possível aceitar: a solicitação já pode ter sido fechada.',
                                    bg: AppColors.error);
                              }
                              return;
                            }
                            if (!context.mounted) return;
                            snack(context, 'Proposta aceita!',
                                bg: AppColors.secondary);
                            await ChatNav.open(context,
                                otherUserId: p.providerId,
                                otherName: p.providerName,
                                otherPhoto: p.providerPhoto);
                          },
                          onChat: () => ChatNav.open(context,
                              otherUserId: p.providerId,
                              otherName: p.providerName,
                              otherPhoto: p.providerPhoto),
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
  const _ProposalTile({
    required this.proposal,
    required this.canAccept,
    required this.onAccept,
    required this.onChat,
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
        Row(children: [
          OutlinedButton(onPressed: onChat, child: const Text('Chat')),
          const SizedBox(width: 8),
          if (canAccept && !proposal.accepted)
            ElevatedButton(
                onPressed: onAccept, child: const Text('Aceitar')),
        ]),
      ]),
    );
  }
}

class MyResolveScreen extends StatelessWidget {
  const MyResolveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus Resolve')),
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
  late Future<ResolveOpportunities> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ResolveOpportunities> _load() async {
    if (AuthService.uid == null) {
      return const ResolveOpportunities(eligible: false, reason: 'not_provider');
    }
    return FS.resolveOpportunities();
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {/* exibido pelo FutureBuilder */}
  }

  Future<void> _propose(ResolveOpportunity req) async {
    if (AuthService.uid == null) {
      snack(context, 'Faça login para enviar propostas');
      return;
    }
    final priceCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '3');
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar proposta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Valor (R\$)')),
          TextField(
              controller: daysCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prazo (dias)')),
          TextField(
              controller: msgCtrl,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(labelText: 'Mensagem')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final days = int.tryParse(daysCtrl.text) ?? 0;
    final message = msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim();
    priceCtrl.dispose();
    daysCtrl.dispose();
    msgCtrl.dispose();
    if (ok != true || !mounted) return;
    if (price <= 0) {
      snack(context, 'Informe um valor válido');
      return;
    }
    if (days < 1) {
      snack(context, 'Informe um prazo válido (em dias)');
      return;
    }
    try {
      await FS.submitResolveProposal(
        requestId: req.id,
        price: price,
        deadlineDays: days,
        message: message,
      );
      if (!mounted) return;
      snack(context, 'Proposta enviada!', bg: AppColors.secondary);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Não foi possível enviar: $e', bg: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oportunidades Resolve'), actions: [
        IconButton(
            tooltip: 'Atualizar',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: FutureBuilder<ResolveOpportunities>(
        future: _future,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              emoji: '⚠️',
              title: 'Não foi possível carregar',
              subtitle: '${snap.error}',
              actionLabel: 'Tentar novamente',
              onAction: _refresh,
            );
          }
          final data = snap.data!;
          if (!data.eligible) {
            return EmptyState(
              emoji: '👷',
              title: 'Área do profissional',
              subtitle: data.reasonLabel,
            );
          }
          if (data.items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(children: const [
                SizedBox(height: 80),
                EmptyState(
                  emoji: '📍',
                  title: 'Nenhuma oportunidade agora',
                  subtitle:
                      'Quando clientes da sua região pedirem orçamentos nos seus serviços, eles aparecem aqui.',
                ),
              ]),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final r = data.items[i];
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
                          '📍 ${r.city}${r.neighborhood != null ? ' · ${r.neighborhood}' : ''} · ${Categories.byId(r.category)?.name ?? r.category}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: r.alreadyProposed
                            ? const AppTag('Proposta enviada',
                                bg: AppColors.secondary)
                            : ElevatedButton(
                                onPressed: () => _propose(r),
                                child: const Text('Enviar proposta'),
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
