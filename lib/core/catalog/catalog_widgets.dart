import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/widgets.dart';
import '../theme/app_colors.dart';
import 'catalog.dart';
import 'catalog_selection.dart';
import 'catalog_service.dart';

/// Constrói a UI a partir do catálogo compartilhado, com estados
/// explícitos: carregando, erro (tentar novamente), vazio (catálogo não
/// configurado), cache offline e "catálogo atualizado". Nunca usa lista
/// fictícia no lugar do servidor.
class CatalogBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, Catalog catalog) builder;
  final ValueListenable<CatalogState>? source;
  final VoidCallback? onRetry;

  /// Mostra a faixa "catálogo salvo no aparelho" quando offline.
  final bool showCacheBanner;

  /// Versão compacta (para seções dentro de telas maiores).
  final bool compact;

  const CatalogBuilder({
    super.key,
    required this.builder,
    this.source,
    this.onRetry,
    this.showCacheBanner = true,
    this.compact = false,
  });

  @override
  State<CatalogBuilder> createState() => _CatalogBuilderState();
}

class _CatalogBuilderState extends State<CatalogBuilder> {
  ValueListenable<CatalogState> get _src =>
      widget.source ?? CatalogService.instance.state;

  @override
  void initState() {
    super.initState();
    if (widget.source == null) CatalogService.instance.ensureStarted();
    _src.addListener(_onChange);
  }

  @override
  void dispose() {
    _src.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final s = _src.value;
    if (s.updatedRemotely && mounted && widget.source == null) {
      CatalogService.instance.acknowledgeUpdate();
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('Catálogo atualizado'),
          duration: Duration(seconds: 2)));
    }
    if (mounted) setState(() {});
  }

  void _retry() =>
      widget.onRetry != null ? widget.onRetry!() : CatalogService.instance.retry();

  @override
  Widget build(BuildContext context) {
    final s = _src.value;
    if (!s.hasData) {
      if (s.error != null) {
        return QueryErrorView(
            error: s.error,
            title: 'Catálogo indisponível',
            onRetry: _retry);
      }
      if (s.loading) {
        return Padding(
            padding: EdgeInsets.all(widget.compact ? 12 : 32),
            child: const Center(
                child: CircularProgressIndicator(
                    semanticsLabel: 'Carregando catálogo')));
      }
      return EmptyState(
          emoji: '🗂️',
          title: s.fromCache ? 'Sem conexão' : 'Catálogo não configurado',
          subtitle: s.fromCache
              ? 'Não há catálogo salvo neste aparelho. Conecte-se para carregar.'
              : 'O catálogo de serviços ainda não foi publicado neste ambiente.',
          actionLabel: 'Tentar novamente',
          onAction: _retry);
    }
    final child = widget.builder(context, s.catalog);
    if (!widget.showCacheBanner || !s.fromCache) return child;
    return LayoutBuilder(
        builder: (_, box) => box.hasBoundedHeight
            ? Column(children: [
                const CatalogOfflineBanner(),
                Expanded(child: child),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                const CatalogOfflineBanner(),
                child,
              ]));
  }
}

class CatalogOfflineBanner extends StatelessWidget {
  const CatalogOfflineBanner({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: const Color(0xFFFFF4E5),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(children: [
            Icon(Icons.cloud_off_rounded, size: 16, color: Color(0xFF8A5300)),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Offline: exibindo o catálogo salvo no aparelho. '
                    'Envios e contratações ficam indisponíveis até reconectar.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8A5300)))),
          ]),
        ),
      );
}

/// Seletor em chips: Categoria → Grupo → Serviço. Trocar o nível superior
/// limpa os inferiores. Só exibe itens ativos.
class CatalogChipSelector extends StatelessWidget {
  final Catalog catalog;
  final CatalogSelection selection;
  final ValueChanged<CatalogSelection> onChanged;
  final CatalogVertical vertical;

  /// Mostra o chip "Todos" na linha de categorias.
  final bool allowAll;
  final bool showServices;

  const CatalogChipSelector({
    super.key,
    required this.catalog,
    required this.selection,
    required this.onChanged,
    this.vertical = CatalogVertical.services,
    this.allowAll = true,
    this.showServices = true,
  });

