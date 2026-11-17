import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../core/security/order_policy.dart';
import '../../shared/widgets/widgets.dart';
import '../orders/order_photo_picker.dart';

// ─────────────────────────────────────────────────────────────
// PROVIDER HOME SCREEN (Vol.3: Perfil do Profissional — Serviços,
// Agenda). Painel onde o prestador vê e responde aos pedidos
// recebidos, fechando o ciclo Cliente → Pedido → Prestador → GPS.
// ─────────────────────────────────────────────────────────────
class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});
  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  StreamSubscription<List<OrderModel>>? _newOrdersSub;
  int _lastPendingCount = -1; // -1 = primeira carga (não alertar)

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Alerta estilo iFood: quando chega pedido novo, vibra e avisa.
    _newOrdersSub = FS.providerOrdersStream(
        statuses: const [OrderStatus.pending]).listen((orders) {
      if (!mounted) return;
      if (_lastPendingCount >= 0 && orders.length > _lastPendingCount) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        snack(context, '🔔 Novo pedido recebido!', bg: AppColors.secondary);
        _tab.animateTo(0);
      }
      _lastPendingCount = orders.length;
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _newOrdersSub?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Widget _kpi(String label, String value) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ]),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
                child: GradHeader(
                    gradient: AppGradients.primary,
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('🔧 Meus Atendimentos',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20)),
                            GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 20))),
                          ]),
                      const SizedBox(height: 12),
                      // ── Estilo Uber/iFood: ficar online/offline. Offline sai da
                      // busca na hora (providersStream filtra active == true).
                      StreamBuilder<ProviderModel?>(
                        stream: FS.myProviderStream(),
                        builder: (_, snap) {
                          final prov = snap.data;
                          final online = prov?.active ?? true;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                      color: online
                                          ? const Color(0xFF69F0AE)
                                          : Colors.white38,
                                      shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      online
                                          ? 'Você está online'
                                          : 'Você está offline',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13))),
                              Switch(
                                value: online,
                                activeColor: const Color(0xFF69F0AE),
                                inactiveThumbColor: Colors.white70,
                                onChanged: prov == null
                                    ? null
                                    : (v) async {
                                        await FS.setProviderOnline(prov.id, v);
                                        if (context.mounted)
                                          snack(
                                              context,
                                              v
                                                  ? '✅ Online! Você aparece nas buscas.'
                                                  : 'Offline. Você saiu das buscas.',
                                              bg: v
                                                  ? AppColors.secondary
                                                  : AppColors.textLight);
                                      },
                              ),
                            ]),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      // ── Ganhos do dia, no padrão dos apps de motorista/entregador.
                      StreamBuilder<List<OrderModel>>(
                        stream: FS.providerOrdersStream(
                            statuses: const [OrderStatus.completed]),
                        builder: (_, snap) {
                          final now = DateTime.now();
                          final today = (snap.data ?? const <OrderModel>[])
                              .where((o) =>
                                  o.createdAt.year == now.year &&
                                  o.createdAt.month == now.month &&
                                  o.createdAt.day == now.day)
                              .toList();
                          final total = today.fold<double>(
                              0, (s, o) => s + (o.price ?? 0));
                          // Repasse: valor menos a comissão da plataforma.
                          final net = total * (1 - AppConst.commission);
                          return Row(children: [
                            _kpi('Hoje', PaySvc.fmt(net)),
                            const SizedBox(width: 8),
                            _kpi('Atendimentos', '${today.length}'),
                            const SizedBox(width: 8),
                            _kpi('Bruto', PaySvc.fmt(total)),
                          ]);
                        },
                      ),
                      const SizedBox(height: 14),
                      TabBar(
                          controller: _tab,
                          indicatorColor: Colors.white,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700),
                          tabs: const [
                            Tab(text: 'Novos'),
                            Tab(text: 'Em andamento'),
                            Tab(text: 'Concluídos')
                          ]),
                    ])))
          ],
          body: TabBarView(controller: _tab, children: [
            _OrderList(
                statuses: const [OrderStatus.pending],
                emptyEmoji: '📭',
                emptyTitle: 'Sem pedidos novos',
                emptySub: 'Novas solicitações aparecerão aqui'),
            _OrderList(
                statuses: const [OrderStatus.accepted, OrderStatus.inProgress],
                emptyEmoji: '🔧',
                emptyTitle: 'Nada em andamento',
                emptySub: 'Pedidos aceitos aparecerão aqui'),
            Column(children: [
              const WeeklyEarnings(),
              Expanded(
                  child: _OrderList(
                      statuses: const [OrderStatus.completed],
                      emptyEmoji: '✅',
                      emptyTitle: 'Sem histórico ainda',
                      emptySub: 'Serviços concluídos aparecerão aqui')),
            ]),
          ]),
        ),
      );
}

