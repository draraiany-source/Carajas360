import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/utils/provider_entry.dart';
import '../../core/search/provider_search.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/brand_categories.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/brand_wordmark.dart';
import '../../shared/widgets/micro_interactions.dart';

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _cardColor(BuildContext context) =>
    _isDark(context) ? AppColors.darkSurface : Brand.white;

Color _textHigh(BuildContext context) =>
    _isDark(context) ? AppColors.darkTextHigh : Brand.text;

Color _textLow(BuildContext context) =>
    _isDark(context) ? AppColors.darkTextLow : Brand.textMuted;

Color _borderColor(BuildContext context) =>
    _isDark(context) ? AppColors.darkBorder : Brand.border;

List<BoxShadow> _softShadow(BuildContext context) => [
      BoxShadow(
        color: (_isDark(context) ? Colors.black : Brand.greenDark)
            .withValues(alpha: _isDark(context) ? 0.3 : 0.06),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ];

/// Home da plataforma Carajás 360.
/// O hub de Serviços permanece em [ServicesHubScreen].
class HomeScreen extends StatefulWidget {
  /// Troca a aba da [MainNav] em vez de empilhar a mesma tela como rota.
  final ValueChanged<int>? onSelectTab;
  const HomeScreen({super.key, this.onSelectTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _city = RegionCities.defaultCity;
  late final Stream<List<ProviderModel>> _providers;

  @override
  void initState() {
    super.initState();
    _providers = FS.providersStream(limit: 20);
    final uid = AuthService.uid;
    if (uid == null) return;
    FS.userStream(uid).first.then((u) {
      if (!mounted) return;
      final c = u?.city?.trim();
      if (c != null && c.isNotEmpty) setState(() => _city = c);
    });
  }

  void _openModule(PlatformModule m) {
    if (!m.isAvailable || m.route == null) {
      snack(context, '🚧 ${m.label} em desenvolvimento. Em breve na região.');
      return;
    }
    Navigator.pushNamed(context, m.route!);
  }

  void _openCategory(BrandCategory c) {
    if (c.route != null) {
      _go(c.route!);
      return;
    }
    Navigator.pushNamed(
      context,
      Routes.search,
      arguments: {
        if (c.group != null) 'group': c.group,
        if (c.category != null) 'category': c.category,
      },
    );
  }

  static const _tabRoutes = {
    Routes.myOrders: 2,
    Routes.chatInbox: 3,
    Routes.profile: 4,
  };

  void _go(String route) {
    final tab = _tabRoutes[route];
    final select = widget.onSelectTab;
    if (tab != null && select != null) {
      select(tab);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  void _pickCity() {
    final cities = [...RegionCities.priority, ...RegionCities.nearby];
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.55,
          child: Column(children: [
            const SheetHandle(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SecHeader(title: 'Sua localização'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: cities.length,
                itemBuilder: (_, i) {
                  final c = cities[i];
                  final sel = c == _city;
                  return ListTile(
                    leading: Icon(
                        sel
                            ? Icons.location_on_rounded
                            : Icons.location_on_outlined,
                        color: Brand.green),
                    title: Text(c,
                        style: TextStyle(
                            fontWeight:
                                sel ? FontWeight.w800 : FontWeight.w500)),
                    trailing: sel
                        ? const Icon(Icons.check_circle, color: Brand.goldDeep)
                        : null,
                    onTap: () {
                      setState(() => _city = c);
                      Navigator.pop(ctx);
                      if (AuthService.uid != null) {
                        FS.updateUser({'city': c});
                      }
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.uid;
    return Scaffold(
      backgroundColor: _isDark(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : Brand.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: Brand.green,
          onRefresh: () async {
            await Future.delayed(const Duration(milliseconds: 450));
            if (mounted) setState(() {});
          },
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final pad = wide ? 28.0 : 16.0;
            return StreamBuilder<UserModel?>(
              stream: uid != null ? FS.userStream(uid) : const Stream.empty(),
              builder: (_, snap) =>
                  _content(context, snap.data, wide: wide, pad: pad),
            );
          }),
        ),
      ),
    );
  }

  /// Atalhos reais: categorias da marca + módulos disponíveis com rota
  /// (sem repetir destinos já cobertos). Módulos "em breve" ficam só em
  /// "Módulos da região", com aviso ao tocar.
  List<_Shortcut> _shortcuts() {
    final covered = <String>{
      Routes.servicesHub,
      for (final c in brandCategories)
        if (c.route != null) c.route!,
    };
    return [
      for (final c in brandCategories)
        _Shortcut(c.label, c.icon, () => _openCategory(c)),
      for (final m in PlatformModules.all)
        if (m.isAvailable && m.route != null && !covered.contains(m.route))
          _Shortcut(m.label, m.icon, () => _openModule(m)),
      _Shortcut('Mais categorias', Icons.grid_view_rounded,
          () => _go(Routes.servicesHub),
          highlight: true),
    ];
  }

  void _search(String query) {
    final q = query.trim();
    Navigator.pushNamed(
      context,
      Routes.universalSearch,
      arguments: {if (q.isNotEmpty) 'q': q},
    );
  }

  Widget _content(BuildContext context, UserModel? user,
      {required bool wide, required double pad}) {
    final firstName =
        user?.firstName.isNotEmpty == true ? user!.firstName : null;
    Widget section(Widget child, {double top = 0}) => SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: BrandShell.maxWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, top, pad, 0),
                child: child,
              ),
            ),
          ),
        );
    Widget bleed(Widget child, {double top = 0}) => SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: BrandShell.maxWidth),
              child: Padding(padding: EdgeInsets.only(top: top), child: child),
            ),
          ),
        );

    return CustomScrollView(slivers: [
      // Em telas largas a MainNav (menu lateral / BrandTopNav) já é a
      // navegação principal: aqui fica só uma barra utilitária compacta.
      section(
        wide
            ? _WideUtilityBar(
                city: _city,
                firstName: firstName,
                onCity: _pickCity,
                onMessages: () => _go(Routes.chatInbox),
              )
            : _MobileTopBar(
                city: _city,
                user: user,
                firstName: firstName,
                onCity: _pickCity,
                onProfile: () => _go(Routes.profile),
                onMessages: () => _go(Routes.chatInbox),
              ),
        top: wide ? 16 : 12,
      ),
      if (BrandShell.demoMode)
        section(
          const BrandDemoNotice(
            message:
                'Modo demonstração • perfis ilustrativos. Pedidos reais só com profissionais cadastrados.',
          ),
          top: 12,
        ),
      section(
        _HeroBanner(
          city: _city,
          wide: wide,
          onSearch: _search,
          onRequest: () => _go(Routes.resolve),
        ),
        top: 14,
      ),
      section(
        const _SectionHeader(
          title: 'O que você precisa hoje?',
          subtitle: 'Escolha uma categoria e encontre quem atende na região.',
        ),
        top: 26,
      ),
      section(_CategoryGrid(shortcuts: _shortcuts()), top: 14),
      section(
        _InfoBanners(
          onHouse: () => Navigator.pushNamed(context, Routes.search,
              arguments: {'group': 'Casa'}),
          onHealth: () => _go(Routes.health),
        ),
        top: 26,
      ),
      section(
        _SectionHeader(
          title: 'Profissionais em destaque',
          action: 'Ver todos',
          onAction: () => _go(Routes.search),
        ),
        top: 28,
      ),
      section(_FeaturedProviders(stream: _providers), top: 14),
      section(
        wide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: _ProviderPromoCard(
                        onTap: () => openProviderEntry(context))),
                const SizedBox(width: 20),
                Expanded(child: _QuickLinksCard(onOpen: _go)),
              ])
            : Column(children: [
                _ProviderPromoCard(onTap: () => openProviderEntry(context)),
                const SizedBox(height: 16),
                _QuickLinksCard(onOpen: _go),
              ]),
        top: 28,
      ),
      section(_TrustBar(city: _city), top: 28),
      section(
        _SectionHeader(
          title: 'Profissionais em $_city',
          subtitle: 'Cadastrados na sua cidade.',
          action: 'Trocar cidade',
          onAction: _pickCity,
        ),
        top: 28,
      ),
      bleed(
        _NearbyProviders(stream: _providers, city: _city, pad: pad, wide: wide),
        top: 12,
      ),
      section(const _SectionHeader(title: 'Módulos da região'), top: 28),
      section(
        LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 1100 ? 6 : (w >= 800 ? 4 : (w >= 480 ? 3 : 2));
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: PlatformModules.all.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 92,
            ),
            itemBuilder: (_, i) {
              final m = PlatformModules.all[i];
              return FadeSlideIn(
                index: i,
                child: _ModuleCard(module: m, onTap: () => _openModule(m)),
              );
            },
          );
        }),
        top: 12,
      ),
      section(const _SectionHeader(title: 'Serviços populares'), top: 24),
      bleed(
        SizedBox(
          height: 40,
          child: ScrollConfiguration(
            behavior: const BrandDragScrollBehavior(),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: Categories.all.length.clamp(0, 12),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c = Categories.all[i];
                return CatChip(
                  emoji: c.emoji,
                  name: c.name,
                  categoryId: c.id,
                  color: c.color,
                  selected: false,
                  onTap: () => Navigator.pushNamed(context, Routes.search,
                      arguments: {'category': c.id}),
                );
              },
            ),
          ),
        ),
        top: 10,
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]);
  }
}