  @override
  Widget build(BuildContext context) {
    final cats = catalog.categories(vertical: vertical);
    final groups = selection.categoryId == null
        ? const <CatalogNode>[]
        : catalog.children(selection.categoryId);
    final services = selection.groupId == null || !showServices
        ? const <CatalogNode>[]
        : catalog.children(selection.groupId);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _row(context, 'Categoria', [
        if (allowAll)
          _chip(context, label: 'Todos', icon: null,
              selected: selection.categoryId == null,
              onTap: () => onChanged(CatalogSelection.none)),
        for (final c in cats)
          _chip(context, label: c.name, icon: c.icon,
              selected: selection.categoryId == c.id,
              onTap: () => onChanged(selection.toggle(catalog, c))),
      ]),
      if (groups.isNotEmpty)
        _row(context, 'Grupo', [
          for (final g in groups)
            _chip(context, label: g.name, icon: g.icon,
                selected: selection.groupId == g.id,
                onTap: () => onChanged(selection.toggle(catalog, g))),
        ]),
      if (services.isNotEmpty)
        _row(context, 'Serviço', [
          for (final sv in services)
            _chip(context, label: sv.name, icon: sv.icon,
                selected: selection.serviceId == sv.id,
                onTap: () => onChanged(selection.toggle(catalog, sv))),
        ]),
    ]);
  }

  /// Celular: linha rolável. Tablet/desktop (≥ 700 px): quebra em linhas,
  /// com todas as opções visíveis.
  Widget _row(BuildContext context, String label, List<Widget> chips) =>
      Semantics(
        container: true,
        label: label,
        child: LayoutBuilder(
          builder: (_, box) => box.maxWidth >= 700
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Wrap(spacing: 8, runSpacing: 8, children: chips))
              : SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: chips.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => chips[i],
                  ),
                ),
        ),
      );

  Widget _chip(BuildContext context,
          {required String label,
          required String? icon,
          required bool selected,
          required VoidCallback onTap}) =>
      Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: ChoiceChip(
          label: Text(icon == null ? label : '$icon  $label',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textDark)),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.white,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
          onSelected: (_) => onTap(),
        ),
      );
}

/// Seleção de uma especialidade contratável (grupo ou serviço) em
/// dropdowns encadeados — usada em formulários (Resolve, cadastro).
class CatalogDropdownSelector extends StatelessWidget {
  final Catalog catalog;
  final CatalogSelection selection;
  final ValueChanged<CatalogSelection> onChanged;
  final CatalogVertical vertical;

  const CatalogDropdownSelector({
    super.key,
    required this.catalog,
    required this.selection,
    required this.onChanged,
    this.vertical = CatalogVertical.services,
  });

