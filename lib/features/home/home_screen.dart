import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_selection.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/catalog/provider_search.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/micro_interactions.dart';
import '../company/company_public_screen.dart';

/// Hub do módulo Serviços. Categorias, grupos e serviços vêm do catálogo
/// administrável (catalogNodes); a lista de profissionais é consultada
/// no servidor para a seleção atual.
class ServicesHubScreen extends StatefulWidget {
  const ServicesHubScreen({super.key});
  @override
  State<ServicesHubScreen> createState() => _ServicesHubState();
}

class _ServicesHubState extends State<ServicesHubScreen> {
  CatalogSelection _sel = CatalogSelection.none;
  int _retryTick = 0;

  /// Verticais especializadas (módulos próprios). Uma categoria de serviço
  /// nunca libera um módulo marcado "Em desenvolvimento".
  static const _verticals = [
    {'id': 'health', 'icon': '🏥', 'label': 'Saúde', 'route': Routes.health},
    {'id': 'delivery', 'icon': '📦', 'label': 'Entregas', 'route': Routes.delivery, 'soon': 'true'},
    {'id': 'marketplace', 'icon': '🛒', 'label': 'Mercado', 'route': Routes.marketplace},
    {'id': 'rental', 'icon': '🔑', 'label': 'Locação', 'route': Routes.rental},
    {'id': 'ai', 'icon': '🤖', 'label': 'Assistente', 'route': Routes.aiAssistant},
  ];