/// Atalho exibido na grade "O que você precisa hoje?".
class _Shortcut {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _Shortcut(this.label, this.icon, this.onTap, {this.highlight = false});
}

// ─────────────────────────────────────────────────────────────
// Cabeçalho
// ─────────────────────────────────────────────────────────────

class _CityPill extends StatelessWidget {
  final String city;
  final VoidCallback onTap;
  const _CityPill({required this.city, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cidade: $city. Alterar cidade',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _borderColor(context)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_rounded,
                  size: 17, color: Brand.green),
              const SizedBox(width: 5),
              Flexible(
                child: Text(city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _textHigh(context))),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _textLow(context)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge(this.count);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
          color: Brand.gold, borderRadius: BorderRadius.circular(8)),
      child: Text(count > 9 ? '9+' : '$count',
          style: const TextStyle(
              color: Brand.greenDark,
              fontSize: 9.5,
              fontWeight: FontWeight.w900)),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;
  final int badge;
  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: tooltip,
        constraints: compact
            ? const BoxConstraints.tightFor(width: 40, height: 44)
            : null,
        padding: compact ? EdgeInsets.zero : null,
        onPressed: onTap,
        icon: Icon(icon, color: _textHigh(context), size: 25),
      ),
      if (badge > 0) Positioned(top: 6, right: 4, child: _Badge(badge)),
    ]);
  }
}

