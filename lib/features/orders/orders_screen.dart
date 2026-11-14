import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/demo_data.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/orders/service_request.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../wallet/wallet_screen.dart' show PixScreen, CardPaymentScreen;

// ─────────────────────────────────────────────────────────────
// FAVORITES SCREEN (Vol.3/Vol.5: coleção favorites)
// ─────────────────────────────────────────────────────────────
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CarajasAppBar(title: '⭐ Favoritos'),
        body: StreamBuilder<List<ProviderModel>>(
          stream: FS.favoritesStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const ShimCard());
            }
            if (snap.hasError) {
              return const EmptyState(
                  emoji: '⚠️',
                  title: 'Falha ao carregar favoritos',
                  subtitle: 'Verifique a conexão e tente novamente.');
            }
            final favs = snap.data ?? [];
            if (favs.isEmpty)
              return const EmptyState(
                  emoji: '⭐',
                  title: 'Nenhum favorito ainda',
                  subtitle:
                      'Toque no coração de um profissional para salvá-lo aqui',
                  asset: AppAssets.ilListaVazia);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: BrandProviderGrid(list: favs),
                ),
              ),
            );
          },
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// MY ORDERS / HISTORY SCREEN (Vol.3: Perfil do Cliente – Pedidos)
// ─────────────────────────────────────────────────────────────
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersState();
}

class _MyOrdersState extends State<MyOrdersScreen> {
  OrderStatus? _filter;