class _OrderList extends StatelessWidget {
  final List<OrderStatus> statuses;
  final String emptyEmoji, emptyTitle, emptySub;
  const _OrderList(
      {required this.statuses,
      required this.emptyEmoji,
      required this.emptyTitle,
      required this.emptySub});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderModel>>(
        stream: FS.providerOrdersStream(statuses: statuses),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError && !snap.hasData) {
            return const EmptyState(
              emoji: '⚠️',
              title: 'Falha ao carregar pedidos',
              subtitle: 'Verifique a conexão e tente novamente.',
            );
          }
          final orders = snap.data ?? const <OrderModel>[];
          if (orders.isEmpty) {
            return EmptyState(
                emoji: emptyEmoji, title: emptyTitle, subtitle: emptySub);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final cat = Categories.byId(o.category);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppDecorations.card(r: 16),
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: (cat?.color ?? AppColors.primary)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(cat?.emoji ?? '🔧',
                                style: const TextStyle(fontSize: 20))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(children: [
                                Expanded(
                                    child: Text(o.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14))),
                                if (o.urgent)
                                  const AppTag('🚨 Urgente',
                                      bg: Color(0xFFFFEBEE),
                                      fg: AppColors.error),
                              ]),
                              Text(fmtDate(o.createdAt),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight)),
                            ])),
                        if (o.price != null)
                          Text(PaySvc.fmt(o.price!),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: AppColors.secondary)),
                      ]),
                      const SizedBox(height: 8),
                      Text(o.description,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMedium,
                              height: 1.4)),
                      if (o.siteVisitRequested) ...[
                        const SizedBox(height: 6),
                        const AppTag('Visita técnica solicitada',
                            bg: Color(0xFFFFF8E1), fg: AppColors.warning),
                      ],
                      if (o.photoUrls.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        OrderPhotoGallery(urls: o.photoUrls),
                      ],
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 14, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(o.address,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textLight),
                                overflow: TextOverflow.ellipsis))
                      ]),
                      if (o.status == OrderStatus.accepted ||
                          o.status == OrderStatus.inProgress) ...[
                        const SizedBox(height: 6),
                        AppTag(o.statusLabel,
                            bg: o.status == OrderStatus.inProgress
                                ? const Color(0xFFE1F5FE)
                                : const Color(0xFFE7F5EB),
                            fg: o.status == OrderStatus.inProgress
                                ? AppColors.info
                                : AppColors.primary),
                        const SizedBox(height: 4),
                        Text(
                            o.isPaid
                                ? 'Pago pelo cliente: valor retido até a conclusão'
                                : 'Aguardando pagamento do cliente (necessário para concluir)',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: o.isPaid
                                    ? AppColors.secondary
                                    : AppColors.textLight)),
                      ],
                      const SizedBox(height: 12),
                      if (o.status == OrderStatus.pending)
                        _PendingActions(order: o),
                      if (o.status == OrderStatus.accepted)
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await FS.startOrder(o.id);
                                if (context.mounted)
                                  Navigator.pushNamed(context, Routes.gps,
                                      arguments: {
                                        'ctx': 'servico',
                                        'orderId': o.id
                                      });
                              },
                              icon: const Icon(Icons.play_arrow_rounded,
                                  size: 18),
                              label: const Text('Iniciar atendimento',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10)),
                            )),
                      if (o.status == OrderStatus.inProgress)
                        Row(children: [
                          Expanded(
                              child: OutlinedButton.icon(
                                  onPressed: () => ChatNav.open(context,
                                      otherUserId: o.clientId,
                                      otherName: 'Cliente'),
                                  icon: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 16),
                                  label: const Text('Chat',
                                      style: TextStyle(fontSize: 12)))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: () async {
                                    try {
                                      await FS.completeOrder(o.id);
                                      if (context.mounted) {
                                        snack(context,
                                            '✅ Serviço concluído. O valor é liberado quando o cliente confirmar ou ao fim do prazo de custódia.',
                                            bg: AppColors.secondary);
                                      }
                                    } on CloudCallException catch (e) {
                                      if (context.mounted) {
                                        snack(context, e.message,
                                            bg: AppColors.error);
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.secondary,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10)),
                                  child: const Text('Concluir',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)))),
                        ]),
                    ]),
              );
            },
          );
        },
      );
}