  void _select(CatalogSelection s) {
    if (s == _sel) return;
    setState(() => _sel = s);
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => setState(() => _retryTick++),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: StreamBuilder<UserModel?>(
            stream: uid != null ? FS.userStream(uid) : const Stream.empty(),
            builder: (_, snap) {
              final user = snap.data;
              return GradHeader(
                  gradient: AppGradients.primary,
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    user?.firstName.isNotEmpty == true
                                        ? 'Olá, ${user!.firstName}'
                                        : 'Olá! Bem-vindo(a)',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.82),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: SvgPicture.asset(
                                        AppAssets.wordmarkWhite,
                                        height: 22)),
                              ]),
                          Row(children: [
                            StreamBuilder<List<NotifModel>>(
                              stream: FS.notifStream(),
                              builder: (_, notifSnap) {
                                final unread = (notifSnap.data ?? [])
                                    .where((n) => !n.read)
                                    .length;
                                return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      IconButton(
                                          tooltip: 'Notificações',
                                          onPressed: () => Navigator.pushNamed(
                                              context, Routes.notifications),
                                          icon: const Icon(
                                              Icons.notifications_none_rounded,
                                              color: Colors.white,
                                              size: 26)),
                                      if (unread > 0)
                                        Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                  color: AppColors.error,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: AppColors.primary,
                                                      width: 1.5)),
                                              constraints: const BoxConstraints(
                                                  minWidth: 16),
                                              child: Text(
                                                  unread > 9 ? '9+' : '$unread',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.w800)),
                                            )),
                                    ]);
                              },
                            ),
                            Tooltip(
                                message: 'Meu perfil',
                                child: Semantics(
                                    button: true,
                                    label: 'Meu perfil',
                                    excludeSemantics: true,
                                    child: GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                            context, Routes.profile),
                                        child: AppAvatar(
                                            url: user?.photoUrl,
                                            name: user?.name ?? '?',
                                            size: 40,
                                            bg: AppColors.warning,
                                            r: 12)))),
                          ]),
                        ]),
                    const SizedBox(height: 14),
                    AppSearchBar(
                        hint: 'Buscar serviços, profissionais...',
                        readOnly: true,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.search)),
                  ]));
            },
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecHeader(title: 'O que você precisa hoje?'),
              const SizedBox(height: 12),
              _tileGrid([
                for (final v in _verticals)
                  _tile(v['icon']!, v['label']!,
                      () => Navigator.pushNamed(context, v['route']!),
                      soon: v['soon'] == 'true'),
              ]),
            ]),
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(children: [
              Expanded(
                  child: _banner(
                      '🏥',
                      'Saúde Carajás 360',
                      'Médico · Psicólogo · Fisio',
                      AppGradients.health,
                      Routes.health)),
              const SizedBox(width: 10),
              Expanded(
                  child: _banner('📦', 'Entregas', 'Em breve no Carajás 360',
                      AppGradients.delivery, Routes.delivery)),
            ]),
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            child: SizedBox(
                height: 130,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _promoBanner('promocoes', Routes.coupons),
                    _promoBanner('marketplace', Routes.marketplace),
                    // Cashback real: compras entregues do Mercado (carteira).
                    _promoBanner('cashback', Routes.wallet),
                    _promoBanner('cupons', Routes.coupons),
                    _promoBanner('home_care', Routes.health),
                    // "Empresas" removido: o banner promete gestão de
                    // manutenção, mas o destino é só o cadastro.
                  ],
                )),
          )),
          SliverToBoxAdapter(
            child: CatalogBuilder(
              key: ValueKey('hub-cat-$_retryTick'),
              compact: true,
              builder: (_, catalog) {
                final sel = _sel.sanitize(catalog);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 6),
                      child: SecHeader(title: 'Categorias')),
                  CatalogChipSelector(
                      catalog: catalog, selection: sel, onChanged: _select),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: SecHeader(
                          title: sel.isEmpty
                              ? 'Em destaque'
                              : 'Em destaque · ${catalog.nameOf(sel.selectedId)}',
                          action: 'Ver todos →',
                          onAction: () => Navigator.pushNamed(context, Routes.search,
                              arguments: {if (sel.selectedId != null) 'catalogId': sel.selectedId}))),
                  _FeaturedProviders(
                      key: ValueKey('featured-${sel.key}-$_retryTick'),
                      catalog: catalog,
                      selection: sel),
                ]);
              },
            ),
          ),
          SliverToBoxAdapter(
              child: uid != null
                  ? StreamBuilder<UserModel?>(
                      stream: FS.userStream(uid),
                      builder: (_, snap) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: XpCard(xp: snap.data?.xp ?? 0)),
                    )
                  : const SizedBox.shrink()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
    );
  }

  /// Grade responsiva (celular, tablet, desktop).
  Widget _tileGrid(List<Widget> tiles) => LayoutBuilder(builder: (_, box) {
        final cols = (box.maxWidth / 92).floor().clamp(4, 10);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cols,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: tiles,
        );
      });

  Widget _tile(String icon, String label, VoidCallback onTap,
          {bool soon = false}) =>
      Semantics(
        button: true,
        label: soon ? '$label, em breve' : label,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
              decoration: AppDecorations.card(r: 14),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              // Com selo: reduz para caber na célula (sem estouro).
              child: _fitIf(soon, Column(mainAxisSize: MainAxisSize.min, children: [
                Text(icon, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 5),
                Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark),
                    textAlign: TextAlign.center),
                // Mesmo selo dos módulos da Home.
                if (soon)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Text('Em breve',
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning)),
                  ),
              ]))),
        ),
      );

  static Widget _fitIf(bool fit, Widget child) => fit
      ? Center(child: FittedBox(fit: BoxFit.scaleDown, child: child))
      : child;

  Widget _promoBanner(String slug, String route) {
    final path = AppAssets.banners[slug];
    if (path == null) return const SizedBox.shrink();
    // Largura responsiva: ~80% da tela, limitada entre 260 e 320, para
    // ficar bem tanto em celulares pequenos quanto em tablets.
    final w = (MediaQuery.of(context).size.width * 0.8).clamp(260.0, 320.0);
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        width: w,
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        decoration:
            BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ]),
        child: SvgPicture.asset(path, fit: BoxFit.cover),
      ),
    );
  }

  Widget _banner(
          String icon, String title, String sub, Gradient g, String route) =>
      GestureDetector(
          onTap: () => Navigator.pushNamed(context, route),
          child: Container(
            decoration: AppDecorations.gradient(g, r: 18),
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
            ]),
          ));

}

