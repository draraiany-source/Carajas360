import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/query_errors.dart';
import 'service_filter.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/micro_interactions.dart';

/// Hub do módulo Serviços (núcleo original do Serviço Conecta).
/// A Home da plataforma Carajás 360 fica em [HomeScreen] (carajas_home_screen.dart).
class ServicesHubScreen extends StatefulWidget {
  const ServicesHubScreen({super.key});
  @override
  State<ServicesHubScreen> createState() => _ServicesHubState();
}

class _ServicesHubState extends State<ServicesHubScreen> {
  ServiceFilter _filter = const ServiceFilter();
  late Stream<List<ProviderModel>> _featured;
  // Grupos vindos da fonte única de categorias — assim novos segmentos
  // (Agro, Drones, Máquinas, Veículos, Lojas...) aparecem automaticamente.
  final _groups = [ServiceFilter.allGroups, ...Categories.groups];

  static const _modules = [
    {'id': 'services', 'icon': '🔧', 'label': 'Serviços'},
    {'id': 'health', 'icon': '🏥', 'label': 'Saúde'},
    {'id': 'delivery', 'icon': '📦', 'label': 'Entregas'},
    {'id': 'marketplace', 'icon': '🛒', 'label': 'Mercado'},
    {'id': 'rental', 'icon': '🔑', 'label': 'Aluguel'},
    {'id': 'machines', 'icon': '🚜', 'label': 'Máquinas'},
    {'id': 'vehicles', 'icon': '🚗', 'label': 'Veículos'},
    {'id': 'labor', 'icon': '👷', 'label': 'Mão de Obra'},
    {'id': 'drones', 'icon': '🚁', 'label': 'Drones'},
    {'id': 'pets', 'icon': '🐾', 'label': 'Pets'},
    {'id': 'beauty', 'icon': '💅', 'label': 'Beleza'},
    {'id': 'education', 'icon': '📚', 'label': 'Educação'},
    {'id': 'agro', 'icon': '🌾', 'label': 'Agro'},
    {'id': 'ai', 'icon': '🤖', 'label': 'IA'},
  ];

  /// Atalhos do hub que filtram por grupo (precisam existir no catálogo).
  static const moduleGroups = {
    'agro': 'Agro',
    'drones': 'Drones',
    'labor': 'Mão de Obra',
    'pets': 'Pets',
    'beauty': 'Beleza',
    'education': 'Educação',
  };

  @override
  void initState() {
    super.initState();
    _featured = _query();
  }

  Stream<List<ProviderModel>> _query() => FS.providersStream(
      category: _filter.queryCategory,
      categories: _filter.queryCategories,
      limit: 5);

