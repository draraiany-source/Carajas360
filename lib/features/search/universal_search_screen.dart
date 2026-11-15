import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/search/provider_search.dart';
import '../../core/search/universal_search.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_categories.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';
import '../services/service_marketplace_screen.dart';

/// Explorar Serviços: busca única de profissionais (aba Explorar,
/// `/search` e `/universal-search`).
class UniversalSearchScreen extends StatefulWidget {
  final String? initialQuery;

  /// Id estável de [Categories] (ex.: 'eletricista').
  final String? initialCategory;

  /// Grupo de [Categories] (ex.: 'Casa').
  final String? initialGroup;
  const UniversalSearchScreen(
      {super.key, this.initialQuery, this.initialCategory, this.initialGroup});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _q = '';
  List<UniversalHit> _hits = const [];
  List<String> _suggestions = const [];
  List<String> _history = const [];

  static const _pageStep = 100;
  int _limit = _pageStep;
  late Stream<List<ProviderModel>> _providers;

  BrandCategory? _category;
  Set<String> _specialties = const {};
  String? _city;
  double _minRating = 0;
  String? _modality;
  double? _maxPrice;
  bool? _priceInformed;
  ProviderSort _sort = ProviderSort.relevance;
  bool _grid = true;
  int _page = 0;
  bool _aiBusy = false;
  int _aiRequest = 0;

  static const _historyKey = 'carajas360_universal_search_history_v1';
  static const _pageSize = 12;
  final _resultsKey = GlobalKey();
  final _scroll = ScrollController();

  ProviderSearchCriteria get _criteria => ProviderSearchCriteria(
        query: _q,
        scopeIds: _category?.ids ?? const {},
        specialties: _specialties,
        city: _city,
        minRating: _minRating,
        modality: _modality,
        maxPrice: _maxPrice,
        priceInformed: _priceInformed,
        sort: _sort,
      );

  /// Filtros secundários ativos (selo do botão "Filtros" no mobile).
  int get _activeFilters =>
      (_city != null ? 1 : 0) +
      (_minRating > 0 ? 1 : 0) +
      (_modality != null ? 1 : 0) +
      (_maxPrice != null ? 1 : 0) +
      (_priceInformed != null ? 1 : 0) +
      _specialties.length;

