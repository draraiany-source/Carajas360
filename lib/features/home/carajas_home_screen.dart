import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/utils/provider_entry.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/brand_categories.dart';
import '../../shared/widgets/brand_provider_card.dart';
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

  Widget _content(BuildContext context, UserModel? user,
      {required bool wide, required double pad}) {
    final firstName =
        user?.firstName.isNotEmpty == true ? user!.firstName : null;
    Widget section(Widget child, {double top = 0}) => SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
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
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(padding: EdgeInsets.only(top: top), child: child),
            ),
          ),
        );

    final hero = _HeroBanner(
      city: _city,
      wide: wide,
      onSearch: () => _go(Routes.universalSearch),
      onRequest: () => _go(Routes.resolve),
    );
    final categoriesHeader = _SectionHeader(
      title: 'Categorias de serviços',
      action: 'Ver todas',
      onAction: () => _go(Routes.servicesHub),
    );
    final featuredHeader = _SectionHeader(
      title: 'Profissionais em destaque',
      action: 'Ver todos',
      onAction: () => _go(Routes.servicesHub),
    );
    final promo = _ProviderPromoCard(onTap: () => openProviderEntry(context));
    final quickLinks = _QuickLinksCard(onOpen: _go);

    return CustomScrollView(slivers: [
      section(
        wide
            ? _WideTopBar(
                city: _city,
                user: user,
                firstName: firstName,
                onCity: _pickCity,
                onSearch: () => _go(Routes.universalSearch),
                onProfile: () => _go(Routes.profile),
                onMessages: () => _go(Routes.chatInbox),
              )
            : _MobileTopBar(
                city: _city,
                user: user,
                firstName: firstName,
                onCity: _pickCity,
                onSearch: () => _go(Routes.universalSearch),
                onProfile: () => _go(Routes.profile),
                onMessages: () => _go(Routes.chatInbox),
              ),
        top: wide ? 20 : 14,
      ),
      if (wide)
        section(
          LayoutBuilder(builder: (context, c) {
            final twoCol = c.maxWidth >= 1000;
            final main = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                hero,
                const SizedBox(height: 28),
                categoriesHeader,
                const SizedBox(height: 14),
                _CategoryGrid(
                    onTap: _openCategory,
                    onMore: () => _go(Routes.servicesHub)),
                const SizedBox(height: 28),
                featuredHeader,
                const SizedBox(height: 14),
                _FeaturedRow(stream: _providers),
              ],
            );
            if (!twoCol) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  main,
                  const SizedBox(height: 20),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: promo),
                    const SizedBox(width: 20),
                    Expanded(child: quickLinks),
                  ]),
                ],
              );
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: main),
              const SizedBox(width: 24),
              SizedBox(
                width: 300,
                child: Column(children: [
                  promo,
                  const SizedBox(height: 20),
                  quickLinks,
                ]),
              ),
            ]);
          }),
          top: 22,
        )
      else ...[
        section(hero, top: 18),
        section(categoriesHeader, top: 24),
        bleed(
          _CategoryStrip(
              pad: pad,
              onTap: _openCategory,
              onMore: () => _go(Routes.servicesHub)),
          top: 10,
        ),
        section(featuredHeader, top: 22),
        bleed(_FeaturedCarousel(stream: _providers, pad: pad), top: 10),
        section(promo, top: 10),
        section(quickLinks, top: 16),
      ],
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

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar serviços',
      excludeSemantics: true,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: _softShadow(context),
        ),
        child: Material(
          color: _cardColor(context),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Row(children: [
                const SizedBox(width: 16),
                const Icon(Icons.search_rounded, size: 23, color: Brand.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                      'O que você precisa? Ex.: eletricista, limpeza, pedreiro...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: _textLow(context))),
                ),
                const SizedBox(width: 16),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  final String city;
  final UserModel? user;
  final String? firstName;
  final VoidCallback onCity, onSearch, onProfile, onMessages;
  const _MobileTopBar({
    required this.city,
    required this.user,
    required this.firstName,
    required this.onCity,
    required this.onSearch,
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
        const SizedBox(height: 16),
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
                size: 46,
                bg: Brand.green,
                r: 23,
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
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: _textHigh(context)),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _CityPill(city: city, onTap: onCity)),
        ]),
        const SizedBox(height: 14),
        _SearchField(onTap: onSearch),
      ],
    );
  }
}

