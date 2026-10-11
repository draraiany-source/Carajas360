import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_env.dart';
import '../../core/constants/runtime_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import 'payments_api.dart';

/// Tokens do SIMULADOR de gateway (somente emulador/dev, nunca produção).
/// Ativado com --dart-define=PAYMENTS_FAKE_TOKENS=true.
abstract final class FakeCardTokens {
  static const _requested =
      bool.fromEnvironment('PAYMENTS_FAKE_TOKENS', defaultValue: false);
  static bool get enabled => _requested && !AppEnv.isProd;
  static const options = {
    'tok_approved': 'Aprovado',
    'tok_rejected': 'Recusado',
    'tok_pending': 'Em análise',
    'tok_challenge': 'Exige autenticação (3DS)',
  };
}

/// Tela de pagamento de um alvo persistido (pedido ou recarga).
/// O estado exibido vem SEMPRE de `paymentAttempts/{id}` no Firestore:
/// a interface nunca marca um pagamento como aprovado por conta própria.
class PaymentScreen extends StatefulWidget {
  final PayTarget target;
  final String method; // pix | card
  const PaymentScreen({super.key, required this.target, required this.method});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  // Mesmo requestId em repetições (clique duplo, nova tentativa após
  // timeout): o servidor devolve a mesma cobrança.
  String _requestId = newRequestId();
  String? _attemptId;
  bool _starting = false;
  String? _error;
  Timer? _refresh;
  Timer? _tick;
  StreamSubscription<PaymentAttempt?>? _sub;
  PaymentAttempt? _attempt;

  // Cartão
  final _form = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _expMonth = TextEditingController();
  final _expYear = TextEditingController();
  final _cvv = TextEditingController();
  final _doc = TextEditingController();
  int _installments = 1;
  String _fakeToken = 'tok_approved';

  bool get _isPix => widget.method == 'pix';

  @override
  void initState() {
    super.initState();
    if (_isPix) _start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _attempt?.pixExpiresAt != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _tick?.cancel();
    _sub?.cancel();
    for (final c in [_number, _holder, _expMonth, _expYear, _cvv, _doc]) {
      c.dispose();
    }
    super.dispose();
  }

