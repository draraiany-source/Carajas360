import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/services/service_matching.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_error.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Marketplace de serviços — vertical → grupo → serviço → questionário → matching.
class ServiceMarketplaceScreen extends StatefulWidget {
  final String? verticalId;
  final String? categoryId;
  const ServiceMarketplaceScreen({super.key, this.verticalId, this.categoryId});

  @override
  State<ServiceMarketplaceScreen> createState() =>
      _ServiceMarketplaceScreenState();
}

class _ServiceMarketplaceScreenState extends State<ServiceMarketplaceScreen> {
  @override
  Widget build(BuildContext context) {
    // Deep-link por categoryId legado → abre fluxo do serviço
    if (widget.categoryId != null && widget.categoryId!.isNotEmpty) {
      final svc = ServiceTaxonomy.serviceByCategoryId(widget.categoryId!);
      if (svc != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceRequestFlowScreen(service: svc),
            ),
          );
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
    }

    final verticals = ServiceTaxonomy.verticals;
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1100 ? 4 : (w >= 700 ? 3 : 2);

    return Scaffold(
      appBar: const CarajasAppBar(title: 'Marketplace de Serviços'),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Carajás 360 Serviços',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18)),
                  SizedBox(height: 6),
                  Text(
                    'Escolha a área, o serviço e descreva sua necessidade. '
                    'Profissionais compatíveis da região enviam propostas.',
                    style: TextStyle(color: Colors.white70, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: w >= 700 ? 1.35 : 1.15,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final v = verticals[i];
                  return _VerticalCard(
                    vertical: v,
                    onTap: () {
                      if (v.independentRoute != null &&
                          (v.id == 'saude' || v.id == 'maquinas')) {
                        Navigator.pushNamed(context, v.independentRoute!);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ServiceGroupsScreen(vertical: v),
                        ),
                      );
                    },
                  );
                },
                childCount: verticals.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalCard extends StatelessWidget {
  final TaxonomyVertical vertical;
  final VoidCallback onTap;
  const _VerticalCard({required this.vertical, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: vertical.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(vertical.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const Spacer(),
              Text(vertical.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 2),
              Text('${vertical.groups.length} grupos',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }
}

class ServiceGroupsScreen extends StatelessWidget {
  final TaxonomyVertical vertical;
  const ServiceGroupsScreen({super.key, required this.vertical});

  @override
  Widget build(BuildContext context) {
    final groups = vertical.groups.where((g) => g.active).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Scaffold(
      appBar: CarajasAppBar(title: vertical.name),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final g = groups[i];
          return Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ServiceListScreen(group: g),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Text(g.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('${g.services.where((s) => s.active).length} serviços',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textLight)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textLight),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ServiceListScreen extends StatelessWidget {
  final TaxonomyGroup group;
  const ServiceListScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final services = group.services.where((s) => s.active).toList();
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 900 ? 3 : (w >= 600 ? 2 : 1);

    return Scaffold(
      appBar: CarajasAppBar(title: group.name),
      body: services.isEmpty
          ? const EmptyState(
              emoji: '📭',
              title: 'Nenhum serviço',
              subtitle: 'Em breve novos serviços nesta área.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: cols == 1 ? 3.2 : 2.4,
              ),
              itemCount: services.length,
              itemBuilder: (_, i) {
                final s = services[i];
                return Material(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceRequestFlowScreen(service: s),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(s.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  s.pricingMode == ServicePricingMode.fixedPrice
                                      ? 'Preço fixo'
                                      : s.pricingMode ==
                                              ServicePricingMode.requestQuote
                                          ? 'Orçamento'
                                          : 'Preço fixo ou orçamento',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Questionário dinâmico + matching + criação de pedido/orçamento.
class ServiceRequestFlowScreen extends StatefulWidget {
  final TaxonomyService service;
  const ServiceRequestFlowScreen({super.key, required this.service});

  @override
  State<ServiceRequestFlowScreen> createState() =>
      _ServiceRequestFlowScreenState();
}

class _ServiceRequestFlowScreenState extends State<ServiceRequestFlowScreen> {
  final _answers = <String, String>{};
  final _controllers = <String, TextEditingController>{};
  final _city = TextEditingController(text: RegionCities.defaultCity);
  ServicePricingMode? _pricingChoice;
  bool _submitting = false;
  bool _showMatches = false;
  List<MatchScore> _matches = const [];

  @override
  void initState() {
    super.initState();
    for (final q in widget.service.questions) {
      _controllers[q.id] = TextEditingController();
    }
    if (widget.service.pricingMode == ServicePricingMode.fixedPrice) {
      _pricingChoice = ServicePricingMode.fixedPrice;
    } else if (widget.service.pricingMode == ServicePricingMode.requestQuote) {
      _pricingChoice = ServicePricingMode.requestQuote;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validate() {
    for (final q in widget.service.questions) {
      if (!q.required) continue;
      final v = (_answers[q.id] ?? _controllers[q.id]?.text ?? '').trim();
      if (v.isEmpty) {
        snack(context, 'Preencha: ${q.label}');
        return false;
      }
      _answers[q.id] = v;
    }
    for (final e in _controllers.entries) {
      if (e.value.text.trim().isNotEmpty) {
        _answers[e.key] = e.value.text.trim();
      }
    }
    if (_pricingChoice == null) {
      snack(context, 'Escolha preço fixo ou solicitar orçamento');
      return false;
    }
    if (!ServiceMatching.pricingAllowed(widget.service, _pricingChoice!)) {
      snack(context, 'Modalidade de preço não permitida para este serviço');
      return false;
    }
    return true;
  }

  Future<void> _runMatching() async {
    if (!_validate()) return;
    setState(() => _submitting = true);
    try {
      List<ProviderModel> pool;
      if (HomologCatalog.enabled) {
        pool = HomologCatalog.providers(category: widget.service.categoryId);
        if (pool.isEmpty) pool = HomologCatalog.providers();
      } else {
        // Dados reais do Firestore — nunca seed de demonstração.
        pool = await FS.providersStream(
          category: widget.service.categoryId,
          limit: 80,
        ).first;
        if (pool.isEmpty) {
          pool = await FS.providersStream(limit: 80).first;
        }
      }
      final matched = ServiceMatching.rank(
        candidates: pool,
        categoryId: widget.service.categoryId,
        city: _city.text.trim(),
        modality: _answers['modality'],
        answers: _answers,
      );
      if (!mounted) return;
      setState(() {
        _matches = matched;
        _showMatches = true;
      });
    } catch (_) {
      if (!mounted) return;
      snack(context,
          'Não foi possível carregar profissionais. Verifique a conexão.',
          bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitQuoteRequest() async {
    if (!_validate()) return;
    if (AuthService.uid == null) {
      snack(context, 'Faça login para continuar');
      Navigator.pushNamed(context, Routes.login,
          arguments: {'returnRoute': Routes.serviceMarketplace});
      return;
    }
    setState(() => _submitting = true);
    try {
      final desc = _answers['description'] ??
          _controllers['description']?.text.trim() ??
          widget.service.name;
      final user = await FS.getUser();
      final id = await FS.createResolveRequest(
        description: desc,
        category: widget.service.categoryId,
        city: _city.text.trim().isEmpty
            ? RegionCities.defaultCity
            : _city.text.trim(),
        clientName: user?.name,
        serviceId: widget.service.id,
        groupId: widget.service.groupId,
        pricingMode: _pricingChoice!.name,
        urgency: _answers['urgency'],
        modality: _answers['modality'],
        answers: Map<String, dynamic>.from(_answers),
        suggestedPrice: _pricingChoice == ServicePricingMode.fixedPrice
            ? widget.service.suggestedFixedPrice
            : null,
      );
      if (!mounted) return;
      snack(context, 'Solicitação enviada!', bg: AppColors.secondary);
      Navigator.pushReplacementNamed(context, Routes.resolveDetail,
          arguments: {'id': id});
    } catch (e) {
      if (mounted) {
        snack(context,
            AppError.userMessage(e, message: 'Não foi possível enviar.'),
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _hireDirect(ProviderModel p) async {
    if (AuthService.uid == null) {
      snack(context, 'Faça login para contratar');
      return;
    }
    Navigator.pushNamed(context, Routes.requestService, arguments: {
      'providerId': p.id,
      'providerName': p.name,
      'category': widget.service.categoryId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return Scaffold(
      appBar: CarajasAppBar(title: s.name),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                if (s.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(s.description,
                      style: const TextStyle(
                          color: AppColors.textLight, height: 1.3)),
                ],
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  AppTag(
                    s.pricingMode == ServicePricingMode.fixedPrice
                        ? 'Preço fixo'
                        : s.pricingMode == ServicePricingMode.requestQuote
                            ? 'Orçamento'
                            : 'Fixo / Orçamento',
                    bg: AppColors.primary,
                  ),
                  if (s.suggestedFixedPrice != null)
                    AppTag(
                      'A partir de R\$ ${s.suggestedFixedPrice!.toStringAsFixed(0)}',
                      bg: AppColors.secondary,
                    ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Como deseja contratar?',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (s.pricingMode != ServicePricingMode.requestQuote)
              ChoiceChip(
                label: const Text('Preço fixo'),
                selected: _pricingChoice == ServicePricingMode.fixedPrice,
                onSelected: (_) => setState(
                    () => _pricingChoice = ServicePricingMode.fixedPrice),
              ),
            if (s.pricingMode != ServicePricingMode.fixedPrice)
              ChoiceChip(
                label: const Text('Solicitar orçamento'),
                selected: _pricingChoice == ServicePricingMode.requestQuote,
                onSelected: (_) => setState(
                    () => _pricingChoice = ServicePricingMode.requestQuote),
              ),
          ]),
          const SizedBox(height: 16),
          const Text('Localização (bairro/cidade)',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
              hintText: 'Cidade — endereço completo só após contratação',
            ),
          ),
          const SizedBox(height: 16),
          ...s.questions.map(_buildQuestion),
          const SizedBox(height: 20),
          if (!_showMatches) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _runMatching,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search_rounded),
                label: Text(
                    _submitting
                        ? 'Buscando…'
                        : 'Ver profissionais compatíveis',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _submitting ? null : _submitQuoteRequest,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Enviar e receber propostas',
                        style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ] else ...[
            Text(
              _matches.isEmpty
                  ? 'Nenhum profissional compatível nesta região'
                  : '${_matches.length} profissional(is) compatível(is)',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (_matches.isEmpty)
              const EmptyState(
                emoji: '🔎',
                title: 'Sem resultados',
                subtitle:
                    'Tente outra cidade ou envie o pedido para a rede receber propostas.',
              )
            else
              ..._matches.take(12).map((m) => _MatchCard(
                    match: m,
                    onHire: () => _hireDirect(m.provider),
                    onQuote: () {
                      _answers['preferred_provider'] = m.provider.id;
                      _submitQuoteRequest();
                    },
                  )),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _showMatches = false),
              child: const Text('Voltar ao formulário'),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitQuoteRequest,
                child: const Text('Solicitar propostas de todos elegíveis'),
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildQuestion(ServiceQuestion q) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.required ? '${q.label} *' : q.label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          switch (q.type) {
            ServiceQuestionType.multiline => TextField(
                controller: _controllers[q.id],
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: q.hint,
                  border: const OutlineInputBorder(),
                ),
              ),
            ServiceQuestionType.singleChoice => Wrap(
                spacing: 8,
                children: q.options
                    .map((o) => ChoiceChip(
                          label: Text(o),
                          selected: _answers[q.id] == o,
                          onSelected: (_) =>
                              setState(() => _answers[q.id] = o),
                        ))
                    .toList(),
              ),
            ServiceQuestionType.boolean => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(q.hint ?? 'Sim / Não'),
                value: _answers[q.id] == 'true',
                onChanged: (v) =>
                    setState(() => _answers[q.id] = v ? 'true' : 'false'),
              ),
            ServiceQuestionType.date => ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border),
                ),
                title: Text(_answers[q.id] ?? 'Selecionar data'),
                trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() => _answers[q.id] =
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
                  }
                },
              ),
            _ => TextField(
                controller: _controllers[q.id],
                keyboardType: q.type == ServiceQuestionType.number
                    ? TextInputType.number
                    : TextInputType.text,
                decoration: InputDecoration(
                  hintText: q.hint,
                  border: const OutlineInputBorder(),
                ),
              ),
          },
        ],
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchScore match;
  final VoidCallback onHire;
  final VoidCallback onQuote;
  const _MatchCard({
    required this.match,
    required this.onHire,
    required this.onQuote,
  });

  @override
  Widget build(BuildContext context) {
    final p = match.provider;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(url: p.photoUrl, name: p.name, size: 44, r: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(
                      '⭐ ${p.rating.toStringAsFixed(1)} · ${p.totalReviews} aval. · ${p.city ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
              if (p.verified)
                const Icon(Icons.verified, color: AppColors.secondary, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: match.reasons
                .take(3)
                .map((r) => AppTag(r,
                    bg: AppColors.primary.withValues(alpha: 0.12),
                    fg: AppColors.primary))
                .toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onQuote,
                  child: const Text('Orçamento'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onHire,
                  child: const Text('Contratar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
