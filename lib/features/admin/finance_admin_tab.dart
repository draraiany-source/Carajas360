import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/security/order_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../checkout/payments_api.dart';
import '../provider/money_parse.dart';
import 'admin_paging.dart';

/// Painel financeiro (admin master/financeiro). Leitura protegida pelas
/// regras (isFinanceAdmin); alterações passam por Cloud Functions que
/// validam limites e registram auditoria.
class FinanceAdminTab extends StatefulWidget {
  const FinanceAdminTab({super.key});
  @override
  State<FinanceAdminTab> createState() => _FinanceAdminTabState();
}

class _FinanceAdminTabState extends State<FinanceAdminTab> {
  // Listas paginadas por cursor (50 por página, "Carregar mais"); criadas
  // uma vez e descartadas no dispose.
  static Query<Map<String, dynamic>> _q(String col) => FirebaseFirestore.instance
      .collection(col)
      .orderBy(col == 'paymentAttempts' ? 'updatedAt' : 'createdAt', descending: true);
  final _orders = pagedQuery(() => _q('marketOrders'))..loadMore();
  final _attempts = pagedQuery(() => _q('paymentAttempts'))..loadMore();
  final _refunds = pagedQuery(() => _q('refunds'))..loadMore();
  final _issues = pagedQuery(() => _q('financialIssues'))..loadMore();

  @override
  void dispose() {
    for (final c in [_orders, _attempts, _refunds, _issues]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 6,
      child: Column(children: [
        const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Configuração'),
          Tab(text: 'Pedidos'),
          Tab(text: 'Tentativas'),
          Tab(text: 'Reembolsos'),
          Tab(text: 'Divergências'),
          Tab(text: 'Conciliação'),
        ]),
        Expanded(
            child: TabBarView(children: [
          const _ConfigPane(),
          _list(_orders, (d) {
            final o = MarketOrder.fromMap(d.id, d.data());
            return ListTile(
              dense: true,
              title: Text('${o.storeName} — ${brl(o.totalCents)}'),
              subtitle: Text(
                  '${o.id}\n${orderStatusLabel[o.status] ?? o.status} · ${paymentStatusLabel[o.paymentStatus] ?? o.paymentStatus}'
                  '${o.refundedCents > 0 ? ' · reembolsado ${brl(o.refundedCents)}' : ''}'),
              isThreeLine: true,
              trailing: o.isPaid
                  ? _RefundButton(order: o, onDone: () {
                      _orders.refresh();
                      _refunds.refresh();
                    })
                  : null,
            );
          }),
          _list(_attempts, (d) {
            final a = d.data();
            return ListTile(
                dense: true,
                title: Text('${a['method']} · ${brl((a['amountCents'] as num?)?.toInt() ?? 0)} · ${a['status']}'),
                subtitle: Text('${d.id} → ${a['targetKind']}/${a['targetId']}\n${a['statusDetail'] ?? ''}${a['divergent'] == true ? ' ⚠️ divergente' : ''}'),
                isThreeLine: true);
          }),
          _list(_refunds, (d) {
            final r = d.data();
            return ListTile(
                dense: true,
                title: Text('${brl((r['amountCents'] as num?)?.toInt() ?? 0)} · ${r['status']}'),
                subtitle: Text('${r['targetId']} · ${r['reason'] ?? ''}'));
          }),
          _list(_issues, (d) {
            final r = d.data();
            return ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                title: Text('${r['type']} · ${r['status']}'),
                subtitle: Text('${r['detail'] ?? ''}\n${r['targetId'] ?? r['attemptId'] ?? r['userId'] ?? ''}'),
                isThreeLine: true);
          }),
          const _ReconcilePane(),
        ])),
      ]));

  static Widget _list(PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> c,
          Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) row) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: c,
          padding: EdgeInsets.zero,
          empty: const Center(child: Text('Nada por aqui.')),
          itemBuilder: (_, d) => row(d));
}

class _RefundButton extends StatelessWidget {
  final MarketOrder order;
  final VoidCallback? onDone;
  const _RefundButton({required this.order, this.onDone});

  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'Reembolsar',
      icon: const Icon(Icons.undo_rounded),
      onPressed: () async {
        final ctrl = TextEditingController(
            text: ((order.totalCents - order.refundedCents - order.refundPendingCents) / 100)
                .toStringAsFixed(2));
        final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
                  title: const Text('Reembolso'),
                  content: TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: 'R\$ ', helperText: 'Parcial ou total')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Voltar')),
                    ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Solicitar')),
                  ],
                ));
        // Aceita "1.500,00" (formato BR).
        final cents = ((parseBrlAmount(ctrl.text) ?? 0) * 100).round();
        ctrl.dispose();
        if (ok != true || !context.mounted) return;
        if (cents <= 0) {
          snack(context, 'Informe um valor válido (ex.: 150,00)', bg: AppColors.error);
          return;
        }
        try {
          await CloudFn.call('refundMarketOrder',
              {'orderId': order.id, 'amountCents': cents, 'reason': 'Reembolso administrativo'});
          if (context.mounted) {
            snack(context, 'Reembolso solicitado — aguardando confirmação do gateway', bg: AppColors.secondary);
          }
          onDone?.call();
        } on CloudCallException catch (e) {
          if (context.mounted) snack(context, e.message, bg: AppColors.error);
        }
      });
}

