import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/demo_data.dart';
import '../../shared/models/models.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../checkout/market_order_screen.dart';
import '../checkout/payment_screens.dart';
import '../checkout/payments_api.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletState();
}

class _WalletState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _uid = AuthService.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) =>
              [SliverToBoxAdapter(child: _header())],
          body: TabBarView(
              controller: _tab, children: [_extract(), _pixTab()]),
        ),
      );

  Widget _header() => GradHeader(
      gradient: AppGradients.primary,
      child: Column(children: [
        Row(children: [
          // Aberta como rota (perfil/banner): precisa de voltar.
          if (Navigator.canPop(context))
            IconButton(
                tooltip: 'Voltar',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white)),
          const Expanded(
            child: Text('👜 Minha Carteira',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 22)),
          ),
          StreamBuilder<UserModel?>(
              stream:
                  _uid.isNotEmpty ? FS.userStream(_uid) : const Stream.empty(),
              builder: (_, s) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(s.data?.levelName ?? '⭐ Iniciante',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11)))),
        ]),
        const SizedBox(height: 18),
        StreamBuilder<WalletModel?>(
            stream: _uid.isNotEmpty ? FS.walletStream() : const Stream.empty(),
            builder: (_, s) {
              final bal = s.data?.balanceCents ?? 0;
              return Container(
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const Text('Saldo disponível',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 8),
                    Text(brl(bal),
                        key: const Key('wallet-balance'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 18),
                    Row(children: [
                      _btn('💳', 'Adicionar', () => _recharge(context)),
                      const SizedBox(width: 8),
                      _btn('📤', 'Sacar', () => _showWithdraw(context)),
                      const SizedBox(width: 8),
                      _btn(
                          '🧾',
                          'Pedidos',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const MyMarketOrdersScreen()))),
                      const SizedBox(width: 8),
                      _btn('📊', 'Extrato', () => _tab.animateTo(0)),
                    ]),
                  ]));
            }),
        const SizedBox(height: 14),
        TabBar(
            controller: _tab,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            dividerColor: Colors.transparent,
            // Planos removidos: assinatura não existe no app.
            tabs: const [
              Tab(text: 'Extrato'),
              Tab(text: 'Recarga'),
            ]),
      ]));

  Widget _btn(String icon, String label, VoidCallback onTap) => Expanded(
      child: GestureDetector(
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 4),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600))
              ]))));

  /// Saque/transferência bancária NÃO está integrado nesta fase: o saldo
  /// é crédito interno da plataforma. Nada é prometido ao usuário.
  void _showWithdraw(BuildContext context) => showDialog(
      context: context,
      builder: (c) => AlertDialog(
            title: const Text('Saque indisponível'),
            content: const Text(
                'O saldo da carteira é um crédito interno da plataforma e pode ser usado para pagar pedidos. '
                'A transferência para conta bancária ainda não está disponível — nenhum saque é processado.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Entendi'))
            ],
          ));

  /// Recarga: cria a recarga no servidor e paga por Pix/cartão. O crédito
  /// só entra depois da confirmação do gateway (webhook/conciliação).
  Future<void> _recharge(BuildContext context) async {
    final ctrl = TextEditingController(text: '50');
    final method = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(c).viewInsets.bottom + 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SheetHandle(),
                const SizedBox(height: 12),
                const Text('Adicionar saldo',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                    key: const Key('recharge-amount'),
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        prefixText: 'R\$ ',
                        helperText: 'Entre R\$ 10 e R\$ 5.000')),
                const SizedBox(height: 12),
                ListTile(
                    leading: const Text('⚡', style: TextStyle(fontSize: 22)),
                    title: const Text('Pagar com Pix'),
                    onTap: () => Navigator.pop(c, 'pix')),
                ListTile(
                    leading: const Icon(Icons.credit_card_rounded),
                    title: const Text('Pagar com cartão'),
                    onTap: () => Navigator.pop(c, 'card')),
              ]),
            ));
    final reais = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    ctrl.dispose();
    if (method == null || !context.mounted) return;
    final cents = (reais * 100).round();
    try {
      final r = await PaymentsApi.createRecharge(cents, newRequestId());
      if (!context.mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PaymentScreen(
                  target: PayTarget('recharge', r['rechargeId'].toString(),
                      cents, 'Recarga da carteira'),
                  method: method)));
    } on CloudCallException catch (e) {
      if (context.mounted) snack(context, e.message, bg: AppColors.error);
    }
  }

  Widget _extract() => StreamBuilder<List<TransactionModel>>(
      stream: _uid.isNotEmpty ? FS.txStream() : const Stream.empty(),
      builder: (_, s) {
        if (s.hasError) return QueryErrorView(error: s.error);
        final txs = DemoData.orEmpty(s.data, _demoTxs);
        if (txs.isEmpty)
          return const EmptyState(
              emoji: '📋',
              title: 'Sem transações',
              subtitle: 'Suas movimentações aparecerão aqui',
              asset: AppAssets.walletExtrato);
        return ListView.separated(
            padding: pagePadding(context),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = txs[i];
              return Container(
                  decoration: AppDecorations.card(),
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: (t.isCredit
                                    ? AppColors.secondary
                                    : AppColors.error)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child:
                            Text(t.icon, style: const TextStyle(fontSize: 22))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(t.description,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textDark)),
                          Text(fmtDate(t.createdAt),
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textLight))
                        ])),
                    Text('${t.isCredit ? '+' : '-'}${brl(t.amountCents)}',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: t.isCredit
                                ? AppColors.secondary
                                : AppColors.error)),
                  ]));
            });
      });

  Widget _pixTab() => ListView(padding: pagePadding(context), children: [
        Container(
            decoration: AppDecorations.card(),
            padding: const EdgeInsets.all(18),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Como funciona a carteira',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 10),
                  for (final t in const [
                    '⚡ Recarga por Pix ou cartão: o saldo entra só depois da confirmação do banco.',
                    '👜 Use o saldo para pagar pedidos do Mercado.',
                    '🎁 Cashback de compras entregues entra como saldo interno.',
                    '🏪 Lojas recebem o valor líquido das vendas entregues como saldo interno.',
                    '⛔ Saque para conta bancária ainda não está disponível.',
                  ])
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(t, style: const TextStyle(fontSize: 13))),
                ])),
        const SizedBox(height: 14),
        ElevatedButton.icon(
            onPressed: () => _recharge(context),
            icon: const Text('⚡', style: TextStyle(fontSize: 18)),
            label: const Text('Adicionar saldo')),
      ]);

  static final _demoTxs = [
    TransactionModel(
        id: '1',
        userId: 'u',
        type: 'credit',
        amount: 150,
        description: 'Pagamento recebido',
        icon: '💰',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    TransactionModel(
        id: '2',
        userId: 'u',
        type: 'debit',
        amount: 120,
        description: 'Serviço de limpeza',
        icon: '🧹',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(hours: 5))),
    TransactionModel(
        id: '3',
        userId: 'u',
        type: 'credit',
        amount: 50,
        description: 'Bônus indicação',
        icon: '🎁',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(days: 1))),
    TransactionModel(
        id: '4',
        userId: 'u',
        type: 'debit',
        amount: 80,
        description: 'Serviço elétrico',
        icon: '⚡',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(days: 2))),
    TransactionModel(
        id: '5',
        userId: 'u',
        type: 'debit',
        amount: 87.40,
        description: 'Mercado Carajás 360',
        icon: '🛒',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];
}