// ─────────────────────────────────────────────────────────────
// PROVIDER ONBOARDING SCREEN (Vol.3: Cadastro de Profissionais —
// foto, documento, selfie, certificados, áreas atendidas).
// Aberta logo após o cadastro básico, quando o tipo é provider.
// Todos os arquivos são opcionais aqui para não travar o fluxo,
// mas o admin só aprova (FS.approveProvider) quem enviou os
// documentos — a UI deixa isso claro para o prestador.
// ─────────────────────────────────────────────────────────────
class ProviderOnboardingScreen extends StatefulWidget {
  /// Falso no fluxo pós-cadastro, onde o envio de documentos é obrigatório.
  final bool allowBack;
  const ProviderOnboardingScreen({super.key, this.allowBack = false});
  @override
  State<ProviderOnboardingScreen> createState() => _ProviderOnboardingState();
}

class _ProviderOnboardingState extends State<ProviderOnboardingScreen> {
  XFile? _photo, _document, _selfie;
  Uint8List? _photoBytes, _documentBytes, _selfieBytes;
  final _certCtrl = TextEditingController();
  final _areasCtrl = TextEditingController();
  final _certificates = <String>[];
  bool _loading = false;

  @override
  void dispose() {
    _certCtrl.dispose();
    _areasCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile, Uint8List) onPicked,
      {required ImageSource source}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1600);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => onPicked(picked, bytes));
    }
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      String? photoUrl, documentUrl, selfieUrl;
      if (_photo != null && _photoBytes != null) {
        photoUrl = await FS.uploadProviderFile(
            _photoBytes!, _photo!.name, 'photo');
      }
      if (_document != null && _documentBytes != null) {
        documentUrl = await FS.uploadProviderFile(
            _documentBytes!, _document!.name, 'document');
      }
      if (_selfie != null && _selfieBytes != null) {
        selfieUrl = await FS.uploadProviderFile(
            _selfieBytes!, _selfie!.name, 'selfie');
      }

      final areas = _areasCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await FS.updateProviderDocuments(
        photoUrl: photoUrl,
        documentUrl: documentUrl,
        selfieUrl: selfieUrl,
        certificates: _certificates,
        serviceAreas: areas,
      );

      if (mounted) {
        snack(context,
            '✅ Documentos enviados! Aguarde a aprovação do administrador.',
            bg: AppColors.secondary);
        Navigator.pushReplacementNamed(context, Routes.main);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Complete seu cadastro'),
            automaticallyImplyLeading: widget.allowBack),
        body: LoadingOverlay(
            loading: _loading,
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Container(
                      decoration:
                          AppDecorations.gradient(AppGradients.primary, r: 18),
                      padding: const EdgeInsets.all(18),
                      child: const Row(children: [
                        Icon(Icons.verified_user_outlined,
                            color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                'Envie seus documentos para ativar seu perfil de prestador e começar a receber pedidos.',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    height: 1.4))),
                      ])),
                  const SizedBox(height: 20),
                  _uploadTile(
                      '📷',
                      'Foto de perfil',
                      'Aparece para os clientes na busca',
                      _photoBytes,
                      () => _pickImage((f, b) {
                            _photo = f;
                            _photoBytes = b;
                          }, source: ImageSource.gallery)),
                  _uploadTile(
                      '🪪',
                      'Documento de identidade',
                      'RG, CNH ou CPF (foto legível)',
                      _documentBytes,
                      () => _pickImage((f, b) {
                            _document = f;
                            _documentBytes = b;
                          }, source: ImageSource.camera)),
                  _uploadTile(
                      '🤳',
                      'Selfie de validação',
                      'Segurando o documento ao lado do rosto',
                      _selfieBytes,
                      () => _pickImage((f, b) {
                            _selfie = f;
                            _selfieBytes = b;
                          }, source: ImageSource.camera)),
                  const SizedBox(height: 8),
                  Container(
                      decoration: AppDecorations.card(r: 16),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎓 Certificados (opcional)',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                  child: TextFormField(
                                      controller: _certCtrl,
                                      decoration: const InputDecoration(
                                          hintText:
                                              'Ex: Curso técnico em elétrica'))),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                  onPressed: () {
                                    if (_certCtrl.text.trim().isNotEmpty)
                                      setState(() {
                                        _certificates
                                            .add(_certCtrl.text.trim());
                                        _certCtrl.clear();
                                      });
                                  },
                                  child: const Icon(Icons.add, size: 18)),
                            ]),
                            if (_certificates.isNotEmpty)
                              Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _certificates
                                          .map((c) => Chip(
                                              label: Text(c,
                                                  style: const TextStyle(
                                                      fontSize: 12)),
                                              onDeleted: () => setState(() =>
                                                  _certificates.remove(c))))
                                          .toList())),
                          ])),
                  const SizedBox(height: 12),
                  Container(
                      decoration: AppDecorations.card(r: 16),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📍 Áreas atendidas',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            const SizedBox(height: 4),
                            const Text(
                                'Bairros ou cidades, separados por vírgula',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textLight)),
                            const SizedBox(height: 8),
                            TextFormField(
                                controller: _areasCtrl,
                                decoration: const InputDecoration(
                                    hintText:
                                        'Ex: Centro, Zona Sul, Vila Mariana')),
                          ])),
                  const SizedBox(height: 24),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Enviar para aprovação',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      )),
                  const SizedBox(height: 8),
                  TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, Routes.main),
                      child: const Text('Completar depois',
                          style: TextStyle(color: AppColors.textLight))),
                  const SizedBox(height: 30),
                ]))),
      );

  Widget _uploadTile(String icon, String title, String subtitle,
          Uint8List? bytes, VoidCallback onTap) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppDecorations.card(r: 16),
        child: ListTile(
          leading: bytes != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(bytes,
                      width: 44, height: 44, fit: BoxFit.cover))
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10)),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 20))),
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(bytes != null ? '✅ Selecionado' : subtitle,
              style: TextStyle(
                  fontSize: 11,
                  color: bytes != null
                      ? AppColors.secondary
                      : AppColors.textLight)),
          trailing: TextButton(
              onPressed: onTap,
              child: Text(bytes != null ? 'Trocar' : 'Enviar')),
        ),
      );
}