  @override
  Widget build(BuildContext context) {
    final cats = catalog.categories(vertical: vertical);
    final groups = selection.categoryId == null
        ? const <CatalogNode>[]
        : catalog.children(selection.categoryId);
    final services = selection.groupId == null
        ? const <CatalogNode>[]
        : catalog.children(selection.groupId);
    Widget dd(String label, String? value, List<CatalogNode> items,
            ValueChanged<String?> on, {bool optional = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            key: ValueKey('$label|$value|${items.length}'),
            initialValue: items.any((n) => n.id == value) ? value : null,
            isExpanded: true,
            decoration: InputDecoration(
                labelText: label, border: const OutlineInputBorder()),
            items: [
              if (optional)
                const DropdownMenuItem<String>(
                    value: null, child: Text('Geral (sem serviço específico)')),
              for (final n in items)
                DropdownMenuItem(
                    value: n.id,
                    child: Text('${n.icon}  ${n.name}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: on,
          ),
        );
    return Column(children: [
      dd('Categoria', selection.categoryId, cats,
          (v) => onChanged(selection.selectCategory(v))),
      if (groups.isNotEmpty)
        dd('Grupo', selection.groupId, groups,
            (v) => onChanged(selection.selectGroup(catalog, v))),
      if (services.isNotEmpty)
        dd('Serviço', selection.serviceId, services,
            (v) => onChanged(selection.selectService(catalog, v)),
            optional: true),
    ]);
  }
}

/// Seleção múltipla de especialidades do prestador (grupos e serviços).
/// Preserva IDs antigos/desativados já declarados (não os remove
/// sozinho) e não acrescenta serviços que o prestador não marcou.
class CatalogMultiSelect extends StatefulWidget {
  final Catalog catalog;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final CatalogVertical? vertical;
  final int maxItems;

  const CatalogMultiSelect({
    super.key,
    required this.catalog,
    required this.selected,
    required this.onChanged,
    this.vertical,
    this.maxItems = 30,
  });

  @override
  State<CatalogMultiSelect> createState() => _CatalogMultiSelectState();
}

class _CatalogMultiSelectState extends State<CatalogMultiSelect> {
  String? _open;

  void _toggle(String id) {
    final next = {...widget.selected};
    if (!next.remove(id)) {
      if (next.length >= widget.maxItems) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
            content: Text('Máximo de ${widget.maxItems} especialidades.')));
        return;
      }
      next.add(id);
    }
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.catalog;
    final verticals = widget.vertical == null
        ? const [CatalogVertical.services, CatalogVertical.health]
        : [widget.vertical!];
    final cats = [for (final v in verticals) ...c.categories(vertical: v)];
    final legacy = widget.selected
        .where((id) => c.byId(id) == null || !c.isActive(id))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (legacy.isNotEmpty) ...[
        const Text('Mantidas no seu perfil (fora do catálogo ativo):',
            style: TextStyle(fontSize: 12, color: AppColors.textLight)),
        Wrap(spacing: 6, children: [
          for (final id in legacy)
            InputChip(
                label: Text(c.byId(id)?.name ?? id),
                avatar: const Icon(Icons.history, size: 16),
                onDeleted: () => _toggle(id),
                tooltip: 'Especialidade antiga ou desativada'),
        ]),
        const SizedBox(height: 8),
      ],
      for (final cat in cats)
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ExpansionTile(
            key: PageStorageKey(cat.id),
            initiallyExpanded: _open == cat.id,
            onExpansionChanged: (o) => setState(() => _open = o ? cat.id : null),
            leading: Text(cat.icon, style: const TextStyle(fontSize: 20)),
            title: Text(cat.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
                '${c.subtreeIds(cat.id).where(widget.selected.contains).length} selecionada(s)',
                style: const TextStyle(fontSize: 11)),
            children: [
              for (final g in c.children(cat.id)) ...[
                CheckboxListTile(
                  dense: true,
                  value: widget.selected.contains(g.id),
                  onChanged: (_) => _toggle(g.id),
                  title: Text('${g.icon}  ${g.name}'),
                  subtitle: c.children(g.id).isEmpty
                      ? null
                      : const Text('Atendo a área em geral',
                          style: TextStyle(fontSize: 11)),
                ),
                for (final s in c.children(g.id))
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: CheckboxListTile(
                      dense: true,
                      value: widget.selected.contains(s.id),
                      onChanged: (_) => _toggle(s.id),
                      title: Text(s.name, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
              ],
            ],
          ),
        ),
    ]);
  }
}

/// Cor do item (#RRGGBB) com fallback para a cor primária.
Color catalogColor(CatalogNode? n) {
  final hex = n?.color;
  if (hex == null || hex.length != 7) return AppColors.primary;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

/// Nome legível de um item do catálogo, reativo. Usa o nome gravado no
/// pedido (snapshot) quando houver — o histórico nunca fica ilegível.
class CatalogLabel extends StatelessWidget {
  final String? id;
  final String? snapshotName;
  final TextStyle? style;
  final bool withIcon;
  final int? maxLines;
  const CatalogLabel(this.id,
      {super.key, this.snapshotName, this.style, this.withIcon = false, this.maxLines});

  @override
  Widget build(BuildContext context) {
    CatalogService.instance.ensureStarted();
    return ValueListenableBuilder<CatalogState>(
      valueListenable: CatalogService.instance.state,
      builder: (_, s, __) {
        final n = s.catalog.byId(id);
        final name = snapshotName ?? n?.name ?? (id == null || id!.isEmpty ? 'Serviço' : id!);
        return Text(withIcon && n != null ? '${n.icon} $name' : name,
            style: style, maxLines: maxLines, overflow: maxLines == null ? null : TextOverflow.ellipsis);
      },
    );
  }
}