  void _goToPage(int p) {
    setState(() => _page = p);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _resultsKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      } else if (_scroll.hasClients) {
        _scroll.animateTo(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _providers = FS.providersStream(limit: _limit);
    _category = BrandCategory.fromArgs(
        category: widget.initialCategory, group: widget.initialGroup);
    _ctrl.text = widget.initialQuery ?? '';
    _q = _ctrl.text;
    _loadHistory();
    if (_q.isNotEmpty) _runSearch(_q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reloadProviders({bool more = false}) {
    if (!more) FS.resetProvidersStreams();
    setState(() {
      if (more) _limit += _pageStep;
      _providers = FS.providersStream(limit: _limit);
    });
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? const [];
    if (mounted) setState(() => _history = list);
  }

  Future<void> _pushHistory(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final next = [
      t,
      ..._history.where((e) => e.toLowerCase() != t.toLowerCase())
    ].take(12).toList();
    await prefs.setStringList(_historyKey, next);
    if (mounted) setState(() => _history = next);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() => _history = const []);
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _q = v;
        _page = 0;
        _suggestions = UniversalSearch.suggest(query: v);
      });
      _runSearch(v);
    });
  }

  /// Enter ou botão "Buscar": aplica o texto na hora.
  void _submitSearch(String v) {
    _debounce?.cancel();
    setState(() {
      _q = v;
      _page = 0;
    });
    _pushHistory(v);
    _runSearch(v);
  }

  /// Serviços e categorias da taxonomia; profissionais vêm do stream.
  void _runSearch(String v) {
    final hits = UniversalSearch.search(query: v)
        .where((h) =>
            h.kind != UniversalHitKind.provider &&
            h.kind != UniversalHitKind.company)
        .take(8)
        .toList();
    if (!mounted) return;
    setState(() => _hits = hits);
  }

  void _setQuery(String s) {
    _ctrl.text = s;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: s.length));
    _debounce?.cancel();
    setState(() {
      _q = s;
      _page = 0;
      _suggestions = const [];
    });
    _runSearch(s);
    _pushHistory(s);
  }

  void _clearQuery() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() {
      _q = '';
      _hits = const [];
      _suggestions = const [];
      _page = 0;
    });
  }

  /// Sugere a especialidade pela descrição (IA). Respostas atrasadas de
  /// pedidos anteriores são descartadas.
  Future<void> _smartSearch() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      snack(context, 'Digite o que você precisa primeiro.');
      _focus.requestFocus();
      return;
    }
    final req = ++_aiRequest;
    setState(() => _aiBusy = true);
    final names = Categories.all
        .where((c) => c.group != 'Saúde')
        .map((c) => c.name)
        .toList();
    String? result;
    try {
      result = await AiSvc.smartSearchCategory(q, names);
    } catch (_) {
      result = null;
    }
    if (!mounted || req != _aiRequest) return;
    setState(() => _aiBusy = false);
    final match = (result == null || result.isEmpty)
        ? null
        : Categories.all.where((c) => c.name == result).firstOrNull;
    if (match == null) {
      snack(context,
          'Não foi possível sugerir uma categoria agora. Escolha uma categoria abaixo.');
      return;
    }
    setState(() {
      _category = BrandCategory.fromArgs(category: match.id);
      _specialties = const {};
      _page = 0;
    });
    snack(context, 'Categoria sugerida: ${match.name}', bg: Brand.green);
  }

  Future<void> _openHit(UniversalHit hit) async {
    await _pushHistory(hit.title);
    if (!mounted) return;
    switch (hit.kind) {
      case UniversalHitKind.service:
        final svc = ServiceTaxonomy.serviceById(hit.serviceId ?? hit.id);
        if (svc != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceRequestFlowScreen(service: svc),
            ),
          );
          return;
        }
        break;
      case UniversalHitKind.group:
        final g = ServiceTaxonomy.groupById(hit.groupId ?? hit.id);
        if (g != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceListScreen(group: g)),
          );
          return;
        }
        break;
      case UniversalHitKind.vertical:
        final v = ServiceTaxonomy.verticalById(hit.verticalId ?? hit.id);
        if (v?.independentRoute != null) {
          Navigator.pushNamed(context, v!.independentRoute!);
          return;
        }
        if (v != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceGroupsScreen(vertical: v)),
          );
          return;
        }
        break;
      case UniversalHitKind.provider:
      case UniversalHitKind.company:
      case UniversalHitKind.category:
        break;
    }
    final cat = hit.categoryId == null
        ? null
        : BrandCategory.fromArgs(category: hit.categoryId);
    if (cat != null) _selectCategory(cat);
  }

  void _selectCategory(BrandCategory? c) {
    if (c?.route != null) {
      Navigator.pushNamed(context, c!.route!);
      return;
    }
    setState(() {
      _category = c;
      _specialties = const {};
      _page = 0;
    });
  }

  void _toggleSpecialty(String id) {
    setState(() {
      final next = {..._specialties};
      if (!next.remove(id)) next.add(id);
      _specialties = next;
      _page = 0;
    });
  }

  void _clearFilters() => setState(() {
        _category = null;
        _specialties = const {};
        _city = null;
        _minRating = 0;
        _modality = null;
        _maxPrice = null;
        _priceInformed = null;
        _sort = ProviderSort.relevance;
        _page = 0;
      });

  /// Muda um filtro e volta à primeira página.
  void _apply(VoidCallback fn) => setState(() {
        fn();
        _page = 0;
      });

  /// Painel de filtros (barra lateral ou folha). [refresh] reconstrói a
  /// folha inferior, que vive fora desta árvore.
  _FiltersPanel _buildPanel(List<ProviderModel> all, {VoidCallback? refresh}) {
    void run(VoidCallback fn) {
      _apply(fn);
      refresh?.call();
    }

    final ids = _category == null
        ? const <String>[]
        : ProviderSearch.availableSpecialties(all, _category!.ids);
    return _FiltersPanel(
      city: _city,
      specialtyIds: ids,
      specialtyCounts: {
        for (final id in ids)
          id: all.where((p) => p.active && p.categories.contains(id)).length,
      },
      specialties: _specialties,
      hasCategory: _category != null,
      hasFilters: _criteria.hasFilters,
      priceInformed: _priceInformed,
      maxPrice: _maxPrice,
      modality: _modality,
      minRating: _minRating,
      onCity: (v) => run(() => _city = v),
      onModality: (v) => run(() => _modality = v),
      onSpecialty: (id) => run(() {
        final next = {..._specialties};
        if (!next.remove(id)) next.add(id);
        _specialties = next;
      }),
      onPriceInformed: (v) => run(() {
        _priceInformed = v;
        if (v == false) _maxPrice = null;
      }),
      onMaxPrice: (v) => run(() {
        _maxPrice = v;
        if (v != null && _priceInformed == false) _priceInformed = null;
      }),
      onRating: (v) => run(() => _minRating = v),
      onClear: () {
        _clearFilters();
        refresh?.call();
      },
    );
  }

  void _openFilters(List<ProviderModel> all) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface(context),
      builder: (sheetCtx) => StatefulBuilder(builder: (ctx, setSheet) {
        final n = ProviderSearch.apply(all, _criteria).length;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _buildPanel(all, refresh: () => setSheet(() {})),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: BrandPrimaryButton(
                  label: 'Ver $n ${n == 1 ? 'profissional' : 'profissionais'}',
                  onPressed: () => Navigator.pop(sheetCtx),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inner = AppNav.isInnerPage(context);
    return Scaffold(
      backgroundColor: Brand.isDark(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : Brand.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final sidebar = constraints.maxWidth >= 1000;
          final pad = wide ? 28.0 : 16.0;
          return StreamBuilder<List<ProviderModel>>(
            stream: _providers,
            builder: (context, snap) {
              final all = snap.data ?? const <ProviderModel>[];
              final loading = snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData &&
                  !snap.hasError;
              final failed = snap.hasError && !snap.hasData;
              final truncated =
                  !HomologCatalog.enabled && snap.hasData && all.length >= _limit;
              final criteria = _criteria;
              final results = ProviderSearch.apply(all, criteria);
              final pages =
                  ProviderSearch.pageCount(results.length, _pageSize);
              final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
              final visible =
                  ProviderSearch.pageSlice(results, page, _pageSize);
              final specialties = _category == null
                  ? const <String>[]
                  : ProviderSearch.availableSpecialties(all, _category!.ids);

              Widget box(Widget child, {double top = 0, bool bleed = false}) =>
                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints:
                          const BoxConstraints(maxWidth: BrandShell.maxWidth),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            bleed ? 0 : pad, top, bleed ? 0 : pad, 0),
                        child: child,
                      ),
                    ),
                  );

              final heading = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      _category != null
                          ? 'Profissionais de ${_category!.label}'
                          : 'Profissionais',
                      style: TextStyle(
                          fontSize: wide ? 22 : 19,
                          fontWeight: FontWeight.w900,
                          color: Brand.ink(context)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      key: _resultsKey,
                      loading
                          ? 'Carregando profissionais...'
                          : failed
                              ? 'Não foi possível carregar os profissionais.'
                              : _countLabel(
                                  total: results.length,
                                  page: page,
                                  pages: pages,
                                  query: _q.trim(),
                                  category: _category?.label),
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.inkMuted(context)),
                    ),
                  ),
                ],
              );
              final sortMenu = _FilterMenu<ProviderSort>(
                icon: Icons.sort_rounded,
                tooltip: 'Ordenar',
                label: providerSortLabels[_sort]!,
                active: _sort != ProviderSort.relevance,
                value: _sort,
                options: [
                  for (final s in ProviderSort.values) (s, providerSortLabels[s]!)
                ],
                onSelected: (v) => _apply(() => _sort = v),
              );
              final toggle = _ViewToggle(
                  grid: _grid, onGrid: (v) => setState(() => _grid = v));
              final nFilters = _activeFilters;
              final toolbar = sidebar
                  ? Row(children: [
                      Expanded(child: heading),
                      const SizedBox(width: 12),
                      sortMenu,
                      const SizedBox(width: 12),
                      toggle,
                    ])
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heading,
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: ScrollConfiguration(
                              behavior: const BrandDragScrollBehavior(),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _openFilters(all),
                                    icon: const Icon(Icons.tune_rounded,
                                        size: 18),
                                    label: Text(nFilters > 0
                                        ? 'Filtros ($nFilters)'
                                        : 'Filtros'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Brand.green,
                                      minimumSize: const Size(0, 44),
                                      side: BorderSide(
                                          color: nFilters > 0
                                              ? Brand.green
                                              : Brand.line(context)),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(22)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  sortMenu,
                                ]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          toggle,
                        ]),
                      ],
                    );

              final resultsColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (HomologCatalog.enabled) ...[
                    const BrandDemoNotice(
                        message:
                            'Ambiente de demonstração: estes perfis não recebem pedidos reais.'),
                    const SizedBox(height: 14),
                  ],
                  toolbar,
                  const SizedBox(height: 14),
                  loading
                      ? const ShimCard()
                      : failed
                          ? _ErrorResults(onRetry: _reloadProviders)
                          : results.isEmpty
                              ? _EmptyResults(
                                  hasFilters:
                                      criteria.hasFilters || _q.isNotEmpty,
                                  onClear: () {
                                    _clearFilters();
                                    _clearQuery();
                                  },
                                  onRequest: () => Navigator.pushNamed(
                                      context, Routes.resolve),
                                )
                              : BrandProviderGrid(
                                  list: visible,
                                  highlight: criteria.effectiveIds,
                                  asList: !_grid,
                                  maxColumns: sidebar ? 3 : null,
                                ),
                  if (pages > 1) ...[
                    const SizedBox(height: 20),
                    _Pagination(page: page, pages: pages, onPage: _goToPage),
                  ],
                  if (truncated) ...[
                    const SizedBox(height: 16),
                    _LoadMore(
                      loaded: all.length,
                      onTap: () => _reloadProviders(more: true),
                    ),
                  ],
                ],
              );

              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  box(
                    _HeroSearch(
                      wide: wide,
                      showBack: inner,
                      autofocus: inner &&
                          widget.initialQuery == null &&
                          _category == null,
                      aiBusy: _aiBusy,
                      controller: _ctrl,
                      focusNode: _focus,
                      city: _city,
                      onCity: (v) => _apply(() => _city = v),
                      onChanged: _onChanged,
                      onSubmitted: _submitSearch,
                      onClear: _clearQuery,
                      onSmartSearch: _smartSearch,
                      onSearch: () {
                        FocusScope.of(context).unfocus();
                        _submitSearch(_ctrl.text);
                      },
                    ),
                    top: wide ? 20 : 12,
                  ),
                  if (_q.trim().isEmpty && _history.isNotEmpty)
                    box(
                      _ChipLine(
                        title: 'Buscas recentes',
                        items: _history.take(8).toList(),
                        icon: Icons.history_rounded,
                        onTap: _setQuery,
                        action: 'Limpar histórico',
                        onAction: _clearHistory,
                      ),
                      top: 12,
                    ),
                  if (_suggestions.isNotEmpty && _q.trim().isNotEmpty)
                    box(
                      _ChipLine(
                        title: 'Sugestões',
                        items: _suggestions,
                        icon: Icons.search_rounded,
                        onTap: _setQuery,
                      ),
                      top: 12,
                    ),
                  if (_hits.isNotEmpty)
                    box(_TaxonomyHits(hits: _hits, onOpen: _openHit), top: 16),
                  box(
                    _CategorySelector(
                      pad: pad,
                      selected: _category,
                      onSelect: _selectCategory,
                      onMore: () =>
                          Navigator.pushNamed(context, Routes.servicesHub),
                    ),
                    top: 18,
                    bleed: true,
                  ),
                  if (!sidebar && specialties.length >= 2)
                    box(
                      _SpecialtyBar(
                        pad: pad,
                        ids: specialties,
                        selected: _specialties,
                        all: all,
                        onToggle: _toggleSpecialty,
                        onAll: () => setState(() {
                          _specialties = const {};
                          _page = 0;
                        }),
                      ),
                      top: 12,
                      bleed: true,
                    ),
                  box(
                    sidebar
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 264,
                                child: BrandSoftCard(
                                  padding: const EdgeInsets.all(18),
                                  child: _buildPanel(all),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(child: resultsColumn),
                            ],
                          )
                        : resultsColumn,
                    top: 18,
                  ),
                ],
              );
            },
          );
        }),
      ),
    );
  }

  static String _countLabel({
    required int total,
    required int page,
    required int pages,
    required String query,
    String? category,
  }) {
    final noun = total == 1 ? 'profissional encontrado' : 'profissionais encontrados';
    final parts = <String>['$total $noun'];
    if (category != null) parts.add('em $category');
    if (query.isNotEmpty) parts.add('para "$query"');
    var s = parts.join(' ');
    if (pages > 1) {
      final from = page * _pageSize + 1;
      final to = ((page + 1) * _pageSize).clamp(0, total);
      s += ' · exibindo $from–$to';
    }
    return s;
  }
}