class _WideTopBar extends StatelessWidget {
  final String city;
  final UserModel? user;
  final String? firstName;
  final VoidCallback onCity, onSearch, onProfile, onMessages;
  const _WideTopBar({
    required this.city,
    required this.user,
    required this.firstName,
    required this.onCity,
    required this.onSearch,
    required this.onProfile,
    required this.onMessages,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _SearchField(onTap: onSearch)),
      const SizedBox(width: 16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: _CityPill(city: city, onTap: onCity),
      ),
      const SizedBox(width: 8),
      const _NotifBell(),
      _TopIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          tooltip: 'Mensagens',
          onTap: onMessages),
      const SizedBox(width: 8),
      Semantics(
        button: true,
        label: firstName != null ? 'Minha conta, $firstName' : 'Entrar',
        excludeSemantics: true,
        onTap: onProfile,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              AppAvatar(
                url: user?.photoUrl,
                name: user?.name ?? '?',
                size: 40,
                bg: Brand.green,
                r: 20,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(firstName != null ? 'Olá, $firstName' : 'Entrar',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _textHigh(context))),
                  Text(firstName != null ? 'Minha conta' : 'ou criar conta',
                      style:
                          TextStyle(fontSize: 11.5, color: _textLow(context))),
                ],
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 20, color: _textLow(context)),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Banner principal
// ─────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String city;
  final bool wide;
  final VoidCallback onSearch, onRequest;
  const _HeroBanner({
    required this.city,
    required this.wide,
    required this.onSearch,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final titleSize = wide ? 34.0 : 25.0;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: wide ? 260 : 0),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(22),
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
              width: wide ? 420 : 260,
              height: wide ? 420 : 260,
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
          right: wide ? 56 : 14,
          top: wide ? 44 : 16,
          child: IgnorePointer(
            child: Opacity(
              opacity: wide ? 0.2 : 0.14,
              child: SvgPicture.asset(
                'assets/logos/logo_mark_mono_white.svg',
                width: wide ? 160 : 70,
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(wide ? 36 : 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 560 : 520),
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
                        text: 'profissional ideal',
                        style: TextStyle(color: Brand.gold)),
                    TextSpan(text: ' para o seu dia a dia'),
                  ]),
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.14,
                      letterSpacing: -0.6),
                ),
                const SizedBox(height: 10),
                Text('Serviços, mão de obra, máquinas e muito mais em $city.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: wide ? 15 : 13.5,
                        height: 1.4)),
                SizedBox(height: wide ? 26 : 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onSearch,
                      icon: const Icon(Icons.search_rounded, size: 19),
                      label: const Text('Buscar serviços agora'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Brand.gold,
                        foregroundColor: Brand.greenDark,
                        elevation: 0,
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: onRequest,
                      icon: const Icon(Icons.flash_on_rounded, size: 18),
                      label: const Text('Solicitar serviço'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.08),
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.6)),
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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

List<Widget> _categoryTiles(
        ValueChanged<BrandCategory> onTap, VoidCallback onMore) =>
    [
      for (final c in brandCategories)
        _CategoryTile(label: c.label, icon: c.icon, onTap: () => onTap(c)),
      _CategoryTile(
          label: 'Mais categorias',
          icon: Icons.grid_view_rounded,
          highlight: true,
          onTap: onMore),
    ];

class _CategoryGrid extends StatelessWidget {
  final ValueChanged<BrandCategory> onTap;
  final VoidCallback onMore;
  const _CategoryGrid({required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final tiles = _categoryTiles(onTap, onMore);
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 10 : 5;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 10 ? 0.78 : 1.15,
        children: tiles,
      );
    });
  }
}

class _CategoryStrip extends StatelessWidget {
  final double pad;
  final ValueChanged<BrandCategory> onTap;
  final VoidCallback onMore;
  const _CategoryStrip(
      {required this.pad, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final tiles = _categoryTiles(onTap, onMore);
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad),
        itemCount: tiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => SizedBox(width: 92, child: tiles[i]),
      ),
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

class _FeaturedRow extends StatelessWidget {
  final Stream<List<ProviderModel>> stream;
  const _FeaturedRow({required this.stream});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 14.0;
      final cols = ((c.maxWidth + gap) / (176 + gap)).floor().clamp(2, 5);
      return _ProvidersStream(
        stream: stream,
        select: (all) => all.take(cols).toList(),
        emptyText:
            'Profissionais da região aparecerão aqui. Abra Serviços para explorar.',
        builder: (list) => SizedBox(
          height: 318,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cols; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(
                  child: i < list.length
                      ? FadeSlideIn(
                          index: i, child: BrandProviderCard(provider: list[i]))
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _FeaturedCarousel extends StatelessWidget {
  final Stream<List<ProviderModel>> stream;
  final double pad;
  const _FeaturedCarousel({required this.stream, required this.pad});

  @override
  Widget build(BuildContext context) {
    return _ProvidersStream(
      stream: stream,
      pad: pad,
      select: (all) => all.take(6).toList(),
      emptyText:
          'Profissionais da região aparecerão aqui. Abra Serviços para explorar.',
      builder: (list) => _ProviderCarousel(list: list, pad: pad),
    );
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

  static String _norm(String s) => s.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return _ProvidersStream(
      stream: stream,
      pad: pad,
      select: (all) => all
          .where((p) => p.city != null && _norm(p.city!) == _norm(city))
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

/// Desktop: grade em vez de carrossel (listas horizontais não rolam com mouse).
class _ProviderGrid extends StatelessWidget {
  final List<ProviderModel> list;
  final double pad;
  const _ProviderGrid({required this.list, required this.pad});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: LayoutBuilder(builder: (context, c) {
        const gap = 14.0;
        final cols = ((c.maxWidth + gap) / (200 + gap)).floor().clamp(2, 6);
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < list.length; i++)
              SizedBox(
                width: w,
                height: 318,
                child: FadeSlideIn(
                    index: i, child: BrandProviderCard(provider: list[i])),
              ),
          ],
        );
      }),
    );
  }
}

class _ProviderCarousel extends StatelessWidget {
  final List<ProviderModel> list;
  final double pad;
  const _ProviderCarousel({required this.list, required this.pad});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 330,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.fromLTRB(pad, 2, pad, 12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => FadeSlideIn(
          index: i,
          child:
              SizedBox(width: 212, child: BrandProviderCard(provider: list[i])),
        ),
      ),
    );
  }
}
