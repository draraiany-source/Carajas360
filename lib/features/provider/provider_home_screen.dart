import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/demo_data.dart';
import '../../shared/models/models.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/catalog/catalog_widgets.dart';
import 'provider_services_screen.dart';
import 'provider_attendance_screen.dart';
import 'money_parse.dart';
import '../resolve/resolve_contact.dart';
export 'money_parse.dart';
import '../health/health_schedule_editor.dart';

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
  // null = primeira carga (não alertar). Compara ids, não a contagem.
  Set<String>? _lastPendingIds;
  // Assinaturas do cabeçalho criadas uma vez (não a cada rebuild).
  late final Stream<ProviderModel?> _myProvider = FS.myProviderStream();
  late final Stream<List<OrderModel>> _completed =
      FS.providerOrdersStream(statuses: const [OrderStatus.completed]);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Alerta estilo iFood: quando chega pedido novo, vibra e avisa.
    _newOrdersSub = FS.providerOrdersStream(
        statuses: const [OrderStatus.pending]).listen((orders) {
      if (!mounted) return;
      final ids = {for (final o in orders) o.id};
      final prev = _lastPendingIds;
      if (prev != null && ids.any((id) => !prev.contains(id))) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        snack(context, '🔔 Novo pedido recebido!', bg: AppColors.secondary);
        _tab.animateTo(0);
      }
      _lastPendingIds = ids;
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

  static final _demoPending = [
    OrderModel(
        id: 'p1',
        clientId: 'c1',
        category: 'eletricista',
        title: 'Instalação de chuveiro',
        description: 'Preciso trocar o chuveiro elétrico do banheiro.',
        address: 'Rua Augusta, 500',
        price: 90,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 12))),
  ];

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
                            Semantics(
                                button: true,
                                label: 'Fechar',
                                child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 20)))),
                          ]),
                      const SizedBox(height: 12),
                      // ── Estilo Uber/iFood: ficar online/offline. Offline sai da
                      // busca na hora (providersStream filtra active == true).
                      StreamBuilder<ProviderModel?>(
                        stream: _myProvider,
                        builder: (_, snap) {
                          final prov = snap.data;
                          // Só prestador verificado pode ficar online.
                          final verified = prov?.verified ?? false;
                          final online = verified && (prov?.active ?? true);
                          return Column(children: [
                            if (prov != null && !verified)
                              ProviderReviewBanner(provider: prov),
                            Container(
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
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        online
                                            ? 'Você está online'
                                            : 'Você está offline',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    if (prov != null && !verified)
                                      const Text(
                                          'Disponível após a verificação do seu cadastro.',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11)),
                                  ])),
                              Switch(
                                value: online,
                                activeColor: const Color(0xFF69F0AE),
                                inactiveThumbColor: Colors.white70,
                                onChanged: prov == null || !verified
                                    ? null
                                    : (v) async {
                                        try {
                                          await FS.setProviderOnline(
                                              prov.id, v);
                                        } catch (e) {
                                          if (context.mounted) {
                                            snack(context,
                                                'Não foi possível alterar o status: $e',
                                                bg: AppColors.error);
                                          }
                                          return;
                                        }
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
                          ),
                          ]);
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ProviderServicesScreen())),
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Minhas especialidades'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.white),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const ProviderAttendanceScreen())),
                          icon: const Icon(Icons.place_outlined, size: 18),
                          label: const Text('Meu atendimento (raio, dias, modalidade)'),
                        ),
                      ),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: HealthScheduleTile(),
                      ),
                      // ── Ganhos do dia, no padrão dos apps de motorista/entregador.
                      StreamBuilder<List<OrderModel>>(
                        stream: _completed,
                        builder: (_, snap) {
                          if (snap.hasError) {
                            return const Text('Não foi possível carregar seus ganhos agora.',
                                style: TextStyle(color: Colors.white, fontSize: 12));
                          }
                          if (!snap.hasData) {
                            return const LinearProgressIndicator(minHeight: 2);
                          }
                          final now = DateTime.now();
                          final today = snap.data!
                              .where((o) =>
                                  o.earnedAt.year == now.year &&
                                  o.earnedAt.month == now.month &&
                                  o.earnedAt.day == now.day)
                              .toList();
                          final total = today.fold<double>(
                              0, (s, o) => s + (o.price ?? 0));
                          // Repasse estimado: comissão registrada em cada pedido.
                          final net = today.fold<double>(0, (s, o) => s + o.providerNet);
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
                demo: _demoPending,
                emptyEmoji: '📭',
                emptyTitle: 'Sem pedidos novos',
                emptySub: 'Novas solicitações aparecerão aqui'),
            _OrderList(
                statuses: const [OrderStatus.accepted, OrderStatus.inProgress],
                demo: const [],
                emptyEmoji: '🔧',
                emptyTitle: 'Nada em andamento',
                emptySub: 'Pedidos aceitos aparecerão aqui'),
            Column(children: [
              const WeeklyEarnings(),
              Expanded(
                  child: _OrderList(
                      statuses: const [OrderStatus.completed],
                      demo: const [],
                      emptyEmoji: '✅',
                      emptyTitle: 'Sem histórico ainda',
                      emptySub: 'Serviços concluídos aparecerão aqui')),
            ]),
          ]),
        ),
      );
}