// ─────────────────────────────────────────────────────────────
// Cabeçalho e busca
// ─────────────────────────────────────────────────────────────

/// Hero da tela: título, busca, cidade e botão dourado "Buscar".
class _HeroSearch extends StatelessWidget {
  final bool wide, showBack, aiBusy, autofocus;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? city;
  final ValueChanged<String?> onCity;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear, onSmartSearch, onSearch;
  const _HeroSearch({
    required this.wide,
    required this.showBack,
    required this.aiBusy,
    required this.autofocus,
    required this.controller,
    required this.focusNode,
    required this.city,
    required this.onCity,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onSmartSearch,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    final search = Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        const SizedBox(width: 14),
        const Icon(Icons.search_rounded, color: Brand.green, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, color: Brand.text),
            decoration: const InputDecoration(
              hintText: 'Nome, serviço ou especialidade',
              hintStyle: TextStyle(color: Brand.textMuted, fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded,
                      color: Brand.textMuted, size: 20),
                  onPressed: onClear,
                ),
        ),
        IconButton(
          tooltip: 'Sugerir categoria com IA',
          onPressed: aiBusy ? null : onSmartSearch,
          icon: aiBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome_rounded, color: Brand.goldDeep),
        ),
        const SizedBox(width: 2),
      ]),
    );
    final cityBox = _BoxDropdown<String>(
      onHero: true,
      icon: Icons.location_on_outlined,
      semanticLabel: 'Cidade',
      value: city ?? '',
      items: _cityItems,
      onChanged: (v) => onCity(v.isEmpty ? null : v),
    );
    final button = SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.gold,
          foregroundColor: Brand.greenDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Buscar',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      ),
    );
    final bottom = wide
        ? Row(children: [
            Expanded(child: search),
            const SizedBox(width: 10),
            SizedBox(width: 230, child: cityBox),
            const SizedBox(width: 10),
            button,
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            search,
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: cityBox),
              const SizedBox(width: 10),
              button,
            ]),
          ]);
    return BrandPageHero(
      title: 'Explorar serviços',
      subtitle: 'Encontre quem entende do que você precisa.',
      padding: EdgeInsets.fromLTRB(
          wide ? 24 : 16, wide ? 22 : 16, wide ? 24 : 16, wide ? 22 : 16),
      leading: showBack
          ? Material(
              color: Colors.white.withValues(alpha: 0.14),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => AppNav.safeBack(context),
              ),
            )
          : null,
      trailing: wide
          ? Opacity(
              opacity: 0.25,
              child: SvgPicture.asset('assets/logos/logo_mark_mono_white.svg',
                  width: 84),
            )
          : null,
      bottom: bottom,
    );
  }
}