  static final _demo = [
    OrderModel(
        id: 'd1',
        clientId: 'me',
        category: 'eletricista',
        title: 'Instalação de tomadas',
        description: 'Instalar 4 tomadas na sala',
        address: 'Rua das Flores, 123',
        price: 180,
        status: OrderStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 2))),
    OrderModel(
        id: 'd2',
        clientId: 'me',
        category: 'diarista',
        title: 'Limpeza semanal',
        description: 'Limpeza completa do apartamento',
        address: 'Av. Paulista, 1000',
        price: 150,
        status: OrderStatus.inProgress,
        createdAt: DateTime.now().subtract(const Duration(hours: 3))),
    OrderModel(
        id: 'd3',
        clientId: 'me',
        category: 'medico',
        title: 'Consulta clínico geral',
        description: 'Consulta de rotina',
        address: 'Online',
        price: 120,
        status: OrderStatus.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
  ];

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAuth) {
      return Scaffold(
        appBar: const CarajasAppBar(title: '📋 Meus Pedidos'),
        body: EmptyState(
          emoji: '📋',
          title: 'Faça login',
          subtitle: 'Entre na conta para ver seus pedidos.',
          actionLabel: 'Entrar',
          onAction: () => Navigator.pushNamed(context, Routes.login),
        ),
      );
    }
    return Scaffold(
      appBar: CarajasAppBar(
        title: '📋 Meus Pedidos',
        actions: [
          TextButton(
            onPressed: () => Navigator.pushNamed(context, Routes.myResolve),
            child: const Text('Resolve'),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Material(
            color: AppColors.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pushNamed(context, Routes.myResolve),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Text('⚡', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pedidos Resolve — propostas e orçamentos abertos',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.secondary),
                ]),
              ),
            ),
          ),
        ),
        SizedBox(
            height: 46,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  _filterChip('Todos', null),
                  _filterChip('Aguardando', OrderStatus.pending),
                  _filterChip('Em andamento', OrderStatus.inProgress),
                  _filterChip('Concluídos', OrderStatus.completed),
                  _filterChip('Cancelados', OrderStatus.cancelled),
                ])),
        Expanded(
            child: StreamBuilder<List<OrderModel>>(
          stream: FS.orderHistoryStream(status: _filter),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return const EmptyState(
                  emoji: '⚠️',
                  title: 'Falha ao carregar pedidos',
                  subtitle: 'Verifique a conexão e tente novamente.');
            }
            final orders = DemoData.orEmpty(
                snap.data,
                _demo
                    .where((o) => _filter == null || o.status == _filter)
                    .toList());
            if (orders.isEmpty)
              return const EmptyState(
                  emoji: '📋',
                  title: 'Nenhum pedido',
                  subtitle: 'Seus pedidos aparecerão aqui',
                  asset: AppAssets.ilListaVazia);
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
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: Text(cat?.emoji ?? '🔧',
                                  style: const TextStyle(fontSize: 20))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(o.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14)),
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
                        const SizedBox(height: 10),
                        _PaymentInfo(order: o),
                        Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 4,
                            children: [
                          AppTag(o.statusLabel,
                              bg: _statusBg(o.status), fg: _statusFg(o.status)),
                          if (o.canPay)
                            TextButton(
                                onPressed: () => _openPayment(context, o),
                                child: const Text('Pagar',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800))),
                          if (o.awaitingClientConfirmation) ...[
                            TextButton(
                                onPressed: () => _confirmService(context, o),
                                child: const Text('Confirmar serviço',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800))),
                            TextButton(
                                onPressed: () => _openDispute(context, o),
                                child: const Text('Contestar',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.error))),
                          ],
                          if (!o.isPaid &&
                              (o.status == OrderStatus.pending ||
                                  o.status == OrderStatus.accepted))
                            TextButton(
                                onPressed: () => _confirmCancel(context, o.id),
                                child: const Text('Cancelar',
                                    style: TextStyle(
                                        fontSize: 12, color: AppColors.error))),
                          if (o.status == OrderStatus.inProgress)
                            TextButton(
                                onPressed: () => Navigator.pushNamed(
                                        context, Routes.gps, arguments: {
                                      'ctx': 'servico',
                                      'orderId': o.id
                                    }),
                                child: const Text('Rastrear',
                                    style: TextStyle(fontSize: 12))),
                          if (o.status == OrderStatus.completed && !o.reviewed)
                            TextButton(
                                onPressed: () => Navigator.pushNamed(
                                    context, Routes.reviews,
                                    arguments: {
                                      'orderId': o.id,
                                      'providerId': o.providerId,
                                    }),
                                child: const Text('Avaliar',
                                    style: TextStyle(fontSize: 12))),
                        ]),
                      ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _filterChip(String label, OrderStatus? status) {
    final sel = _filter == status;
    return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _filter = status),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: sel ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.textDark)),
          ),
        ));
  }

  Color _statusBg(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return const Color(0xFFFFF8E1);
      case OrderStatus.accepted:
        return const Color(0xFFE7F5EB);
      case OrderStatus.inProgress:
        return const Color(0xFFE1F5FE);
      case OrderStatus.awaitingPayment:
      case OrderStatus.paid:
        return const Color(0xFFE8EAF6);
      case OrderStatus.completed:
        return const Color(0xFFE8F5E9);
      case OrderStatus.cancelled:
        return const Color(0xFFFFEBEE);
      case OrderStatus.disputed:
        return const Color(0xFFFFF3E0);
      case OrderStatus.refunded:
        return const Color(0xFFF3E5F5);
    }
  }

  Color _statusFg(OrderStatus s) {
    switch (s) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.accepted:
        return AppColors.primary;
      case OrderStatus.inProgress:
        return AppColors.info;
      case OrderStatus.awaitingPayment:
      case OrderStatus.paid:
        return AppColors.primary;
      case OrderStatus.completed:
        return AppColors.secondary;
      case OrderStatus.cancelled:
        return AppColors.error;
      case OrderStatus.disputed:
        return AppColors.orange;
      case OrderStatus.refunded:
        return AppColors.textLight;
    }
  }

  void _openPayment(BuildContext context, OrderModel o) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pagar ${PaySvc.fmt(o.price!)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text(
                    'O valor fica retido pela plataforma e só é liberado ao profissional depois que você confirmar o serviço ou quando terminar o prazo de custódia sem contestação.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textLight, height: 1.4)),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('👜', style: TextStyle(fontSize: 22)),
                  title: const Text('Saldo da carteira'),
                  onTap: () async {
                    Navigator.pop(sheet);
                    try {
                      await FS.payOrderWithWalletOrThrow(o.id);
                      if (context.mounted) {
                        snack(context, 'Pagamento confirmado.',
                            bg: AppColors.secondary);
                      }
                    } on CloudCallException catch (e) {
                      if (context.mounted) {
                        snack(context, e.message, bg: AppColors.error);
                      }
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('⚡', style: TextStyle(fontSize: 22)),
                  title: const Text('PIX'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PixScreen(
                                amount: o.price!,
                                desc: o.title,
                                orderId: o.id)));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('💳', style: TextStyle(fontSize: 22)),
                  title: const Text('Cartão de crédito'),
                  onTap: () {
                    Navigator.pop(sheet);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CardPaymentScreen(
                                amount: o.price!,
                                desc: o.title,
                                orderId: o.id)));
                  },
                ),
              ]),
        ),
      ),
    );
  }

  void _confirmService(BuildContext context, OrderModel o) => showDialog(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const Text('Confirmar serviço'),
            content: const Text(
                'Confirme apenas se o serviço foi feito. O valor retido será liberado ao profissional.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Voltar')),
              TextButton(
                  onPressed: () async {
                    Navigator.pop(dialog);
                    try {
                      await FS.confirmOrder(o.id);
                      if (context.mounted) {
                        snack(context, 'Serviço confirmado.',
                            bg: AppColors.secondary);
                      }
                    } on CloudCallException catch (e) {
                      if (context.mounted) {
                        snack(context, e.message, bg: AppColors.error);
                      }
                    }
                  },
                  child: const Text('Confirmar')),
            ],
          ));

  void _openDispute(BuildContext context, OrderModel o) {
    final reason = TextEditingController();
    showDialog(
        context: context,
        builder: (dialog) => AlertDialog(
              title: const Text('Contestar pedido'),
              content: TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Explique o que aconteceu'),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialog),
                    child: const Text('Voltar')),
                TextButton(
                    onPressed: () async {
                      if (reason.text.trim().isEmpty) return;
                      Navigator.pop(dialog);
                      try {
                        await FS.disputeOrder(o.id, reason: reason.text);
                        if (context.mounted) {
                          snack(context,
                              'Contestação registrada. O repasse fica bloqueado até a análise.',
                              bg: AppColors.warning);
                        }
                      } on CloudCallException catch (e) {
                        if (context.mounted) {
                          snack(context, e.message, bg: AppColors.error);
                        }
                      }
                    },
                    child: const Text('Enviar',
                        style: TextStyle(color: AppColors.error))),
              ],
            )).whenComplete(reason.dispose);
  }

  void _confirmCancel(BuildContext context, String orderId) => showDialog(
      context: context,
      builder: (_) => AlertDialog(
            title: const Text('Cancelar pedido'),
            content: const Text(
                'Tem certeza que deseja cancelar esta solicitação? Essa ação não pode ser desfeita.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Voltar')),
              TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      await FS.cancelOrder(orderId);
                      if (context.mounted) {
                        snack(context, 'Pedido cancelado', bg: AppColors.error);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        snack(context, 'Não foi possível cancelar.',
                            bg: AppColors.error);
                      }
                    }
                  },
                  child: const Text('Cancelar pedido',
                      style: TextStyle(color: AppColors.error))),
            ],
          ));
}

