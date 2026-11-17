import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/monetization/lead_unlock_service.dart';
import '../../core/monetization/monetization_config.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

class CreditPackagesScreen extends StatefulWidget {
  const CreditPackagesScreen({super.key});
  @override
  State<CreditPackagesScreen> createState() => _CreditPackagesScreenState();
}

class _CreditPackagesScreenState extends State<CreditPackagesScreen> {
  MonetizationConfig _cfg = MonetizationConfig.defaults();
  bool _busy = false;
  StreamSubscription? _cfgSub;

  @override
  void initState() {
    super.initState();
    _cfgSub = FS.platformConfigStream().listen((m) {
      if (mounted) setState(() => _cfg = MonetizationConfig.fromMap(m));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    super.dispose();
  }

  Future<void> _buy(CreditPackage pkg) async {
    if (!_cfg.creditsEnabled) {
      snack(context, 'Creditos desativados pelo Admin');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comprar creditos (Sandbox)'),
        content: Text(
          '${pkg.name}\n${pkg.totalCredits} creditos\n${pkg.price.formatted}\n\n'
          'Pagamento Sandbox — sem cobranca real. '
          'Creditos so sao liberados apos confirmacao do backend/webhook.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar Sandbox')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      if (HomologCatalog.enabled) {
        // Simula webhook confirmado UMA vez (idempotente por pacote+timestamp curto)
        final uid = AuthService.uid ?? 'homolog_pro';
        await LeadUnlockService.homologAddCredits(uid, pkg.totalCredits);
        if (!mounted) return;
        snack(context, 'Sandbox confirmado: +${pkg.totalCredits} creditos',
            bg: AppColors.secondary);
      } else {
        await CloudFn.call('purchaseCreditPackage', {
          'packageId': pkg.id,
          // preco NAO enviado — servidor valida
        });
        if (!mounted) return;
        snack(context, 'Pedido Sandbox criado. Aguarde confirmacao.',
            bg: AppColors.secondary);
      }
    } catch (e) {
      if (mounted) snack(context, 'Falha: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Comprar creditos'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              'Creditos liberam contatos de oportunidades. '
              'Nunca confie apenas no frontend — liberacao apos Sandbox/webhook.',
              style: TextStyle(color: Colors.white, height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          ..._cfg.creditPackages.map((p) => Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  title: Text(p.name,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${p.credits} creditos${p.bonusCredits > 0 ? ' + ${p.bonusCredits} bonus' : ''}'),
                  trailing: ElevatedButton(
                    onPressed: _busy ? null : () => _buy(p),
                    child: Text(p.price.formatted),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class CarajasProScreen extends StatefulWidget {
  const CarajasProScreen({super.key});
  @override
  State<CarajasProScreen> createState() => _CarajasProScreenState();
}

class _CarajasProScreenState extends State<CarajasProScreen> {
  MonetizationConfig _cfg = MonetizationConfig.defaults();
  String _status = 'NONE';
  StreamSubscription? _cfgSub;

  @override
  void initState() {
    super.initState();
    _cfgSub = FS.platformConfigStream().listen((m) {
      if (mounted) setState(() => _cfg = MonetizationConfig.fromMap(m));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    super.dispose();
  }

  Future<void> _subscribe() async {
    if (!_cfg.proEnabled) {
      snack(context, 'Carajas PRO desativado pelo Admin');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assinar Carajas PRO'),
        content: Text(
          'Valor: ${_cfg.proPriceMonthly.formatted}/mes (Admin).\n'
          'Pagamento Sandbox — sem cobranca real.\n'
          'Ativacao somente apos confirmacao do backend.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assinar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      if (HomologCatalog.enabled) {
        setState(() => _status = 'ACTIVE');
        snack(context, 'PRO ativado (homologacao Sandbox)',
            bg: AppColors.secondary);
      } else {
        await CloudFn.call('requestPlanChange', {
          'tier': 'professional',
          'sandbox': true,
        });
        if (!mounted) return;
        setState(() => _status = 'PENDING');
        snack(context, 'Assinatura Sandbox solicitada');
      }
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Falha: $e', bg: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Carajas PRO'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_cfg.proPriceMonthly.formatted + '/mes',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Status: $_status',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('Beneficios', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('• Mais destaque nas buscas\n'
              '• Creditos promocionais quando habilitado pelo Admin\n'
              '• Selo PRO no perfil\n'
              '• Suporte prioritario'),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _subscribe,
            child: const Text('ASSINAR (SANDBOX)',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => setState(() => _status = 'CANCELLED'),
            child: const Text('Cancelar assinatura (homolog)'),
          ),
        ],
      ),
    );
  }
}

class HighlightsBuyScreen extends StatefulWidget {
  const HighlightsBuyScreen({super.key});
  @override
  State<HighlightsBuyScreen> createState() => _HighlightsBuyScreenState();
}

class _HighlightsBuyScreenState extends State<HighlightsBuyScreen> {
  MonetizationConfig _cfg = MonetizationConfig.defaults();
  StreamSubscription? _cfgSub;

  @override
  void initState() {
    super.initState();
    _cfgSub = FS.platformConfigStream().listen((m) {
      if (mounted) setState(() => _cfg = MonetizationConfig.fromMap(m));
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _cfgSub?.cancel();
    super.dispose();
  }

  Future<void> _buy(HighlightPlan plan) async {
    if (!_cfg.sponsoredEnabled) {
      snack(context, 'Destaques desativados pelo Admin');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comprar destaque'),
        content: Text(
          '${plan.name}\n${plan.price.formatted}\n\n'
          'O perfil fica PATROCINADO pelo periodo. '
          'Nao altera avaliacoes. Sandbox apenas.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar Sandbox')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (HomologCatalog.enabled) {
      snack(context, 'Destaque ${plan.name} ativo (homolog). Selo PATROCINADO.',
          bg: AppColors.secondary);
    } else {
      try {
        await CloudFn.call('purchaseHighlight', {'planId': plan.id});
        if (!mounted) return;
        snack(context, 'Pedido Sandbox criado');
      } catch (e) {
        if (!mounted) return;
        snack(context, 'Falha: $e', bg: AppColors.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Destaques'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppTag('PATROCINADO', bg: Colors.amber, fg: Colors.black87),
          const SizedBox(height: 12),
          ..._cfg.highlightPlans.map((p) => ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${p.hours}h de destaque'),
                trailing: ElevatedButton(
                  onPressed: () => _buy(p),
                  child: Text(p.price.formatted),
                ),
              )),
        ],
      ),
    );
  }
}

class DisputeHelpScreen extends StatefulWidget {
  final String? orderId;
  final String? paymentId;
  const DisputeHelpScreen({super.key, this.orderId, this.paymentId});
  @override
  State<DisputeHelpScreen> createState() => _DisputeHelpScreenState();
}

class _DisputeHelpScreenState extends State<DisputeHelpScreen> {
  String? _reason;
  final _notes = TextEditingController();
  bool _sending = false;

  static const _reasons = [
    'Profissional nao apareceu',
    'Servico nao realizado',
    'Servico diferente do combinado',
    'Problema com pagamento',
    'Quero cancelar',
    'Outro',
  ];

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) {
      snack(context, 'Selecione o motivo');
      return;
    }
    setState(() => _sending = true);
    try {
      if (HomologCatalog.enabled) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        snack(context, 'Ticket criado (homolog) — analise administrativa',
            bg: AppColors.secondary);
        Navigator.pop(context);
      } else {
        await FS.createDisputeTicket(
          reason: _reason!,
          notes: _notes.text.trim(),
          orderId: widget.orderId,
          paymentId: widget.paymentId,
        );
        if (!mounted) return;
        snack(context, 'Ticket enviado para analise', bg: AppColors.secondary);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) snack(context, 'Falha: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Ajuda com este servico'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Selecione o motivo',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ..._reasons.map((r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
              )),
          TextField(
            controller: _notes,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Detalhes',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Abrir ticket',
                    style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