List<(String, String)> get _cityItems => [
      ('', 'Todas as cidades'),
      for (final c in [...RegionCities.priority, ...RegionCities.nearby]) (c, c),
    ];

/// Seletor em caixa (hero: fundo branco; painel de filtros: com borda).
class _BoxDropdown<T> extends StatelessWidget {
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final IconData? icon;
  final bool onHero;
  final String semanticLabel;
  const _BoxDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.semanticLabel,
    this.icon,
    this.onHero = false,
  });

  @override
  Widget build(BuildContext context) {
    final fill = onHero ? Colors.white : Brand.surface(context);
    final ink = onHero ? Brand.text : Brand.ink(context);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Container(
        height: onHero ? 50 : 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: onHero ? null : Border.all(color: Brand.line(context)),
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Brand.green),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: fill,
                icon: Icon(Icons.expand_more_rounded,
                    color: onHero ? Brand.textMuted : Brand.inkMuted(context)),
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: ink),
                items: [
                  for (final (v, l) in items)
                    DropdownMenuItem<T>(
                      value: v,
                      child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ChipLine extends StatelessWidget {
  final String title;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String> onTap;
  final String? action;
  final VoidCallback? onAction;
  const _ChipLine({
    required this.title,
    required this.items,
    required this.icon,
    required this.onTap,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Brand.ink(context))),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  foregroundColor: Brand.green, minimumSize: const Size(0, 40)),
              child: Text(action!,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in items)
              ActionChip(
                avatar: Icon(icon, size: 16, color: Brand.green),
                label: Text(s),
                backgroundColor: Brand.surface(context),
                side: BorderSide(color: Brand.line(context)),
                onPressed: () => onTap(s),
              ),
          ],
        ),
      ],
    );
  }
}

