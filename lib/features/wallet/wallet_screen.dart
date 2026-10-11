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
    _tab = TabController(length: 3, vsync: this);
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
              controller: _tab, children: [_extract(), _pixTab(), _plans()]),
        ),
      );

  Widget _header() => GradHeader(
      gradient: AppGradients.primary,
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('👜 Minha Carteira',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 22)),
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
            tabs: const [
              Tab(text: 'Extrato'),
              Tab(text: 'Recarga'),
              Tab(text: 'Planos')
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
            padding: const EdgeInsets.all(16),
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

  Widget _pixTab() => ListView(padding: const EdgeInsets.all(16), children: [
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

  Widget _plans() => StreamBuilder<UserModel?>(
        stream: _uid.isNotEmpty ? FS.userStream(_uid) : const Stream.empty(),
        builder: (_, snap) {
          final currentPlan = snap.data?.plan ?? PlanTier.free;
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Escolha seu plano',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Desbloqueie mais benefícios',
                style: TextStyle(fontSize: 13, color: AppColors.textLight)),
            const SizedBox(height: 20),
            for (final p in _plansData)
              _planCard(p, isCurrent: p['tier'] == currentPlan),
          ]);
        },
      );

  Widget _planCard(Map<String, dynamic> p, {required bool isCurrent}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: AppDecorations.gradient(p['grad'] as Gradient, r: 20),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(p['name'] as String,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            if (isCurrent)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('✓ Ativo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)))
            else if (p['badge'] != null)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(p['badge'] as String,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 4),
          Text(p['price'] as String,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22)),
          const SizedBox(height: 12),
          for (final f in (p['features'] as List<String>))
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 8),
                  Text(f,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.9), fontSize: 13))
                ])),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrent ? null : () => _subscribe(context, p),
                style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.white.withOpacity(isCurrent ? 0.1 : 0.25),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(isCurrent ? 'Plano atual' : 'Assinar ${p['name']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              )),
        ]),
      );

  /// Assinaturas não têm cobrança integrada nesta fase: nenhum fluxo de
  /// pagamento é oferecido (evita cobrar sem efeito no plano).
  void _subscribe(BuildContext context, Map<String, dynamic> plan) => snack(
      context,
      'Assinatura do plano ${plan['name']} ainda não está disponível para contratação no app.',
      bg: AppColors.warning);

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
        description: 'MercadoConecta',
        icon: '🛒',
        status: 'done',
        createdAt: DateTime.now().subtract(const Duration(days: 3))),
  ];

  static final _plansData = [
    {
      'name': 'Básico',
      'price': 'Grátis',
      'priceValue': 0.0,
      'tier': PlanTier.free,
      'grad': AppGradients.dark,
      'badge': null,
      'features': ['1 solicitação por semana', 'Suporte por chat']
    },
    {
      'name': 'Profissional',
      'price': 'R\$ 49,90/mês',
      'priceValue': 49.90,
      'tier': PlanTier.professional,
      'grad': AppGradients.primary,
      'badge': '⭐ Popular',
      'features': [
        'Serviços ilimitados',
        'Destaque na busca',
        'Suporte prioritário',
        'Cupons exclusivos'
      ]
    },
    {
      'name': 'Premium',
      'price': 'R\$ 99,90/mês',
      'priceValue': 99.90,
      'tier': PlanTier.premium,
      'grad': AppGradients.gold,
      'badge': '💎 Melhor',
      'features': [
        'Tudo ilimitado',
        'IA Assistente',
        'Saúde incluída',
        'Aluguel com desconto',
        'Gerente dedicado'
      ]
    },
  ];
}
