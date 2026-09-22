import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/demo_data.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/utils/perf_log.dart';
import '../../core/utils/tap_guard.dart';
import '../../core/constants/category_icons.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/micro_interactions.dart';
import '../services/service_marketplace_screen.dart';

/// Hub do módulo Serviços (profissionais da região).
/// A Home da plataforma Carajás 360 fica em [HomeScreen] (carajas_home_screen.dart).
class ServicesHubScreen extends StatefulWidget {
  const ServicesHubScreen({super.key});
  @override
  State<ServicesHubScreen> createState() => _ServicesHubState();
}

class _ServicesHubState extends State<ServicesHubScreen> {
  String _selGroup = 'Todos';
  // Grupos vindos da fonte única de categorias — assim novos segmentos
  // (Agro, Drones, Máquinas, Veículos, Lojas...) aparecem automaticamente.
  final _groups = ['Todos', ...Categories.groups];

  static const _modules = [
    {'id': 'services', 'label': 'Serviços'},
    {'id': 'health', 'label': 'Saúde'},
    {'id': 'delivery', 'label': 'Entregas'},
    {'id': 'marketplace', 'label': 'Mercado'},
    {'id': 'rental', 'label': 'Aluguel'},
    {'id': 'machines', 'label': 'Máquinas'},
    {'id': 'vehicles', 'label': 'Veículos'},
    {'id': 'labor', 'label': 'Mão de Obra'},
    {'id': 'drones', 'label': 'Drones'},
    {'id': 'pets', 'label': 'Pets'},
    {'id': 'beauty', 'label': 'Beleza'},
    {'id': 'education', 'label': 'Educação'},
    {'id': 'agro', 'label': 'Agro'},
    {'id': 'ai', 'label': 'IA'},
  ];