// ── Ações do pedido pendente com timer de expiração (estilo iFood) ──
class _PendingActions extends StatefulWidget {
  final OrderModel order;
  const _PendingActions({required this.order});

  @override
  State<_PendingActions> createState() => _PendingActionsState();
}

class _PendingActionsState extends State<_PendingActions> {
  static const _window = Duration(minutes: 15);
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _left {
    final elapsed = DateTime.now().difference(widget.order.createdAt);
    final left = _window - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  /// Proposta: valor + prazo + descrição (cliente vê e paga o valor).
  Future<void> _accept(BuildContext context) async {
    final current = widget.order.price;
    final priceCtrl = TextEditingController(
        text: current != null ? current.toStringAsFixed(2) : '');
    final daysCtrl = TextEditingController(text: '3');
    final noteCtrl = TextEditingController();
    final proposal = await showDialog<({double price, String note})>(
      context: context,
      builder: (dialog) {
        String? error;
        return StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
            title: const Text('Enviar proposta'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (widget.order.siteVisitRequested)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Cliente pediu visita técnica — descreva se a visita está inclusa.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                TextField(
                  controller: priceCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: 'Valor (R\$)',
                      prefixText: 'R\$ ',
                      hintText: '0,00',
                      errorText: error),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Prazo (dias)', hintText: '3'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da proposta',
                    hintText: 'Escopo, materiais, visita técnica…',
                    alignLabelWithHint: true,
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Voltar')),
              TextButton(
                  onPressed: () {
                    final raw = priceCtrl.text.trim();
                    final v = double.tryParse(raw.contains(',')
                        ? raw.replaceAll('.', '').replaceAll(',', '.')
                        : raw);
                    if (v == null || v <= 0) {
                      setLocal(() => error = 'Informe um valor válido');
                      return;
                    }
                    final days = int.tryParse(daysCtrl.text.trim()) ?? 0;
                    final note = noteCtrl.text.trim();
                    final parts = <String>[
                      if (note.isNotEmpty) note,
                      if (days > 0) 'Prazo estimado: $days dia(s).',
                      if (widget.order.siteVisitRequested)
                        'Visita técnica: conforme combinado na proposta.',
                    ];
                    Navigator.pop(dialog, (price: v, note: parts.join(' ')));
                  },
                  child: const Text('Enviar proposta')),
            ],
          ),
        );
      },
    );
    priceCtrl.dispose();
    daysCtrl.dispose();
    noteCtrl.dispose();
    if (proposal == null) return;
    try {
      await FS.acceptOrder(widget.order.id, price: proposal.price);
      if (proposal.note.isNotEmpty) {
        try {
          final room = await FS.getOrCreateRoom(widget.order.clientId);
          await FS.sendMessage(
            roomId: room,
            senderName: 'Profissional',
            text:
                '💼 Proposta: ${PaySvc.fmt(proposal.price)}\n${proposal.note}',
          );
        } catch (_) {}
      }
      if (context.mounted) {
        snack(context, 'Proposta enviada!', bg: AppColors.secondary);
      }
    } on CloudCallException catch (e) {
      if (context.mounted) snack(context, e.message, bg: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    final expired = left == Duration.zero;
    final mm = left.inMinutes.toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    final urgent = left.inMinutes < 3;
    return Column(children: [
      // Barra de tempo restante para responder
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: expired
              ? const Color(0xFFF5F5F5)
              : (urgent ? const Color(0xFFFFEBEE) : const Color(0xFFE7F5EB)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(expired ? Icons.timer_off_outlined : Icons.timer_outlined,
              size: 15,
              color: expired
                  ? AppColors.textLight
                  : (urgent ? AppColors.error : AppColors.primary)),
          const SizedBox(width: 6),
          Text(expired ? 'Tempo esgotado' : 'Responda em $mm:$ss',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: expired
                      ? AppColors.textLight
                      : (urgent ? AppColors.error : AppColors.primary))),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: expired
                    ? null
                    : () async {
                        await FS.declineOrder(widget.order.id);
                      },
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                        color: expired ? AppColors.border : AppColors.error)),
                child: Text('Recusar',
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            expired ? AppColors.textLight : AppColors.error)))),
        const SizedBox(width: 8),
        Expanded(
            child: ElevatedButton(
                onPressed: expired
                    ? null
                    : () => _accept(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 10)),
                child: const Text('Aceitar',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w700)))),
      ]),
    ]);
  }
}

