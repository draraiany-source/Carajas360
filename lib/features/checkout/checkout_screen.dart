import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import 'cart.dart';
import 'cart_service.dart';
import 'market_order_screen.dart';
import 'payments_api.dart';

/// Carrinho agrupado por loja. Cada loja é finalizada em um pedido
/// separado (o total cobrado é sempre de UMA loja; os itens das outras
/// continuam no carrinho).
class CartScreen extends StatelessWidget {
  final String? resumeStoreId;
  const CartScreen({super.key, this.resumeStoreId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: CartService.instance,
      builder: (context, _) {
        final groups = CartService.instance.cart.byStore();
        return Scaffold(
          appBar: AppBar(title: const Text('🛒 Carrinho')),
          body: groups.isEmpty
              ? const EmptyState(
                  emoji: '🛒',
                  title: 'Seu carrinho está vazio',
                  subtitle: 'Adicione produtos para continuar')
              : ListView(padding: pagePadding(context), children: [
                  if (groups.length > 1)
                    const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                            'Seu carrinho tem produtos de lojas diferentes. Cada loja gera um pedido e um pagamento separados.',
                            style: TextStyle(fontSize: 12, color: AppColors.textLight))),
                  for (final e in groups.entries) _StoreGroup(storeId: e.key, lines: e.value),
                ]),
        );
      });
}

class _StoreGroup extends StatelessWidget {
  final String storeId;
  final List<CartLine> lines;
  const _StoreGroup({required this.storeId, required this.lines});

  @override
  Widget build(BuildContext context) {
    final est = lines.fold<int>(0, (s, l) => s + l.subtotalCents);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: AppDecorations.card(r: 16),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('🏪 ${lines.first.storeName.isEmpty ? 'Loja' : lines.first.storeName}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        for (final l in lines)
          Row(children: [
            Expanded(child: Text('${l.emoji} ${l.name}', style: const TextStyle(fontSize: 13))),
            IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                onPressed: () => CartService.instance.setQty(l, l.qty - 1)),
            Text('${l.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => CartService.instance.setQty(l, l.qty + 1)),
          ]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Estimativa (sem frete)', style: TextStyle(fontSize: 12)),
          Text(brl(est), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton(
                key: Key('checkout-$storeId'),
                onPressed: () => openCheckout(context, storeId),
                child: const Text('Finalizar pedido desta loja'))),
      ]),
    );
  }
}

/// Abre o checkout exigindo login; após entrar, o app volta ao checkout.
Future<void> openCheckout(BuildContext context, String storeId) async {
  if (!AuthService.isAuth) {
    await CartService.setPendingCheckout(storeId);
    if (context.mounted) Navigator.pushNamed(context, Routes.login);
    return;
  }
  await Navigator.push(context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(storeId: storeId)));
}

/// Endereço/entrega + cotação do SERVIDOR + criação do pedido (antes de
/// qualquer cobrança). O requestId é salvo por loja: fechar/atualizar a
/// tela e tentar de novo devolve o mesmo pedido em vez de duplicar.
class CheckoutScreen extends StatefulWidget {
  final String storeId;
  const CheckoutScreen({super.key, required this.storeId});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _mode = 'delivery';
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _reference = TextEditingController();
  final _coupon = TextEditingController();
  Map<String, dynamic>? _quote;
  String? _error;
  bool _loadingQuote = false, _creating = false;
  Timer? _debounce;
  // Descarta respostas de cotações antigas (ex.: cupom alterado no meio).
  int _quoteSeq = 0;

  List<CartLine> get _lines =>
      CartService.instance.cart.byStore()[widget.storeId] ?? const [];

  Map<String, dynamic> _body() => {
        'storeId': widget.storeId,
        'items': _lines.map((l) => {'productId': l.productId, 'qty': l.qty}).toList(),
        'deliveryMode': _mode,
        if (_coupon.text.trim().isNotEmpty) 'couponCode': _coupon.text.trim(),
      };

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in [_street, _number, _district, _city, _reference, _coupon]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuote() async {
    if (_lines.isEmpty) return;
    _debounce?.cancel();
    final seq = ++_quoteSeq;
    // Sem cotação válida até o servidor responder (não mostra total antigo).
    setState(() {
      _loadingQuote = true;
      _error = null;
      _quote = null;
    });
    try {
      final q = await PaymentsApi.quote(_body());
      if (mounted && seq == _quoteSeq) setState(() => _quote = q);
    } on CloudCallException catch (e) {
      if (mounted && seq == _quoteSeq) setState(() => _error = e.message);
    } catch (e) {
      if (mounted && seq == _quoteSeq) {
        setState(() => _error = 'Não foi possível calcular o total. Tente novamente.');
      }
    } finally {
      if (mounted && seq == _quoteSeq) setState(() => _loadingQuote = false);
    }
  }

