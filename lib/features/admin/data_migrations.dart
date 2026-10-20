import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/order_policy.dart' show CloudCallException;
import '../../shared/services/firebase_service.dart' show CloudFn;
import '../../shared/widgets/widgets.dart';

/// Migrações de dados que acompanham as correções da auditoria 3. Rodam no
/// servidor (idempotentes: repetir não altera o que já foi corrigido) e
/// exigem perfil master/financeiro, conferido nas próprias callables.
class DataMigrationsCard extends StatefulWidget {
  const DataMigrationsCard({super.key});
  @override
  State<DataMigrationsCard> createState() => _DataMigrationsCardState();
}

class _DataMigrationsCardState extends State<DataMigrationsCard> {
  String? _running;
  final _results = <String, String>{};

  Future<void> _run(String key, String confirm,
      Future<String> Function() job) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Executar migração?'),
              content: Text(confirm),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancelar')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Executar')),
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => _running = key);
    try {
      final r = await job();
      if (mounted) setState(() => _results[key] = r);
    } on CloudCallException catch (e) {
      if (mounted) setState(() => _results[key] = 'Falhou: ${e.message}');
    } catch (_) {
      if (mounted) {
        setState(() => _results[key] = 'Falhou. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  Future<String> _market({required bool dryRun}) async {
    final r = await CloudFn.call('adminReconcileMarket', {'dryRun': dryRun});
    return '${dryRun ? 'Simulação' : 'Concluído'}: ${r['productsFixed'] ?? 0} '
        'de ${r['products'] ?? 0} produtos e ${r['countersFixed'] ?? 0} de '
        '${r['stores'] ?? 0} contadores de loja ${dryRun ? 'seriam corrigidos' : 'corrigidos'}.';
  }

  /// Anexos do chat: página a página até `done` (cada chamada ≤ 540 s).
  Future<String> _chatMedia() async {
    var migrated = 0, discarded = 0, missing = 0, errors = 0, pages = 0;
    String? cursor;
    do {
      final r = await CloudFn.call('adminMigrateChatMedia',
          {if (cursor != null) 'cursor': cursor, 'pageSize': 50});
      migrated += (r['migrated'] as num?)?.toInt() ?? 0;
      discarded += (r['discarded'] as num?)?.toInt() ?? 0;
      missing += (r['missing'] as num?)?.toInt() ?? 0;
      errors += (r['errors'] as num?)?.toInt() ?? 0;
      cursor = r['done'] == true ? null : r['nextCursor'] as String?;
      pages++;
    } while (cursor != null && pages < 200 && mounted);
    return 'Concluído: $migrated anexo(s) protegido(s), $discarded link(s) '
        'externo(s) descartado(s), $missing sem arquivo, $errors erro(s).'
        '${cursor != null ? ' Ainda há salas: execute de novo.' : ''}';
  }

  Future<String> _orderExpiry() async {
    final r = await CloudFn.call(
        'adminRunMaintenance', {'jobs': ['backfillOrderExpiry']});
    final b = (r['backfillOrderExpiry'] as Map?) ?? const {};
    if (b['error'] != null) return 'Falhou: ${b['error']}';
    return 'Concluído: ${b['updated'] ?? 0} de ${b['scanned'] ?? 0} pedidos '
        'pendentes receberam prazo.${b['done'] == false ? ' Execute de novo para continuar.' : ''}';
  }

  Widget _item(String key, String title, String subtitle,
      List<Widget> actions) {
    final busy = _running == key;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
        const SizedBox(height: 6),
        busy
            ? const LinearProgressIndicator()
            : Wrap(spacing: 8, children: actions),
        if (_results[key] != null)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_results[key]!,
                  key: Key('migration-result-$key'),
                  style: const TextStyle(fontSize: 12))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idle = _running == null;
    return Container(
      decoration: AppDecorations.card(r: 14),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SecHeader(title: 'Migrações de dados'),
        const Text(
            'Rode uma vez após publicar esta versão (pode repetir sem efeito colateral). Exige perfil master ou financeiro.',
            style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        const SizedBox(height: 12),
        _item('market', 'Mercado: lojas e contadores',
            'Oculta produtos de lojas desativadas/não aprovadas e recalcula o total de produtos.', [
          OutlinedButton(
              onPressed: idle
                  ? () => _run('market', 'Simular sem gravar nada?',
                      () => _market(dryRun: true))
                  : null,
              child: const Text('Simular')),
          ElevatedButton(
              onPressed: idle
                  ? () => _run(
                      'market',
                      'Aplicar a reconciliação do Mercado? Lojas não aprovadas deixam de aparecer na vitrine.',
                      () => _market(dryRun: false))
                  : null,
              child: const Text('Aplicar')),
        ]),
        _item('chat', 'Anexos do chat',
            'Troca links permanentes por acesso autenticado e revoga os links antigos.', [
          ElevatedButton(
              onPressed: idle
                  ? () => _run(
                      'chat',
                      'Migrar os anexos do chat? Os links antigos deixam de funcionar.',
                      _chatMedia)
                  : null,
              child: const Text('Migrar')),
        ]),
        _item('expiry', 'Prazo dos pedidos',
            'Grava o prazo de expiração (7 dias) nos pedidos pendentes antigos.', [
          ElevatedButton(
              onPressed: idle
                  ? () => _run('expiry', 'Preencher o prazo dos pedidos pendentes?',
                      _orderExpiry)
                  : null,
              child: const Text('Preencher')),
        ]),
      ]),
    );
  }
}
