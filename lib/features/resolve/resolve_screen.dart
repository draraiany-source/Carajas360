import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/catalog/catalog_selection.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/catalog/catalog.dart';
import '../../core/security/order_policy.dart';
import 'package:geolocator/geolocator.dart';
import '../checkout/payment_screens.dart';
import '../checkout/payments_api.dart';
import 'questionnaire.dart';
import 'questionnaire_form.dart';
import 'resolve_contact.dart';
import '../provider/money_parse.dart';

/// Cliente: descreve necessidade e recebe propostas.
class ResolveScreen extends StatefulWidget {
  /// Serviço já escolhido (ex.: "pedir orçamento" a partir de um serviço).
  final String? initialCatalogId;
  const ResolveScreen({super.key, this.initialCatalogId});
  @override
  State<ResolveScreen> createState() => _ResolveScreenState();
}

class _ResolveScreenState extends State<ResolveScreen> {
  final _desc = TextEditingController();
  final _city = TextEditingController(text: RegionCities.defaultCity);
  final _address = TextEditingController();
  final _phone = TextEditingController();
  CatalogSelection _sel = CatalogSelection.none;
  String? get _category => _sel.groupId == null ? null : _sel.selectedId;
  bool _sending = false;
  // Mesmo id em repetições (clique duplo / resposta perdida): o servidor
  // devolve a mesma solicitação.
  String _requestId = _newId();
  String _modality = 'presential';
  DateTime? _date;
  String _period = 'any';
  Map<String, double>? _geo;
  Questionnaire? _questionnaire;
  String? _questionnaireFor;
  final Map<String, Object?> _answers = {};
  bool _initApplied = false;

  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${AuthService.uid?.substring(0, 4) ?? 'x'}';

