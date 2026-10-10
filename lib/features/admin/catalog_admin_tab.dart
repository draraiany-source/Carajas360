import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_admin.dart';
import '../../core/catalog/catalog_selection.dart';
import '../../core/catalog/catalog_text.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';

/// Gestão do catálogo (categorias → grupos → serviços). Toda alteração
/// passa pelas Cloud Functions (validação + auditoria) e chega às telas
/// em tempo real, sem nova versão do app. Não existe exclusão: itens são
/// desativados para preservar históricos.
class CatalogAdminTab extends StatefulWidget {
  const CatalogAdminTab({super.key});
  @override
  State<CatalogAdminTab> createState() => _CatalogAdminTabState();
}

class _CatalogAdminTabState extends State<CatalogAdminTab> {
  final _expanded = <String>{};
  bool _preview = false;
  bool _busy = false;

  Future<void> _run(Future<Object?> Function() op, String ok) async {
    setState(() => _busy = true);
    try {
      await op();
      if (mounted) snack(context, ok, bg: AppColors.secondary);
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CatalogBuilder(
        builder: (_, catalog) => Column(children: [
          _toolbar(catalog),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _preview ? _CatalogPreview(catalog: catalog) : _tree(catalog)),
        ]),
      );

  Widget _toolbar(Catalog c) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton.icon(
              onPressed: _busy ? null : () => _edit(c, level: CatalogLevel.category),
              icon: const Icon(Icons.add),
              label: const Text('Categoria')),
          OutlinedButton.icon(
              onPressed: _busy ? null : _migration,
              icon: const Icon(Icons.move_down_rounded),
              label: const Text('Migração v1')),
          FilterChip(
              label: const Text('Prévia do cliente'),
              selected: _preview,
              onSelected: (v) => setState(() => _preview = v)),
          Text('${c.length} itens', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ]),
      );

  Widget _tree(Catalog c) {
    final roots = c.children(null, activeOnly: false);
    if (roots.isEmpty) {
      return const EmptyState(
          emoji: '🗂️',
          title: 'Catálogo vazio',
          subtitle: 'Execute a migração v1 (simulação primeiro) para importar o catálogo atual.');
    }
    final rows = <Widget>[];
    void add(CatalogNode n, int depth, List<CatalogNode> siblings) {
      rows.add(_row(c, n, depth, siblings));
      if (_expanded.contains(n.id)) {
        final kids = c.children(n.id, activeOnly: false);
        for (final k in kids) {
          add(k, depth + 1, kids);
        }
        if (n.level != CatalogLevel.service) {
          rows.add(Padding(
            padding: EdgeInsets.only(left: 16.0 + (depth + 1) * 20, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _edit(c,
                        level: n.level == CatalogLevel.category
                            ? CatalogLevel.group
                            : CatalogLevel.service,
                        parent: n),
                icon: const Icon(Icons.add, size: 16),
                label: Text(n.level == CatalogLevel.category ? 'Novo grupo' : 'Novo serviço'),
              ),
            ),
          ));
        }
      }
    }

    for (final r in roots) {
      add(r, 0, roots);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 80), children: rows);
  }

  Widget _row(Catalog c, CatalogNode n, int depth, List<CatalogNode> siblings) {
    final effective = c.isActive(n.id);
    final idx = siblings.indexWhere((s) => s.id == n.id);
    final hasKids = n.level != CatalogLevel.service;
    return Container(
      margin: EdgeInsets.fromLTRB(8.0 + depth * 20, 2, 8, 2),
      decoration: AppDecorations.card(r: 12),
      child: ListTile(
        dense: true,
        onTap: hasKids
            ? () => setState(() => _expanded.contains(n.id) ? _expanded.remove(n.id) : _expanded.add(n.id))
            : null,
        leading: Text(n.icon, style: TextStyle(fontSize: 20, color: effective ? null : Colors.grey)),
        title: Text(n.name,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: effective ? null : TextDecoration.lineThrough,
                color: effective ? null : AppColors.textLight)),
        subtitle: Text(
            '${n.levelLabel} · ${n.id}${n.level == CatalogLevel.category ? ' · ${n.vertical.name}' : ''}'
            '${!n.active ? ' · desativado' : (!effective ? ' · inativo pelo nível superior' : '')}'
            '${n.questionnaireVersion != null ? ' · questionário v${n.questionnaireVersion}' : ''}',
            style: const TextStyle(fontSize: 11)),
        trailing: Wrap(spacing: 0, children: [
          IconButton(
              tooltip: 'Subir',
              icon: const Icon(Icons.arrow_upward, size: 18),
              onPressed: _busy || idx <= 0 ? null : () => _move(n, siblings, -1)),
          IconButton(
              tooltip: 'Descer',
              icon: const Icon(Icons.arrow_downward, size: 18),
              onPressed: _busy || idx >= siblings.length - 1 ? null : () => _move(n, siblings, 1)),
          if (n.level != CatalogLevel.category)
            IconButton(
                tooltip: 'Questionário',
                icon: const Icon(Icons.quiz_outlined, size: 18),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => QuestionnaireAdminScreen(node: n)))),
          IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              onPressed: _busy ? null : () => _edit(c, node: n)),
          Switch(
              value: n.active,
              onChanged: _busy ? null : (v) => _toggle(c, n, v)),
        ]),
      ),
    );
  }

  Future<void> _move(CatalogNode n, List<CatalogNode> siblings, int delta) async {
    final ids = siblings.map((s) => s.id).toList();
    final i = ids.indexOf(n.id);
    ids
      ..removeAt(i)
      ..insert(i + delta, n.id);
    await _run(() => CatalogAdmin.reorder(n.parentId, ids), 'Ordem atualizada');
  }

  Future<void> _toggle(Catalog c, CatalogNode n, bool active) async {
    if (!active) {
      final count = c.subtreeIds(n.id, activeOnly: false).length;
      final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('Desativar "${n.name}"?'),
                content: Text(
                    'Isso impede novas seleções e contratações em $count item(ns). '
                    'Pedidos, perfis e históricos existentes são preservados.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Desativar')),
                ],
              ));
      if (ok != true) return;
    }
    await _run(() => CatalogAdmin.setActive(n.id, active), active ? 'Ativado' : 'Desativado');
  }

  Future<void> _migration() async {
    setState(() => _busy = true);
    Map<String, dynamic>? dry;
    try {
      dry = await CatalogAdmin.migrate(dryRun: true);
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (dry == null || !mounted) return;
    final run = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Migração do catálogo v1 — simulação'),
              content: SingleChildScrollView(
                  child: SelectableText(const JsonEncoder.withIndent('  ').convert({
                'criar': dry!['toCreate'],
                'semAlteração': dry['unchanged'],
                'conflitos': dry['conflicts'],
                'referênciasDesconhecidas': dry['unknownReferences'],
                'categoriasLegadasAdmin': dry['legacyAdminCategories'],
                'documentosVerificados': dry['scanned'],
              }), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Fechar')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Executar (sem exclusões)')),
              ],
            ));
    if (run == true) {
      await _run(() => CatalogAdmin.migrate(dryRun: false), 'Migração concluída');
    }
  }

  Future<void> _edit(Catalog c, {CatalogNode? node, CatalogLevel? level, CatalogNode? parent}) async {
    final res = await showModalBottomSheet<CatalogNode>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _NodeEditor(catalog: c, node: node, level: level ?? node!.level, parent: parent));
    if (res == null) return;
    await _run(() => CatalogAdmin.upsert(res, isNew: node == null),
        node == null ? 'Item criado' : 'Item atualizado');
  }
}

