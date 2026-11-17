import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_nav.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/auth/sign_in_gate.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/orders/service_request.dart';
import '../../core/security/order_policy.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';
import '../wallet/wallet_screen.dart' show PixScreen, CardPaymentScreen;
import 'order_photo_picker.dart';

// ─────────────────────────────────────────────────────────────
// MY ORDERS / HISTORY SCREEN (Tela 06 — Meus pedidos)
// Dados 100% do stream real do cliente: nada de pedidos de exemplo.
// ─────────────────────────────────────────────────────────────

/// Grupos de status usados nos cartões de resumo e nas abas. Derivados de
/// [OrderStatus] (mesma máquina de estados de [OrderPolicy]).
enum _OrderGroup { awaiting, active, done, closed }

_OrderGroup _groupOf(OrderStatus s) => switch (s) {
      OrderStatus.pending => _OrderGroup.awaiting,
      OrderStatus.accepted ||
      OrderStatus.inProgress ||
      OrderStatus.awaitingPayment ||
      OrderStatus.paid ||
      OrderStatus.disputed =>
        _OrderGroup.active,
      OrderStatus.completed => _OrderGroup.done,
      OrderStatus.cancelled || OrderStatus.refunded => _OrderGroup.closed,
    };

String _statusText(OrderStatus s) => switch (s) {
      OrderStatus.pending => 'Aguardando orçamento',
      OrderStatus.accepted => 'Aceito',
      OrderStatus.inProgress => 'Em andamento',
      OrderStatus.awaitingPayment => 'Aguardando pagamento',
      OrderStatus.paid => 'Pago',
      OrderStatus.completed => 'Concluído',
      OrderStatus.cancelled => 'Cancelado',
      OrderStatus.disputed => 'Em contestação',
      OrderStatus.refunded => 'Estornado',
    };

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}h${d.minute == 0 ? '' : d.minute.toString().padLeft(2, '0')}';

String _shortId(String id) =>
    '#${(id.length > 8 ? id.substring(0, 8) : id).toUpperCase()}';

enum _StepState { done, current, todo, bad }

class _TimelineStep {
  final String label;
  final String? detail;
  final _StepState state;
  const _TimelineStep(this.label, this.state, {this.detail});
}

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override
  State<MyOrdersScreen> createState() => _MyOrdersState();
}

class _MyOrdersState extends State<MyOrdersScreen> {
  /// null = Todos.
  _OrderGroup? _tab;
  String _q = '';
  String? _selectedId;

  /// Stream único (filtros são locais): contagens vêm da lista completa.
  late Stream<List<OrderModel>> _orders =
      FS.orderHistoryStream().asBroadcastStream();
  int _streamGen = 0;

  /// Profissionais dos pedidos (nome/foto), carregados uma vez por id.
  final Map<String, ProviderModel?> _providers = {};
  final Set<String> _requested = {};

  void _retryOrders() {
    setState(() {
      _streamGen++;
      _orders = FS.orderHistoryStream().asBroadcastStream();
    });
  }

  void _ensureProviders(List<OrderModel> all) {
    for (final o in all) {
      final id = o.providerId;
      if (id == null || id.isEmpty || !_requested.add(id)) continue;
      FS.providerStream(id).first.then((p) {
        if (!mounted) return;
        setState(() => _providers[id] = p);
      }).catchError((Object _) {
        if (mounted) setState(() => _providers[id] = null);
      });
    }
  }

  String _titleOf(OrderModel o) {
    final p = _providers[o.providerId];
    return p != null && p.name.isNotEmpty ? p.name : o.title;
  }

  String _subtitleOf(OrderModel o) {
    final p = _providers[o.providerId];
    if (p != null && p.name.isNotEmpty) return o.title;
    return Categories.byId(o.category)?.name ?? o.category;
  }