  @override
  void dispose() {
    for (final c in [_desc, _city, _address, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Carrega o questionário publicado do item mais específico selecionado.
  Future<void> _loadQuestionnaire(Catalog catalog) async {
    final id = _category;
    if (id == _questionnaireFor) return;
    _questionnaireFor = id;
    String? qid;
    for (final n in catalog.pathOf(id ?? '').reversed) {
      if (n.questionnaireId != null) {
        qid = n.questionnaireId;
        break;
      }
    }
    _answers.clear();
    if (qid == null) {
      if (mounted) setState(() => _questionnaire = null);
      return;
    }
    final m = await FS.resolveQuestionnaire(qid);
    if (!mounted || _questionnaireFor != id) return;
    setState(() => _questionnaire = m == null
        ? null
        : Questionnaire.fromMap(m['id'] as String, Map<String, dynamic>.from(m)));
  }

  Future<void> _useLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) snack(context, 'Permissão de localização negada.');
        return;
      }
      final p = await Geolocator.getCurrentPosition();
      // Aproximada (~1 km): o endereço exato fica no campo privado.
      setState(() => _geo = {
            'lat': (p.latitude * 100).roundToDouble() / 100,
            'lng': (p.longitude * 100).roundToDouble() / 100,
          });
    } catch (e) {
      if (mounted) snack(context, 'Não foi possível obter a localização.');
    }
  }

  Future<void> _submit() async {
    if (AuthService.uid == null) {
      snack(context, 'Faça login para pedir orçamento');
      return;
    }
    if (_desc.text.trim().length < 10) {
      snack(context, 'Descreva melhor o que você precisa (mín. 10 caracteres)');
      return;
    }
    if (_category == null) {
      snack(context, 'Selecione a categoria e o grupo do serviço');
      return;
    }
    final cs = CatalogService.instance.state.value;
    if (cs.fromCache) {
      snack(context, 'Você está offline. O pedido só pode ser enviado com conexão.',
          bg: AppColors.error);
      return;
    }
    if (!cs.catalog.isActive(_category!)) {
      snack(context, 'Este serviço não está disponível para novas solicitações.',
          bg: AppColors.error);
      return;
    }
    final q = _questionnaire?.collect(_answers);
    if (q != null && q.errors.isNotEmpty) {
      snack(context, q.errors.first, bg: AppColors.error);
      return;
    }
    setState(() => _sending = true);
    try {
      final id = await FS.createResolveRequest(
        requestId: _requestId,
        description: _desc.text.trim(),
        category: _category!,
        city: _city.text.trim(),
        modality: _modality,
        preferredDate: _date?.toIso8601String().substring(0, 10),
        preferredPeriod: _period,
        geo: _geo,
        address: _address.text,
        phone: _phone.text,
        answers: q?.answers ?? const {},
      );
      if (!mounted) return;
      _requestId = _newId();
      snack(context, 'Pedido enviado! Profissionais compatíveis foram avisados.',
          bg: AppColors.secondary);
      Navigator.pushReplacementNamed(context, Routes.resolveDetail,
          arguments: {'id': id});
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } catch (e) {
      if (mounted) {
        snack(context, 'Sem resposta do servidor. Tente de novo — o pedido não será duplicado.',
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  static const _modalities = {
    'presential': 'Presencial',
    'home_care': 'No meu endereço',
    'online': 'Online',
  };
  static const _periods = {
    'any': 'Qualquer horário',
    'morning': 'Manhã',
    'afternoon': 'Tarde',
    'evening': 'Noite',
  };

  Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resolve Carajás'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, Routes.myResolve),
            child: const Text('Meus pedidos'),
          ),
        ],
      ),
      body: ListView(
        padding: pagePadding(context),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppGradients.secondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Descreva o que você precisa. Profissionais aprovados, do serviço, da sua região e disponíveis enviam propostas com valor e prazo.',
              style: TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
          _h('Serviço'),
          CatalogBuilder(
            compact: true,
            builder: (_, catalog) {
              final init = widget.initialCatalogId;
              if (_sel.isEmpty && init != null && !_initApplied && catalog.byId(init) != null) {
                _initApplied = true;
                _sel = CatalogSelection.forNode(catalog, init);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) => _loadQuestionnaire(catalog));
              return CatalogDropdownSelector(
                catalog: catalog,
                selection: _sel.sanitize(catalog),
                onChanged: (v) => setState(() => _sel = v),
              );
            },
          ),
          _h('O que você precisa?'),
          TextField(
            key: const Key('resolve-desc'),
            controller: _desc,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ex.: Preciso instalar 3 ar-condicionados no comércio.',
              border: OutlineInputBorder(),
            ),
          ),
          if (_questionnaire != null) ...[
            _h(_questionnaire!.title),
            QuestionnaireForm(
                questionnaire: _questionnaire!,
                answers: _answers,
                onChanged: () => setState(() {})),
          ],
          _h('Como será o atendimento?'),
          Wrap(spacing: 8, children: [
            for (final e in _modalities.entries)
              ChoiceChip(
                  label: Text(e.value),
                  selected: _modality == e.key,
                  onSelected: (_) => setState(() => _modality = e.key)),
          ]),
          _h('Quando?'),
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(_date == null
                    ? 'Sem data definida'
                    : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'),
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(
                      context: context,
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 180)),
                      initialDate: _date ?? now.add(const Duration(days: 1)));
                  if (d != null) setState(() => _date = d);
                }),
            if (_date != null)
              IconButton(
                  tooltip: 'Remover data',
                  onPressed: () => setState(() => _date = null),
                  icon: const Icon(Icons.close)),
            for (final e in _periods.entries)
              ChoiceChip(
                  label: Text(e.value),
                  selected: _period == e.key,
                  onSelected: (_) => setState(() => _period = e.key)),
          ]),
          if (_modality != 'online') ...[
            _h('Onde?'),
            TextField(
              controller: _city,
              decoration: const InputDecoration(
                labelText: 'Cidade',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Endereço (só o profissional escolhido verá)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                icon: Icon(_geo == null ? Icons.my_location : Icons.check_circle, size: 18),
                label: Text(_geo == null
                    ? 'Usar minha localização aproximada (para o raio de atendimento)'
                    : 'Localização aproximada definida'),
                onPressed: _useLocation),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone (opcional, só para o profissional escolhido)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              key: const Key('resolve-submit'),
              onPressed: _sending ? null : _submit,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Pedir orçamento', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, Routes.resolveOpportunities),
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
                        '${CatalogService.instance.catalog.byId(req.category)?.icon ?? '🛠️'} ${req.serviceName ?? CatalogService.instance.catalog.nameOf(req.category)} · 📍 ${req.city}',
                        style: const TextStyle(
                            color: AppColors.textLight, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (req.preferredDate != null)
                      Text('📅 ${req.preferredDate} · ${_periodLabel(req.preferredPeriod)} · ${_modalityLabel(req.modality)}',
                          style: const TextStyle(color: AppColors.textLight, fontSize: 12)),
                    for (final a in req.answers)
                      Text('• ${a['label']}: ${a['value']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                    const SizedBox(height: 4),
                    Text(
                        req.status == ResolveStatus.matched
                            ? 'Status: contratado'
                            : req.status == ResolveStatus.cancelled
                                ? 'Status: cancelado'
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
              if (req.status == ResolveStatus.matched && req.orderId != null)
                _ContractCard(request: req),
              if (req.status == ResolveStatus.open && req.clientId == AuthService.uid)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () async {
                        try {
                          await FS.cancelResolveRequest(requestId);
                        } on CloudCallException catch (e) {
                          if (context.mounted) snack(context, e.message, bg: AppColors.error);
                        }
                      },
                      child: const Text('Cancelar solicitação', style: TextStyle(color: AppColors.error))),
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
                            'Profissionais da região foram notificados. Volte em breve.',
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
                            final ok = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                      title: const Text('Aceitar proposta?'),
                                      content: Text(
                                          '${p.providerName} · ${brl((p.price * 100).round())} · ${p.deadlineDays} dia(s).\nAs demais propostas serão encerradas.'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
                                        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Aceitar')),
                                      ],
                                    ));
                            if (ok != true) return;
                            try {
                              await FS.acceptResolveProposal(
                                  requestId: requestId,
                                  proposalId: p.id,
                                  expectedPriceCents: (p.price * 100).round());
                            } on CloudCallException catch (e) {
                              if (context.mounted) snack(context, e.message, bg: AppColors.error);
                              return;
                            } catch (e) {
                              if (context.mounted) {
                                snack(context, 'Sem resposta do servidor. Tente de novo — o aceite não será duplicado.',
                                    bg: AppColors.error);
                              }
                              return;
                            }
                            if (context.mounted) {
                              snack(context, 'Proposta aceita! Pedido criado.', bg: AppColors.secondary);
                            }
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
                    '⭐ ${proposal.rating.toStringAsFixed(1)} · ${proposal.totalServices} serviços',
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
          Text(brl((proposal.price * 100).round()),
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.primary)),
          const SizedBox(width: 12),
          Text('Prazo: ${proposal.deadlineDays} dia(s)',
              style: const TextStyle(fontSize: 13)),
          if (proposal.available) ...[
            const SizedBox(width: 8),
            const Text('· Disponível',
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
          if (snap.hasError) return QueryErrorView(error: snap.error);
          final list = snap.data ?? [];
          if (snap.connectionState == ConnectionState.waiting &&
              list.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (list.isEmpty) {
            return const EmptyState(
              emoji: '📋',
              title: 'Nenhum pedido ainda',
              subtitle: 'Peça um orçamento e receba propostas da região.',
            );
          }
          return ListView.separated(
            padding: pagePadding(context),
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
                    '${r.city} · ${r.proposalCount} proposta(s) · ${resolveStatusLabel(r.status)}'),
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
    final price = parseBrlAmount(priceCtrl.text) ?? 0;
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
              padding: pagePadding(context),
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
                          '📍 ${r.city}${r.neighborhood != null ? ' · ${r.neighborhood}' : ''} · ${CatalogService.instance.catalog.nameOf(r.category)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textLight)),
                      Text(
                          [
                            _modalityLabel(r.modality),
                            if (r.distanceKm != null) '~${r.distanceKm!.toStringAsFixed(1)} km',
                            if (r.preferredDate != null) '📅 ${r.preferredDate} (${_periodLabel(r.preferredPeriod)})',
                            if (r.attachmentCount > 0) '📎 ${r.attachmentCount} anexo(s) após aceite',
                          ].join(' · '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                      for (final a in r.answers)
                        Text('• ${a['label']}: ${a['value']}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
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

/// Situação da solicitação em português (lista "Meus Resolve").
String resolveStatusLabel(ResolveStatus s) => switch (s) {
      ResolveStatus.open => 'Aguardando propostas',
      ResolveStatus.matched => 'Contratado',
      ResolveStatus.closed => 'Encerrado',
      ResolveStatus.cancelled => 'Cancelado',
    };

String _modalityLabel(String? m) => switch (m) {
      'online' => 'Online',
      'home_care' => 'No endereço do cliente',
      _ => 'Presencial',
    };

String _periodLabel(String? p) => switch (p) {
      'morning' => 'manhã',
      'afternoon' => 'tarde',
      'evening' => 'noite',
      _ => 'qualquer horário',
    };

/// Contratação: pedido criado no aceite, com chat, agenda e pagamento.
class _ContractCard extends StatelessWidget {
  final ResolveRequest request;
  const _ContractCard({required this.request});

  // Lista todos os anexos; cada um abre por URL temporária do servidor.
  void _openAttachments(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (c) => SafeArea(
              child: ListView(shrinkWrap: true, children: [
                for (var i = 0; i < request.attachmentCount; i++)
                  ListTile(
                      key: Key('attachment-$i'),
                      leading: const Icon(Icons.attach_file),
                      title: Text('Anexo ${i + 1}'),
                      onTap: () async {
                        try {
                          final url = await FS.resolveAttachmentUrl(request.id, i);
                          if (url != null) await launchUrl(Uri.parse(url));
                        } on CloudCallException catch (e) {
                          if (context.mounted) snack(context, e.message, bg: AppColors.error);
                        } catch (_) {
                          if (context.mounted) snack(context, genericActionError, bg: AppColors.error);
                        }
                      }),
              ]),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final mine = request.clientId == AuthService.uid;
    // Prestador escolhido vê endereço/telefone do cliente.
    final isProvider = request.matchedProviderId != null &&
        request.matchedProviderId == AuthService.uid;
    return StreamBuilder(
        stream: FirebaseFirestore.instance.collection('orders').doc(request.orderId).snapshots(),
        builder: (context, snap) {
          final o = snap.data?.data();
          final paid = o?['paymentStatus'] == 'paid';
          final price = (o?['priceCents'] as num?)?.toInt() ?? ((request.acceptedPrice ?? 0) * 100).round();
          // Nome da outra parte no chat.
          String nameOf(Object? v, String fallback) {
            final t = (v ?? '').toString().trim();
            return t.isEmpty ? fallback : t;
          }
          final otherName = mine
              ? nameOf(o?['providerName'], 'Profissional')
              : nameOf(o?['clientName'] ?? request.clientName, 'Cliente');
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.secondary)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✅ Pedido contratado', style: TextStyle(fontWeight: FontWeight.w800)),
              Text('Valor aceito: ${brl(price)} · ${paid ? 'pago' : 'pagamento pendente'}',
                  key: const Key('contract-status'), style: const TextStyle(fontSize: 12)),
              if (request.preferredDate != null)
                Text('Agenda: ${request.preferredDate} (${_periodLabel(request.preferredPeriod)}) — a confirmar com o profissional',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              if (isProvider) ...[
                const SizedBox(height: 6),
                ResolveClientContact(requestId: request.id),
              ],
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (request.chatRoomId != null)
                  OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Chat'),
                      onPressed: () => Navigator.pushNamed(context, Routes.chat,
                          arguments: {'roomId': request.chatRoomId, 'name': otherName})),
                if (mine && !paid && o != null && price > 0)
                  ElevatedButton.icon(
                      key: const Key('pay-service'),
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Pagar'),
                      onPressed: () => showModalBottomSheet(
                          context: context,
                          builder: (c) => SafeArea(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  for (final m in const [('pix', 'Pix'), ('card', 'Cartão de crédito')])
                                    ListTile(
                                        title: Text(m.$2),
                                        onTap: () {
                                          Navigator.pop(c);
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) => PaymentScreen(
                                                      target: PayTarget('service', request.orderId!, price,
                                                          'Serviço contratado (Resolve)'),
                                                      method: m.$1)));
                                        }),
                                ]),
                              ))),
                if (request.attachmentCount > 0)
                  TextButton.icon(
                      icon: const Icon(Icons.attach_file, size: 18),
                      label: Text('Anexos (${request.attachmentCount})'),
                      onPressed: () => _openAttachments(context)),
              ]),
            ]),
          );
        });
  }
}