class _OrderList extends StatefulWidget {
  final List<OrderStatus> statuses;
  final List<OrderModel> demo;
  final String emptyEmoji, emptyTitle, emptySub;
  const _OrderList(
      {required this.statuses,
      required this.demo,
      required this.emptyEmoji,
      required this.emptyTitle,
      required this.emptySub});

  @override
  State<_OrderList> createState() => _OrderListState();
}

class _OrderListState extends State<_OrderList> {
  List<OrderStatus> get statuses => widget.statuses;
  List<OrderModel> get demo => widget.demo;
  String get emptyEmoji => widget.emptyEmoji;
  String get emptyTitle => widget.emptyTitle;
  String get emptySub => widget.emptySub;

  // Uma assinatura por aba, criada uma vez (os status de cada aba são fixos).
  late final Stream<List<OrderModel>> _orders =
      FS.providerOrdersStream(statuses: statuses);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderModel>>(
        stream: _orders,
        builder: (_, snap) {
          if (snap.hasError) return QueryErrorView(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final orders = DemoData.orEmpty(
              snap.data,
              statuses.contains(OrderStatus.pending) ? demo : <OrderModel>[]);
          if (orders.isEmpty)
            return EmptyState(
                emoji: emptyEmoji, title: emptyTitle, subtitle: emptySub);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (_, i) {
              final o = orders[i];
              final cat = CatalogService.instance.catalog.byId(o.category);
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
                                color: catalogColor(cat).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: Text(cat?.icon ?? '🔧',
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
                              CatalogLabel(o.category,
                                  snapshotName: o.serviceName,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
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
                      const SizedBox(height: 6),
                      // Resolve: endereço/telefone ficam no doc privado da solicitação.
                      if (o.source == 'resolve')
                        ResolveClientContact(orderId: o.id)
                      else
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
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          AppTag(o.statusLabel,
                              bg: o.status == OrderStatus.inProgress
                                  ? const Color(0xFFE1F5FE)
                                  : const Color(0xFFE3F0FF),
                              fg: o.status == OrderStatus.inProgress
                                  ? AppColors.info
                                  : AppColors.primary),
                          _PaymentTag(order: o),
                        ]),
                      ],
                      if (o.status == OrderStatus.pending) ...[
                        const SizedBox(height: 6),
                        _PaymentTag(order: o),
                      ],
                      const SizedBox(height: 12),
                      if (o.status == OrderStatus.pending)
                        _PendingActions(order: o),
                      if (o.status == OrderStatus.accepted)
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // Sem pagamento confirmado: confirma antes de iniciar.
                                if (!o.isPaid) {
                                  final go = await showDialog<bool>(
                                      context: context,
                                      builder: (c) => AlertDialog(
                                            title: const Text('Pagamento ainda não confirmado'),
                                            content: const Text(
                                                'O cliente ainda não pagou este pedido. Deseja iniciar o atendimento mesmo assim?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () => Navigator.pop(c, false),
                                                  child: const Text('Voltar')),
                                              ElevatedButton(
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: const Text('Iniciar mesmo assim')),
                                            ],
                                          ));
                                  if (go != true) return;
                                }
                                try {
                                  await FS.startOrder(o.id);
                                  if (context.mounted) {
                                    snack(context, 'Atendimento iniciado.',
                                        bg: AppColors.secondary);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    snack(context, '$e', bg: AppColors.error);
                                  }
                                }
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
                              child: o.awaitingClientConfirmation
                                  ? const Text(
                                      'Aguardando confirmação do cliente',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textLight))
                                  : ElevatedButton(
                                      onPressed: () async {
                                        try {
                                          await FS.markOrderDoneByProvider(
                                              o.id);
                                          if (context.mounted) {
                                            snack(context,
                                                'Marcado como concluído. Aguardando confirmação do cliente.',
                                                bg: AppColors.secondary);
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            snack(context, '$e',
                                                bg: AppColors.error);
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10)),
                                      child: const Text('Marcar como concluído',
                                          textAlign: TextAlign.center,
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
// "Enviar para aprovação" exige documento e selfie (o admin só
// aprova quem enviou); "Completar depois" segue sem enviar nada.
// ─────────────────────────────────────────────────────────────
class ProviderOnboardingScreen extends StatefulWidget {
  /// Aberta pelo Perfil ("Quero ser prestador"): ao sair, volta ao Perfil.
  final bool fromProfile;
  const ProviderOnboardingScreen({super.key, this.fromProfile = false});
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

  bool get _canSubmit => _documentBytes != null && _selfieBytes != null;

  void _leave() => widget.fromProfile
      ? Navigator.pop(context)
      : Navigator.pushReplacementNamed(context, Routes.main);

  Future<void> _submit() async {
    if (!_canSubmit) {
      snack(context, 'Envie o documento de identidade e a selfie de validação.',
          bg: AppColors.error);
      return;
    }
    setState(() => _loading = true);
    try {
      // Foto: URL pública. Documento e selfie: caminho privado no Storage.
      String? photoUrl, documentPath, selfiePath;
      if (_photo != null && _photoBytes != null) {
        photoUrl = await FS.uploadProviderFile(
            _photoBytes!, _photo!.name, 'photo');
      }
      if (_document != null && _documentBytes != null) {
        documentPath = await FS.uploadProviderFile(
            _documentBytes!, _document!.name, 'document');
      }
      if (_selfie != null && _selfieBytes != null) {
        selfiePath = await FS.uploadProviderFile(
            _selfieBytes!, _selfie!.name, 'selfie');
      }
      final failed = (_photo != null && photoUrl == null) ||
          (_document != null && documentPath == null) ||
          (_selfie != null && selfiePath == null);
      if (failed) {
        if (mounted) {
          snack(context, 'Falha ao enviar arquivos. Verifique a conexão e tente novamente.',
              bg: AppColors.error);
        }
        return;
      }

      final areas = _areasCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      await FS.updateProviderDocuments(
        photoUrl: photoUrl,
        documentPath: documentPath,
        selfiePath: selfiePath,
        certificates: _certificates,
        serviceAreas: areas,
      );
      // Pelo Perfil, recusado que reenviou documentos volta para a fila
      // (o servidor ignora quando não está recusado).
      if (widget.fromProfile) {
        try {
          await FS.requestProviderReview();
        } catch (e) {
          debugPrint('requestProviderReview: $e');
        }
      }

      if (mounted) {
        snack(context,
            '✅ Documentos enviados! Aguarde a aprovação do administrador.',
            bg: AppColors.secondary);
        _leave();
      }
    } catch (e) {
      if (mounted) {
        snack(context, 'Não foi possível salvar o cadastro: $e',
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Complete seu cadastro'),
            automaticallyImplyLeading: false),
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
                  if (!_canSubmit)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                            'Para enviar, adicione o documento de identidade e a selfie de validação.',
                            key: Key('onboarding-missing-docs'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textLight))),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const Key('onboarding-submit'),
                        onPressed: _loading || !_canSubmit ? null : _submit,
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
                      onPressed: _leave,
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

// ── Ações do pedido pendente (estilo iFood) ──
// O servidor grava o prazo (expiresAt, 7 dias) e recusa a resposta depois
// dele. Aqui o prazo só é exibido e, vencido no relógio do aparelho,
// desabilita os botões; quem decide é o servidor.
class _PendingActions extends StatefulWidget {
  final OrderModel order;
  const _PendingActions({required this.order});

  @override
  State<_PendingActions> createState() => _PendingActionsState();
}

class _PendingActionsState extends State<_PendingActions> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Prestador aprovado porém offline: avisa antes de chamar o servidor.
  Future<bool> _isOfflineApproved() async {
    final uid = AuthService.uid;
    if (uid == null) return false;
    try {
      final p = await FirebaseFirestore.instance
          .collection(Col.providers)
          .doc(uid)
          .get();
      final d = p.data();
      return d != null && d['verified'] == true && d['active'] != true;
    } catch (_) {
      return false; // sem leitura: o servidor decide
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (await _isOfflineApproved()) {
        if (mounted) {
          snack(context, 'Fique online para aceitar pedidos.',
              bg: AppColors.warning);
        }
        return;
      }
      if (!mounted) return;
      // Pedido sem preço: o prestador informa o orçamento.
      double? price;
      if ((widget.order.price ?? 0) <= 0) {
        price = await askQuote(context);
        if (price == null) return;
      }
      await FS.acceptOrder(widget.order.id, price: price);
      if (mounted) snack(context, '✅ Pedido aceito!', bg: AppColors.secondary);
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FS.declineOrder(widget.order.id);
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final mins = now.difference(widget.order.createdAt).inMinutes;
    final expired = widget.order.isExpiredAt(now);
    final urgent = expired || mins >= 10;
    final expiry =
        OrderModel.expiryLabel(widget.order.expiresAtOrDefault, now);
    return Column(children: [
      // Informativo: há quanto tempo o pedido chegou.
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: urgent ? const Color(0xFFFFEBEE) : const Color(0xFFE3F0FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.timer_outlined,
              size: 15, color: urgent ? AppColors.error : AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
                expired
                    ? '⌛ Expirado · prazo de resposta encerrado'
                    : '${mins < 1 ? 'Recebido agora' : 'Recebido há $mins min'} · $expiry',
                key: const Key('pending-info'),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: urgent ? AppColors.error : AppColors.primary)),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed: _busy || expired ? null : _decline,
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.error)),
                child: const Text('Recusar',
                    style: TextStyle(fontSize: 13, color: AppColors.error)))),
        const SizedBox(width: 8),
        Expanded(
            child: ElevatedButton(
                key: const Key('pending-accept'),
                onPressed: _busy || expired ? null : _accept,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 10)),
                child: Text(expired ? 'Expirado' : 'Aceitar',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)))),
      ]),
    ]);
  }
}