/// Situação do pagamento e da custódia do pedido.
class _PaymentInfo extends StatelessWidget {
  final OrderModel order;
  const _PaymentInfo({required this.order});

  @override
  Widget build(BuildContext context) {
    final o = order;
    String? text;
    var color = AppColors.textLight;
    if (o.payoutProcessed) {
      text = 'Pagamento liberado ao profissional';
      color = AppColors.secondary;
    } else if (o.escrowStatus == 'disputed') {
      text = 'Em contestação: repasse bloqueado até a análise';
      color = AppColors.orange;
    } else if (o.awaitingClientConfirmation) {
      final due = o.releaseAt;
      text = due != null
          ? 'Concluído pelo profissional. Confirme ou conteste até ${fmtDate(due)}; depois disso o valor é liberado.'
          : 'Concluído pelo profissional. Confirme o serviço ou conteste.';
      color = AppColors.primary;
    } else if (o.isPaid) {
      text = 'Pago: valor retido até a conclusão do serviço';
      color = AppColors.secondary;
    } else if (o.status == OrderStatus.pending && o.providerId != null) {
      text = 'Aguardando o profissional aceitar e informar o valor';
    } else if (o.canPay) {
      text = 'Valor informado pelo profissional. Pague para ele iniciar com segurança.';
      color = AppColors.primary;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REQUEST SERVICE SCREEN (Vol.3: Detalhes do Serviço — Solicitar
// orçamento). Cria o OrderModel real antes de abrir o chat com o
// profissional, fechando o fluxo Cliente → Pedido → Negociação.
// ─────────────────────────────────────────────────────────────
class RequestServiceScreen extends StatefulWidget {
  final String providerId, providerName, category;
  final String? initialDescription;
  final bool remoteOnly;
  final Color providerColor;
  const RequestServiceScreen(
      {super.key,
      required this.providerId,
      required this.providerName,
      required this.category,
      this.initialDescription,
      this.remoteOnly = false,
      this.providerColor = AppColors.primary});
  @override
  State<RequestServiceScreen> createState() => _RequestServiceState();
}

class _RequestServiceState extends State<RequestServiceScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();
  bool _urgent = false,
      _loading = false,
      _improvingDescription = false,
      _loadingBudget = false;
  String? _budgetSuggestion;
  String? _senderName;
  final _guard = SubmitGuard();

  @override
  void initState() {
    super.initState();
    _description.text = widget.initialDescription?.trim() ?? '';
    final uid = AuthService.uid;
    if (uid == null) return;
    FS.userStream(uid).first.then((u) {
      if (!mounted) return;
      final name = u?.name.trim() ?? '';
      if (name.isNotEmpty) _senderName = name;
      final addr = u?.address?.trim();
      if (addr != null && addr.isNotEmpty && _address.text.isEmpty) {
        _address.text = addr;
      }
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _improveDescription() async {
    if (_description.text.trim().isEmpty) {
      snack(context, 'Escreva algumas palavras primeiro');
      return;
    }
    setState(() => _improvingDescription = true);
    final catName = Categories.byId(widget.category)?.name ?? widget.category;
    final suggestion = await AiSvc.suggestDescription(
        category: catName, draft: _description.text.trim());
    if (!mounted) return;
    setState(() => _improvingDescription = false);
    if (suggestion != null && suggestion.isNotEmpty) {
      setState(() => _description.text = suggestion);
    } else {
      snack(context,
          'Não foi possível gerar uma sugestão agora. Tente novamente.',
          bg: AppColors.error);
    }
  }

  Future<void> _estimateBudget() async {
    if (_description.text.trim().isEmpty) {
      snack(context, 'Descreva o serviço primeiro');
      return;
    }
    setState(() => _loadingBudget = true);
    final catName = Categories.byId(widget.category)?.name ?? widget.category;
    final suggestion = await AiSvc.suggestBudget(
        category: catName, description: _description.text.trim());
    if (!mounted) return;
    setState(() {
      _loadingBudget = false;
      _budgetSuggestion = suggestion;
    });
  }

  Future<void> _submit() async {
    if (_guard.busy) return;
    if (!await ensureSignedIn(context,
        message: 'Faça login para solicitar um serviço.')) {
      return;
    }
    if (!mounted) return;
    final uid = AuthService.uid;
    final block = ServiceRequest.blockReason(
      uid: uid,
      providerId: widget.providerId,
      demoProvider: HomologCatalog.enabled &&
          HomologCatalog.isDemoProvider(widget.providerId),
    );
    if (block != null) {
      snack(context, block, bg: AppColors.warning);
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final title = _title.text.trim();
    final description = _description.text.trim();
    final result = await _guard.run(() async {
      final orderId = await FS.createOrder(ServiceRequest.payload(
        providerId: widget.providerId,
        category: widget.category,
        title: title,
        description: description,
        address: _address.text,
        urgent: _urgent,
        remoteOnly: widget.remoteOnly,
      ));
      String? roomId;
      try {
        roomId = await FS.getOrCreateRoom(widget.providerId);
        await FS.sendMessage(
            roomId: roomId,
            senderName: _senderName ?? 'Cliente',
            text: ServiceRequest.chatIntro(title, description));
      } catch (_) {
        roomId = null;
      }
      return (orderId: orderId, roomId: roomId);
    }).catchError((Object _) => null);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) {
      snack(context,
          'Não foi possível enviar a solicitação. Verifique a conexão e tente novamente.',
          bg: AppColors.error);
      return;
    }
    final roomId = result.roomId;
    if (roomId == null) {
      snack(context,
          'Solicitação registrada. Não foi possível abrir a conversa agora; acompanhe em Pedidos.',
          bg: AppColors.warning);
      Navigator.pushReplacementNamed(context, Routes.myOrders);
      return;
    }
    snack(context, 'Solicitação enviada! Acompanhe pela conversa ou em Pedidos.',
        bg: AppColors.secondary);
    Navigator.pushReplacementNamed(context, Routes.chat, arguments: {
      'roomId': roomId,
      'id': widget.providerId,
      'name': widget.providerName,
      'orderId': result.orderId
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CarajasAppBar(title: 'Solicitar orçamento'),
        body: LoadingOverlay(
            loading: _loading,
            child: Form(
                key: _form,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Container(
                      decoration: AppDecorations.card(),
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        AppAvatar(
                            name: widget.providerName,
                            size: 48,
                            bg: widget.providerColor,
                            r: 14),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(widget.providerName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              Text(
                                  Categories.byId(widget.category)?.name ??
                                      widget.category,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textLight)),
                            ])),
                      ])),
                  const SizedBox(height: 20),
                  TextFormField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Título do serviço *',
                          prefixIcon: Icon(Icons.title_outlined)),
                      validator: ServiceRequest.titleError),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _description,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          labelText: 'Descreva o que você precisa *',
                          alignLabelWithHint: true),
                      validator: ServiceRequest.descriptionError),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                      onPressed:
                          _improvingDescription ? null : _improveDescription,
                      icon: _improvingDescription
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Melhorar com IA',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                      onPressed: _loadingBudget ? null : _estimateBudget,
                      icon: _loadingBudget
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.payments_outlined, size: 16),
                      label: const Text('Estimar preço',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10)),
                    )),
                  ]),
                  if (_budgetSuggestion != null)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            color: AppColors.secondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text('Estimativa da IA: $_budgetSuggestion',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _address,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                          labelText: widget.remoteOnly
                              ? 'Endereço (opcional, atendimento a distância)'
                              : 'Endereço do atendimento *',
                          prefixIcon: const Icon(Icons.location_on_outlined)),
                      validator: (v) => ServiceRequest.addressError(v,
                          remoteOnly: widget.remoteOnly)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Serviço urgente',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Prioriza sua solicitação na fila do profissional',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                    activeThumbColor: AppColors.error,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Enviar solicitação',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      )),
                  const SizedBox(height: 40),
                ]))),
      );
}