  bool _matches(OrderModel o) {
    if (_tab != null && _groupOf(o.status) != _tab) return false;
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return true;
    final hay = [
      o.title,
      o.description,
      o.address,
      o.id,
      Categories.byId(o.category)?.name ?? o.category,
      _providers[o.providerId]?.name ?? '',
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.isAuth) {
      return Scaffold(
        appBar: const CarajasAppBar(title: 'Meus pedidos'),
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
      backgroundColor: Brand.isDark(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : Brand.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<OrderModel>>(
          key: ValueKey(_streamGen),
          stream: _orders,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError && !snap.hasData) {
              return EmptyState(
                  emoji: '⚠️',
                  title: 'Falha ao carregar pedidos',
                  subtitle: 'Verifique a conexão e tente novamente.',
                  actionLabel: 'Tentar novamente',
                  onAction: _retryOrders);
            }
            final all = snap.data ?? const <OrderModel>[];
            _ensureProviders(all);
            return LayoutBuilder(builder: (context, c) {
              final split = c.maxWidth >= 1000;
              return _body(context, all, split: split);
            });
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, List<OrderModel> all,
      {required bool split}) {
    final inner = AppNav.isInnerPage(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    int count(_OrderGroup g) =>
        all.where((o) => _groupOf(o.status) == g).length;

    final filtered = all.where(_matches).toList();
    OrderModel? selected;
    if (split && filtered.isNotEmpty) {
      selected = filtered.firstWhere((o) => o.id == _selectedId,
          orElse: () => filtered.first);
    }

    final stats = LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 720 ? 4 : 2;
      const gap = 12.0;
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      final items = <(IconData, String, int)>[
        (Icons.assignment_outlined, 'Total', all.length),
        (Icons.hourglass_empty_rounded, 'Aguardando orçamento',
            count(_OrderGroup.awaiting)),
        (Icons.sync_rounded, 'Em andamento', count(_OrderGroup.active)),
        (Icons.check_circle_outline_rounded, 'Concluídos',
            count(_OrderGroup.done)),
      ];
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final (icon, label, n) in items)
          SizedBox(width: w, child: _StatCard(icon: icon, label: label, value: n)),
      ]);
    });

    final tabs = <(String, _OrderGroup?, int)>[
      ('Todos', null, all.length),
      ('Aguardando', _OrderGroup.awaiting, count(_OrderGroup.awaiting)),
      ('Em andamento', _OrderGroup.active, count(_OrderGroup.active)),
      ('Concluídos', _OrderGroup.done, count(_OrderGroup.done)),
      ('Cancelados', _OrderGroup.closed, count(_OrderGroup.closed)),
    ];