// ── Resumo semanal de ganhos com gráfico de barras (Flutter puro) ──
class WeeklyEarnings extends StatelessWidget {
  const WeeklyEarnings({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderModel>>(
        stream:
            FS.providerOrdersStream(statuses: const [OrderStatus.completed]),
        builder: (_, snap) {
          final now = DateTime.now();
          final days = List.generate(
              7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
          final totals = days
              .map((d) => (snap.data ?? const <OrderModel>[])
                  .where((o) =>
                      o.createdAt.year == d.year &&
                      o.createdAt.month == d.month &&
                      o.createdAt.day == d.day)
                  .fold<double>(0,
                      (s, o) => s + (o.price ?? 0) * (1 - AppConst.commission)))
              .toList();
          final max = totals.fold<double>(0, (a, b) => a > b ? a : b);
          final week = totals.fold<double>(0, (a, b) => a + b);
          const labels = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
          String lbl(DateTime d) => labels[(d.weekday - 1) % 7];
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(r: 16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Ganhos da semana',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                Text(PaySvc.fmt(week),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.secondary)),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                  height: 68,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(7, (i) {
                      final isToday = i == 6;
                      final h = max <= 0
                          ? 4.0
                          : (totals[i] / max * 48).clamp(4.0, 48.0);
                      return Expanded(
                          child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                  height: h,
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? AppColors.secondary
                                        : AppColors.primary.withOpacity(0.35),
                                    borderRadius: BorderRadius.circular(4),
                                  )),
                              const SizedBox(height: 5),
                              Text(lbl(days[i]),
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isToday
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isToday
                                          ? AppColors.secondary
                                          : AppColors.textLight)),
                            ]),
                      ));
                    }),
                  )),
            ]),
          );
        },
      );
}