class _NodeEditor extends StatefulWidget {
  final Catalog catalog;
  final CatalogNode? node;
  final CatalogLevel level;
  final CatalogNode? parent;
  const _NodeEditor({required this.catalog, required this.node, required this.level, this.parent});
  @override
  State<_NodeEditor> createState() => _NodeEditorState();
}

class _NodeEditorState extends State<_NodeEditor> {
  late final _name = TextEditingController(text: widget.node?.name);
  late final _id = TextEditingController(text: widget.node?.id);
  late final _desc = TextEditingController(text: widget.node?.description);
  late final _icon = TextEditingController(text: widget.node?.icon ?? '🔧');
  late final _keywords = TextEditingController(text: widget.node?.keywords.join(', '));
  late final _synonyms = TextEditingController(text: widget.node?.synonyms.join(', '));
  late Set<String> _modalities = {...?widget.node?.modalities};
  late CommercialModel _commercial = widget.node?.commercialModel ?? CommercialModel.quote;
  late CatalogVertical _vertical = widget.node?.vertical ?? CatalogVertical.services;
  bool _idTouched = false;

  bool get _isNew => widget.node == null;

  String get _prefix => switch (widget.level) {
        CatalogLevel.category => 'cat_',
        CatalogLevel.group => 'grp_',
        CatalogLevel.service => 'svc_',
      };