/// Primeira página de profissionais para a seleção atual. Ao trocar a
/// seleção, o widget é recriado (key): nunca exibe resultados antigos.
class _FeaturedProviders extends StatefulWidget {
  final Catalog catalog;
  final CatalogSelection selection;
  const _FeaturedProviders({super.key, required this.catalog, required this.selection});
  @override
  State<_FeaturedProviders> createState() => _FeaturedProvidersState();
}

class _FeaturedProvidersState extends State<_FeaturedProviders> {
  late Future<ProviderPage> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = ProviderSearch().fetch(
        ProviderQuery(catalogToken: widget.selection.token(widget.catalog)),
        pageSize: 5);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 12,
            MediaQuery.of(context).size.width > 980 ? MediaQuery.of(context).size.width - 940 : 16, 0),
        child: FutureBuilder<ProviderPage>(
          future: _future,
          builder: (_, snap) {
            if (snap.hasError) {
              return QueryErrorView(
                  error: snap.error,
                  title: 'Não foi possível carregar profissionais',
                  onRetry: () => setState(_load));
            }
            if (snap.connectionState != ConnectionState.done) {
              return Column(children: List.generate(3, (_) => const SkeletonCard()));
            }
            final list = snap.data!.items
                .where((p) => widget.selection.matches(widget.catalog, p.categories))
                .toList();
            if (list.isEmpty) {
              return EmptyState(
                  emoji: '🔍',
                  title: 'Nenhum profissional disponível',
                  subtitle: widget.selection.isEmpty
                      ? 'Ainda não há profissionais aprovados disponíveis.'
                      : 'Ainda não há profissionais aprovados em '
                          '${widget.catalog.nameOf(widget.selection.selectedId)}.');
            }
            return Column(children: [
              for (final p in list)
                ProviderResultCard(
                    provider: p, catalog: widget.catalog, selection: widget.selection),
            ]);
          },
        ),
      );
}

/// Card de profissional ligado ao catálogo (especialidade correta na
/// contratação; serviço desativado bloqueia nova contratação).
class ProviderResultCard extends StatelessWidget {
  final ProviderModel provider;
  final Catalog catalog;
  final CatalogSelection selection;
  const ProviderResultCard(
      {super.key, required this.provider, required this.catalog, required this.selection});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final specialty = selection.contractedCategory(catalog, p.categories);
    return ProvCard(
      key: ValueKey(p.id),
      name: p.name,
      role: specialty.isEmpty ? 'Profissional' : catalog.nameOf(specialty),
      badge: p.badge,
      price: p.minPrice != null
          ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(0)}'
          : 'Consultar',
      rating: p.rating,
      reviews: p.totalReviews,
      isOnline: p.modalities.contains('online'),
      photo: p.photoUrl,
      providerId: p.id,
      onTap: () => Navigator.pushNamed(context, Routes.providerProfile, arguments: {
        'providerId': p.id,
        'category': specialty,
      }),
      onChat: () => ChatNav.open(context,
          otherUserId: p.userId.isNotEmpty ? p.userId : p.id,
          otherName: p.name,
          otherPhoto: p.photoUrl),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BUSCA
// ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  /// Item do catálogo pré-selecionado (categoria, grupo ou serviço).
  final String? initialCatalogId;
  const SearchScreen({super.key, this.initialCatalogId});
  @override
  State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  // Campo de preço da folha de filtros (descartado no dispose).
  final _priceCtrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  CatalogSelection? _pendingInitial;
  /// Usuário pediu para buscar o texto no nome (ignora correspondência
  /// com o catálogo).
  bool _nameOnly = false;
  CatalogSelection _sel = CatalogSelection.none;
  String? _city;
  String? _modality;
  double? _minRating;
  double? _maxPrice;
  ProviderSort _sort = ProviderSort.rating;

  // Paginação
  final _items = <ProviderModel>[];
  dynamic _cursor;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  int _generation = 0;
  String? _queryKey;

