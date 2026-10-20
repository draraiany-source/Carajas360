import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/order_policy.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/memo.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import 'cart_service.dart';
import 'payment_screens.dart';
import 'payments_api.dart';

/// Acompanhamento do pedido do Mercado. Tudo que aparece aqui (pago,
/// pendente, reembolso…) vem do documento persistido no servidor.
class MarketOrderScreen extends StatefulWidget {
  final String orderId;
  const MarketOrderScreen({super.key, required this.orderId});
  @override
  State<MarketOrderScreen> createState() => _MarketOrderScreenState();
}

class _MarketOrderScreenState extends State<MarketOrderScreen> {
  // Assinaturas criadas uma vez (por pedido / tentativa ativa), não a cada
  // rebuild: _busy e cada atualização do pedido recriavam o histórico e a
  // tentativa de pagamento.
  final _order = Memo<Stream<MarketOrder?>>();
  final _events = Memo<Stream<List<Map<String, dynamic>>>>();
  final _attempt = Memo<Stream<PaymentAttempt?>>();
  bool _busy = false;
  bool _cartCleaned = false;

  /// Itens só saem do carrinho quando o pagamento está CONFIRMADO.
  /// Roda após o frame (notifyListeners não pode ocorrer durante o build).
  void _cleanCart(MarketOrder o) {
    if (_cartCleaned || !o.isPaid) return;
    _cartCleaned = true;
    final ids = o.items.map((i) => i.productId).toList();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => CartService.instance.removeProducts(ids));
  }

  Future<void> _pay(MarketOrder o, String method) async {
    final target = PayTarget('market', o.id, o.totalCents, 'Pedido ${o.storeName}');
    if (method == 'wallet') {
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                title: const Text('Pagar com a carteira?'),
                content: Text('Serão debitados ${brl(o.totalCents)} do seu saldo interno.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
                  ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Pagar')),
                ],
              ));
      if (ok != true) return;
      setState(() => _busy = true);
      try {
        final a = await PaymentsApi.start(target: target, method: 'wallet', requestId: newRequestId());
        if (mounted && a != null && !a.approved) {
          snack(context, a.statusDetail ?? 'Pagamento com carteira não concluído', bg: AppColors.error);
        }
      } on CloudCallException catch (e) {
        if (mounted) snack(context, e.message, bg: AppColors.error);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => PaymentScreen(target: target, method: method)));
  }

  Future<void> _cancel(MarketOrder o) async {
    final paid = !o.awaitingPayment;
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: Text(paid ? 'Cancelar e pedir reembolso?' : 'Cancelar pedido?'),
              content: Text(paid
                  ? 'O reembolso é solicitado ao meio de pagamento e só aparece como concluído depois da confirmação.'
                  : 'A cobrança pendente será cancelada e os itens voltam ao estoque.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
                ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar')),
              ],
            ));
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await PaymentsApi.cancelOrder(o.id);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmReceipt(MarketOrder o) async {
    // Libera o pagamento à loja: ação irreversível, pede confirmação.
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Confirmar recebimento?'),
              content: const Text(
                  'Confirme apenas se recebeu os itens. O pagamento será liberado à loja e esta ação não pode ser desfeita.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
                ElevatedButton(
                    key: const Key('confirm-receipt-ok'),
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Confirmar')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await PaymentsApi.confirmReceipt(o.id);
      if (mounted) {
        snack(context, 'Recebimento confirmado', bg: AppColors.secondary);
      }
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Pedido')),
        body: StreamBuilder<MarketOrder?>(
          stream: _order.of(
              widget.orderId, () => PaymentsApi.orderStream(widget.orderId)),
          builder: (context, s) {
            if (s.hasError) return QueryErrorView(error: s.error);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final o = s.data;
            if (o == null) return const Center(child: Text('Pedido não encontrado.'));
            _cleanCart(o);
            return LoadingOverlay(loading: _busy, child: _body(o));
          },
        ),
      );

  Widget _body(MarketOrder o) {
    final expired = o.awaitingPayment && o.reservationExpired(DateTime.now());
    return ListView(padding: pagePadding(context), children: [
      Container(
        decoration: AppDecorations.card(r: 16),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('🏪 ${o.storeName}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 6),
          Text(orderStatusLabel[o.status] ?? o.status,
              key: const Key('order-status'),
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          Text(paymentStatusLabel[o.paymentStatus] ?? o.paymentStatus,
              key: const Key('order-payment-status'),
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          if (o.awaitingPayment && o.reservedUntil != null && !expired)
            Text('Reserva dos itens até ${_hm(o.reservedUntil!)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          if (o.refundPendingCents > 0)
            Text('Reembolso em processamento: ${brl(o.refundPendingCents)}',
                style: const TextStyle(fontSize: 12, color: AppColors.warning)),
          if (o.refundedCents > 0)
            Text('Reembolsado: ${brl(o.refundedCents)}',
                style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
          const Divider(),
          for (final i in o.items)
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('${i.name} x${i.qty}', style: const TextStyle(fontSize: 13))),
              Text(brl(i.subtotalCents)),
            ]),
          const Divider(),
          _row('Subtotal', brl(o.subtotalCents)),
          if (o.discountCents > 0) _row('Desconto', '- ${brl(o.discountCents)}'),
          _row(o.deliveryMode == 'pickup' ? 'Retirada' : 'Frete', brl(o.deliveryFeeCents)),
          _row('Total', brl(o.totalCents), bold: true),
          if (o.deliveryMode == 'delivery' && o.address.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Entrega: ${marketAddressLine(o.address)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight))),
        ]),
      ),
      const SizedBox(height: 16),
      if (expired)
        const Text('A reserva venceu. Volte ao carrinho para refazer o pedido.',
            style: TextStyle(color: AppColors.error))
      else if (o.awaitingPayment) ...[
        if (o.activeAttemptId != null) _activeAttempt(o),
        const Text('Forma de pagamento', style: TextStyle(fontWeight: FontWeight.w700)),
        ListTile(
            key: const Key('pay-pix'),
            leading: const Text('⚡', style: TextStyle(fontSize: 22)),
            title: const Text('Pix'),
            subtitle: const Text('QR Code e copia e cola'),
            onTap: () => _pay(o, 'pix')),
        ListTile(
            key: const Key('pay-card'),
            leading: const Icon(Icons.credit_card_rounded, color: AppColors.primary),
            title: const Text('Cartão de crédito'),
            onTap: () => _pay(o, 'card')),
        ListTile(
            key: const Key('pay-wallet'),
            leading: const Text('👜', style: TextStyle(fontSize: 22)),
            title: const Text('Saldo da carteira'),
            onTap: () => _pay(o, 'wallet')),
      ],
      if (o.awaitingReceipt && o.clientId == AuthService.uid)
        ElevatedButton(
            key: const Key('confirm-receipt'),
            onPressed: _busy ? null : () => _confirmReceipt(o),
            child: const Text('Confirmar recebimento'))
      else if (o.status == 'delivered' && o.released)
        const Text('Recebimento confirmado',
            style: TextStyle(
                color: AppColors.secondary, fontWeight: FontWeight.w700)),
      if (o.canCancel)
        TextButton(
            key: const Key('cancel-order'),
            onPressed: () => _cancel(o),
            child: Text(o.awaitingPayment ? 'Cancelar pedido' : 'Cancelar e pedir reembolso',
                style: const TextStyle(color: AppColors.error))),
      const SizedBox(height: 12),
      const Text('Histórico', style: TextStyle(fontWeight: FontWeight.w700)),
      StreamBuilder<List<Map<String, dynamic>>>(
          stream: _events.of(o.id, () => PaymentsApi.orderEvents(o.id)),
          builder: (_, s) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in s.data ?? const <Map<String, dynamic>>[])
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• ${_eventLabel(e['type']?.toString() ?? '')}',
                          style: const TextStyle(fontSize: 12))),
              ])),
    ]);
  }

  Widget _activeAttempt(MarketOrder o) => StreamBuilder<PaymentAttempt?>(
      stream: _attempt.of(o.activeAttemptId,
          () => PaymentsApi.attemptStream(o.activeAttemptId!)),
      builder: (_, s) {
        final a = s.data;
        if (a == null || !a.active) return const SizedBox.shrink();
        return Card(
            child: ListTile(
                title: Text(attemptStatusLabel[a.status] ?? a.status),
                subtitle: Text('Cobrança em andamento (${a.method == 'pix' ? 'Pix' : 'cartão'}). Continue por aqui para não gerar outra.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pay(o, a.method)));
      });

  // Horário no fuso da região (UTC−3), como holdTimeLabel.
  static String _hm(DateTime d) => holdTimeLabel(d.millisecondsSinceEpoch);

  static String _eventLabel(String t) => marketEventLabel(t);

  Widget _row(String a, String b, {bool bold = false}) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
            Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
          ]);
}