  /// Atualiza filtro e consulta juntos (a lista nunca fica sem filtro).
  void _setFilter(ServiceFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _featured = _query();
    });
  }

  void _retry() => setState(() => _featured = _query());

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SecHeader(title: 'O que você precisa hoje?'),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
                children: _modules
                    .map((m) => GestureDetector(
                        onTap: () => _navigate(m['id']!),
                        child: Container(
                            decoration: AppDecorations.card(r: 14),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 2),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(m['icon']!,
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(height: 5),
                                  Text(m['label']!,
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textDark),
                                      textAlign: TextAlign.center),
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
                      'SaúdeConecta',
                      'Médico · Psicólogo · Fisio',
                      AppGradients.health,
                      Routes.health)),
              const SizedBox(width: 10),
              Expanded(
                  child: _banner('📦', 'EntregaConecta', 'GPS em tempo real',
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
                        final sel = _filter.group == _groups[i];
                        return Semantics(
                          button: true,
                          selected: sel,
                          label: 'Grupo ${_groups[i]}',
                          child: GestureDetector(
                            onTap: () =>
                                _setFilter(_filter.selectGroup(_groups[i])),
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
                                            : AppColors.textDark)))));
                      })),
              // Serviços do grupo selecionado: tocar filtra os profissionais
              // abaixo (tocar de novo remove o filtro de serviço).
              if (!_filter.isAll)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filter.groupServiceIds.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final c =
                              Categories.byId(_filter.groupServiceIds[i])!;
                          return CatChip(
                              emoji: c.emoji,
                              name: c.name,
                              categoryId: c.id,
                              color: c.color,
                              selected: _filter.service == c.id,
                              onTap: () =>
                                  _setFilter(_filter.toggleService(c.id)));
                        },
                      )),
                ),
            ]),
          )),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SecHeader(
                      title: _featuredTitle,
                      action: 'Ver todos →',
                      onAction: () => Navigator.pushNamed(
                              context, Routes.search, arguments: {
                            if (_filter.service != null)
                              'category': _filter.service,
                            if (_filter.service == null && !_filter.isAll)
                              'group': _filter.group,
                          })))),
          SliverToBoxAdapter(
              child: StreamBuilder<List<ProviderModel>>(
            key: ValueKey(_filter.key),
            stream: _featured,
            builder: (_, snap) {
              if (snap.hasError) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: EmptyState(
                        emoji: '⚠️',
                        title: 'Não foi possível carregar profissionais',
                        subtitle: friendlyQueryError(snap.error),
                        actionLabel: 'Tentar novamente',
                        onAction: _retry));
              }
              if (!snap.hasData) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                        children: List.generate(
                            3, (_) => const SkeletonCard())));
              }
              final provs = snap.data!
                  .where((p) => _filter.matches(p.categories))
                  .toList();
              if (provs.isEmpty) {
                return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: EmptyState(
                        emoji: '🔍',
                        title: 'Nenhum profissional disponível',
                        subtitle: _filter.isAll
                            ? 'Ainda não há profissionais aprovados disponíveis.'
                            : 'Ainda não há profissionais aprovados em ${_filterLabel()}.'));
              }
              return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                      children: provs.map((p) {
                    final specialty = _filter.contractedCategory(p.categories);
                    return ProvCard(
                      name: p.name,
                      role: _filter.roleLabel(p.categories),
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
                          context, Routes.requestService,
                          arguments: {
                            'providerId': p.id,
                            'providerName': p.name,
                            'category': specialty,
                          }),
                      onChat: () => ChatNav.open(context,
                          otherUserId: p.userId.isNotEmpty ? p.userId : p.id,
                          otherName: p.name,
                          otherPhoto: p.photoUrl),
                    );
                  }).toList()));
            },
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

  String _filterLabel() => _filter.service != null
      ? (Categories.byId(_filter.service!)?.name ?? _filter.service!)
      : _filter.group;

  String get _featuredTitle =>
      _filter.isAll ? 'Em destaque' : 'Em destaque · ${_filterLabel()}';

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
      // Segmentos de serviço: filtram o hub pelo grupo.
      case 'agro':
      case 'drones':
      case 'labor':
      case 'pets':
      case 'beauty':
      case 'education':
        _setFilter(_filter.selectGroup(moduleGroups[id]!));
        break;
      default:
        Navigator.pushNamed(context, Routes.search);
    }
  }
}

class SearchScreen extends StatefulWidget {
  /// Categoria pré-selecionada (usada ao vir de um chip de segmento).
  final String? initialCategory;
  /// Grupo pré-selecionado (ex.: "Casa"), vindo do hub Serviços.
  final String? initialGroup;
  const SearchScreen({super.key, this.initialCategory, this.initialGroup});
  @override
  State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';
  late ServiceFilter _filter;
  late Stream<List<ProviderModel>> _results;
  bool _onlineOnly = false;
  String _sort = 'rating';