class _TaxonomyHits extends StatelessWidget {
  final List<UniversalHit> hits;
  final ValueChanged<UniversalHit> onOpen;
  const _TaxonomyHits({required this.hits, required this.onOpen});

  static IconData _icon(UniversalHitKind k) => switch (k) {
        UniversalHitKind.vertical => Icons.category_outlined,
        UniversalHitKind.group => Icons.account_tree_outlined,
        UniversalHitKind.service => Icons.handyman_outlined,
        UniversalHitKind.category => Icons.label_outline,
        UniversalHitKind.provider => Icons.person_outline,
        UniversalHitKind.company => Icons.storefront_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Serviços e categorias',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Brand.ink(context))),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 560 ? 2 : 1);
          final w = (c.maxWidth - 10 * (cols - 1)) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final h in hits)
                SizedBox(
                  width: w,
                  child: Material(
                    color: Brand.surface(context),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onOpen(h),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Brand.line(context)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Brand.greenLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_icon(h.kind),
                                size: 19, color: Brand.green),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: Brand.ink(context))),
                                Text(h.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Brand.inkMuted(context))),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: Brand.inkMuted(context)),
                        ]),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Categorias e filtros
// ─────────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final double pad;
  final BrandCategory? selected;
  final ValueChanged<BrandCategory?> onSelect;
  final VoidCallback onMore;
  const _CategorySelector({
    required this.pad,
    required this.selected,
    required this.onSelect,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    final items = <(String, IconData, bool, VoidCallback)>[
      ('Todas', Icons.grid_view_rounded, sel == null, () => onSelect(null)),
      if (sel != null && !brandCategories.contains(sel))
        (sel.label, sel.icon, true, () => onSelect(sel)),
      for (final c in brandCategories)
        (c.label, c.icon, sel == c, () => onSelect(c)),
      ('Mais categorias', Icons.add_rounded, false, onMore),
    ];
    return SizedBox(
      height: 100,
      child: ScrollConfiguration(
        behavior: const BrandDragScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 2),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final (label, icon, isSel, onTap) = items[i];
            return Semantics(
              button: true,
              selected: isSel ? true : null,
              label: isSel ? '$label, categoria selecionada' : label,
              excludeSemantics: true,
              onTap: onTap,
              child: Material(
                color: isSel ? Brand.green : Brand.surface(context),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isSel ? Brand.gold : Brand.line(context),
                          width: isSel ? 2 : 1),
                    ),
                    child: Column(children: [
                      Icon(icon,
                          size: 26, color: isSel ? Brand.gold : Brand.green),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.2,
                                fontWeight:
                                    isSel ? FontWeight.w800 : FontWeight.w700,
                                color: isSel
                                    ? Colors.white
                                    : Brand.ink(context))),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Especialidades (subcategorias) da categoria ativa; múltipla escolha.
class _SpecialtyBar extends StatelessWidget {
  final double pad;
  final List<String> ids;
  final Set<String> selected;
  final List<ProviderModel> all;
  final ValueChanged<String> onToggle;
  final VoidCallback onAll;
  const _SpecialtyBar({
    required this.pad,
    required this.ids,
    required this.selected,
    required this.all,
    required this.onToggle,
    required this.onAll,
  });

  @override
  Widget build(BuildContext context) {
    int count(String id) =>
        all.where((p) => p.active && p.categories.contains(id)).length;
    Widget chip(String label, bool sel, VoidCallback onTap) => FilterChip(
          label: Text(label),
          selected: sel,
          onSelected: (_) => onTap(),
          showCheckmark: true,
          checkmarkColor: Brand.greenDark,
          selectedColor: Brand.goldLight,
          backgroundColor: Brand.surface(context),
          side: BorderSide(color: sel ? Brand.goldDeep : Brand.line(context)),
          labelStyle: TextStyle(
              fontSize: 12.5,
              fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
              color: Brand.ink(context)),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Text('Especialidades',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink(context))),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ScrollConfiguration(
            behavior: const BrandDragScrollBehavior(),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              children: [
                chip('Todas', selected.isEmpty, onAll),
                for (final id in ids) ...[
                  const SizedBox(width: 8),
                  chip('${ProviderSearch.categoryName(id)} (${count(id)})',
                      selected.contains(id), () => onToggle(id)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: tooltip,
      initialValue: value,
      onSelected: onSelected,
      position: PopupMenuPosition.under,
      itemBuilder: (_) => [
        for (final (v, l) in options)
          PopupMenuItem<T>(
            value: v,
            child: Row(children: [
              Icon(v == value ? Icons.check_rounded : null,
                  size: 18, color: Brand.green),
              const SizedBox(width: 8),
              Text(l),
            ]),
          ),
      ],
      child: Semantics(
        button: true,
        label: '$tooltip: $label',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: active ? Brand.greenLight : Brand.surface(context),
            borderRadius: BorderRadius.circular(22),
            border:
                Border.all(color: active ? Brand.green : Brand.line(context)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: Brand.green),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Brand.ink(context))),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: Brand.inkMuted(context)),
          ]),
        ),
      ),
    );
  }
}