class _NotifBell extends StatelessWidget {
  final bool compact;
  const _NotifBell({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NotifModel>>(
      stream: FS.notifStream(),
      builder: (_, snap) {
        final unread = (snap.data ?? []).where((n) => !n.read).length;
        return _TopIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: unread > 0 ? 'Notificações ($unread novas)' : 'Notificações',
          compact: compact,
          badge: unread,
          onTap: () => Navigator.pushNamed(context, Routes.notifications),
        );
      },
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  final String city;
  final UserModel? user;
  final String? firstName;
  final VoidCallback onCity, onProfile, onMessages;
  const _MobileTopBar({
    required this.city,
    required this.user,
    required this.firstName,
    required this.onCity,
    required this.onProfile,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          BrandWordmark(size: MediaQuery.sizeOf(context).width < 400 ? 21 : 24),
          const Spacer(),
          _TopIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: 'Mensagens',
              compact: true,
              onTap: onMessages),
          const _NotifBell(compact: true),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Semantics(
            button: true,
            label: 'Minha conta',
            excludeSemantics: true,
            onTap: onProfile,
            child: GestureDetector(
              onTap: onProfile,
              child: AppAvatar(
                url: user?.photoUrl,
                name: user?.name ?? '?',
                size: 44,
                bg: Brand.green,
                r: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              firstName != null ? 'Olá, $firstName!' : 'Bem-vindo!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _textHigh(context)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _CityPill(city: city, onTap: onCity)),
        ]),
      ],
    );
  }
}

/// Barra utilitária compacta (desktop): sem logo nem links de navegação,
/// pois a MainNav já fornece menu lateral / BrandTopNav.
class _WideUtilityBar extends StatelessWidget {
  final String city;
  final String? firstName;
  final VoidCallback onCity, onMessages;
  const _WideUtilityBar({
    required this.city,
    required this.firstName,
    required this.onCity,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(
          firstName != null ? 'Olá, $firstName!' : 'Bem-vindo ao Carajás 360',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: _textHigh(context)),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: _CityPill(city: city, onTap: onCity),
      ),
      const SizedBox(width: 8),
      const _NotifBell(),
      _TopIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Mensagens',
          onTap: onMessages),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Banner principal
// ─────────────────────────────────────────────────────────────

class _HeroBanner extends StatefulWidget {
  final String city;
  final bool wide;
  final ValueChanged<String> onSearch;
  final VoidCallback onRequest;
  const _HeroBanner({
    required this.city,
    required this.wide,
    required this.onSearch,
    required this.onRequest,
  });

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => widget.onSearch(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    final wide = widget.wide;
    final city = widget.city;
    final titleSize = wide ? 36.0 : 26.0;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: wide ? 280 : 0),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Brand.greenDark.withValues(alpha: 0.25),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: wide ? -70 : -80,
          bottom: wide ? -140 : -120,
          child: IgnorePointer(
            child: Container(
              width: wide ? 440 : 260,
              height: wide ? 440 : 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                    color: Brand.gold.withValues(alpha: 0.35), width: 2),
              ),
            ),
          ),
        ),
        Positioned(
          right: wide ? 64 : 14,
          top: wide ? 48 : 16,
          child: IgnorePointer(
            child: Opacity(
              opacity: wide ? 0.2 : 0.14,
              child: SvgPicture.asset(
                'assets/logos/logo_mark_mono_white.svg',
                width: wide ? 180 : 70,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(wide ? 40 : 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 640 : 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SERVIÇOS LOCAIS EM ${city.toUpperCase()}',
                    style: TextStyle(
                        color: Brand.gold,
                        fontSize: wide ? 11.5 : 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6)),
                const SizedBox(height: 10),
                Text.rich(
                  const TextSpan(children: [
                    TextSpan(text: 'Encontre o '),
                    TextSpan(
                        text: 'profissional certo',
                        style: TextStyle(color: Brand.gold)),
                    TextSpan(text: ' perto de você'),
                  ]),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.14,
                      letterSpacing: -0.6),
                ),
                const SizedBox(height: 10),
                Text(
                    'Serviços, mão de obra, máquinas e muito mais em $city e região. Compare perfis e converse pelo app.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: wide ? 15 : 13.5,
                        height: 1.4)),
                SizedBox(height: wide ? 24 : 18),
                _HeroSearchBar(
                  controller: _ctrl,
                  onSubmit: _submit,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onRequest,
                    icon: const Icon(Icons.flash_on_rounded,
                        size: 18, color: Brand.gold),
                    label: const Text('Ou peça um orçamento'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: const Size(0, 36),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

/// Campo de busca branco com botão dourado "Buscar".
class _HeroSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _HeroSearchBar({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    const none = InputBorder.none;
    return Container(
      height: 56,
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: Brand.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, size: 22, color: Brand.green),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmit(),
            style: const TextStyle(fontSize: 14.5, color: Brand.text),
            cursorColor: Brand.green,
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              border: none,
              enabledBorder: none,
              focusedBorder: none,
              disabledBorder: none,
              errorBorder: none,
              focusedErrorBorder: none,
              contentPadding: EdgeInsets.zero,
              hintText: 'Qual serviço você precisa?',
              hintStyle: TextStyle(fontSize: 14.5, color: Brand.textMuted),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Brand.gold,
            foregroundColor: Brand.greenDark,
            elevation: 0,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Buscar'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Categorias
// ─────────────────────────────────────────────────────────────

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlight;
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: highlight ? label : 'Categoria $label',
      excludeSemantics: true,
      onTap: onTap,
      child: TapScale(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
          decoration: BoxDecoration(
            color: _cardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor(context)),
          ),
          child: Column(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: highlight ? Brand.goldLight : Brand.greenLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  size: 24, color: highlight ? Brand.goldDeep : Brand.green),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: _textHigh(context))),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_Shortcut> shortcuts;
  const _CategoryGrid({required this.shortcuts});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final cols = w >= 1000 ? shortcuts.length.clamp(1, 10) : (w >= 640 ? 5 : 3);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: shortcuts.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 112,
        ),
        itemBuilder: (_, i) {
          final s = shortcuts[i];
          return _CategoryTile(
            label: s.label,
            icon: s.icon,
            onTap: s.onTap,
            highlight: s.highlight,
          );
        },
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────
// Banners informativos (sem preços nem promoções)
// ─────────────────────────────────────────────────────────────

class _InfoBanners extends StatelessWidget {
  final VoidCallback onHouse, onHealth;
  const _InfoBanners({required this.onHouse, required this.onHealth});

  @override
  Widget build(BuildContext context) {
    final house = _InfoBanner(
      icon: Icons.home_repair_service_rounded,
      title: 'Cuidando da sua casa',
      text:
          'Encontre pedreiros, eletricistas, encanadores e outros profissionais para obra, reforma e manutenção.',
      cta: 'Ver profissionais',
      dark: true,
      onTap: onHouse,
    );
    final health = _InfoBanner(
      icon: Icons.health_and_safety_rounded,
      title: 'Saúde e bem-estar',
      text:
          'Conheça clínicas e profissionais de saúde da região e agende pelo aplicativo.',
      cta: 'Ver saúde',
      dark: false,
      onTap: onHealth,
    );
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth >= 700) {
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: house),
            const SizedBox(width: 16),
            Expanded(child: health),
          ]),
        );
      }
      return Column(children: [house, const SizedBox(height: 14), health]);
    });
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title, text, cta;
  final bool dark;
  final VoidCallback onTap;
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.text,
    required this.cta,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final night = _isDark(context);
    final titleColor = dark ? Colors.white : _textHigh(context);
    final bodyColor =
        dark ? Colors.white.withValues(alpha: 0.86) : _textLow(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: dark
            ? Brand.heroGradient
            : LinearGradient(
                colors: night
                    ? [AppColors.darkSurface, AppColors.darkSurface]
                    : [Brand.greenLight, Brand.goldLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        border: dark ? null : Border.all(color: _borderColor(context)),
        boxShadow: _softShadow(context),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: titleColor)),
              const SizedBox(height: 6),
              Text(text,
                  style:
                      TextStyle(fontSize: 13, height: 1.4, color: bodyColor)),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark ? Brand.gold : Brand.green,
                  foregroundColor: dark ? Brand.greenDark : Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(cta),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark
                ? Brand.gold.withValues(alpha: 0.18)
                : Brand.green.withValues(alpha: 0.12),
          ),
          child: Icon(icon,
              size: 34, color: dark ? Brand.gold : Brand.green),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Cartões laterais e confiança