/// Rótulo legível de um evento do histórico do pedido.
String marketEventLabel(String t) => const {
        'created': 'Pedido criado',
        'payment_started': 'Pagamento iniciado',
        'payment_failed': 'Tentativa de pagamento não concluída',
        'paid': 'Pagamento confirmado',
        'late_approval': 'Pagamento confirmado após cancelamento — reembolso automático',
        'preparing': 'Loja preparando',
        'shipped': 'Saiu para entrega',
        'ready': 'Pronto para retirada',
        'delivered': 'Entregue',
        'cancellation_requested': 'Cancelamento solicitado',
        'refund_requested': 'Reembolso solicitado',
        'refund_confirmed': 'Reembolso confirmado',
        'cancelled': 'Cancelado',
        'expired': 'Reserva expirada',
        'released': 'Pagamento liberado à loja',
      }[t] ??
    t;

/// Endereço de entrega em uma linha (rua, número, bairro — cidade).
String marketAddressLine(Map<String, dynamic> a) {
  String f(String k) => (a[k] ?? '').toString().trim();
  final street = [f('street'), f('number')].where((x) => x.isNotEmpty).join(', ');
  final head = [street, f('district')].where((x) => x.isNotEmpty).join(' — ');
  return [head, f('city')].where((x) => x.isNotEmpty).join(' — ');
}

