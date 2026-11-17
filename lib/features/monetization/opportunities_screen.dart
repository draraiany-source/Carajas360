import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/app_constants.dart';
import '../../core/monetization/lead_unlock_service.dart';
import '../../core/monetization/monetization_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_error.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Oportunidades para o profissional (FASE 2).
class OpportunitiesHubScreen extends StatefulWidget {
  const OpportunitiesHubScreen({super.key});
  @override
  State<OpportunitiesHubScreen> createState() => _OpportunitiesHubScreenState();
}

class _OpportunitiesHubScreenState extends State<OpportunitiesHubScreen> {
  String? _category;
  String? _city;
  String? _urgency;
  String _sort = 'recent';
  MonetizationConfig _cfg = MonetizationConfig.defaults();
  StreamSubscription? _cfgSub;

  @override
  void initState() {
    super.initState();
    _cfgSub = FS.platformConfigStream().listen((m) {
      if (!mounted) return;
      setState(() => _cfg = MonetizationConfig.fromMap(m));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    super.dispose();
  }

  List<ResolveRequest> _filter(List<ResolveRequest> raw) {
    var list = List<ResolveRequest>.from(raw);
    if (_category != null) {
      list = list.where((r) => r.category == _category).toList();
    }
    if (_city != null && _city!.isNotEmpty) {
      final c = _city!.toLowerCase();
      list = list.where((r) => r.city.toLowerCase().contains(c)).toList();
    }
    if (_urgency != null) {
      list = list.where((r) => r.urgency == _urgency).toList();
    }
    switch (_sort) {
      case 'budget':
        list.sort((a, b) => (b.budgetMax ?? 0).compareTo(a.budgetMax ?? 0));
        break;
      case 'urgency':
        list.sort((a, b) => (b.urgency ?? '').compareTo(a.urgency ?? ''));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Oportunidades para voce'),
      body: StreamBuilder<ProviderModel?>(
        stream: FS.myProviderStream(),
        builder: (_, provSnap) {
          final prov = HomologCatalog.enabled
              ? (provSnap.data ??
                  HomologCatalog.providers().firstOrNull)
              : provSnap.data;
          return Column(
            children: [
              _filters(),
              Expanded(
                child: StreamBuilder<List<ResolveRequest>>(
                  stream: FS.resolveOpportunitiesStream(),
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting &&
                        (snap.data == null || snap.data!.isEmpty)) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: 4,
                        itemBuilder: (_, __) => const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: ShimCard(),
                        ),
                      );
                    }
                    if (prov == null && !HomologCatalog.enabled) {
                      return const EmptyState(
                        emoji: '👷',
                        title: 'Area do profissional',
                        subtitle:
                            'Cadastre-se como prestador para ver oportunidades.',
                      );
                    }
                    var list = _filter(snap.data ?? []);
                    if (prov != null &&
                        prov.categories.isNotEmpty &&
                        !HomologCatalog.enabled) {
                      list = list
                          .where((r) => prov.categories.contains(r.category))
                          .toList();
                    }
                    if (list.isEmpty) {
                      return const EmptyState(
                        emoji: '📍',
                        title: 'Sem oportunidades',
                        subtitle:
                            'Nenhuma solicitacao agora. Ajuste filtros ou volte depois.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OpportunityCard(
                        request: list[i],
                        creditCost: _cfg.defaultLeadCreditCost,
                        onOpen: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OpportunityDetailScreen(
                              request: list[i],
                              config: _cfg,
                              providerId: prov?.id ??
                                  AuthService.uid ??
                                  'homolog_pro',
                            ),
                          ),
                        ),
                      ),
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

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        FilterChip(
          label: Text(_category == null
              ? 'Categoria'
              : (Categories.byId(_category!)?.name ?? _category!)),
          selected: _category != null,
          onSelected: (_) async {
            final cats = ['freios', 'eletricista', 'guincho', 'diarista', 'mecanica_geral'];
            final pick = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => ListView(
                children: [
                  ListTile(
                      title: const Text('Todas'),
                      onTap: () => Navigator.pop(ctx, '')),
                  ...cats.map((c) => ListTile(
                        title: Text(Categories.byId(c)?.name ?? c),
                        onTap: () => Navigator.pop(ctx, c),
                      )),
                ],
              ),
            );
            if (pick != null) {
              setState(() => _category = pick.isEmpty ? null : pick);
            }
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(_urgency ?? 'Urgencia'),
          selected: _urgency != null,
          onSelected: (_) async {
            const opts = ['Hoje', 'Esta semana', 'Flexivel', 'Emergencia'];
            final pick = await showModalBottomSheet<String>(
              context: context,
              builder: (ctx) => ListView(
                children: [
                  ListTile(
                      title: const Text('Todas'),
                      onTap: () => Navigator.pop(ctx, '')),
                  ...opts.map((o) => ListTile(
                        title: Text(o),
                        onTap: () => Navigator.pop(ctx, o),
                      )),
                ],
              ),
            );
            if (pick != null) {
              setState(() => _urgency = pick.isEmpty ? null : pick);
            }
          },
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Recentes'),
          selected: _sort == 'recent',
          onSelected: (_) => setState(() => _sort = 'recent'),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Faixa valor'),
          selected: _sort == 'budget',
          onSelected: (_) => setState(() => _sort = 'budget'),
        ),
      ]),
    );
  }
}

class _OpportunityCard extends StatelessWidget {
  final ResolveRequest request;
  final int creditCost;
  final VoidCallback onOpen;
  const _OpportunityCard({
    required this.request,
    required this.creditCost,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final cat = Categories.byId(request.category);
    final group = request.groupId != null
        ? ServiceTaxonomy.groupById(request.groupId!)
        : null;
    final budget = request.budgetMin != null || request.budgetMax != null
        ? 'R\$ ${(request.budgetMin ?? 0).toStringAsFixed(0)}–${(request.budgetMax ?? 0).toStringAsFixed(0)}'
        : 'A combinar';
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${cat?.name ?? request.category}${group != null ? ' · ${group.name}' : ''}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                if (request.urgency != null)
                  AppTag(request.urgency!,
                      bg: request.urgency!.toLowerCase().contains('emerg')
                          ? AppColors.error
                          : AppColors.primary),
              ]),
              const SizedBox(height: 8),
              Text(request.summary,
                  style: const TextStyle(height: 1.35, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '${request.approxLocation} · ${_fmtDate(request.createdAt)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                AppTag(budget,
                    bg: AppColors.secondary.withValues(alpha: 0.15),
                    fg: AppColors.secondary),
                AppTag('${request.proposalCount} interessados',
                    bg: AppColors.primary.withValues(alpha: 0.12),
                    fg: AppColors.primary),
                AppTag('${request.slotsRemaining} vagas',
                    bg: AppColors.surfaceMuted, fg: AppColors.textDark),
                if (creditCost > 0)
                  AppTag('$creditCost creditos',
                      bg: Colors.orange.shade100, fg: Colors.orange.shade900),
              ]),
              if (request.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Fotos anexadas',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class OpportunityDetailScreen extends StatefulWidget {
  final ResolveRequest request;
  final MonetizationConfig config;
  final String providerId;
  const OpportunityDetailScreen({
    super.key,
    required this.request,
    required this.config,
    required this.providerId,
  });

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  bool _busy = false;
  bool _unlocked = false;
  String? _contactPhone;
  String? _contactName;

  @override
  void initState() {
    super.initState();
    LeadUnlockService.isUnlocked(
            providerId: widget.providerId, requestId: widget.request.id)
        .then((v) {
      if (mounted) setState(() => _unlocked = v);
    });
  }

  Future<void> _unlock() async {
    final cost = widget.config.defaultLeadCreditCost;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desbloquear contato'),
        content: Text(
          'Custo: $cost creditos.\n\n'
          'O valor e definido pelo Admin/plataforma — nao pelo aplicativo.\n'
          'Se voce ja desbloqueou este pedido, nao sera cobrado novamente.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final res = await LeadUnlockService.unlock(
      requestId: widget.request.id,
      providerId: widget.providerId,
      config: widget.config,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!res.ok) {
      snack(context, res.error ?? 'Falha ao desbloquear', bg: AppColors.error);
      return;
    }
    setState(() {
      _unlocked = true;
      _contactName = res.contactName;
      _contactPhone = res.contactPhone;
    });
    snack(
      context,
      res.alreadyUnlocked
          ? 'Contato ja liberado (sem nova cobranca)'
          : 'Contato liberado · ${res.creditsUsed} creditos',
      bg: AppColors.secondary,
    );
  }

  Future<void> _sendProposal() async {
    final priceCtrl = TextEditingController();
    final daysCtrl = TextEditingController(text: '3');
    final msgCtrl = TextEditingController();
    final materials = ValueNotifier<bool>(false);
    final validDays = TextEditingController(text: '7');
    final drafting = ValueNotifier<bool>(false);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Proposta assistida (rascunho)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'Voce informa valor, prazo e condicoes. A IA so organiza o texto. '
              'Nenhum envio ocorre sem a sua aprovacao. Sem cobranca neste passo.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Valor (R\$) — obrigatorio',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: daysCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Prazo (dias)', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(
                controller: msgCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Mensagem / condicoes (editavel)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: materials,
              builder: (_, v, __) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Materiais inclusos'),
                value: v,
                onChanged: (n) => materials.value = n,
              ),
            ),
            TextField(
                controller: validDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Validade da proposta (dias)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: drafting,
              builder: (_, busy, __) => OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () async {
                        final price = double.tryParse(
                                priceCtrl.text.replaceAll(',', '.')) ??
                            0;
                        final days = int.tryParse(daysCtrl.text) ?? 0;
                        if (price <= 0 || days < 1) {
                          snack(ctx,
                              'Informe valor e prazo antes de gerar o rascunho',
                              bg: AppColors.error);
                          return;
                        }
                        drafting.value = true;
                        try {
                          final res = await AiSvc.assistProposalDraft(
                            requestId: widget.request.id,
                            price: price,
                            deadlineDays: days,
                            requestSummary: widget.request.description,
                            materialsIncluded: materials.value,
                            conditions: msgCtrl.text.trim(),
                          );
                          if (res == null) {
                            if (!ctx.mounted) return;
                            snack(ctx,
                                'Assistente indisponivel. Escreva a mensagem manualmente.',
                                bg: AppColors.warning);
                            return;
                          }
                          final draft = Map<String, dynamic>.from(
                              res['draft'] as Map? ?? {});
                          msgCtrl.text = '${draft['message'] ?? ''}'.trim();
                        } finally {
                          drafting.value = false;
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(busy ? 'Gerando rascunho...' : 'Gerar rascunho com IA'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Revisar e aprovar envio',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) {
      priceCtrl.dispose();
      daysCtrl.dispose();
      msgCtrl.dispose();
      validDays.dispose();
      materials.dispose();
      drafting.dispose();
      return;
    }
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0;
    final days = int.tryParse(daysCtrl.text) ?? 1;
    final messageBody =
        '${msgCtrl.text.trim()}${materials.value ? '\nMateriais inclusos.' : ''}\nValidade: ${validDays.text} dias.';
    priceCtrl.dispose();
    daysCtrl.dispose();
    msgCtrl.dispose();
    validDays.dispose();
    materials.dispose();
    drafting.dispose();
    if (price <= 0) {
      snack(context, 'Informe um valor valido');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar envio da proposta?'),
        content: Text(
          'Valor: R\$ ${price.toStringAsFixed(2)}\n'
          'Prazo: $days dia(s)\n\n'
          '${messageBody.trim()}\n\n'
          'Confirme para enviar. Em homologacao nao ha cobranca real.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Editar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aprovar e enviar')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (HomologCatalog.enabled) {
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        snack(context, 'Proposta aprovada (homologacao — sem envio real de cobranca)',
            bg: AppColors.secondary);
        Navigator.pushNamed(context, Routes.resolveDetail,
            arguments: {'id': widget.request.id});
      } else {
        final prov = await FS.myProviderStream().first;
        await FS.submitResolveProposal(
          requestId: widget.request.id,
          providerName: prov?.name ?? 'Profissional',
          providerPhoto: prov?.photoUrl,
          price: price,
          deadlineDays: days,
          message: messageBody.trim(),
          rating: prov?.rating ?? 0,
          totalServices: prov?.totalReviews ?? 0,
        );
        if (!mounted) return;
        snack(context, 'Proposta enviada!', bg: AppColors.secondary);
      }
    } catch (e) {
      if (mounted) {
        snack(context, AppError.userMessage(e), bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final cat = Categories.byId(r.category);
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Detalhe da oportunidade'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(cat?.name ?? r.category,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(r.description, style: const TextStyle(height: 1.4)),
          const SizedBox(height: 12),
          _row('Localizacao aproximada', r.approxLocation),
          _row('Quando', r.urgency ?? 'A combinar'),
          _row('Modalidade', r.modality ?? 'A combinar'),
          _row('Interessados', '${r.proposalCount}'),
          _row('Vagas restantes', '${r.slotsRemaining}'),
          _row('Custo em creditos', '${widget.config.defaultLeadCreditCost}'),
          if (r.budgetMin != null || r.budgetMax != null)
            _row('Faixa',
                'R\$ ${(r.budgetMin ?? 0).toStringAsFixed(0)} – ${(r.budgetMax ?? 0).toStringAsFixed(0)}'),
          const SizedBox(height: 8),
          const Text(
            'Telefone, WhatsApp, e-mail e endereco completo so apos autorizacao '
            '(desbloqueio ou contratacao protegida).',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          if (_unlocked) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Contato liberado\n${_contactName ?? 'Cliente'}\n${_contactPhone ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Como participar?',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading: const Text('🔓', style: TextStyle(fontSize: 22)),
              title: const Text('Desbloquear contato',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Gasta creditos. Fala direto com o cliente. Sem comissao do app neste caminho.'),
              trailing: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
              onTap: _busy || _unlocked ? null : _unlock,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border)),
            child: ListTile(
              leading: const Text('🛡️', style: TextStyle(fontSize: 22)),
              title: const Text('Enviar proposta pelo Carajas 360',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Fluxo protegido: proposta, aceite, pagamento Sandbox, comissao e split.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : _sendProposal,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 140,
                child: Text(k,
                    style: const TextStyle(
                        color: AppColors.textLight, fontSize: 13))),
            Expanded(
                child: Text(v,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