  String? get _cat => _filter.service;

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;
    final group = widget.initialGroup;
    _filter = cat != null && Categories.byId(cat) != null
        ? const ServiceFilter().toggleService(cat)
        : (group != null && Categories.groups.contains(group)
            ? const ServiceFilter().selectGroup(group)
            : const ServiceFilter());
    _results = _query();
  }

  Stream<List<ProviderModel>> _query() => FS.providersStream(
      category: _filter.queryCategory,
      categories: _filter.queryCategories,
      limit: 30);

  void _setFilter(ServiceFilter f) {
    if (f == _filter) return;
    setState(() {
      _filter = f;
      _results = _query();
    });
  }

  @override
  void dispose() {
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
    final catNames = Categories.all.map((c) => c.name).toList();
    final result = await AiSvc.smartSearchCategory(_q, catNames);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (result != null && result.isNotEmpty) {
      final matched = Categories.all.firstWhere((c) => c.name == result,
          orElse: () => Categories.all.first);
      _setFilter(ServiceFilter(group: matched.group, service: matched.id));
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
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
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
        body: Column(children: [
          SizedBox(
              height: 58,
              child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  itemCount: _chipServices.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final c = _chipServices[i];
                    return CatChip(
                        emoji: c.emoji,
                        name: c.name,
                        categoryId: c.id,
                        color: c.color,
                        selected: _cat == c.id,
                        onTap: () => _setFilter(_filter.toggleService(c.id)));
                  })),
          if (!_filter.isAll)
            InfoBanner(
                icon: '🗂️',
                text: _cat != null
                    ? 'Serviço: ${Categories.byId(_cat!)?.name ?? _cat}'
                    : 'Grupo: ${_filter.group}',
                bg: const Color(0xFFE3F0FF),
                fg: AppColors.primary),
          if (_onlineOnly)
            const InfoBanner(
                icon: '📹',
                text: 'Filtro ativo: somente atendimento online',
                bg: Color(0xFFE3F0FF),
                fg: AppColors.primary),
          Expanded(
              child: StreamBuilder<List<ProviderModel>>(
            key: ValueKey(_filter.key),
            stream: _results,
            builder: (_, snap) {
              if (snap.hasError) {
                return EmptyState(
                    emoji: '⚠️',
                    title: 'Não foi possível buscar profissionais',
                    subtitle: friendlyQueryError(snap.error),
                    actionLabel: 'Tentar novamente',
                    onAction: () => setState(() => _results = _query()));
              }
              var list = (snap.data ?? [])
                  .where((p) => _filter.matches(p.categories))
                  .toList();
              if (_q.isNotEmpty) {
                final q = _q.toLowerCase();
                list = list
                    .where((p) =>
                        p.name.toLowerCase().contains(q) ||
                        p.categories.any((c) =>
                            c.contains(q) ||
                            (Categories.byId(c)?.name.toLowerCase() ?? '')
                                .contains(q)))
                    .toList();
              }
              if (_onlineOnly)
                list =
                    list.where((p) => p.modalities.contains('online')).toList();
              list = [...list];
              if (_sort == 'reviews') {
                list.sort((a, b) => b.totalReviews.compareTo(a.totalReviews));
              } else if (_sort == 'price_asc') {
                list.sort((a, b) => (a.minPrice ?? double.infinity)
                    .compareTo(b.minPrice ?? double.infinity));
              } else {
                list.sort((a, b) => b.rating.compareTo(a.rating));
              }
              if (snap.data == null)
                return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 5,
                    itemBuilder: (_, __) => const SkeletonCard());
              if (list.isEmpty)
                return const EmptyState(
                    emoji: '🔍',
                    title: 'Nenhum resultado',
                    subtitle: 'Tente outros filtros ou palavras-chave',
                    asset: AppAssets.estadoNenhumResultado);
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final p = list[i];
                    final catName = _filter.roleLabel(p.categories);
                    return FadeSlideIn(
                        index: i,
                        child: ProvCard(
                            key: ValueKey(p.id),
                            name: p.name,
                            role: catName,
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
                                    context, Routes.requestService, arguments: {
                                  'providerId': p.id,
                                  'providerName': p.name,
                                  'category':
                                      _filter.contractedCategory(p.categories)
                                }),
                            onChat: () => ChatNav.open(context,
                                otherUserId:
                                    p.userId.isNotEmpty ? p.userId : p.id,
                                otherName: p.name,
                                otherPhoto: p.photoUrl)));
                  });
            },
          )),
        ]),
      );

  /// Chips: serviços do grupo ativo, ou todos quando sem grupo.
  List<ServiceCategory> get _chipServices => _filter.isAll
      ? Categories.all
      : _filter.groupServiceIds.map((id) => Categories.byId(id)!).toList();

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