/// Histórico de pedidos do Mercado do cliente.
class MyMarketOrdersScreen extends StatefulWidget {
  const MyMarketOrdersScreen({super.key});
  @override
  State<MyMarketOrdersScreen> createState() => _MyMarketOrdersScreenState();
}

class _MyMarketOrdersScreenState extends State<MyMarketOrdersScreen> {
  // Uma assinatura por usuário logado (não a cada rebuild).
  final _orders = Memo<Stream<List<MarketOrder>>>();
  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus pedidos do Mercado')),
      body: uid == null
          ? const Center(child: Text('Faça login para ver seus pedidos.'))
          : StreamBuilder<List<MarketOrder>>(
              stream: _orders.of(uid, () => PaymentsApi.myOrders(uid)),
              builder: (_, s) {
                if (s.hasError) return QueryErrorView(error: s.error);
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final list = s.data!;
                if (list.isEmpty) {
                  return const EmptyState(emoji: '🧾', title: 'Nenhum pedido', subtitle: 'Suas compras aparecerão aqui');
                }
                return ListView(children: [
                  for (final o in list)
                    ListTile(
                        title: Text('${o.storeName} — ${brl(o.totalCents)}'),
                        subtitle: Text('${orderStatusLabel[o.status] ?? o.status} · ${paymentStatusLabel[o.paymentStatus] ?? o.paymentStatus}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => MarketOrderScreen(orderId: o.id)))),
                ]);
              }),
    );
  }
}