  static final _demoProviders = [
    ProviderModel(
        id: 'd1',
        userId: 'u1',
        name: 'Carlos Silva',
        categories: ['eletricista'],
        rating: 4.9,
        totalReviews: 312,
        modalities: ['presential'],
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'd2',
        userId: 'u2',
        name: 'Ana Oliveira',
        categories: ['diarista'],
        rating: 4.8,
        totalReviews: 524,
        modalities: ['presential'],
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'd3',
        userId: 'u3',
        name: 'Dr. Marcos',
        categories: ['medico'],
        rating: 5.0,
        totalReviews: 480,
        modalities: ['online', 'presential'],
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'd4',
        userId: 'u4',
        name: 'Julia Santos',
        categories: ['cabeleireiro'],
        rating: 4.7,
        totalReviews: 198,
        modalities: ['presential'],
        createdAt: DateTime.now()),
  ];

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CarajasAppBar(title: 'Serviços'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 600));
          if (mounted) setState(() {});
        },
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
                                    'Olá, ${user?.firstName.isNotEmpty == true ? user!.firstName : 'Bem-vindo'}',
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.82),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: SafeSvg(
                                        AppAssets.wordmarkWhite,
                                        height: 22,
                                        fallback: Text(AppInfo.name,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18)))),
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
                            GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                    context, Routes.profile),
                                child: AppAvatar(
                                    url: user?.photoUrl,
                                    name: user?.name ?? '?',
                                    size: 40,
                                    bg: AppColors.warning,
                                    r: 12)),
                          ]),
                        ]),
                    const SizedBox(height: 14),
                    AppSearchBar(
                        hint: 'O que você precisa?',
                        readOnly: true,
                        onTap: () => Navigator.pushNamed(
                            context, Routes.universalSearch)),
                  ]));
            },
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecHeader(title: 'O que você precisa hoje?'),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: MediaQuery.sizeOf(context).width >= 900
                    ? 7
                    : (MediaQuery.sizeOf(context).width >= 600 ? 5 : 4),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.95,
                children: _modules
                    .map((m) => GestureDetector(
                        onTap: () => _navigate(m['id']!),
                        child: Container(
                            decoration: AppDecorations.card(r: 12),
                            padding: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 2),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CategoryIcons.forModule(m['id']!),
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(m['label']!,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ]))))
                    .toList(),
              ),
            ]),
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: Row(children: [
              Expanded(
                  child: _banner(
                      '🏥',
                      'Saúde 360',
                      'Médico · Psicólogo · Fisio',
                      AppGradients.health,
                      Routes.health)),
              const SizedBox(width: 10),
              Expanded(
                  child: _banner('📦', 'Entregas', 'GPS em tempo real',
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
                    _promoBanner('cashback', Routes.wallet),
                    _promoBanner('cupons', Routes.coupons),
                    _promoBanner('home_care', Routes.health),
                    _promoBanner('empresas', Routes.companyProfile),
                  ],
                )),
          )),
          SliverToBoxAdapter(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SecHeader(title: 'Categorias')),
              const SizedBox(height: 10),
              SizedBox(
                  height: 40,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _groups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final sel = _selGroup == _groups[i];
                        return GestureDetector(
                            onTap: () => setState(() => _selGroup = _groups[i]),
                            child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : AppColors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: sel
                                            ? AppColors.primary
                                            : AppColors.border)),
                                child: Text(_groups[i],
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: sel
                                            ? AppColors.white
                                            : AppColors.textDark))));
                      })),
              // Categorias do grupo selecionado — dá acesso direto aos
              // segmentos (Agro, Drones, Máquinas, Veículos, Lojas...).
              if (_selGroup != 'Todos')
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: Categories.all
                            .where((c) => c.group == _selGroup)
                            .length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c = Categories.all
                              .where((c) => c.group == _selGroup)
                              .elementAt(i);
                          return CatChip(
                              emoji: c.emoji,
                              name: c.name,
                              categoryId: c.id,
                              color: c.color,
                              selected: false,
                              onTap: () {
                                final svc =
                                    ServiceTaxonomy.serviceByCategoryId(c.id);
                                if (svc != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ServiceRequestFlowScreen(service: svc),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.pushNamed(context, Routes.search,
                                    arguments: {'category': c.id});
                              });
                        },
                      )),
                ),
            ]),
          )),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                          context, Routes.serviceMarketplace),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('Abrir marketplace completo',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SecHeader(
                      title: 'Em destaque',
                      action: 'Ver todos →',
                      onAction: () => Navigator.pushNamed(
                            context,
                            Routes.search,
                            arguments: {
                              if (_selGroup != 'Todos') 'group': _selGroup,
                            },
                          )))),
          SliverToBoxAdapter(
              child: _NearbyProvidersList(
                group: _selGroup == 'Todos' ? null : _selGroup,
                demoFallback: _demoProviders,
              )),
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
        child: SafeSvg(path, fit: BoxFit.cover),
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

  void _navigate(String id) {
    switch (id) {
      case 'health':
        Navigator.pushNamed(context, Routes.health);
        break;
      case 'delivery':
        Navigator.pushNamed(context, Routes.delivery);
        break;
      case 'marketplace':
        Navigator.pushNamed(context, Routes.marketplace);
        break;
      case 'ai':
        Navigator.pushNamed(context, Routes.aiAssistant);
        break;
      // Locação: abre a vitrine já na aba certa.
      case 'rental':
        Navigator.pushNamed(context, Routes.rental);
        break;
      case 'vehicles':
        Navigator.pushNamed(context, Routes.rental, arguments: {'tab': 0});
        break;
      case 'machines':
        Navigator.pushNamed(context, Routes.rental, arguments: {'tab': 1});
        break;
      // Segmentos de serviço: abrem a busca filtrada pelo grupo.
      case 'agro':
        setState(() => _selGroup = 'Agro');
        break;
      case 'drones':
        setState(() => _selGroup = 'Drones');
        break;
      case 'labor':
        setState(() => _selGroup = 'Mão de Obra');
        break;
      case 'pets':
        setState(() => _selGroup = 'Pets');
        break;
      case 'beauty':
        setState(() => _selGroup = 'Beleza');
        break;
      case 'education':
        setState(() => _selGroup = 'Educação');
        break;
      default:
        Navigator.pushNamed(context, Routes.search);
    }
  }
}

class SearchScreen extends StatefulWidget {
  /// Categoria pré-selecionada (usada ao vir de um chip de segmento).
  final String? initialCategory;
  /// Grupo pré-selecionado (ex.: Veículos, Jurídico) vindo do hub.
  final String? initialGroup;
  const SearchScreen({super.key, this.initialCategory, this.initialGroup});
  @override
  State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';
  String? _cat;
  String? _groupFocus;
  bool _onlineOnly = false;
  String _sort = 'rating';
  late Stream<List<ProviderModel>> _providersStream;
  int _streamGen = 0;
  Timer? _debounce;