  // Empresas
  Future<List<CompanyHit>>? _companies;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    if (widget.initialCatalogId != null) {
      _pendingInitial = const CatalogSelection(); // resolvido com o catálogo
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _scroll.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _q = v.trim();
        _nameOnly = false;
      });
    });
  }

  /// Consulta efetiva: seleção explícita OU correspondência forte do texto
  /// com um item do catálogo ("eletricista" busca o serviço); senão o
  /// texto é procurado no NOME dos profissionais.
  ({ProviderQuery query, CatalogNode? implicit}) _effective(Catalog c) {
    CatalogNode? implicit;
    var token = _sel.token(c);
    var nameText = _q;
    if (token == null && _q.isNotEmpty && !_nameOnly) {
      final m = c.search(_q, verticals: {CatalogVertical.services, CatalogVertical.health}, limit: 1);
      if (m.isNotEmpty && m.first.score >= 80) {
        implicit = m.first.node;
        token = Catalog.tokenFor(implicit);
        nameText = '';
      }
    }
    return (
      query: ProviderQuery(
          catalogToken: token,
          nameText: nameText,
          city: _city,
          modality: _modality,
          minRating: _minRating,
          maxInitialPrice: _maxPrice,
          sort: _sort),
      implicit: implicit,
    );
  }

  void _ensureQuery(ProviderQuery q) {
    if (q.key == _queryKey) return;
    _queryKey = q.key;
    _generation++;
    _items.clear();
    _cursor = null;
    _hasMore = true;
    _error = null;
    _loading = false;
    _companies = _q.length >= 2 ? CompanySearch().byName(_q) : null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore(q));
  }

  ProviderQuery? _current;

  Future<void> _loadMore([ProviderQuery? q]) async {
    final query = q ?? _current;
    if (query == null || _loading || !_hasMore) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ProviderSearch().fetch(query, after: _cursor, pageSize: 20);
      if (!mounted || gen != _generation) return; // resposta antiga: descarta
      setState(() {
        _items.addAll(page.items.where((p) => !_items.any((x) => x.id == p.id)));
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _retry() {
    setState(() {
      _error = null;
      _hasMore = true;
    });
    _loadMore();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
              controller: _ctrl,
              autofocus: widget.initialCatalogId == null,
              onChanged: _onText,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                  hintText: 'Serviço, profissional ou empresa',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 14))),
          actions: [
            IconButton(
                tooltip: 'Filtros',
                icon: const Icon(Icons.tune_rounded),
                onPressed: _openFilters),
          ],
        ),
        body: CatalogBuilder(builder: (_, catalog) {
          if (_pendingInitial != null) {
            _sel = CatalogSelection.forNode(catalog, widget.initialCatalogId!).sanitize(catalog);
            _pendingInitial = null;
          }
          _sel = _sel.sanitize(catalog);
          final eff = _effective(catalog);
          _current = eff.query;
          _ensureQuery(eff.query);
          final matches = _q.isEmpty
              ? const <CatalogMatch>[]
              : catalog.search(_q, verticals: {CatalogVertical.services, CatalogVertical.health}, limit: 6);
          final otherVerticals = _q.isEmpty
              ? const <CatalogMatch>[]
              : catalog.search(_q, verticals: {CatalogVertical.market, CatalogVertical.rental}, limit: 3);
          // Desktop: conteúdo centralizado com largura legível.
          return ListView(controller: _scroll, padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 980
                  ? (MediaQuery.of(context).size.width - 940) / 2
                  : 0), children: [
            CatalogChipSelector(
                catalog: catalog,
                selection: _sel,
                onChanged: (s) => setState(() => _sel = s)),
            _activeFilters(catalog, eff.implicit),
            if (matches.isNotEmpty) ...[
              _section('Serviços e categorias'),
              for (final m in matches) _catalogTile(catalog, m.node),
            ],
            if (otherVerticals.isNotEmpty) _verticalShortcuts(otherVerticals),
            if (_companies != null) _companySection(),
            _section(eff.implicit != null
                ? 'Profissionais · ${eff.implicit!.name}'
                : (_q.isNotEmpty && _sel.isEmpty ? 'Profissionais com "$_q" no nome' : 'Profissionais')),
            ..._providerList(catalog),
            const SizedBox(height: 40),
          ]);
        }),
      );

  Widget _section(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(t,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)));

  Widget _catalogTile(Catalog c, CatalogNode n) {
    final path = c.pathOf(n.id).map((x) => x.name).join(' › ');
    return ListTile(
      leading: Text(n.icon, style: const TextStyle(fontSize: 22)),
      title: Text(n.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: AppTag(n.levelLabel, bg: AppColors.primarySoft, fg: AppColors.primary),
      onTap: () {
        if (n.vertical == CatalogVertical.health) {
          Navigator.pushNamed(context, Routes.health, arguments: {'catalogId': n.id});
          return;
        }
        _ctrl.clear();
        setState(() {
          _q = '';
          _sel = CatalogSelection.forNode(c, n.id);
        });
      },
    );
  }

  Widget _verticalShortcuts(List<CatalogMatch> ms) {
    final hasMarket = ms.any((m) => m.node.vertical == CatalogVertical.market);
    final hasRental = ms.any((m) => m.node.vertical == CatalogVertical.rental);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        if (hasMarket)
          ActionChip(
              avatar: const Text('🛒'),
              label: const Text('Procurar produtos no Mercado'),
              onPressed: () => Navigator.pushNamed(context, Routes.marketplace)),
        if (hasRental)
          ActionChip(
              avatar: const Text('🔑'),
              label: const Text('Ver anúncios de Locação'),
              onPressed: () => Navigator.pushNamed(context, Routes.rental)),
      ]),
    );
  }

  Widget _companySection() => FutureBuilder<List<CompanyHit>>(
        future: _companies,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
          if (snap.hasError || (snap.data ?? const []).isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _section('Empresas'),
            for (final c in snap.data!)
              ListTile(
                leading: AppAvatar(url: c.logoUrl, name: c.name, size: 40, r: 10),
                title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: c.city == null ? null : Text(c.city!),
                trailing: const AppTag('Empresa', bg: AppColors.surfaceMuted, fg: AppColors.textDark),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CompanyPublicScreen(companyId: c.id))),
              ),
          ]);
        },
      );

  List<Widget> _providerList(Catalog c) {
    if (_error != null && _items.isEmpty) {
      return [
        Padding(
            padding: const EdgeInsets.all(16),
            child: QueryErrorView(
                error: _error, title: 'Não foi possível buscar profissionais', onRetry: _retry))
      ];
    }
    if (_items.isEmpty && (_loading || _hasMore)) {
      return [
        for (var i = 0; i < 4; i++)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SkeletonCard())
      ];
    }
    if (_items.isEmpty) {
      return const [
        EmptyState(
            emoji: '🔍',
            title: 'Nenhum profissional encontrado',
            subtitle: 'Tente outro serviço, cidade ou filtros.',
            asset: AppAssets.estadoNenhumResultado)
      ];
    }
    return [
      for (var i = 0; i < _items.length; i++)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FadeSlideIn(
                index: i % 20,
                child: ProviderResultCard(provider: _items[i], catalog: c, selection: _sel))),
      if (_loading)
        const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(semanticsLabel: 'Carregando mais'))),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.all(16),
            child: QueryErrorView(error: _error, onRetry: _retry)),
      if (!_loading && _hasMore && _error == null)
        Center(
            child: TextButton(onPressed: _loadMore, child: const Text('Carregar mais'))),
      if (!_hasMore)
        const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: Text('Fim dos resultados',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight)))),
    ];
  }

  Widget _activeFilters(Catalog c, CatalogNode? implicit) {
    final chips = <Widget>[
      if (implicit != null)
        InputChip(
            label: Text('Serviço: ${implicit.name}'),
            onDeleted: () => setState(() => _nameOnly = true),
            tooltip: 'Buscar "$_q" no nome dos profissionais'),
      if (_city != null)
        InputChip(label: Text('📍 $_city'), onDeleted: () => setState(() => _city = null)),
      if (_modality != null)
        InputChip(
            label: Text(_modalityLabel(_modality!)),
            onDeleted: () => setState(() => _modality = null)),
      if (_minRating != null)
        InputChip(
            label: Text('⭐ ${_minRating!.toStringAsFixed(1)}+'),
            onDeleted: () => setState(() => _minRating = null)),
      if (_maxPrice != null)
        InputChip(
            label: Text('Até R\$ ${_maxPrice!.toStringAsFixed(0)}'),
            onDeleted: () => setState(() => _maxPrice = null)),
      if (_sort != ProviderSort.rating)
        InputChip(
            label: Text(_sortLabel(_sort)),
            onDeleted: () => setState(() => _sort = ProviderSort.rating)),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Wrap(spacing: 6, runSpacing: 6, children: chips));
  }

  static String _modalityLabel(String m) => switch (m) {
        'online' => '💻 Online',
        'home_care' => '🏠 Domiciliar',
        _ => '📍 Presencial',
      };

  static String _sortLabel(ProviderSort s) => switch (s) {
        ProviderSort.rating => 'Melhor avaliação',
        ProviderSort.reviews => 'Mais avaliações',
        ProviderSort.priceAsc => 'Menor preço inicial',
      };

  void _openFilters() {
    final priceCtrl = _priceCtrl
      ..text = _maxPrice == null ? '' : _maxPrice!.toStringAsFixed(0);
    String? city = _city;
    String? modality = _modality;
    double? minRating = _minRating;
    var sort = _sort;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const SheetHandle(),
                          const SizedBox(height: 12),
                          const Text('Filtros',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: city,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Cidade', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                              for (final c in [...RegionCities.priority, ...RegionCities.nearby])
                                DropdownMenuItem<String?>(value: c, child: Text(c)),
                            ],
                            onChanged: (v) => setS(() => city = v),
                          ),
                          const SizedBox(height: 12),
                          const Text('Modalidade', style: TextStyle(fontWeight: FontWeight.w700)),
                          Wrap(spacing: 6, children: [
                            for (final m in const ['presential', 'online', 'home_care'])
                              ChoiceChip(
                                  label: Text(_modalityLabel(m)),
                                  selected: modality == m,
                                  onSelected: (on) => setS(() => modality = on ? m : null)),
                          ]),
                          const SizedBox(height: 12),
                          const Text('Avaliação mínima', style: TextStyle(fontWeight: FontWeight.w700)),
                          Wrap(spacing: 6, children: [
                            for (final r in const [null, 4.0, 4.5])
                              ChoiceChip(
                                  label: Text(r == null ? 'Todas' : '${r.toStringAsFixed(1)}+'),
                                  selected: minRating == r,
                                  onSelected: (_) => setS(() => minRating = r)),
                          ]),
                          const SizedBox(height: 12),
                          TextField(
                              controller: priceCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'Preço inicial até (R\$)',
                                  helperText: 'Profissionais sem preço informado não aparecem com este filtro',
                                  border: OutlineInputBorder())),
                          const SizedBox(height: 12),
                          const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.w700)),
                          Wrap(spacing: 6, children: [
                            for (final s in ProviderSort.values)
                              ChoiceChip(
                                  label: Text(_sortLabel(s)),
                                  selected: sort == s,
                                  onSelected: (_) => setS(() => sort = s)),
                          ]),
                          const SizedBox(height: 8),
                          const Text(
                              'Distância e disponibilidade ainda não estão disponíveis como filtro.',
                              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                          const SizedBox(height: 16),
                          SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                  onPressed: () {
                                    final p = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
                                    setState(() {
                                      _city = city;
                                      _modality = modality;
                                      _minRating = minRating;
                                      _maxPrice = (p != null && p > 0) ? p : null;
                                      _sort = sort;
                                    });
                                    Navigator.pop(ctx);
                                  },
                                  child: const Text('Aplicar'))),
                        ]),
                  ),
                )));
  }
}