  void _watch(String attemptId) {
    if (_attemptId == attemptId && _sub != null) return;
    _attemptId = attemptId;
    _sub?.cancel();
    _sub = PaymentsApi.attemptStream(attemptId).listen((a) {
      if (!mounted || a == null) return;
      setState(() => _attempt = a);
      if (!a.active) _refresh?.cancel();
    }, onError: (Object e) {
      if (mounted) setState(() => _error = 'Não foi possível acompanhar o pagamento: $e');
    });
    // Consulta periódica ao servidor (que confirma no gateway). O webhook
    // e a rotina agendada confirmam mesmo com o app fechado.
    _refresh?.cancel();
    _refresh = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_attempt != null && !_attempt!.active) return;
      try {
        await PaymentsApi.refresh(attemptId);
      } catch (_) {/* próxima rodada */}
    });
  }

  Future<void> _start({Map<String, dynamic>? card}) async {
    if (_starting) return;
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final a = await PaymentsApi.start(
          target: widget.target,
          method: widget.method,
          requestId: _requestId,
          card: card);
      if (!mounted || a == null) return;
      setState(() => _attempt = a);
      if (a.id.isNotEmpty) _watch(a.id);
    } on CloudCallException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      // Resposta perdida: repetir com o MESMO requestId é seguro.
      if (mounted) {
        setState(() => _error =
            'Sem resposta do servidor. Toque em "Tentar novamente" — não haverá cobrança duplicada.');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Nova cobrança (após recusa/expiração): novo requestId.
  void _newAttempt() {
    _sub?.cancel();
    _sub = null;
    _refresh?.cancel();
    setState(() {
      _requestId = newRequestId();
      _attemptId = null;
      _attempt = null;
    });
    if (_isPix) _start();
  }

  Future<void> _cancel() async {
    final id = _attemptId;
    if (id == null) return;
    try {
      await PaymentsApi.cancelAttempt(id);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    }
  }

  Future<void> _payCard() async {
    if (!FakeCardTokens.enabled && !_form.currentState!.validate()) return;
    setState(() => _error = null);
    String? token;
    if (FakeCardTokens.enabled) {
      token = _fakeToken;
    } else {
      setState(() => _starting = true);
      // Tokenização direto no gateway: número e CVV não passam pelo nosso
      // backend e nunca são gravados.
      token = await PaySvc.tokenizeCard(
        cardNumber: _number.text,
        holderName: _holder.text,
        expMonth: _expMonth.text,
        expYear: _expYear.text,
        cvv: _cvv.text,
        docNumber: _doc.text.replaceAll(RegExp(r'\D'), ''),
      );
      _cvv.clear();
      if (mounted) setState(() => _starting = false);
    }
    if (token == null) {
      setState(() => _error = RuntimeConfig.hasPlaceholderMercadoPago
          ? 'Pagamento com cartão indisponível neste ambiente (chave pública de teste não configurada).'
          : 'Não foi possível validar o cartão. Confira os dados.');
      return;
    }
    await _start(card: {
      'token': token,
      'installments': _installments,
      'docNumber': _doc.text.replaceAll(RegExp(r'\D'), ''),
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = _attempt;
    return Scaffold(
      appBar: AppBar(
          title: Text(_isPix ? '⚡ Pagamento Pix' : '💳 Pagamento com cartão'),
          backgroundColor: _isPix ? AppColors.pix : AppColors.primary,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          _summary(a),
          const SizedBox(height: 16),
          if (_error != null) _errorBox(_error!),
          if (a == null && _isPix && _starting)
            const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: AppColors.pix))
          else if (a == null && !_isPix)
            _cardForm()
          else if (a == null)
            OutlinedButton(onPressed: _start, child: const Text('Tentar novamente'))
          else
            _state(a),
        ]),
      ),
    );
  }

  Widget _summary(PaymentAttempt? a) => Container(
      width: double.infinity,
      decoration: AppDecorations.gradient(
          a?.approved == true
              ? AppGradients.secondary
              : (_isPix ? AppGradients.pix : AppGradients.primary),
          r: 20),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text(a == null ? 'Total a pagar' : (attemptStatusLabel[a.status] ?? a.status),
            key: const Key('payment-status'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 6),
        Text(brl(a?.amountCents ?? widget.target.amountCents),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
        Text(widget.target.description,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13)),
      ]));

  Widget _errorBox(String msg) => Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: const TextStyle(color: AppColors.error, fontSize: 12))),
      ]));

  Widget _state(PaymentAttempt a) {
    if (a.approved) {
      return Column(children: [
        const SizedBox(height: 24),
        const Text('🎉', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 12),
        const Text('Pagamento confirmado pelo banco',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.secondary)),
        const SizedBox(height: 24),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuar')),
      ]);
    }
    if (a.failed) {
      return Column(children: [
        const SizedBox(height: 12),
        Text(a.statusDetail ?? 'O pagamento não foi concluído.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _newAttempt, child: const Text('Tentar outra vez')),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Escolher outra forma de pagamento')),
      ]);
    }
    if (a.status == 'creating' || a.status == 'uncertain') {
      return Column(children: [
        const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        Text(a.status == 'uncertain'
            ? 'Estamos confirmando com o banco se a cobrança foi criada. Não pague de novo.'
            : 'Gerando cobrança…', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: _starting ? null : () => _start(),
            child: const Text('Tentar novamente')),
      ]);
    }
    if (a.status == 'challenge') {
      return Column(children: [
        const Text('Seu banco pediu uma confirmação de segurança (3DS).',
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        if (a.challengeUrl != null)
          ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Autenticar no banco'),
              onPressed: () => launchUrl(Uri.parse(a.challengeUrl!),
                  mode: LaunchMode.externalApplication)),
        const SizedBox(height: 8),
        const Text('Depois de autenticar, a confirmação aparece aqui automaticamente.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
            textAlign: TextAlign.center),
        TextButton(onPressed: _cancel, child: const Text('Cancelar cobrança')),
      ]);
    }
    // pending
    if (a.method == 'pix') return _pix(a);
    return Column(children: [
      const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      const Text('Pagamento em análise pelo emissor. Avisaremos quando houver resposta.',
          textAlign: TextAlign.center),
      TextButton(onPressed: _cancel, child: const Text('Cancelar cobrança')),
    ]);
  }

  Widget _pix(PaymentAttempt a) {
    final exp = a.pixExpiresAt;
    final left = exp == null ? null : exp.difference(DateTime.now());
    final code = a.pixCode;
    return Container(
        decoration: AppDecorations.card(r: 20),
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text('Escaneie com o app do seu banco',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          if (code != null)
            QrImageView(data: code, size: 200, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          if (left != null)
            Text(
                left.isNegative
                    ? 'Código vencido — aguardando confirmação final'
                    : 'Vence em ${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: (left.inMinutes < 2) ? AppColors.error : AppColors.textLight)),
          const SizedBox(height: 12),
          const Text('Pix copia e cola:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
                child: Text(code ?? '',
                    key: const Key('pix-code'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight))),
            IconButton(
                icon: const Icon(Icons.copy_rounded, color: AppColors.pix),
                onPressed: code == null
                    ? null
                    : () {
                        Clipboard.setData(ClipboardData(text: code));
                        snack(context, 'Código Pix copiado', bg: AppColors.secondary);
                      }),
          ]),
          const SizedBox(height: 8),
          const Text(
              'A confirmação chega pelo banco. Você pode fechar o app: o pedido é atualizado mesmo assim.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textLight)),
          TextButton(onPressed: _cancel, child: const Text('Cancelar cobrança')),
        ]));
  }

  Widget _cardForm() {
    final total = widget.target.amountCents;
    final options = [
      for (var n = 1; n <= 12; n++)
        if (n == 1 || total ~/ n >= 500) n
    ];
    return Form(
        key: _form,
        child: Column(children: [
          if (FakeCardTokens.enabled) ...[
            const Text('Ambiente de teste: cartão simulado (nenhuma cobrança real).',
                style: TextStyle(fontSize: 12, color: AppColors.warning)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const Key('fake-card'),
              value: _fakeToken,
              items: FakeCardTokens.options.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _fakeToken = v ?? 'tok_approved'),
            ),
          ] else ...[
            TextFormField(
                controller: _number,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'Número do cartão', prefixIcon: Icon(Icons.credit_card)),
                validator: (v) => (v?.replaceAll(' ', '').length ?? 0) < 13
                    ? 'Número inválido'
                    : null),
            const SizedBox(height: 10),
            TextFormField(
                controller: _holder,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    hintText: 'Nome impresso no cartão',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v!.trim().isEmpty ? 'Campo obrigatório' : null),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextFormField(
                      controller: _expMonth,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(hintText: 'MM', counterText: ''),
                      validator: (v) => (v?.length ?? 0) != 2 ? 'MM' : null)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: _expYear,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(hintText: 'AA', counterText: ''),
                      validator: (v) => (v?.length ?? 0) != 2 ? 'AA' : null)),
              const SizedBox(width: 8),
              Expanded(
                  child: TextFormField(
                      controller: _cvv,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      decoration: const InputDecoration(hintText: 'CVV', counterText: ''),
                      validator: (v) => (v?.length ?? 0) < 3 ? 'CVV' : null)),
            ]),
            const SizedBox(height: 10),
            TextFormField(
                controller: _doc,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    hintText: 'CPF do titular', prefixIcon: Icon(Icons.badge_outlined)),
                validator: (v) =>
                    (v?.replaceAll(RegExp(r'\D'), '').length ?? 0) < 11
                        ? 'CPF inválido'
                        : null),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: options.contains(_installments) ? _installments : 1,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.repeat_rounded)),
            items: options
                .map((n) => DropdownMenuItem(
                    value: n,
                    child: Text(n == 1
                        ? 'À vista — ${brl(total)}'
                        : '${n}x de ${brl(total ~/ n)}')))
                .toList(),
            onChanged: (v) => setState(() => _installments = v ?? 1),
          ),
          const SizedBox(height: 20),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('pay-card'),
                onPressed: _starting ? null : _payCard,
                child: _starting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Pagar ${brl(total)}'),
              )),
          const SizedBox(height: 8),
          const Text('Os dados do cartão vão direto para o processador; não são armazenados.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]));
  }
}