  /// Cupom alterado: invalida a cotação e recalcula após uma pausa.
  void _onCouponChanged(String _) {
    _debounce?.cancel();
    _quoteSeq++;
    setState(() {
      _quote = null;
      _loadingQuote = false;
    });
    _debounce = Timer(const Duration(milliseconds: 700), _loadQuote);
  }

  Future<String> _requestId() async {
    final key = 'checkout_req_${widget.storeId}';
    final p = await SharedPreferences.getInstance();
    return p.getString(key) ?? (await () async {
      final id = newRequestId();
      await p.setString(key, id);
      return id;
    }());
  }

  Future<void> _create() async {
    if (_creating) return;
    if (_mode == 'delivery' && (_street.text.trim().isEmpty || _city.text.trim().isEmpty)) {
      setState(() => _error = 'Informe rua e cidade para entrega.');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final r = await PaymentsApi.createMarketOrder({
        ..._body(),
        'requestId': await _requestId(),
        'address': {
          'street': _street.text,
          'number': _number.text,
          'district': _district.text,
          'city': _city.text,
          'reference': _reference.text,
        },
      });
      // Pedido criado: o próximo checkout desta loja é outra intenção.
      final p = await SharedPreferences.getInstance();
      await p.remove('checkout_req_${widget.storeId}');
      if (!mounted) return;
      await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => MarketOrderScreen(orderId: r['orderId'].toString())));
    } on CloudCallException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error =
            'Sem resposta do servidor. Toque em "Criar pedido" de novo — o mesmo pedido será recuperado.');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return Scaffold(
      appBar: AppBar(title: const Text('Finalizar pedido')),
      body: LoadingOverlay(
        loading: _creating,
        child: ListView(padding: pagePadding(context), children: [
          if (_lines.isEmpty)
            const Text('Não há itens desta loja no carrinho.'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'delivery', label: Text('Entrega'), icon: Icon(Icons.delivery_dining)),
              ButtonSegment(value: 'pickup', label: Text('Retirada'), icon: Icon(Icons.storefront)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() => _mode = s.first);
              _loadQuote();
            },
          ),
          const SizedBox(height: 12),
          if (_mode == 'delivery') ...[
            TextField(controller: _street, decoration: const InputDecoration(labelText: 'Rua *')),
            Row(children: [
              Expanded(child: TextField(controller: _number, decoration: const InputDecoration(labelText: 'Número'))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: TextField(controller: _district, decoration: const InputDecoration(labelText: 'Bairro'))),
            ]),
            TextField(controller: _city, decoration: const InputDecoration(labelText: 'Cidade *')),
            TextField(controller: _reference, decoration: const InputDecoration(labelText: 'Referência')),
            const SizedBox(height: 12),
          ],
          Row(children: [
            Expanded(
                child: TextField(
                    key: const Key('coupon-field'),
                    controller: _coupon,
                    onChanged: _onCouponChanged,
                    decoration: const InputDecoration(labelText: 'Cupom'))),
            TextButton(onPressed: _loadQuote, child: const Text('Aplicar')),
          ]),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, key: const Key('checkout-error'), style: const TextStyle(color: AppColors.error))),
          if (_loadingQuote) const LinearProgressIndicator(),
          if (q != null) _quoteCard(q),
          const SizedBox(height: 16),
          ElevatedButton(
              key: const Key('create-order'),
              onPressed: (_creating || q == null || q['ok'] != true) ? null : _create,
              child: const Text('Criar pedido e escolher pagamento')),
          const SizedBox(height: 8),
          const Text(
              'Os valores são confirmados pelo servidor. O estoque fica reservado por tempo limitado até o pagamento.',
              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
      ),
    );
  }

  Widget _quoteCard(Map<String, dynamic> q) {
    final lines = (q['lines'] as List?) ?? const [];
    final errors = ((q['errors'] as List?) ?? const []).map((e) => e.toString()).toList();
    int c(String k) => (q[k] as num?)?.toInt() ?? 0;
    return Container(
      decoration: AppDecorations.card(r: 16),
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        for (final l in lines.whereType<Map>())
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text('${l['name']} x${l['qty']}', style: const TextStyle(fontSize: 13))),
            Text(brl((l['subtotalCents'] as num).toInt())),
          ]),
        const Divider(),
        _row('Subtotal', brl(c('subtotalCents'))),
        if (c('discountCents') > 0) _row('Desconto', '- ${brl(c('discountCents'))}'),
        _row(_mode == 'pickup' ? 'Retirada' : 'Frete', brl(c('deliveryFeeCents'))),
        _row('Total', brl(c('totalCents')), bold: true, key: const Key('quote-total')),
        for (final e in errors)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('⚠️ $e', style: const TextStyle(color: AppColors.error, fontSize: 12))),
      ]),
    );
  }

  Widget _row(String a, String b, {bool bold = false, Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
        Text(b, key: key, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600)),
      ]));
}
