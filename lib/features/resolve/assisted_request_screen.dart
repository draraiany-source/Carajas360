import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/services/service_matching.dart';
import '../../core/utils/app_error.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Pedido de servico assistido: cliente descreve → rascunho editavel → confirma → publica.
class AssistedRequestScreen extends StatefulWidget {
  const AssistedRequestScreen({super.key});
  @override
  State<AssistedRequestScreen> createState() => _AssistedRequestState();
}

class _AssistedRequestState extends State<AssistedRequestScreen> {
  final _freeCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: RegionCities.defaultCity);
  final _neighborhoodCtrl = TextEditingController();
  String? _categoryId;
  String _urgency = 'Esta semana';
  bool _loading = false;
  bool _publishing = false;
  String? _source;
  List<String> _questions = const [];
  List<String> _missing = const [];
  List<MatchScore> _matches = const [];
  String? _idempotencyKey;

  List<Map<String, dynamic>> get _catalog {
    final out = <Map<String, dynamic>>[];
    for (final v in ServiceTaxonomy.verticals) {
      for (final g in v.groups) {
        for (final s in g.services.where((e) => e.active)) {
          out.add({
            'id': s.categoryId,
            'name': s.name,
            'groupId': g.id,
            'keywords': [
              s.name,
              s.categoryId,
              s.description,
              ...s.questions.map((q) => q.label),
            ].where((e) => e.trim().isNotEmpty).toList(),
          });
        }
      }
    }
    if (out.isEmpty) {
      for (final c in Categories.all) {
        out.add({'id': c.id, 'name': c.name, 'groupId': c.group, 'keywords': [c.name, c.id]});
      }
    }
    return out;
  }

  @override
  void dispose() {
    _freeCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _cityCtrl.dispose();
    _neighborhoodCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (AuthService.uid == null) {
      snack(context, 'Faca login para usar o assistente');
      Navigator.pushNamed(context, Routes.login,
          arguments: {'returnRoute': Routes.assistedRequest});
      return;
    }
    final text = _freeCtrl.text.trim();
    if (text.length < 8) {
      snack(context, 'Descreva com mais detalhes o que voce precisa', bg: AppColors.error);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await AiSvc.assistServiceRequest(
        freeText: text,
        city: _cityCtrl.text.trim(),
        urgency: _urgency,
        neighborhood: _neighborhoodCtrl.text.trim(),
        catalog: _catalog,
      );
      if (!mounted) return;
      if (res == null) {
        snack(context,
            'Assistente indisponivel. Voce ainda pode preencher o pedido manualmente.',
            bg: AppColors.warning);
        setState(() {
          _descCtrl.text = text;
          _titleCtrl.text = text.length > 60 ? '${text.substring(0, 57)}...' : text;
          _loading = false;
        });
        return;
      }
      final draft = Map<String, dynamic>.from(res['draft'] as Map? ?? {});
      _titleCtrl.text = '${draft['title'] ?? ''}';
      _descCtrl.text = '${draft['description'] ?? text}';
      _categoryId = draft['categoryId'] as String?;
      if ((draft['city'] as String?)?.isNotEmpty == true) {
        _cityCtrl.text = draft['city'] as String;
      }
      _questions = ((draft['clarifyingQuestions'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();
      _missing = ((draft['missingFields'] as List?) ?? const [])
          .map((e) => '$e')
          .toList();
      _source = res['source'] as String?;
      _idempotencyKey =
          'assist_${AuthService.uid}_${DateTime.now().millisecondsSinceEpoch}';
      await _refreshMatches();
      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        snack(context, AppError.userMessage(e, message: 'Falha ao analisar pedido.'),
            bg: AppColors.error);
      }
    }
  }

  Future<void> _refreshMatches() async {
    final cat = _categoryId;
    if (cat == null || cat.isEmpty) {
      setState(() => _matches = const []);
      return;
    }
    List<ProviderModel> pool = const [];
    if (HomologCatalog.enabled) {
      pool = HomologCatalog.providers(category: cat);
    } else {
      try {
        pool = await FS.providersStream(category: cat).first
            .timeout(const Duration(seconds: 8), onTimeout: () => <ProviderModel>[]);
      } catch (_) {
        pool = const [];
      }
    }
    final ranked = ServiceMatching.rank(
      candidates: pool,
      categoryId: cat,
      city: _cityCtrl.text.trim(),
    );
    if (mounted) setState(() => _matches = ranked.take(5).toList());
  }

  Future<void> _publish() async {
    if (AuthService.uid == null) return;
    if (_categoryId == null || _categoryId!.isEmpty) {
      snack(context, 'Selecione uma categoria valida', bg: AppColors.error);
      return;
    }
    if (_cityCtrl.text.trim().isEmpty || _descCtrl.text.trim().length < 20) {
      snack(context, 'Complete cidade e descricao antes de publicar', bg: AppColors.error);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Publicar pedido?'),
        content: const Text(
          'Revise o rascunho. A publicacao cria uma solicitacao real (ou homolog) '
          'para profissionais compativeis. Endereco completo e telefone nao serao expostos.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Editar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      final key = _idempotencyKey ??
          'assist_${AuthService.uid}_${DateTime.now().millisecondsSinceEpoch}';
      Map<String, dynamic>? published;
      try {
        published = await AiSvc.publishAssistedRequest(
          idempotencyKey: key,
          confirmed: true,
          draft: {
            'title': _titleCtrl.text.trim(),
            'description': _descCtrl.text.trim(),
            'categoryId': _categoryId,
            'city': _cityCtrl.text.trim(),
            'neighborhood': _neighborhoodCtrl.text.trim(),
            'urgency': _urgency,
          },
          catalog: _catalog,
        );
      } catch (e) {
        // Sem Functions deployadas / homolog: publica localmente sem duplicar via key em memoria.
        if (!HomologCatalog.enabled) rethrow;
        published = null;
      }
      String? id = published?['requestId'] as String?;
      if (id == null || id.isEmpty) {
        id = await FS.createResolveRequest(
          description: _descCtrl.text.trim(),
          category: _categoryId!,
          city: _cityCtrl.text.trim(),
          clientName: (await FS.getUser())?.name,
          urgency: _urgency,
        );
      }
      if (!mounted) return;
      snack(context, published?['already'] == true
          ? 'Pedido ja publicado (sem duplicar).'
          : 'Pedido publicado!', bg: AppColors.secondary);
      Navigator.pushReplacementNamed(context, Routes.resolveDetail,
          arguments: {'id': id});
    } catch (e) {
      if (mounted) {
        snack(context, AppError.userMessage(e, message: 'Nao foi possivel publicar.'),
            bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catName = _categoryId == null
        ? null
        : (ServiceTaxonomy.serviceByCategoryId(_categoryId!)?.name ??
            () {
              for (final c in Categories.all) {
                if (c.id == _categoryId) return c.name;
              }
              return null;
            }());
    return Scaffold(
      appBar: const CarajasAppBar(title: 'Pedido assistido'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Descreva o que voce precisa. O assistente sugere categoria e organiza o texto. '
            'Voce revisa e confirma antes de publicar. A IA nao inventa profissionais nem precos.',
            style: TextStyle(color: AppColors.textLight, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _freeCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'O que voce precisa?',
              border: OutlineInputBorder(),
              hintText: 'Ex.: preciso trocar disjuntor e instalar 4 tomadas na cozinha',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_loading ? 'Analisando...' : 'Organizar com assistente',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          if (_source != null) ...[
            const SizedBox(height: 8),
            Text('Fonte: $_source',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(labelText: 'Titulo (editavel)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Descricao (editavel)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Categoria sugerida', border: OutlineInputBorder()),
            child: Text(catName ?? (_categoryId ?? 'Nao definida — selecione abaixo')),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _categoryId != null &&
                    _catalog.any((c) => c['id'] == _categoryId)
                ? _categoryId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Confirmar categoria', border: OutlineInputBorder()),
            items: _catalog
                .take(80)
                .map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']}', overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) async {
              setState(() => _categoryId = v);
              await _refreshMatches();
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _cityCtrl,
            decoration: const InputDecoration(labelText: 'Cidade (aproximada)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _neighborhoodCtrl,
            decoration: const InputDecoration(
                labelText: 'Bairro (opcional — sem endereco completo)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _urgency,
            decoration: const InputDecoration(labelText: 'Prazo / urgencia', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'Hoje', child: Text('Hoje')),
              DropdownMenuItem(value: 'Esta semana', child: Text('Esta semana')),
              DropdownMenuItem(value: 'Flexivel', child: Text('Flexivel')),
              DropdownMenuItem(value: 'Emergencia', child: Text('Emergencia')),
            ],
            onChanged: (v) => setState(() => _urgency = v ?? _urgency),
          ),
          if (_questions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Perguntas sugeridas', style: TextStyle(fontWeight: FontWeight.w800)),
            ..._questions.map((q) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $q', style: const TextStyle(color: AppColors.textLight)),
                )),
          ],
          if (_missing.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Falta completar: ${_missing.join(', ')}',
                style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          if (_matches.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Prestadores compativeis (filtro real do catalogo)',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ..._matches.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.handyman_outlined),
                  title: Text(m.provider.name),
                  subtitle: Text(
                    '${m.provider.rating.toStringAsFixed(1)} · ${m.reasons.take(2).join(' · ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                )),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _publishing ? null : _publish,
              child: _publishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Revisar e publicar pedido',
                      style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}