  List<String> _list(TextEditingController c) =>
      c.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final parentName = widget.parent?.name ?? widget.catalog.byId(widget.node?.parentId)?.name;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          Text('${_isNew ? 'Novo' : 'Editar'} ${widget.level == CatalogLevel.category ? 'categoria' : widget.level == CatalogLevel.group ? 'grupo' : 'serviço'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (parentName != null)
            Text('Em: $parentName', style: const TextStyle(color: AppColors.textLight)),
          const SizedBox(height: 12),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nome *', border: OutlineInputBorder()),
              onChanged: (v) {
                if (_isNew && !_idTouched) {
                  _id.text = '$_prefix${CatalogText.normalize(v).replaceAll(' ', '_')}';
                }
              }),
          const SizedBox(height: 10),
          TextField(
              controller: _id,
              enabled: _isNew,
              onChanged: (_) => _idTouched = true,
              decoration: const InputDecoration(
                  labelText: 'ID estável *',
                  helperText: 'Não muda depois de criado (usado em perfis e pedidos)',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
                width: 90,
                child: TextField(
                    controller: _icon,
                    decoration: const InputDecoration(labelText: 'Ícone', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            if (widget.level == CatalogLevel.category)
              Expanded(
                child: DropdownButtonFormField<CatalogVertical>(
                  initialValue: _vertical,
                  decoration: const InputDecoration(labelText: 'Vertical', border: OutlineInputBorder()),
                  items: [
                    for (final v in CatalogVertical.values)
                      DropdownMenuItem(value: v, child: Text(_verticalLabel(v))),
                  ],
                  onChanged: (v) => setState(() => _vertical = v ?? _vertical),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: _desc,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
          TextField(
              controller: _synonyms,
              decoration: const InputDecoration(
                  labelText: 'Sinônimos (separados por vírgula)',
                  helperText: 'Ex.: faxina, limpeza',
                  border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: _keywords,
              decoration: const InputDecoration(
                  labelText: 'Palavras-chave (separadas por vírgula)', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          const Text('Modalidades permitidas', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 6, children: [
            for (final m in const {'presential': 'Presencial', 'online': 'Online', 'home_care': 'Domiciliar'}.entries)
              FilterChip(
                  label: Text(m.value),
                  selected: _modalities.contains(m.key),
                  onSelected: (on) => setState(() => on ? _modalities.add(m.key) : _modalities.remove(m.key))),
          ]),
          const SizedBox(height: 12),
          const Text('Modalidade comercial', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          SegmentedButton<CommercialModel>(
            segments: const [
              ButtonSegment(value: CommercialModel.quote, label: Text('Orçamento')),
              ButtonSegment(value: CommercialModel.fixed, label: Text('Preço fixo')),
              ButtonSegment(value: CommercialModel.both, label: Text('Ambos')),
            ],
            selected: {_commercial},
            onSelectionChanged: (s) => setState(() => _commercial = s.first),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_name.text.trim().length < 2 || _id.text.trim().isEmpty) {
                  snack(context, 'Nome e ID são obrigatórios', bg: AppColors.error);
                  return;
                }
                final base = widget.node;
                Navigator.pop(
                    context,
                    CatalogNode(
                      id: _id.text.trim(),
                      level: widget.level,
                      name: _name.text.trim(),
                      description: _desc.text.trim(),
                      parentId: base?.parentId ?? widget.parent?.id,
                      icon: _icon.text.trim().isEmpty ? '🔧' : _icon.text.trim(),
                      color: base?.color,
                      order: base?.order ??
                          (widget.catalog.children(widget.parent?.id, activeOnly: false).length + 1) * 10,
                      active: base?.active ?? true,
                      vertical: _vertical,
                      keywords: _list(_keywords),
                      synonyms: _list(_synonyms),
                      modalities: _modalities.toList(),
                      commercialModel: _commercial,
                    ));
              },
              child: const Text('Salvar'),
            ),
          ),
        ]),
      ),
    );
  }

  static String _verticalLabel(CatalogVertical v) => switch (v) {
        CatalogVertical.services => 'Serviços',
        CatalogVertical.health => 'Saúde',
        CatalogVertical.market => 'Mercado',
        CatalogVertical.rental => 'Locação',
        CatalogVertical.delivery => 'Entregas',
      };
}

/// Prévia do que o cliente vê (somente itens ativos) + teste de busca.
class _CatalogPreview extends StatefulWidget {
  final Catalog catalog;
  const _CatalogPreview({required this.catalog});
  @override
  State<_CatalogPreview> createState() => _CatalogPreviewState();
}

class _CatalogPreviewState extends State<_CatalogPreview> {
  CatalogSelection _sel = CatalogSelection.none;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = widget.catalog;
    final matches = c.search(_q, limit: 8);
    return ListView(children: [
      const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Como o cliente vê (apenas itens ativos)',
              style: TextStyle(fontWeight: FontWeight.w700))),
      CatalogChipSelector(catalog: c, selection: _sel.sanitize(c), onChanged: (s) => setState(() => _sel = s)),
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
            decoration: const InputDecoration(
                labelText: 'Testar busca (acentos e sinônimos)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (v) => setState(() => _q = v)),
      ),
      for (final m in matches)
        ListTile(
          dense: true,
          leading: Text(m.node.icon),
          title: Text(m.node.name),
          subtitle: Text(c.pathOf(m.node.id).map((n) => n.name).join(' › ')),
          trailing: Text(m.node.levelLabel),
        ),
    ]);
  }
}