/// Painel de filtros: barra lateral (>= 1000px) ou folha inferior (mobile).
class _FiltersPanel extends StatelessWidget {
  final String? city;
  final List<String> specialtyIds;
  final Map<String, int> specialtyCounts;
  final Set<String> specialties;
  final bool hasCategory, hasFilters;
  final bool? priceInformed;
  final double? maxPrice;
  final String? modality;
  final double minRating;
  final ValueChanged<String?> onCity, onModality;
  final ValueChanged<String> onSpecialty;
  final ValueChanged<bool?> onPriceInformed;
  final ValueChanged<double?> onMaxPrice;
  final ValueChanged<double> onRating;
  final VoidCallback onClear;
  const _FiltersPanel({
    required this.city,
    required this.specialtyIds,
    required this.specialtyCounts,
    required this.specialties,
    required this.hasCategory,
    required this.hasFilters,
    required this.priceInformed,
    required this.maxPrice,
    required this.modality,
    required this.minRating,
    required this.onCity,
    required this.onModality,
    required this.onSpecialty,
    required this.onPriceInformed,
    required this.onMaxPrice,
    required this.onRating,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t,
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w800, color: ink)),
        );
    Widget divider() => Divider(height: 26, color: Brand.line(context));
    Widget check(String label, bool v, VoidCallback onTap) => CheckboxListTile(
          value: v,
          onChanged: (_) => onTap(),
          title: Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: v ? FontWeight.w800 : FontWeight.w600,
                  color: ink)),
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          activeColor: Brand.green,
          checkColor: Colors.white,
        );
    Widget hint(String t) =>
        Text(t, style: TextStyle(fontSize: 12.5, height: 1.35, color: muted));

    // Material próprio: o ListTile dos checkboxes não pode pintar sobre o
    // fundo decorado do cartão.
    return Material(
      type: MaterialType.transparency,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text('Filtros',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: ink)),
          ),
          TextButton(
            onPressed: hasFilters ? onClear : null,
            style: TextButton.styleFrom(
                foregroundColor: Brand.green, minimumSize: const Size(0, 40)),
            child: const Text('Limpar filtros',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
          ),
        ]),
        const SizedBox(height: 10),
        title('Cidade'),
        _BoxDropdown<String>(
          semanticLabel: 'Cidade',
          value: city ?? '',
          items: _cityItems,
          onChanged: (v) => onCity(v.isEmpty ? null : v),
        ),
        divider(),
        title('Especialidade'),
        if (specialtyIds.isEmpty)
          hint(hasCategory
              ? 'Esta categoria não tem subespecialidades cadastradas.'
              : 'Escolha uma categoria acima para filtrar por especialidade.')
        else
          for (final id in specialtyIds)
            check(
                '${ProviderSearch.categoryName(id)} (${specialtyCounts[id] ?? 0})',
                specialties.contains(id),
                () => onSpecialty(id)),
        divider(),
        title('Preço'),
        check('Sob orçamento', priceInformed == false,
            () => onPriceInformed(priceInformed == false ? null : false)),
        check('Preço informado', priceInformed == true,
            () => onPriceInformed(priceInformed == true ? null : true)),
        if (priceInformed != false) ...[
          const SizedBox(height: 6),
          _BoxDropdown<double>(
            semanticLabel: 'Preço inicial máximo',
            value: maxPrice ?? -1.0,
            items: const [
              (-1.0, 'Qualquer valor inicial'),
              (100.0, 'Inicial até R\$ 100'),
              (200.0, 'Inicial até R\$ 200'),
            ],
            onChanged: (v) => onMaxPrice(v < 0 ? null : v),
          ),
        ],
        divider(),
        title('Atendimento'),
        check('Domiciliar', modality == 'home_care',
            () => onModality(modality == 'home_care' ? null : 'home_care')),
        check('Presencial', modality == 'presential',
            () => onModality(modality == 'presential' ? null : 'presential')),
        check('Online', modality == 'online',
            () => onModality(modality == 'online' ? null : 'online')),
        divider(),
        title('Avaliação'),
        _BoxDropdown<double>(
          semanticLabel: 'Avaliação mínima',
          value: minRating,
          items: const [
            (0.0, 'Qualquer avaliação'),
            (4.0, 'Nota 4,0 ou mais'),
            (4.5, 'Nota 4,5 ou mais'),
          ],
          onChanged: onRating,
        ),
      ],
    ),
    );
  }
}