    final listCard = BrandSoftCard(
      padding: EdgeInsets.all(wide ? 20 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Suas solicitações',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _q = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar pedido ou profissional',
              prefixIcon: const Icon(Icons.search_rounded, color: Brand.green),
              isDense: true,
              filled: true,
              fillColor: Brand.isDark(context)
                  ? AppColors.darkSurface
                  : Brand.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Brand.line(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Brand.line(context)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final (label, g, n) in tabs)
                _TabButton(
                  label: '$label ($n)',
                  selected: _tab == g,
                  onTap: () => setState(() => _tab = g),
                ),
            ]),
          ),
          Divider(height: 1, color: Brand.line(context)),
          const SizedBox(height: 12),
          if (all.isEmpty)
            _emptyOrders()
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'Nenhum pedido encontrado com este filtro ou busca.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.inkMuted(context)),
              ),
            )
          else
            for (final o in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _OrderRow(
                  order: o,
                  title: _titleOf(o),
                  subtitle: _subtitleOf(o),
                  photoUrl: _providers[o.providerId]?.photoUrl,
                  selected: split && selected?.id == o.id,
                  bg: _statusBg(o.status),
                  fg: _statusFg(o.status),
                  onOpen: () => split
                      ? setState(() => _selectedId = o.id)
                      : _openSheet(o.id),
                ),
              ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        BrandContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: wide ? 16 : 12),
              if (wide) ...[
                BrandBreadcrumb(items: [
                  (
                    'Início',
                    () => Navigator.pushNamedAndRemoveUntil(
                        context, Routes.main, (_) => false)
                  ),
                  ('Meus pedidos', null),
                ]),
                const SizedBox(height: 12),
              ],
              BrandPageHero(
                title: 'Meus pedidos',
                subtitle: 'Acompanhe suas solicitações e os próximos passos.',
                leading: inner
                    ? Material(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Voltar',
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => AppNav.safeBack(context),
                        ),
                      )
                    : null,
                trailing: Icon(Icons.assignment_turned_in_rounded,
                    size: wide ? 56 : 38,
                    color: Brand.gold.withValues(alpha: 0.9)),
              ),
              if (HomologCatalog.enabled) ...[
                const SizedBox(height: 12),
                const BrandDemoNotice(),
              ],
              const SizedBox(height: 12),
              BrandSoftCard(
                onTap: () => Navigator.pushNamed(context, Routes.myResolve),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  const Icon(Icons.bolt_rounded, color: Brand.goldDeep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pedidos Resolve — propostas e orçamentos abertos',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Brand.ink(context)),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Brand.green),
                ]),
              ),
              const SizedBox(height: 14),
              stats,
              const SizedBox(height: 16),
              if (split)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: listCard),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 9,
                      child: BrandSoftCard(
                        padding: const EdgeInsets.all(20),
                        child: selected == null
                            ? _detailPlaceholder(all.isEmpty)
                            : _detail(context, selected),
                      ),
                    ),
                  ],
                )
              else
                listCard,
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyOrders() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(children: [
          const Icon(Icons.assignment_outlined, size: 44, color: Brand.green),
          const SizedBox(height: 10),
          Text('Nenhum pedido ainda',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink(context))),
          const SizedBox(height: 4),
          Text('Quando você pedir um orçamento, ele aparece aqui.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Brand.inkMuted(context))),
          const SizedBox(height: 14),
          BrandPrimaryButton(
            label: 'Explorar serviços',
            icon: Icons.search_rounded,
            expanded: false,
            onPressed: () => Navigator.pushNamed(context, Routes.search),
          ),
        ]),
      );

  Widget _detailPlaceholder(bool noOrders) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            noOrders
                ? 'Os detalhes do pedido aparecem aqui.'
                : 'Nenhum pedido selecionado.',
            style: TextStyle(color: Brand.inkMuted(context)),
          ),
        ),
      );

  /// Detalhe em folha (telas estreitas): reflete o stream ao vivo.
  void _openSheet(String orderId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface(context),
      builder: (sheetCtx) => StreamBuilder<List<OrderModel>>(
        stream: _orders,
        builder: (ctx, snap) {
          final o =
              snap.data?.where((e) => e.id == orderId).firstOrNull;
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: o == null
                    ? _detailPlaceholder(false)
                    : _detail(context, o, sheetCtx: sheetCtx),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_TimelineStep> _timeline(OrderModel o) {
    final s = o.status;
    final showPayment = o.isPaid ||
        s == OrderStatus.awaitingPayment ||
        s == OrderStatus.paid;
    // Caminho feliz permitido por OrderPolicy.transitions.
    const path = ['pending', 'accepted', 'inProgress', 'completed'];
    assert(() {
      for (var i = 0; i < path.length - 1; i++) {
        if (!OrderPolicy.isAllowedTransition(path[i], path[i + 1])) {
          return false;
        }
      }
      return true;
    }());
    final cur = switch (s) {
      OrderStatus.pending => 0,
      OrderStatus.accepted => 1,
      OrderStatus.inProgress => 2,
      OrderStatus.awaitingPayment => 3,
      OrderStatus.paid => 3,
      OrderStatus.completed => 4,
      _ => 0,
    };
    final terminalOk = s == OrderStatus.completed || s == OrderStatus.paid;
    _StepState st(int i) {
      if (i < cur) return _StepState.done;
      if (i == cur) {
        return (i == 4 || (i == 3 && terminalOk))
            ? _StepState.done
            : _StepState.current;
      }
      return _StepState.todo;
    }

    final failed = s == OrderStatus.cancelled ||
        s == OrderStatus.refunded ||
        s == OrderStatus.disputed;
    final steps = <_TimelineStep>[
      _TimelineStep('Solicitação registrada', _StepState.done,
          detail:
              '${_dmy(o.createdAt)} • ${_hm(o.createdAt)}'),
    ];
    if (failed) {
      steps.add(_TimelineStep(
          switch (s) {
            OrderStatus.cancelled => 'Pedido cancelado',
            OrderStatus.refunded => 'Pedido estornado',
            _ => 'Pedido em contestação',
          },
          _StepState.bad,
          detail: s == OrderStatus.disputed
              ? 'O repasse fica bloqueado até a análise.'
              : null));
      return steps;
    }
    steps.add(_TimelineStep(
        'Aceito pelo profissional', st(1),
        detail: st(1) == _StepState.current
            ? 'Combine os próximos passos pelo chat.'
            : null));
    steps.add(_TimelineStep(
        'Serviço em andamento', st(2),
        detail: st(2) == _StepState.current ? 'Serviço sendo executado.' : null));
    if (showPayment) {
      steps.add(_TimelineStep('Pagamento', st(3),
          detail: s == OrderStatus.awaitingPayment
              ? 'Aguardando o pagamento.'
              : (o.isPaid ? 'Valor retido até a conclusão.' : null)));
    }
    steps.add(_TimelineStep('Serviço concluído', st(4)));
    if (s == OrderStatus.pending) {
      steps[0] = _TimelineStep('Solicitação registrada', _StepState.done,
          detail: '${_dmy(o.createdAt)} • ${_hm(o.createdAt)}');
      steps.insert(
          1,
          _TimelineStep('Aguardando orçamento', _StepState.current,
              detail: (o.providerId?.isNotEmpty ?? false)
                  ? 'O profissional ainda não respondeu.'
                  : 'Aguardando um profissional responder.'));
    }
    return steps;
  }

  Widget _detail(BuildContext context, OrderModel o, {BuildContext? sheetCtx}) {
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    final provider = _providers[o.providerId];
    final steps = _timeline(o);
    final hasProvider = o.providerId?.isNotEmpty ?? false;
    final canCancel = !o.isPaid &&
        (o.status == OrderStatus.pending || o.status == OrderStatus.accepted);

    void closeSheet() {
      if (sheetCtx != null && sheetCtx.mounted) Navigator.pop(sheetCtx);
    }

    Widget action(String label, VoidCallback? onTap,
        {IconData? icon, bool primary = false, bool danger = false}) {
      final color = danger ? AppColors.error : Brand.green;
      return primary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: Brand.green,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(
                    color: onTap == null ? Brand.line(context) : color),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text('Detalhes do pedido',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
          ),
          Text(_shortId(o.id),
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: muted)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          AppAvatar(
            url: provider?.photoUrl,
            name: _titleOf(o),
            size: 56,
            r: 16,
            bg: Brand.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_titleOf(o),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900, color: ink)),
              Text(_subtitleOf(o),
                  style: TextStyle(fontSize: 13.5, color: muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _StatusPill(
                    text: _statusText(o.status),
                    bg: _statusBg(o.status),
                    fg: _statusFg(o.status)),
                if (HomologCatalog.enabled &&
                    hasProvider &&
                    HomologCatalog.isDemoProvider(o.providerId!))
                  const _StatusPill(
                      text: 'Perfil demonstrativo',
                      bg: Brand.greenLight,
                      fg: Brand.green),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        for (var i = 0; i < steps.length; i++)
          _TimelineTile(step: steps[i], last: i == steps.length - 1),
        const SizedBox(height: 10),
        Divider(height: 1, color: Brand.line(context)),
        const SizedBox(height: 12),
        Wrap(spacing: 22, runSpacing: 10, children: [
          if (o.address.trim().isNotEmpty)
            _Fact(icon: Icons.location_on_outlined, label: 'Local', value: o.address),
          _Fact(
              icon: Icons.payments_outlined,
              label: 'Valor',
              value: o.price != null ? PaySvc.fmt(o.price!) : 'Sob orçamento'),
          if (o.urgent)
            const _Fact(
                icon: Icons.bolt_rounded, label: 'Prioridade', value: 'Urgente'),
        ]),
        if (o.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(o.description.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, height: 1.4, color: ink)),
        ],
        if (o.siteVisitRequested) ...[
          const SizedBox(height: 8),
          Text('Visita técnica solicitada',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Brand.inkMuted(context))),
        ],
        if (o.photoUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Fotos do ambiente',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink(context))),
          const SizedBox(height: 6),
          OrderPhotoGallery(urls: o.photoUrls),
        ],
        const SizedBox(height: 10),
        _PaymentInfo(order: o),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          action(
            'Mensagens',
            hasProvider
                ? () => _openChat(o, provider)
                : null,
            icon: Icons.chat_bubble_outline_rounded,
          ),
          if (o.canPay)
            action('Pagar', () {
              closeSheet();
              _openPayment(this.context, o);
            }, icon: Icons.lock_outline_rounded, primary: true),
          if (o.awaitingClientConfirmation) ...[
            action('Confirmar serviço', () {
              closeSheet();
              _confirmService(this.context, o);
            }, icon: Icons.check_rounded, primary: true),
            action('Contestar', () {
              closeSheet();
              _openDispute(this.context, o);
            }, danger: true),
          ],
          if (o.status == OrderStatus.inProgress)
            action('Rastrear', () {
              closeSheet();
              Navigator.pushNamed(this.context, Routes.gps,
                  arguments: {'ctx': 'servico', 'orderId': o.id});
            }, icon: Icons.my_location_rounded),
          if (o.status == OrderStatus.completed && !o.reviewed)
            action('Avaliar', () {
              closeSheet();
              Navigator.pushNamed(this.context, Routes.reviews, arguments: {
                'orderId': o.id,
                'providerId': o.providerId,
                'providerName': provider?.name,
              });
            }, icon: Icons.star_outline_rounded),
          if (canCancel)
            action('Cancelar solicitação', () {
              closeSheet();
              _confirmCancel(this.context, o.id);
            }, icon: Icons.cancel_outlined, danger: true),
        ]),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () {
              closeSheet();
              Navigator.pushNamed(this.context, Routes.support);
            },
            icon: const Icon(Icons.help_outline_rounded, size: 18),
            label: const Text('Precisa de ajuda?'),
            style: TextButton.styleFrom(foregroundColor: Brand.green),
          ),
        ),
      ],
    );
  }

  Future<void> _openChat(OrderModel o, ProviderModel? p) async {
    final id = o.providerId;
    if (id == null || id.isEmpty) return;
    if (!await ensureSignedIn(context,
        message: 'Entre na conta para conversar com o profissional.')) {
      return;
    }
    if (!mounted) return;
    try {
      await ChatNav.open(
        context,
        otherUserId: id,
        otherName: p?.name.isNotEmpty == true ? p!.name : 'Profissional',
        otherPhoto: p?.photoUrl,
      );
    } catch (_) {
      if (mounted) {
        snack(context, 'Não foi possível abrir a conversa agora.',
            bg: AppColors.error);
      }
    }
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label: $value',
      child: BrandSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 28, color: Brand.goldDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Brand.inkMuted(context))),
                Text('$value',
                    style: TextStyle(
                        fontSize: 26,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Brand.isDark(context)
                            ? Brand.gold
                            : Brand.greenDark)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: selected ? Brand.green : Colors.transparent,
                  width: 3),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                  color: selected ? Brand.green : Brand.inkMuted(context))),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _StatusPill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style:
                TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
      );
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  final String title, subtitle;
  final String? photoUrl;
  final bool selected;
  final Color bg, fg;
  final VoidCallback onOpen;
  const _OrderRow({
    required this.order,
    required this.title,
    required this.subtitle,
    required this.photoUrl,
    required this.selected,
    required this.bg,
    required this.fg,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    final o = order;
    return Semantics(
      button: true,
      selected: selected,
      label: '$title, $subtitle, ${_statusText(o.status)}',
      excludeSemantics: true,
      onTap: onOpen,
      child: Material(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? Brand.gold : Brand.line(context),
                  width: selected ? 2 : 1),
            ),
            child: Row(children: [
              AppAvatar(
                  url: photoUrl, name: title, size: 52, r: 14, bg: Brand.green),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: ink)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: ink)),
                    Text(_shortId(o.id),
                        style: TextStyle(fontSize: 11.5, color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusPill(
                        text: _statusText(o.status), bg: bg, fg: fg),
                    const SizedBox(height: 4),
                    Text(
                        o.price != null ? PaySvc.fmt(o.price!) : 'Sob orçamento',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: ink)),
                    Text('Solicitado em ${_dmy(o.createdAt)}',
                        style: TextStyle(fontSize: 11, color: muted)),
                    const Text('Ver detalhes ›',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Brand.green)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _TimelineStep step;
  final bool last;
  const _TimelineTile({required this.step, required this.last});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (step.state) {
      _StepState.done => (Brand.green, Icons.check_circle_rounded),
      _StepState.current => (Brand.gold, Icons.radio_button_checked_rounded),
      _StepState.bad => (AppColors.error, Icons.cancel_rounded),
      _StepState.todo => (Brand.line(context), Icons.circle_outlined),
    };
    final todo = step.state == _StepState.todo;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 26,
          child: Column(children: [
            Icon(icon, size: 20, color: todo ? Brand.inkMuted(context) : color),
            if (!last)
              Expanded(
                child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: step.state == _StepState.done
                        ? Brand.green
                        : Brand.line(context)),
              ),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(step.label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          todo ? FontWeight.w600 : FontWeight.w800,
                      color: todo
                          ? Brand.inkMuted(context)
                          : Brand.ink(context))),
              if (step.detail != null)
                Text(step.detail!,
                    style: TextStyle(
                        fontSize: 12, color: Brand.inkMuted(context))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Fact({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: Brand.green),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: value),
            ]),
            style: TextStyle(fontSize: 12.5, color: Brand.ink(context)),
          ),
        ),
      ]),
    );
  }
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