// ─────────────────────────────────────────────────────────────

class _ProviderPromoCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ProviderPromoCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Brand.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: Brand.gold, size: 24),
          ),
          const SizedBox(height: 14),
          const Text('Cadastre seu serviço',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Divulgue seu trabalho e seja encontrado por clientes da sua região.',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Brand.gold,
                foregroundColor: Brand.greenDark,
                elevation: 0,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Anunciar agora',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  final ValueChanged<String> onOpen;
  const _QuickLinksCard({required this.onOpen});

  static const _links = [
    (
      Icons.flash_on_rounded,
      'Pedir orçamento',
      'Descreva o que precisa',
      Routes.resolve
    ),
    (
      Icons.receipt_long_rounded,
      'Acompanhe seus pedidos',
      'Status e histórico',
      Routes.myOrders
    ),
    (
      Icons.chat_bubble_outline_rounded,
      'Mensagens',
      'Converse com profissionais',
      Routes.chatInbox
    ),
    (
      Icons.favorite_border_rounded,
      'Meus favoritos',
      'Profissionais salvos',
      Routes.favorites
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < _links.length; i++) ...[
          if (i > 0) Divider(height: 1, color: _borderColor(context)),
          Semantics(
            button: true,
            label: _links[i].$2,
            excludeSemantics: true,
            onTap: () => onOpen(_links[i].$4),
            child: InkWell(
              onTap: () => onOpen(_links[i].$4),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Brand.greenLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_links[i].$1, size: 20, color: Brand.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_links[i].$2,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _textHigh(context))),
                        Text(_links[i].$3,
                            style: TextStyle(
                                fontSize: 11.5, color: _textLow(context))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _textLow(context)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _TrustBar extends StatelessWidget {
  final String city;
  const _TrustBar({required this.city});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.verified_user_rounded,
        'Perfis verificados',
        'Selo exibido só para perfis aprovados'
      ),
      (
        Icons.location_on_rounded,
        'Serviços perto de você',
        'Profissionais de $city e região'
      ),
      (
        Icons.forum_rounded,
        'Converse antes de contratar',
        'Chat direto pelo aplicativo'
      ),
      (
        Icons.support_agent_rounded,
        'Suporte pelo app',
        'Central de ajuda e atendimento'
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 860 ? 4 : (c.maxWidth >= 420 ? 2 : 1);
        final w = (c.maxWidth - (cols - 1) * 16) / cols;
        return Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                        color: Brand.greenLight, shape: BoxShape.circle),
                    child: Icon(it.$1, color: Brand.green, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.$2,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: _textHigh(context))),
                        const SizedBox(height: 2),
                        Text(it.$3,
                            style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                color: _textLow(context))),
                      ],
                    ),
                  ),
                ]),
              ),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Seções
// ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle, action;
  final VoidCallback? onAction;
  const _SectionHeader(
      {required this.title, this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize:
                          MediaQuery.sizeOf(context).width < 600 ? 18 : 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: _textHigh(context))),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!,
                    style: TextStyle(fontSize: 13, color: _textLow(context))),
              ],
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: _isDark(context) ? Brand.gold : Brand.green,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              minimumSize: const Size(0, 36),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(action!,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              const Icon(Icons.arrow_forward_rounded, size: 16),
            ]),
          ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final PlatformModule module;
  final VoidCallback onTap;
  const _ModuleCard({required this.module, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final soon = !module.isAvailable;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: module.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(module.icon, size: 20, color: module.accent),
            ),
            const SizedBox(height: 8),
            Text(
              module.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: _textHigh(context)),
            ),
            if (soon) ...[
              const SizedBox(height: 2),
              const Text('Em breve',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Brand.goldDeep)),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Profissionais
// ─────────────────────────────────────────────────────────────

/// Resolve carregamento, erro e vazio do stream de profissionais.
class _ProvidersStream extends StatelessWidget {
  final Stream<List<ProviderModel>> stream;
  final List<ProviderModel> Function(List<ProviderModel>) select;
  final String emptyText;
  final double pad;
  final Widget Function(List<ProviderModel>) builder;
  const _ProvidersStream({
    required this.stream,
    required this.select,
    required this.emptyText,
    required this.builder,
    this.pad = 0,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderModel>>(
      stream: stream,
      builder: (_, snap) {
        var all = snap.data ?? [];
        if (all.isEmpty && HomologCatalog.enabled) {
          all = HomologCatalog.providers();
        }
        if (snap.connectionState == ConnectionState.waiting &&
            all.isEmpty &&
            !HomologCatalog.enabled) {
          return Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: const ShimCard());
        }
        final list = select(all);
        if (list.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: InfoBanner(
              icon: snap.hasError ? '⚠️' : '📍',
              text: snap.hasError
                  ? 'Não foi possível carregar os profissionais agora. Puxe para atualizar.'
                  : emptyText,
              bg: _isDark(context) ? AppColors.darkSurface : Brand.greenLight,
              fg: _isDark(context) ? AppColors.darkTextMed : Brand.greenDark,
            ),
          );
        }
        return builder(list);
      },
    );
  }
}