/// Situação do pagamento do pedido (paymentStatus gravado pelo servidor).
class _PaymentTag extends StatelessWidget {
  final OrderModel order;
  const _PaymentTag({required this.order});
  @override
  Widget build(BuildContext context) => order.isPaid
      ? const AppTag('💳 Pagamento confirmado',
          bg: Color(0xFFE8F5E9), fg: AppColors.secondary)
      : const AppTag('⏳ Aguardando pagamento',
          bg: Color(0xFFFFF8E1), fg: AppColors.warning);
}

// ── Resumo semanal de ganhos com gráfico de barras (Flutter puro) ──
class WeeklyEarnings extends StatefulWidget {
  const WeeklyEarnings({super.key});

  @override
  State<WeeklyEarnings> createState() => _WeeklyEarningsState();
}

class _WeeklyEarningsState extends State<WeeklyEarnings> {
  // Criado uma vez (não a cada rebuild).
  late final Stream<List<OrderModel>> _completed =
      FS.providerOrdersStream(statuses: const [OrderStatus.completed]);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<OrderModel>>(
        stream: _completed,
        builder: (_, snap) {
          if (snap.hasError) {
            return const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Não foi possível carregar os ganhos da semana.',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12)));
          }
          if (!snap.hasData) {
            return const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator());
          }
          final now = DateTime.now();
          final days = List.generate(
              7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
          final totals = days
              .map((d) => snap.data!
                  .where((o) =>
                      o.earnedAt.year == d.year &&
                      o.earnedAt.month == d.month &&
                      o.earnedAt.day == d.day)
                  .fold<double>(0, (s, o) => s + o.providerNet))
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
                const Text('Ganhos da semana (estimativa)',
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

/// Diálogo de orçamento (R\$ 1 a 1.000.000). Retorna null se cancelado.
Future<double?> askQuote(BuildContext context) {
  final ctrl = TextEditingController();
  String? error;
  return showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: const Text('Informe o orçamento'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
          ],
          decoration: InputDecoration(
              prefixText: 'R\$ ', hintText: '0,00', errorText: error),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () {
                final v = parseQuote(ctrl.text);
                if (v == null) {
                  setD(() => error = 'Valor entre R\$ 1 e R\$ 1.000.000');
                  return;
                }
                Navigator.pop(ctx, v);
              },
              child: const Text('Aceitar')),
        ],
      ),
    ),
  );
}