/// Questionários versionados de um grupo/serviço. Nesta fase: estrutura e
/// gestão. A aplicação nas solicitações acontece na fase do Resolve.
class QuestionnaireAdminScreen extends StatelessWidget {
  final CatalogNode node;
  const QuestionnaireAdminScreen({super.key, required this.node});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Questionário · ${node.name}')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => QuestionnaireEditorScreen(serviceId: node.id))),
            icon: const Icon(Icons.add),
            label: const Text('Novo rascunho')),
        body: Column(children: [
          const InfoBanner(
              icon: 'ℹ️',
              text: 'Estrutura preparada. Os questionários ainda NÃO são exibidos aos clientes; '
                  'a aplicação nas solicitações será feita na fase do Resolve.',
              bg: Color(0xFFE3F0FF),
              fg: AppColors.primary),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: CatalogAdmin.questionnaires(node.id),
              builder: (_, snap) {
                if (snap.hasError) return QueryErrorView(error: snap.error);
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final list = snap.data!;
                if (list.isEmpty) {
                  return const EmptyState(
                      emoji: '📝', title: 'Nenhum questionário', subtitle: 'Crie um rascunho para começar.');
                }
                return ListView(children: [
                  for (final q in list)
                    ListTile(
                      title: Text((q['title'] ?? '') as String),
                      subtitle: Text(
                          '${q['status']}${q['version'] != null ? ' · v${q['version']}' : ''} · ${(q['questions'] as List?)?.length ?? 0} pergunta(s)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => QuestionnaireEditorScreen(serviceId: node.id, existing: q))),
                    ),
                ]);
              },
            ),
          ),
        ]),
      );
}

class QuestionnaireEditorScreen extends StatefulWidget {
  final String serviceId;
  final Map<String, dynamic>? existing;
  const QuestionnaireEditorScreen({super.key, required this.serviceId, this.existing});
  @override
  State<QuestionnaireEditorScreen> createState() => _QuestionnaireEditorState();
}

class _QuestionnaireEditorState extends State<QuestionnaireEditorScreen> {
  late final _title = TextEditingController(text: widget.existing?['title'] as String?);
  late final List<Map<String, dynamic>> _questions = [
    for (final q in (widget.existing?['questions'] as List? ?? const [])) Map<String, dynamic>.from(q as Map)
  ];
  bool _saving = false;

  bool get _readOnlyPublished => widget.existing != null && widget.existing!['status'] != 'draft';

  static const _types = {
    'text': 'Texto curto',
    'long_text': 'Texto longo',
    'number': 'Número',
    'single_choice': 'Escolha única',
    'multi_choice': 'Múltipla escolha',
    'boolean': 'Sim/Não',
    'date': 'Data',
    'attachment': 'Anexo',
  };