  static const _priorityGroups = [
    'Casa',
    'Limpeza',
    'Veículos',
    'Jurídico',
    'Beleza',
    'Tech',
    'Pets',
    'Agro',
    'Educação',
    'Eventos',
    'Transporte',
    'Equipamentos',
    'Jardim',
  ];

  List<ServiceCategory> get _chipCategories {
    List<ServiceCategory> chips;
    final focus = _groupFocus;
    if (focus != null && focus.isNotEmpty && focus != 'Saúde') {
      chips = Categories.all.where((c) => c.group == focus).toList();
    } else if (_cat != null) {
      final g = Categories.byId(_cat!)?.group;
      if (g != null && g != 'Saúde') {
        chips = Categories.all.where((c) => c.group == g).toList();
      } else {
        chips = _defaultChips();
      }
    } else {
      chips = _defaultChips();
    }
    if (_cat != null && !chips.any((c) => c.id == _cat)) {
      final sel = Categories.byId(_cat!);
      if (sel != null && sel.group != 'Saúde') chips = [sel, ...chips];
    }
    return chips;
  }

  List<ServiceCategory> _defaultChips() {
    final out = <ServiceCategory>[];
    for (final g in _priorityGroups) {
      out.addAll(Categories.all.where((c) => c.group == g));
      if (out.length >= 20) break;
    }
    return out.take(20).toList();
  }

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
    _groupFocus = widget.initialGroup ??
        (_cat != null ? Categories.byId(_cat!)?.group : null);
    if (_groupFocus == 'Saúde') _groupFocus = null;
    _providersStream = FS.providersStream(category: _cat, limit: 30);
    PerfLog.screen('search');
  }

  void _bindStream() {
    _providersStream = FS.providersStream(category: _cat, limit: 30);
  }

  void _setCategory(String id) {
    setState(() {
      _cat = _cat == id ? null : id;
      if (_cat != null) {
        final g = Categories.byId(_cat!)?.group;
        _groupFocus = (g != null && g != 'Saúde') ? g : _groupFocus;
      }
      _streamGen++;
      _bindStream();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // Busca inteligente (Vol.11: IA): interpreta a query em linguagem
  // natural e pré-seleciona a categoria mais próxima do catálogo,
  // em vez do usuário precisar navegar manualmente pelos chips.
  Future<void> _smartSearch() async {
    if (_q.trim().isEmpty) {
      snack(context, 'Digite o que você precisa primeiro');
      return;
    }
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    final catNames = Categories.all
        .where((c) => c.group != 'Saúde')
        .map((c) => c.name)
        .toList();
    final result = await AiSvc.smartSearchCategory(_q, catNames);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (result != null && result.isNotEmpty) {
      final matched = Categories.all.firstWhere((c) => c.name == result,
          orElse: () => Categories.all.first);
      setState(() {
        if (_cat != matched.id) {
          _cat = matched.id;
          _groupFocus =
              matched.group != 'Saúde' ? matched.group : _groupFocus;
          _streamGen++;
          _bindStream();
        }
      });
      snack(context, '🔍 Categoria sugerida: ${matched.name}',
          bg: AppColors.secondary);
    } else {
      snack(context,
          'Não consegui identificar uma categoria. Tente ser mais específico.',
          bg: AppColors.error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: CarajasAppBar(
          title: 'Buscar profissionais',
          titleWidget: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 200), () {
                  if (mounted) setState(() => _q = v);
                });
              },
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                  hintText: 'Buscar profissionais...',
                  hintStyle: TextStyle(color: Colors.white54, fontSize: 15),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 14))),
          actions: [
            IconButton(
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: 'Busca inteligente com IA',
                onPressed: _smartSearch),
            IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: _filters),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(children: [
          SizedBox(
              height: 58,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  itemCount: _chipCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _chipCategories[i];
                    return CatChip(
                        emoji: c.emoji,
                        name: c.name,
                        categoryId: c.id,
                        color: c.color,
                        selected: _cat == c.id,
                        onTap: () => _setCategory(c.id));
                  })),
          if (_onlineOnly)
            const InfoBanner(
                icon: '📹',
                text: 'Filtro ativo: somente atendimento online',
                bg: Color(0xFFE3F0FF),
                fg: AppColors.primary),
          Expanded(
              child: StreamBuilder<List<ProviderModel>>(
            key: ValueKey(
                'prov-$_streamGen-${_cat ?? _groupFocus ?? 'all'}'),
            stream: _providersStream,
            builder: (_, snap) {
              if (snap.hasError) {
                PerfLog.error('search_providers', snap.error!);
                return EmptyState(
                  emoji: '⚠️',
                  title: 'Não foi possível carregar',
                  subtitle: 'Verifique a conexão e tente novamente.',
                  actionLabel: 'Tentar novamente',
                  onAction: () {
                    _streamGen++;
                    _bindStream();
                    setState(() {});
                  },
                );
              }
              var list = List<ProviderModel>.from(snap.data ?? const []);
              // Sempre reaplica filtros locais (categoria/query) para não
              // exibir snapshot antigo se o stream atrasar no web.
              if (HomologCatalog.enabled) {
                list = HomologCatalog.filter(
                  category: _cat,
                  group: _cat == null ? _groupFocus : null,
                  query: _q,
                  onlineOnly: _onlineOnly,
                );
              } else {
                if (_cat != null && _cat!.isNotEmpty) {
                  list = list
                      .where((p) => p.categories.contains(_cat))
                      .toList();
                } else if (_groupFocus != null &&
                    _groupFocus!.isNotEmpty &&
                    _groupFocus != 'Todos') {
                  final ids = Categories.all
                      .where((c) => c.group == _groupFocus)
                      .map((c) => c.id)
                      .toSet();
                  list = list
                      .where((p) => p.categories.any(ids.contains))
                      .toList();
                }
                if (_q.isNotEmpty) {
                  final q = _q.toLowerCase();
                  list = list
                      .where((p) =>
                          p.name.toLowerCase().contains(q) ||
                          p.categories.any((c) => c.contains(q)))
                      .toList();
                }
                if (_onlineOnly) {
                  list = list
                      .where((p) => p.modalities.contains('online'))
                      .toList();
                }
              }
              list = [...list];
              if (_sort == 'reviews') {
                list.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
              } else if (_sort == 'price_asc') {
                list.sort((a, b) => (a.minPrice ?? double.infinity)
                    .compareTo(b.minPrice ?? double.infinity));
              } else {
                list.sort((a, b) => b.rating.compareTo(a.rating));
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  snap.data == null &&
                  !HomologCatalog.enabled) {
                return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, __) => const SkeletonCard());
              }
              if (list.isEmpty) {
                return EmptyState(
                    emoji: '🔍',
                    title: 'Nenhum resultado',
                    subtitle: HomologCatalog.enabled
                        ? 'Tente outra palavra ou categoria'
                        : 'Tente outros filtros ou palavras-chave',
                    asset: AppAssets.estadoNenhumResultado,
                    actionLabel: snap.data == null && !HomologCatalog.enabled
                        ? 'Tentar novamente'
                        : null,
                    onAction: snap.data == null && !HomologCatalog.enabled
                        ? () {
                            _streamGen++;
                            _bindStream();
                            setState(() {});
                          }
                        : null);
              }
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final catName = _cat != null
                        ? (Categories.byId(_cat!)?.name ?? _cat!)
                        : (p.categories.isNotEmpty
                            ? (Categories.byId(p.categories.first)?.name ??
                                p.categories.first)
                            : 'Profissional');
                    return ProvCard(
                        key: ValueKey(p.id),
                        name: p.name,
                        role: catName,
                        city: p.city,
                        badge: p.badge,
                        price: p.minPrice != null
                            ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(0)}'
                            : 'Consultar',
                        rating: p.rating,
                        reviews: p.totalReviews,
                        isOnline: p.modalities.contains('online'),
                        photo: p.photoUrl,
                        providerId: p.id,
                        onTap: TapGuard.wrap(() => Navigator.pushNamed(
                                context, Routes.requestService, arguments: {
                              'providerId': p.id,
                              'providerName': p.name,
                              'category': p.categories.isNotEmpty
                                  ? p.categories.first
                                  : (_cat ?? '')
                            })),
                        onChat: TapGuard.wrap(() => ChatNav.open(context,
                            otherUserId:
                                p.userId.isNotEmpty ? p.userId : p.id,
                            otherName: p.name,
                            otherPhoto: p.photoUrl)));
                  });
            },
          )),
        ]),
          ),
        ),
      );

  void _filters() => showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (ctx, setS) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const SheetHandle(),
                    const SizedBox(height: 16),
                    const Text('Filtros',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    SwitchListTile(
                        title: const Text('Somente online'),
                        subtitle: const Text('Atendimento remoto disponível'),
                        value: _onlineOnly,
                        onChanged: (v) {
                          setS(() => _onlineOnly = v);
                          setState(() {});
                        }),
                    const Divider(),
                    const Text('Ordenar por',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    for (final e in {
                      'rating': '⭐ Melhor avaliação',
                      'reviews': '📊 Mais avaliações',
                      'price_asc': '💰 Menor preço'
                    }.entries)
                      RadioListTile<String>(
                          title: Text(e.value),
                          value: e.key,
                          groupValue: _sort,
                          onChanged: (v) {
                            setS(() => _sort = v!);
                            setState(() {});
                          }),
                    const SizedBox(height: 8),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Aplicar'))),
                  ]))));
}