/// Situação da análise do cadastro: recusado (com motivo e "Pedir nova
/// análise") ou em análise.
class ProviderReviewBanner extends StatefulWidget {
  final ProviderModel provider;
  const ProviderReviewBanner({super.key, required this.provider});
  @override
  State<ProviderReviewBanner> createState() => _ProviderReviewBannerState();
}

class _ProviderReviewBannerState extends State<ProviderReviewBanner> {
  bool _sending = false;

  Future<void> _requestReview() async {
    setState(() => _sending = true);
    try {
      await FS.requestProviderReview();
      if (mounted) snack(context, 'Pedido enviado. Seu cadastro voltou para análise.', bg: AppColors.secondary);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } catch (_) {
      if (mounted) snack(context, genericActionError, bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final reason = (p.rejectionReason ?? '').trim();
    final review = (p.reviewReason ?? '').trim();
    final String title;
    final String? detail;
    if (p.rejected) {
      title = 'Cadastro não aprovado: ${reason.isEmpty ? 'confira seus dados e documentos' : reason}';
      detail = 'Corrija o que foi apontado (dados, especialidades ou documentos) e peça nova análise.';
    } else if (p.inReview) {
      title = 'Seu cadastro está em análise';
      detail = review.isNotEmpty
          ? 'Em nova análise: $review'
          : (reason.isNotEmpty ? 'Em nova análise (recusa anterior: $reason)' : null);
    } else {
      title = 'Seu cadastro está em análise';
      detail = 'Você recebe um aviso assim que for aprovado.';
    }
    return Container(
      key: const Key('provider-review-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: p.rejected ? AppColors.error.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        if (detail != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(detail, style: const TextStyle(color: Colors.white, fontSize: 11.5)),
          ),
        if (p.rejected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton(
                onPressed: _sending ? null : _requestReview,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.error),
                child: Text(_sending ? 'Enviando…' : 'Pedir nova análise')),
          ),
      ]),
    );
  }
}
