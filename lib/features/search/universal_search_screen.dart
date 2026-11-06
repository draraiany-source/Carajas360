import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/app_constants.dart';
import '../../core/search/universal_search.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/tap_guard.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_categories.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/widgets.dart';
import '../services/service_marketplace_screen.dart';

enum _Sort { relevance, rating, reviews, price }

const _sortLabels = {
  _Sort.relevance: 'Mais relevantes',
  _Sort.rating: 'Melhor avaliados',
  _Sort.reviews: 'Mais avaliados',
  _Sort.price: 'Menor preço',
};

/// Explorar Serviços: busca universal + profissionais com filtros reais.
class UniversalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const UniversalSearchScreen({super.key, this.initialQuery});

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
  late final Stream<List<ProviderModel>> _providers;

  BrandCategory? _category;
  double _minRating = 0;
  String? _modality;
  double? _maxPrice;
  _Sort _sort = _Sort.relevance;
  bool _grid = true;
  int _page = 0;

  static const _historyKey = 'carajas360_universal_search_history_v1';
  static const _pageSize = 12;
  final _resultsKey = GlobalKey();
  final _scroll = ScrollController();

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
    _providers = FS.providersStream(limit: 100);
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

  List<CompanyModel> get _homologCompanies {
    if (!HomologCatalog.enabled) return const [];
    return [
      CompanyModel(
        id: 'hc1',
        ownerId: 'hc1',
        name: 'Construtora Serra Norte',
        cnpj: '00.000.000/0001-00',
        city: 'Canaa dos Carajas',
        categories: const ['pedreiro', 'pintor'],
        verified: true,
        createdAt: DateTime(2025, 1, 1),
      ),
      CompanyModel(
        id: 'hc2',
        ownerId: 'hc2',
        name: 'Auto Center Carajas',
        cnpj: '00.000.000/0001-01',
        city: 'Parauapebas',
        categories: const ['mecanica_geral', 'funilaria'],
        verified: true,
        createdAt: DateTime(2025, 2, 1),
      ),
      CompanyModel(
        id: 'hc3',
        ownerId: 'hc3',
        name: 'Agro Servicos PA',
        cnpj: '00.000.000/0001-02',
        city: 'Canaa dos Carajas',
        categories: const ['tecnico_agricola'],
        verified: true,
        createdAt: DateTime(2025, 3, 1),
      ),
    ];
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

  /// Serviços, categorias e empresas da taxonomia; profissionais vêm do stream.
  void _runSearch(String v) {
    final hits = UniversalSearch.search(query: v, companies: _homologCompanies)
        .where((h) => h.kind != UniversalHitKind.provider)
        .take(8)
        .toList();
    if (!mounted) return;
    setState(() => _hits = hits);
  }

  void _setQuery(String s) {
    _ctrl.text = s;
    _ctrl.selection =
        TextSelection.fromPosition(TextPosition(offset: s.length));
    _onChanged(s);
    _pushHistory(s);
  }

  void _clearQuery() {
    _ctrl.clear();
    setState(() {
      _q = '';
      _hits = const [];
      _suggestions = const [];
      _page = 0;
    });
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
        Navigator.pushNamed(context, Routes.requestService, arguments: {
          'providerId': hit.id,
          'providerName': hit.title,
          'category': hit.categoryId ?? '',
        });
        return;
      case UniversalHitKind.company:
        Navigator.pushNamed(context, Routes.companyProfile);
        return;
      case UniversalHitKind.category:
        break;
    }
    if (hit.categoryId != null) {
      Navigator.pushNamed(context, Routes.search,
          arguments: {'category': hit.categoryId});
    }
  }

  void _selectCategory(BrandCategory? c) {
    if (c?.route != null) {
      Navigator.pushNamed(context, c!.route!);
      return;
    }
    setState(() {
      _category = c;
      _page = 0;
    });
  }

  bool get _hasFilters =>
      _category != null ||
      _minRating > 0 ||
      _modality != null ||
      _maxPrice != null ||
      _sort != _Sort.relevance;

  void _clearFilters() => setState(() {
        _category = null;
        _minRating = 0;
        _modality = null;
        _maxPrice = null;
        _sort = _Sort.relevance;
        _page = 0;
      });

  bool _matchesCategory(ProviderModel p) {
    final c = _category;
    if (c == null) return true;
    if (c.category != null) return p.categories.contains(c.category);
    if (c.group != null) {
      return p.categories.any((id) => Categories.byId(id)?.group == c.group);
    }
    return true;
  }

  bool _matchesQuery(ProviderModel p) {
    final q = _q.trim();
    if (q.isEmpty) return true;
    final cats = p.categories.map((id) => Categories.byId(id)?.name ?? id);
    final haystack = [p.name, ...cats, p.bio ?? '', p.city ?? ''].join(' ');
    return q
        .split(RegExp(r'\s+'))
        .every((word) => UniversalSearch.fuzzyMatch(haystack, word));
  }

  List<ProviderModel> _apply(List<ProviderModel> all) {
    final list = all.where((p) {
      if (!_matchesCategory(p) || !_matchesQuery(p)) return false;
      if (_minRating > 0 && (p.totalReviews == 0 || p.rating < _minRating)) {
        return false;
      }
      if (_modality != null && !p.modalities.contains(_modality)) return false;
      if (_maxPrice != null &&
          (p.minPrice == null || p.minPrice! > _maxPrice!)) {
        return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case _Sort.relevance:
        break;
      case _Sort.rating:
        list.sort((a, b) => b.rating.compareTo(a.rating));
      case _Sort.reviews:
        list.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
      case _Sort.price:
        list.sort((a, b) => (a.minPrice ?? double.infinity)
            .compareTo(b.minPrice ?? double.infinity));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return Scaffold(
      backgroundColor: Brand.isDark(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : Brand.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final pad = wide ? 28.0 : 16.0;
          return StreamBuilder<List<ProviderModel>>(
            stream: _providers,
            builder: (context, snap) {
              var all = snap.data ?? const <ProviderModel>[];
              if (all.isEmpty && HomologCatalog.enabled) {
                all = HomologCatalog.providers();
              }
              final loading = snap.connectionState == ConnectionState.waiting &&
                  all.isEmpty &&
                  !HomologCatalog.enabled;
              final results = _apply(all);
              final pages = (results.length / _pageSize).ceil();
              final page = pages == 0 ? 0 : _page.clamp(0, pages - 1);
              final visible =
                  results.skip(page * _pageSize).take(_pageSize).toList();

              Widget box(Widget child, {double top = 0, bool bleed = false}) =>
                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            bleed ? 0 : pad, top, bleed ? 0 : pad, 0),
                        child: child,
                      ),
                    ),
                  );

              return ListView(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 100),
                children: [
                  box(_Header(wide: wide, canPop: canPop), top: wide ? 20 : 12),
                  box(
                    _SearchBox(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: canPop && widget.initialQuery == null,
                      onChanged: _onChanged,
                      onSubmitted: (v) {
                        _pushHistory(v);
                        _runSearch(v);
                      },
                      onClear: _clearQuery,
                    ),
                    top: 16,
                  ),
                  if (_q.trim().isEmpty && _history.isNotEmpty)
                    box(
                      _ChipLine(
                        title: 'Buscas recentes',
                        items: _history.take(8).toList(),
                        icon: Icons.history_rounded,
                        onTap: _setQuery,
                        action: 'Limpar',
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
                  box(
                    _FilterBar(
                      wide: wide,
                      minRating: _minRating,
                      modality: _modality,
                      maxPrice: _maxPrice,
                      sort: _sort,
                      grid: _grid,
                      hasFilters: _hasFilters,
                      onRating: (v) => setState(() {
                        _minRating = v;
                        _page = 0;
                      }),
                      onModality: (v) => setState(() {
                        _modality = v;
                        _page = 0;
                      }),
                      onPrice: (v) => setState(() {
                        _maxPrice = v;
                        _page = 0;
                      }),
                      onSort: (v) => setState(() => _sort = v),
                      onGrid: (v) => setState(() => _grid = v),
                      onClear: _clearFilters,
                    ),
                    top: 16,
                  ),
                  box(
                    Text(
                      key: _resultsKey,
                      loading
                          ? 'Carregando profissionais...'
                          : '${results.length} ${results.length == 1 ? 'profissional encontrado' : 'profissionais encontrados'}'
                              '${_q.trim().isNotEmpty ? ' para "${_q.trim()}"' : ''}',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.inkMuted(context)),
                    ),
                    top: 16,
                  ),
                  box(
                    loading
                        ? const ShimCard()
                        : snap.hasError && all.isEmpty
                            ? const InfoBanner(
                                icon: '⚠️',
                                text:
                                    'Não foi possível carregar os profissionais agora. Tente novamente em instantes.',
                                bg: Brand.greenLight,
                                fg: Brand.greenDark,
                              )
                            : results.isEmpty
                                ? _EmptyResults(
                                    hasFilters: _hasFilters || _q.isNotEmpty,
                                    onClear: () {
                                      _clearFilters();
                                      _clearQuery();
                                    },
                                    onRequest: () => Navigator.pushNamed(
                                        context, Routes.resolve),
                                  )
                                : _grid
                                    ? _ResultsGrid(list: visible, wide: wide)
                                    : _ResultsList(list: visible),
                    top: 12,
                  ),
                  if (pages > 1)
                    box(
                      _Pagination(
                        page: page,
                        pages: pages,
                        onPage: _goToPage,
                      ),
                      top: 20,
                    ),
                ],
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cabeçalho e busca
// ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool wide, canPop;
  const _Header({required this.wide, required this.canPop});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          wide ? 28 : 16, wide ? 22 : 16, wide ? 28 : 16, wide ? 22 : 16),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: wide ? 10 : -6,
          top: wide ? -10 : -8,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.16,
              child: SvgPicture.asset('assets/logos/logo_mark_mono_white.svg',
                  width: wide ? 110 : 64),
            ),
          ),
        ),
        Row(children: [
          if (canPop) ...[
            Material(
              color: Colors.white.withValues(alpha: 0.14),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Explorar Serviços',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 28 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Encontre rapidamente o serviço ideal na sua região.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.86),
                        fontSize: wide ? 14.5 : 13)),
              ],
            ),
          ),
        ]),
      ]),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear;
  const _SearchBox({
    required this.controller,
    required this.focusNode,
    required this.autofocus,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.line(context)),
        boxShadow: Brand.shadow(context),
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        const Icon(Icons.search_rounded, color: Brand.green, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 15, color: Brand.ink(context)),
            decoration: InputDecoration(
              hintText: 'Serviço, categoria ou profissional...',
              hintStyle:
                  TextStyle(color: Brand.inkMuted(context), fontSize: 14),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox(width: 12)
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon:
                      Icon(Icons.close_rounded, color: Brand.inkMuted(context)),
                  onPressed: onClear,
                ),
        ),
      ]),
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
                  foregroundColor: Brand.green, minimumSize: const Size(0, 32)),
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
    final items = <(String, IconData, bool, VoidCallback)>[
      (
        'Todos',
        Icons.grid_view_rounded,
        selected == null,
        () => onSelect(null)
      ),
      for (final c in brandCategories)
        (c.label, c.icon, selected == c, () => onSelect(c)),
      ('Mais categorias', Icons.add_rounded, false, onMore),
    ];
    return SizedBox(
      height: 96,
      child: ScrollConfiguration(
        behavior: const BrandDragScrollBehavior(),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: pad),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final (label, icon, sel, onTap) = items[i];
            return Semantics(
              button: true,
              selected: sel ? true : null,
              label: label,
              excludeSemantics: true,
              onTap: onTap,
              child: Material(
                color: sel ? Brand.goldLight : Brand.surface(context),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onTap,
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: sel ? Brand.gold : Brand.line(context),
                          width: sel ? 1.6 : 1),
                    ),
                    child: Column(children: [
                      Icon(icon,
                          size: 26, color: sel ? Brand.goldDeep : Brand.green),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(label,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                height: 1.2,
                                fontWeight:
                                    sel ? FontWeight.w800 : FontWeight.w700,
                                color: Brand.ink(context))),
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

class _FilterMenu<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  const _FilterMenu({
    required this.icon,
    required this.label,
    required this.active,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: label,
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
      child: ExcludeSemantics(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? Brand.greenLight : Brand.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? Brand.green : Brand.line(context)),
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
      )),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final bool wide, grid, hasFilters;
  final double minRating;
  final String? modality;
  final double? maxPrice;
  final _Sort sort;
  final ValueChanged<double> onRating;
  final ValueChanged<String?> onModality;
  final ValueChanged<double?> onPrice;
  final ValueChanged<_Sort> onSort;
  final ValueChanged<bool> onGrid;
  final VoidCallback onClear;
  const _FilterBar({
    required this.wide,
    required this.minRating,
    required this.modality,
    required this.maxPrice,
    required this.sort,
    required this.grid,
    required this.hasFilters,
    required this.onRating,
    required this.onModality,
    required this.onPrice,
    required this.onSort,
    required this.onGrid,
    required this.onClear,
  });

  String _money(double v) => 'R\$ ${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final filters = [
      _FilterMenu<double>(
        icon: Icons.star_outline_rounded,
        label: minRating > 0
            ? 'Avaliação ${minRating.toStringAsFixed(1)}+'
            : 'Avaliação',
        active: minRating > 0,
        value: minRating,
        options: const [
          (0.0, 'Qualquer'),
          (4.0, '4,0 ou mais'),
          (4.5, '4,5 ou mais'),
        ],
        onSelected: onRating,
      ),
      _FilterMenu<double>(
        icon: Icons.sell_outlined,
        label: maxPrice != null ? 'Até ${_money(maxPrice!)}' : 'Preço',
        active: maxPrice != null,
        value: maxPrice ?? -1,
        options: const [
          (-1.0, 'Qualquer'),
          (100.0, 'Preço inicial até R\$ 100'),
          (200.0, 'Preço inicial até R\$ 200'),
        ],
        onSelected: (v) => onPrice(v < 0 ? null : v),
      ),
      _FilterMenu<String>(
        icon: Icons.event_available_outlined,
        label: switch (modality) {
          'online' => 'Online',
          'presential' => 'Presencial',
          _ => 'Atendimento',
        },
        active: modality != null,
        value: modality ?? '',
        options: const [
          ('', 'Todos'),
          ('presential', 'Presencial'),
          ('online', 'Online'),
        ],
        onSelected: (v) => onModality(v.isEmpty ? null : v),
      ),
      _FilterMenu<_Sort>(
        icon: Icons.sort_rounded,
        label: _sortLabels[sort]!,
        active: sort != _Sort.relevance,
        value: sort,
        options: [for (final s in _Sort.values) (s, _sortLabels[s]!)],
        onSelected: onSort,
      ),
      if (hasFilters)
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text('Limpar filtros'),
          style: TextButton.styleFrom(foregroundColor: Brand.green),
        ),
    ];
    final toggle = Container(
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
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: wide
            ? Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              )
            : ScrollConfiguration(
                behavior: const BrandDragScrollBehavior(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in filters) ...[f, const SizedBox(width: 8)],
                  ]),
                ),
              ),
      ),
      const SizedBox(width: 12),
      toggle,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Resultados