/// Alternância grade/lista.
class _ViewToggle extends StatelessWidget {
  final bool grid;
  final ValueChanged<bool> onGrid;
  const _ViewToggle({required this.grid, required this.onGrid});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.line(context)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (g, icon, tip) in [
          (true, Icons.grid_view_rounded, 'Ver em grade'),
          (false, Icons.view_list_rounded, 'Ver em lista'),
        ])
          IconButton(
            tooltip: tip,
            isSelected: grid == g,
            onPressed: () => onGrid(g),
            style: IconButton.styleFrom(
              backgroundColor: grid == g ? Brand.green : Colors.transparent,
              foregroundColor:
                  grid == g ? Colors.white : Brand.inkMuted(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(icon, size: 20),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Estados de resultado
// ─────────────────────────────────────────────────────────────

class _StateCard extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final List<Widget> actions;
  const _StateCard(
      {required this.icon,
      required this.title,
      required this.text,
      required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.line(context)),
      ),
      child: Column(children: [
        Icon(icon, size: 40, color: Brand.green),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Brand.ink(context))),
        const SizedBox(height: 4),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Brand.inkMuted(context))),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: actions,
        ),
      ]),
    );
  }
}

class _ErrorResults extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorResults({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.cloud_off_rounded,
      title: 'Não foi possível carregar os profissionais',
      text: 'Verifique sua conexão e tente novamente.',
      actions: [
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Tentar novamente'),
          style: ElevatedButton.styleFrom(
              backgroundColor: Brand.green,
              foregroundColor: Colors.white,
              elevation: 0),
        ),
      ],
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear, onRequest;
  const _EmptyResults(
      {required this.hasFilters,
      required this.onClear,
      required this.onRequest});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.search_off_rounded,
      title: 'Nenhum profissional encontrado',
      text: hasFilters
          ? 'Ajuste os filtros ou descreva o que precisa para receber propostas.'
          : 'Ainda não há profissionais cadastrados. Descreva o que precisa para receber propostas.',
      actions: [
        if (hasFilters)
          OutlinedButton(
            onPressed: onClear,
            style: OutlinedButton.styleFrom(
                foregroundColor: Brand.green,
                side: const BorderSide(color: Brand.green)),
            child: const Text('Limpar busca e filtros'),
          ),
        ElevatedButton(
          onPressed: onRequest,
          style: ElevatedButton.styleFrom(
              backgroundColor: Brand.gold,
              foregroundColor: Brand.greenDark,
              elevation: 0),
          child: const Text('Pedir orçamento',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

class _LoadMore extends StatelessWidget {
  final int loaded;
  final VoidCallback onTap;
  const _LoadMore({required this.loaded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(
        'Os resultados consideram os $loaded profissionais mais bem avaliados carregados até agora.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context)),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Carregar mais profissionais'),
        style: OutlinedButton.styleFrom(
            foregroundColor: Brand.green,
            side: const BorderSide(color: Brand.green),
            minimumSize: const Size(0, 44)),
      ),
    ]);
  }
}

class _Pagination extends StatelessWidget {
  final int page, pages;
  final ValueChanged<int> onPage;
  const _Pagination(
      {required this.page, required this.pages, required this.onPage});

  @override
  Widget build(BuildContext context) {
    Widget btn(Widget child,
            {VoidCallback? onTap, bool sel = false, String? tip}) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Semantics(
            button: true,
            enabled: onTap != null,
            selected: sel ? true : null,
            label: tip,
            excludeSemantics: true,
            onTap: onTap,
            child: Tooltip(
              message: tip ?? '',
              excludeFromSemantics: true,
              child: Material(
                color: sel ? Brand.green : Brand.surface(context),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onTap,
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? Brand.green : Brand.line(context)),
                    ),
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: sel ? Colors.white : Brand.ink(context)),
                      child: IconTheme.merge(
                        data: IconThemeData(
                            color: onTap == null
                                ? Brand.line(context)
                                : Brand.ink(context)),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Center(
      child: Wrap(runSpacing: 6, children: [
        btn(const Icon(Icons.chevron_left_rounded),
            tip: 'Página anterior',
            onTap: page > 0 ? () => onPage(page - 1) : null),
        for (var i = 0; i < pages; i++)
          btn(Text('${i + 1}'),
              tip: 'Página ${i + 1}', sel: i == page, onTap: () => onPage(i)),
        btn(const Icon(Icons.chevron_right_rounded),
            tip: 'Próxima página',
            onTap: page < pages - 1 ? () => onPage(page + 1) : null),
      ]),
    );
  }
}