/// Pedidos recebidos pela loja (dono): avança preparo/envio/entrega.
/// A entrega libera o valor líquido como SALDO INTERNO da loja.
class StoreOrdersScreen extends StatefulWidget {
  const StoreOrdersScreen({super.key});
  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen> {
  // Uma assinatura por usuário logado (não a cada rebuild).
  final _orders = Memo<Stream<List<MarketOrder>>>();
  static const _payoutNote =
      'O repasse é liberado quando o cliente confirmar o recebimento (ou em 7 dias).';
  static const _next = {
    'paid': [('preparing', 'Iniciar preparo')],
    'preparing': [('shipped', 'Enviado'), ('ready', 'Pronto p/ retirada')],
    'shipped': [('delivered', 'Entregue')],
    'ready': [('delivered', 'Retirado/entregue')],
  };

  List<Widget> _details(BuildContext context, MarketOrder o) {
    const small = TextStyle(fontSize: 12, color: AppColors.textLight);
    final ref = (o.address['reference'] ?? '').toString().trim();
    return [
      if (o.clientName.isNotEmpty) Text('Cliente: ${o.clientName}', style: small),
      for (final i in o.items)
        Text('• ${i.name} × ${i.qty}', style: const TextStyle(fontSize: 13)),
      const SizedBox(height: 6),
      Text(o.deliveryMode == 'pickup' ? 'Modo: retirada na loja' : 'Modo: entrega', style: small),
      if (o.deliveryMode == 'delivery' && o.address.isNotEmpty) ...[
        Text('Endereço: ${marketAddressLine(o.address)}', style: small),
        if (ref.isNotEmpty) Text('Referência: $ref', style: small),
      ],
      if (o.clientId.isNotEmpty)
        TextButton.icon(
            key: Key('chat-client-${o.id}'),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Conversar com o cliente'),
            onPressed: () => ChatNav.open(context, otherUserId: o.clientId, otherName: o.clientName.isNotEmpty ? o.clientName : 'Cliente')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos da loja')),
      body: uid == null
          ? const Center(child: Text('Faça login.'))
          : StreamBuilder<List<MarketOrder>>(
              stream: _orders.of(uid, () => PaymentsApi.storeOrders(uid)),
              builder: (context, s) {
                if (s.hasError) return QueryErrorView(error: s.error);
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                if (s.data!.isEmpty) {
                  return const EmptyState(emoji: '📦', title: 'Sem pedidos', subtitle: 'Pedidos da sua loja aparecem aqui');
                }
                return ListView(children: [
                  for (final o in s.data!)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Detalhes para a loja separar e entregar.
                              ExpansionTile(
                                  key: Key('store-order-${o.id}'),
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: const EdgeInsets.only(bottom: 8),
                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                  title: Text('${o.items.length} item(ns) — ${brl(o.totalCents)} · ${o.deliveryMode == 'pickup' ? 'retirada' : 'entrega'}',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  subtitle: Text('${orderStatusLabel[o.status] ?? o.status} · ${paymentStatusLabel[o.paymentStatus] ?? o.paymentStatus}',
                                      style: const TextStyle(fontSize: 12)),
                                  children: _details(context, o)),
                              if (o.awaitingReceipt) const Text(_payoutNote, style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                              Wrap(spacing: 8, children: [
                                for (final (to, label) in _next[o.status] ?? const <(String, String)>[])
                                  if (to != 'ready' || o.deliveryMode == 'pickup')
                                    if (to != 'shipped' || o.deliveryMode == 'delivery')
                                      OutlinedButton(
                                          onPressed: () async {
                                            try {
                                              await PaymentsApi.updateStatus(o.id, to);
                                              if (to == 'delivered' && context.mounted) snack(context, _payoutNote);
                                            } on CloudCallException catch (e) {
                                              if (context.mounted) snack(context, e.message, bg: AppColors.error);
                                            }
                                          },
                                          child: Text(label)),
                              ]),
                            ]))),
                ]);
              }),
    );
  }
}