  Future<void> _save({required bool publish}) async {
    setState(() => _saving = true);
    try {
      final r = await CatalogAdmin.saveQuestionnaire({
        // Publicado é imutável: editar gera novo rascunho no servidor.
        if (widget.existing != null) 'id': widget.existing!['id'],
        'serviceId': widget.serviceId,
        'title': _title.text.trim(),
        'questions': _questions,
        'publish': publish,
      });
      if (!mounted) return;
      snack(context, publish ? 'Publicado como v${r['version']}' : 'Rascunho salvo', bg: AppColors.secondary);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) snack(context, '$e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editQuestion([int? index]) async {
    final q = index == null ? <String, dynamic>{} : Map<String, dynamic>.from(_questions[index]);
    final id = TextEditingController(text: q['id'] as String?);
    final label = TextEditingController(text: q['label'] as String?);
    final options = TextEditingController(text: (q['options'] as List?)?.join(', '));
    var type = (q['type'] as String?) ?? 'text';
    var required = q['required'] == true;
    final cond = q['showIf'] as Map?;
    String? condQ = cond?['questionId'] as String?;
    var condOp = (cond?['op'] as String?) ?? 'equals';
    final condValue = TextEditingController(text: cond?['value']?.toString());
    final earlier = _questions.take(index ?? _questions.length).toList();
    final res = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setD) => AlertDialog(
                  title: Text(index == null ? 'Nova pergunta' : 'Editar pergunta'),
                  content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(controller: id, decoration: const InputDecoration(labelText: 'ID (a-z, 0-9, _)')),
                      TextField(controller: label, decoration: const InputDecoration(labelText: 'Enunciado')),
                      DropdownButtonFormField<String>(
                        initialValue: type,
                        decoration: const InputDecoration(labelText: 'Tipo'),
                        items: [for (final t in _types.entries) DropdownMenuItem(value: t.key, child: Text(t.value))],
                        onChanged: (v) => setD(() => type = v ?? type),
                      ),
                      if (type == 'single_choice' || type == 'multi_choice')
                        TextField(
                            controller: options,
                            decoration: const InputDecoration(labelText: 'Opções (separadas por vírgula)')),
                      SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Obrigatória'),
                          value: required,
                          onChanged: (v) => setD(() => required = v)),
                      DropdownButtonFormField<String?>(
                        initialValue: condQ,
                        decoration: const InputDecoration(labelText: 'Mostrar somente se (pergunta anterior)'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Sempre mostrar')),
                          for (final e in earlier)
                            DropdownMenuItem<String?>(value: e['id'] as String, child: Text(e['label'] as String)),
                        ],
                        onChanged: (v) => setD(() => condQ = v),
                      ),
                      if (condQ != null) ...[
                        DropdownButtonFormField<String>(
                          initialValue: condOp,
                          decoration: const InputDecoration(labelText: 'Condição'),
                          items: const [
                            DropdownMenuItem(value: 'equals', child: Text('igual a')),
                            DropdownMenuItem(value: 'not_equals', child: Text('diferente de')),
                            DropdownMenuItem(value: 'answered', child: Text('foi respondida')),
                          ],
                          onChanged: (v) => setD(() => condOp = v ?? condOp),
                        ),
                        if (condOp != 'answered')
                          TextField(controller: condValue, decoration: const InputDecoration(labelText: 'Valor')),
                      ],
                    ]),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () {
                          final target = earlier.where((e) => e['id'] == condQ).firstOrNull;
                          Object? value = condValue.text.trim();
                          if (target?['type'] == 'boolean') value = condValue.text.trim().toLowerCase() == 'sim' || condValue.text.trim() == 'true';
                          Navigator.pop(ctx, {
                            'id': id.text.trim(),
                            'label': label.text.trim(),
                            'type': type,
                            'required': required,
                            'options': options.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                            'showIf': condQ == null ? null : {'questionId': condQ, 'op': condOp, 'value': condOp == 'answered' ? null : value},
                          });
                        },
                        child: const Text('OK')),
                  ],
                )));
    if (res == null) return;
    setState(() => index == null ? _questions.add(res) : _questions[index] = res);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Editor de questionário')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_readOnlyPublished)
            const InfoBanner(
                icon: '🔒',
                text: 'Versão publicada é imutável. Salvar cria um novo rascunho.',
                bg: Color(0xFFFFF4E5),
                fg: Color(0xFF8A5300)),
          TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          for (var i = 0; i < _questions.length; i++)
            Card(
              child: ListTile(
                title: Text('${i + 1}. ${_questions[i]['label']}'),
                subtitle: Text('${_types[_questions[i]['type']] ?? _questions[i]['type']}'
                    '${_questions[i]['required'] == true ? ' · obrigatória' : ''}'
                    '${_questions[i]['showIf'] != null ? ' · condicional' : ''}'),
                onTap: () => _editQuestion(i),
                trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _questions.removeAt(i))),
              ),
            ),
          TextButton.icon(onPressed: () => _editQuestion(), icon: const Icon(Icons.add), label: const Text('Adicionar pergunta')),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: _saving ? null : () => _save(publish: false), child: const Text('Salvar rascunho'))),
            const SizedBox(width: 10),
            Expanded(
                child: FilledButton(
                    onPressed: _saving ? null : () => _save(publish: true), child: const Text('Publicar versão'))),
          ]),
          const SizedBox(height: 8),
          const Text('A validação final (tipos, opções e condições só para perguntas anteriores) é feita no servidor.',
              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
        ]),
      );
}