/// Preview de prestadores — stream criado uma vez (evita re-subscribe a cada build).
class _NearbyProvidersList extends StatefulWidget {
  final List<ProviderModel> demoFallback;
  final String? group;
  const _NearbyProvidersList({
    this.demoFallback = const [],
    this.group,
  });

  @override
  State<_NearbyProvidersList> createState() => _NearbyProvidersListState();
}

class _NearbyProvidersListState extends State<_NearbyProvidersList> {
  late Stream<List<ProviderModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FS.providersStream(limit: 8);
  }

  @override
  void didUpdateWidget(covariant _NearbyProvidersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group != widget.group) {
      setState(() {
        _stream = FS.providersStream(limit: 8);
      });
    }
  }

  List<ProviderModel> _filterByGroup(List<ProviderModel> list) {
    final g = widget.group;
    if (g == null || g.isEmpty || g == 'Todos') return list;
    final ids =
        Categories.all.where((c) => c.group == g).map((c) => c.id).toSet();
    return list.where((p) => p.categories.any(ids.contains)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderModel>>(
      stream: _stream,
      builder: (_, snap) {
        var provs = snap.data ?? [];
        if (HomologCatalog.enabled) {
          provs = HomologCatalog.providers(group: widget.group).take(8).toList();
        } else if (provs.isEmpty) {
          provs = DemoData.orEmpty(snap.data, widget.demoFallback);
          provs = _filterByGroup(provs);
        } else {
          provs = _filterByGroup(provs);
        }
        if (provs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: EmptyState(
              emoji: '🔧',
              title: widget.group != null
                  ? 'Nenhum profissional nesta categoria'
                  : 'Nenhum profissional ainda',
              subtitle: widget.group != null
                  ? 'Tente outro grupo ou veja todos os profissionais.'
                  : 'Em breve profissionais da região aparecerão aqui.',
            ),
          );
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: provs.map((p) {
                  final catName = p.categories.isNotEmpty
                      ? (Categories.byId(p.categories.first)?.name ??
                          p.categories.first)
                      : 'Profissional';
                  return ProvCard(
                    name: p.name,
                    role: catName,
                    city: p.city,
                    badge: p.badge,
                    price: p.minPrice != null
                        ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(0)}'
                        : 'Consultar',
                    rating: p.rating,
                    reviews: p.totalReviews,
                    isOnline: p.modalities.contains('online'),
                    photo: p.photoUrl,
                    providerId: p.id,
                    onTap: () => Navigator.pushNamed(
                      context,
                      Routes.requestService,
                      arguments: {
                        'providerId': p.id,
                        'providerName': p.name,
                        'category':
                            p.categories.isNotEmpty ? p.categories.first : '',
                      },
                    ),
                    onChat: () => ChatNav.open(
                      context,
                      otherUserId: p.userId.isNotEmpty ? p.userId : p.id,
                      otherName: p.name,
                      otherPhoto: p.photoUrl,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