/// Comissão, cashback e limites — fonte única no servidor (versionada).
class _ConfigPane extends StatefulWidget {
  const _ConfigPane();
  @override
  State<_ConfigPane> createState() => _ConfigPaneState();
}

class _ConfigPaneState extends State<_ConfigPane> {
  final _commission = TextEditingController();
  final _cashback = TextEditingController();
  final _maxInst = TextEditingController();
  final _reservation = TextEditingController();
  bool _loaded = false, _saving = false;
  // Assinado uma vez (não a cada rebuild).
  final _config = FirebaseFirestore.instance.collection('config').doc('finance').snapshots();

  @override
  void dispose() {
    for (final c in [_commission, _cashback, _maxInst, _reservation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    int pct(TextEditingController c) =>
        ((double.tryParse(c.text.replaceAll(',', '.')) ?? -1) * 100).round();
    setState(() => _saving = true);
    try {
      final r = await CloudFn.call('updateFinanceConfig', {
        'commissionBps': pct(_commission),
        'cashbackBps': pct(_cashback),
        'maxInstallments': int.tryParse(_maxInst.text) ?? -1,
        'reservationMinutes': int.tryParse(_reservation.text) ?? -1,
      });
      if (mounted) snack(context, 'Configuração salva (versão ${r['version']}). Pedidos anteriores mantêm as condições originais.', bg: AppColors.secondary);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _config,
      builder: (_, s) {
        if (s.hasError) return QueryErrorView(error: s.error);
        final d = s.data?.data() ?? const {};
        if (s.hasData && !_loaded) {
          _loaded = true;
          _commission.text = (((d['commissionBps'] as num?) ?? 1500) / 100).toStringAsFixed(2);
          _cashback.text = (((d['cashbackBps'] as num?) ?? 200) / 100).toStringAsFixed(2);
          _maxInst.text = '${d['maxInstallments'] ?? 12}';
          _reservation.text = '${d['reservationMinutes'] ?? 30}';
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('Versão atual: ${d['version'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
              'Comissão: incide sobre mercadorias menos desconto (o frete é integral da loja). '
              'É gravada no pedido na criação e reconhecida na entrega, quando o líquido vira saldo interno da loja. '
              'Reembolsos ajustam comissão, repasse e cashback proporcionalmente. '
              'Não há split bancário nem saque integrados.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(height: 12),
          TextField(controller: _commission, decoration: const InputDecoration(labelText: 'Comissão (%) — 0 a 30', suffixText: '%')),
          TextField(controller: _cashback, decoration: const InputDecoration(labelText: 'Cashback (%) — 0 a 10', suffixText: '%')),
          TextField(controller: _maxInst, decoration: const InputDecoration(labelText: 'Máximo de parcelas (1 a 12)')),
          TextField(controller: _reservation, decoration: const InputDecoration(labelText: 'Reserva de estoque (30 a 120 min)')),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _saving ? null : _save, child: const Text('Salvar nova versão')),
        ]);
      });
}

class _ReconcilePane extends StatefulWidget {
  const _ReconcilePane();
  @override
  State<_ReconcilePane> createState() => _ReconcilePaneState();
}

class _ReconcilePaneState extends State<_ReconcilePane> {
  final _uid = TextEditingController();
  String? _out;
  bool _busy = false;
  final _runs = FirebaseFirestore.instance.collection('reconciliationRuns').orderBy('at', descending: true).limit(20).snapshots();

  @override
  void dispose() {
    _uid.dispose();
    super.dispose();
  }

  Future<void> _run(String fn, Map<String, dynamic> body) async {
    setState(() => _busy = true);
    try {
      final r = await CloudFn.call(fn, body);
      setState(() => _out = r.toString());
    } on CloudCallException catch (e) {
      setState(() => _out = 'Erro: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Rotina de manutenção (também roda a cada 10 min): expira reservas, concilia cobranças pendentes/incertas e reenvia reembolsos.',
            style: TextStyle(fontSize: 12)),
        ElevatedButton(
            onPressed: _busy ? null : () => _run('runPaymentsMaintenance', {}),
            child: const Text('Executar conciliação agora')),
        const Divider(height: 32),
        TextField(controller: _uid, decoration: const InputDecoration(labelText: 'Usuário (uid) — saldo × razão')),
        ElevatedButton(
            onPressed: _busy ? null : () => _run('walletReconcile', {'userId': _uid.text.trim()}),
            child: const Text('Conciliar carteira')),
        if (_out != null) Padding(padding: const EdgeInsets.only(top: 12), child: SelectableText(_out!)),
        const Divider(height: 32),
        const Text('Execuções recentes', style: TextStyle(fontWeight: FontWeight.w700)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _runs,
            builder: (_, s) {
              if (s.hasError) return QueryErrorView(error: s.error);
              return Column(children: [
                for (final d in s.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[])
                  ListTile(dense: true, title: Text(d.data().entries.where((e) => e.key != 'at').map((e) => '${e.key}: ${e.value}').join(' · '))),
              ]);
            }),
      ]);
}
