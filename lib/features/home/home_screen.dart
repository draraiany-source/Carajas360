import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_assets.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/category_icons.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../services/service_marketplace_screen.dart';
import '../../core/search/provider_search.dart';
import '../../shared/widgets/brand_provider_card.dart';

/// Hub do módulo Serviços (profissionais da região).
/// A Home da plataforma Carajás 360 fica em [HomeScreen] (carajas_home_screen.dart).
class ServicesHubScreen extends StatefulWidget {
  const ServicesHubScreen({super.key});
  @override
  State<ServicesHubScreen> createState() => _ServicesHubState();
}

class _ServicesHubState extends State<ServicesHubScreen> {
  String _selGroup = 'Todos';
  int _refreshTick = 0;
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

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CarajasAppBar(title: 'Serviços'),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          FS.resetProvidersStreams();
          if (mounted) setState(() => _refreshTick++);
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
                key: ValueKey(_refreshTick),
                group: _selGroup == 'Todos' ? null : _selGroup,
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

/// Destaques do hub: mesmo stream e cartão da busca Explorar.
class _NearbyProvidersList extends StatefulWidget {
  final String? group;
  const _NearbyProvidersList({super.key, this.group});

  @override
  State<_NearbyProvidersList> createState() => _NearbyProvidersListState();
}

class _NearbyProvidersListState extends State<_NearbyProvidersList> {
  late final Stream<List<ProviderModel>> _stream =
      FS.providersStream(limit: 100);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderModel>>(
      stream: _stream,
      builder: (_, snap) {
        final scope = widget.group == null
            ? const <String>{}
            : ProviderSearch.idsForGroup(widget.group!);
        final provs = ProviderSearch.apply(snap.data ?? const [],
                ProviderSearchCriteria(scopeIds: scope))
            .take(6)
            .toList();
        Widget pad(Widget child) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: child);
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return pad(const ShimCard());
        }
        if (snap.hasError && !snap.hasData) {
          return pad(const EmptyState(
            emoji: '⚠️',
            title: 'Não foi possível carregar os profissionais',
            subtitle: 'Puxe a tela para baixo para tentar novamente.',
          ));
        }
        if (provs.isEmpty) {
          return pad(EmptyState(
            emoji: '🔧',
            title: widget.group != null
                ? 'Nenhum profissional nesta categoria'
                : 'Nenhum profissional ainda',
            subtitle: widget.group != null
                ? 'Tente outro grupo ou veja todos os profissionais.'
                : 'Em breve profissionais da região aparecerão aqui.',
          ));
        }
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: pad(BrandProviderGrid(list: provs, highlight: scope)),
          ),
        );
      },
    );
  }
}