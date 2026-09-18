import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/demo_data.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

// ─────────────────────────────────────────────────────────────
// FAVORITES SCREEN (Vol.3/Vol.5: coleção favorites)
// ─────────────────────────────────────────────────────────────
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('⭐ Favoritos')),
        body: StreamBuilder<List<ProviderModel>>(
          stream: FS.favoritesStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 3,
                  itemBuilder: (_, __) => const ShimCard());
            }
            final favs = snap.data ?? [];
            if (favs.isEmpty)
              return const EmptyState(
                  emoji: '⭐',
                  title: 'Nenhum favorito ainda',
                  subtitle:
                      'Toque no ícone de estrela em um profissional para salvá-lo aqui',
                  asset: AppAssets.ilListaVazia);
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favs.length,
              itemBuilder: (_, i) {
                final p = favs[i];
                final catName = p.categories.isNotEmpty
                    ? (Categories.byId(p.categories.first)?.name ??
                        p.categories.first)
                    : 'Profissional';
                return Dismissible(
                  key: Key(p.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(16)),
                    child:
                        const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  onDismissed: (_) => FS.toggleFavorite(p.id),
                  child: ProvCard(
                    name: p.name,
                    role: catName,
                    badge: p.badge,
                    price: p.minPrice != null
                        ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(0)}'
                        : 'Consultar',
                    rating: p.rating,
                    reviews: p.totalReviews,
                    isOnline: p.modalities.contains('online'),
                    photo: p.photoUrl,
                    providerId: p.id,
                    onTap: () => Navigator.pushNamed(
                            context, Routes.requestService,
                            arguments: {
                          'providerId': p.id,
                          'providerName': p.name,
                          'category': p.categories.isNotEmpty
                              ? p.categories.first
                              : ''
                        }),
                    onChat: () => ChatNav.open(context,
                        otherUserId: p.userId.isNotEmpty ? p.userId : p.id,
                        otherName: p.name,
                        otherPhoto: p.photoUrl),
                  ),
                );
              },
            );
          },
        ),
      );
}

// Nota: o botão de favoritar já está embutido no ProvCard (via parâmetro providerId).

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('📋 Meus Pedidos'),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.myResolve),
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
                onTap: () =>
                    Navigator.pushNamed(context, Routes.myResolve),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Text('⚡', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pedidos Resolve — propostas e orçamentos abertos',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.secondary),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                          Row(children: [
                            AppTag(o.statusLabel,
                                bg: _statusBg(o.status),
                                fg: _statusFg(o.status)),
                            const Spacer(),
                            if (o.status == OrderStatus.pending ||
                                o.status == OrderStatus.accepted)
                              TextButton(
                                  onPressed: () =>
                                      _confirmCancel(context, o.id),
                                  child: const Text('Cancelar',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.error))),
                            if (o.status == OrderStatus.inProgress)
                              TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                          context, Routes.gps, arguments: {
                                        'ctx': 'servico',
                                        'orderId': o.id
                                      }),
                                  child: const Text('Rastrear',
                                      style: TextStyle(fontSize: 12))),
                            if (o.status == OrderStatus.completed &&
                                !o.reviewed)
                              TextButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, Routes.reviews,
                                      arguments: {'orderId': o.id}),
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
        return const Color(0xFFE3F0FF);
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

// ─────────────────────────────────────────────────────────────
// REQUEST SERVICE SCREEN (Vol.3: Detalhes do Serviço — Solicitar
// orçamento). Cria o OrderModel real antes de abrir o chat com o
// profissional, fechando o fluxo Cliente → Pedido → Negociação.
// ─────────────────────────────────────────────────────────────
class RequestServiceScreen extends StatefulWidget {
  final String providerId, providerName, category;
  final Color providerColor;
  const RequestServiceScreen(
      {super.key,
      required this.providerId,
      required this.providerName,
      required this.category,
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
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    final orderId = await FS.createOrder({
      'providerId': widget.providerId,
      'category': widget.category,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'address': _address.text.trim(),
      'urgent': _urgent,
    });

    final roomId = await FS.getOrCreateRoom(widget.providerId);
    await FS.sendMessage(
        roomId: roomId,
        senderName: 'Você',
        text:
            '📋 Nova solicitação: ${_title.text.trim()}\n${_description.text.trim()}');
    await FS.pushNotif(widget.providerId, '📋 Nova solicitação de serviço',
        _title.text.trim(), 'order');

    if (!mounted) return;
    setState(() => _loading = false);
    snack(context, '✅ Solicitação enviada! Acompanhe pelo chat.',
        bg: AppColors.secondary);
    Navigator.pop(context);
    Navigator.pushNamed(context, Routes.chat, arguments: {
      'roomId': roomId,
      'id': widget.providerId,
      'name': widget.providerName,
      'orderId': orderId
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Solicitar orçamento')),
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
                          hintText: 'Título do serviço *',
                          prefixIcon: Icon(Icons.title_outlined)),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Campo obrigatório' : null),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _description,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'Descreva o que você precisa *',
                          alignLabelWithHint: true),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Campo obrigatório' : null),
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
                      decoration: const InputDecoration(
                          hintText: 'Endereço *',
                          prefixIcon: Icon(Icons.location_on_outlined)),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Campo obrigatório' : null),
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