// ─────────────────────────────────────────────────────────────

class _ResultsGrid extends StatelessWidget {
  final List<ProviderModel> list;
  final bool wide;
  const _ResultsGrid({required this.list, required this.wide});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 14.0;
      final minW = wide ? 210.0 : 158.0;
      final cols = ((c.maxWidth + gap) / (minW + gap)).floor().clamp(1, 6);
      final w = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in list)
            SizedBox(
                width: w, height: 318, child: BrandProviderCard(provider: p)),
        ],
      );
    });
  }
}

class _ResultsList extends StatelessWidget {
  final List<ProviderModel> list;
  const _ResultsList({required this.list});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final p in list) ...[
        _ProviderRow(provider: p),
        const SizedBox(height: 10),
      ],
    ]);
  }
}

class _ProviderRow extends StatelessWidget {
  final ProviderModel provider;
  const _ProviderRow({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final price = p.minPrice != null
        ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
        : 'Valor sob consulta';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Brand.line(context)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              width: 72, height: 72, child: BrandProviderPhoto(provider: p)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Brand.ink(context))),
                ),
                if (p.verified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded,
                      size: 16, color: Brand.green),
                ],
              ]),
              Text(
                  [
                    providerCategoryName(p),
                    if (p.city != null && p.city!.isNotEmpty) p.city!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Brand.inkMuted(context))),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.star_rounded, size: 15, color: Brand.gold),
                const SizedBox(width: 2),
                Text(
                    p.totalReviews > 0
                        ? '${p.rating.toStringAsFixed(1)} (${p.totalReviews})'
                        : 'Novo',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Brand.ink(context))),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Brand.green)),
                ),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        BrandFavoriteButton(providerId: p.id),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: TapGuard.wrap(() => requestProviderService(context, p)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Brand.green,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          ),
          child: const Text('Solicitar',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ]),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.line(context)),
      ),
      child: Column(children: [
        const Icon(Icons.search_off_rounded, size: 40, color: Brand.green),
        const SizedBox(height: 10),
        Text('Nenhum profissional encontrado',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Brand.ink(context))),
        const SizedBox(height: 4),
        Text(
            hasFilters
                ? 'Ajuste os filtros ou descreva o que precisa para receber propostas.'
                : 'Ainda não há profissionais cadastrados. Descreva o que precisa para receber propostas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Brand.inkMuted(context))),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            if (hasFilters)
              OutlinedButton(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Brand.green,
                    side: const BorderSide(color: Brand.green)),
                child: const Text('Limpar filtros'),
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
        ),
      ]),
    );
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
                    width: 38,
                    height: 38,
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
      child: Wrap(children: [
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