class _FeaturedProviders extends StatelessWidget {
  final Stream<List<ProviderModel>> stream;
  const _FeaturedProviders({required this.stream});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final cols = BrandProviderGrid.columnsFor(c.maxWidth, max: 4);
      // Uma fileira em telas largas; três cartões empilhados no celular.
      final count = cols == 1 ? 3 : cols;
      return _ProvidersStream(
        stream: stream,
        select: (all) => all.take(count).toList(),
        emptyText:
            'Profissionais da região aparecerão aqui. Abra Serviços para explorar.',
        builder: (list) => BrandProviderGrid(list: list, maxColumns: cols),
      );
    });
  }
}

class _NearbyProviders extends StatelessWidget {
  final Stream<List<ProviderModel>> stream;
  final String city;
  final double pad;
  final bool wide;
  const _NearbyProviders({
    required this.stream,
    required this.city,
    required this.pad,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    return _ProvidersStream(
      stream: stream,
      pad: pad,
      select: (all) => all
          .where((p) => ProviderSearch.matchesCity(p, city))
          .take(8)
          .toList(),
      emptyText:
          'Ainda não há profissionais cadastrados em $city. Troque a cidade ou explore todos os serviços.',
      builder: (list) => wide
          ? _ProviderGrid(list: list, pad: pad)
          : _ProviderCarousel(list: list, pad: pad),
    );
  }
}

class _ProviderGrid extends StatelessWidget {
  final List<ProviderModel> list;
  final double pad;
  const _ProviderGrid({required this.list, required this.pad});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        child: BrandProviderGrid(list: list),
      );
}

/// Celular: lista vertical curta (o cartão completo não cabe num carrossel
/// estreito sem cortar texto).
class _ProviderCarousel extends StatelessWidget {
  final List<ProviderModel> list;
  final double pad;
  const _ProviderCarousel({required this.list, required this.pad});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(pad, 2, pad, 12),
        child: BrandProviderGrid(list: list.take(3).toList()),
      );
}