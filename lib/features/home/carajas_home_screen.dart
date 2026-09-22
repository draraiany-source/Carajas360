import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/micro_interactions.dart';

/// Home da plataforma Carajás 360.
/// O hub de Serviços permanece em [ServicesHubScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _city = RegionCities.defaultCity;

  @override
  void initState() {
    super.initState();
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

  void _pickCity() {
    final cities = [...RegionCities.priority, ...RegionCities.nearby];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
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
                        color: AppColors.primary),
                    title: Text(c,
                        style: TextStyle(
                            fontWeight:
                                sel ? FontWeight.w800 : FontWeight.w500)),
                    trailing: sel
                        ? const Icon(Icons.check_circle,
                            color: AppColors.secondary)
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 450));
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Olá, ${user?.firstName.isNotEmpty == true ? user!.firstName : 'Bem-vindo'}',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.82),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 6),
                                const Text(AppInfo.name,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        height: 1.05,
                                        letterSpacing: -0.4)),
                                const SizedBox(height: 4),
                                Text(AppInfo.slogan,
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                        fontSize: 12,
                                        height: 1.3)),
                              ],
                            ),
                          ),
                          StreamBuilder<List<NotifModel>>(
                            stream: FS.notifStream(),
                            builder: (_, nSnap) {
                              final unread = (nSnap.data ?? [])
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
                                        size: 26),
                                  ),
                                  if (unread > 0)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: AppColors.error,
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text(
                                            unread > 9 ? '9+' : '$unread',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, Routes.profile),
                            child: AppAvatar(
                                url: user?.photoUrl,
                                name: user?.name ?? '?',
                                size: 40,
                                bg: AppColors.warning,
                                r: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppSearchBar(
                        hint: 'O que você precisa hoje?',
                        readOnly: true,
                        onTap: () => Navigator.pushNamed(
                            context, Routes.universalSearch),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _pickCity,
                        child: Row(children: [
                          const Icon(Icons.location_on_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(_city,
                                style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.92),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white.withValues(alpha: 0.85),
                              size: 20),
                        ]),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: _ResolveCard(
                onTap: () => Navigator.pushNamed(context, Routes.resolve),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 22),
              child: SecHeader(title: 'Módulos da região'),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: LayoutBuilder(builder: (context, constraints) {
                final w = constraints.maxWidth;
                final cols = w >= 1200
                    ? 6
                    : (w >= 900 ? 4 : (w >= 520 ? 3 : 2));
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
                      child: _ModuleCard(
                        module: m,
                        onTap: () => _openModule(m),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: SecHeader(
                title: 'Próximos de você',
                action: 'Ver serviços →',
                onAction: () =>
                    Navigator.pushNamed(context, Routes.servicesHub),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: _NearbyProvidersList()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecHeader(title: 'Mais procurados'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          onTap: () => Navigator.pushNamed(
                              context, Routes.search,
                              arguments: {'category': c.id}),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: Column(children: [
                const _SoftBlock(
                  icon: Icons.work_outline_rounded,
                  title: 'Novas vagas',
                  text:
                      'Em breve — oportunidades locais para a região.',
                ),
                const SizedBox(height: 10),
                const _SoftBlock(
                  icon: Icons.local_offer_outlined,
                  title: 'Ofertas da região',
                  text:
                      'Em breve — campanhas e destaques locais.',
                ),
                const SizedBox(height: 10),
                _SoftBlock(
                  icon: Icons.flash_on_rounded,
                  title: 'Precisa resolver agora?',
                  text:
                      'Descreva o problema e receba propostas de profissionais.',
                  action: 'Pedir orçamento',
                  onAction: () =>
                      Navigator.pushNamed(context, Routes.resolve),
                ),
                const SizedBox(height: 10),
                const _SoftBlock(
                  icon: Icons.nightlight_round,
                  title: 'Serviços 24 horas',
                  text:
                      'Em breve — plantão e urgências da região.',
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
    );
  }
}

class _ResolveCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ResolveCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: AppGradients.secondary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.secondary.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resolva agora',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 6),
            Text('Descreva o que você precisa e receba propostas.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.35)),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Pedir orçamento',
                  style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
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
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppColors.textDark),
            ),
            if (soon) ...[
              const SizedBox(height: 2),
              Text('Em breve',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning.withValues(alpha: 0.95))),
            ],
          ],
        ),
      ),
    );
  }
}

class _SoftBlock extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final String? action;
  final VoidCallback? onAction;
  const _SoftBlock({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                      height: 1.35)),
              if (action != null && onAction != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(action!,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ]),
          ),
        ],
      ),
    );
  }
}

class _NearbyProvidersList extends StatefulWidget {
  const _NearbyProvidersList();

  @override
  State<_NearbyProvidersList> createState() => _NearbyProvidersListState();
}

class _NearbyProvidersListState extends State<_NearbyProvidersList> {
  late final Stream<List<ProviderModel>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = FS.providersStream(limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProviderModel>>(
      stream: _stream,
      builder: (_, snap) {
        var list = snap.data ?? [];
        if (list.isEmpty && HomologCatalog.enabled) {
          list = HomologCatalog.providers().take(5).toList();
        }
        if (snap.connectionState == ConnectionState.waiting &&
            list.isEmpty &&
            !HomologCatalog.enabled) {
          return const Padding(padding: EdgeInsets.all(16), child: ShimCard());
        }
        if (list.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: InfoBanner(
              icon: '📍',
              text:
                  'Profissionais da região aparecerão aqui. Abra Serviços para explorar.',
              bg: AppColors.surfaceMuted,
              fg: AppColors.textMedium,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: list.map((p) {
              final cat = p.categories.isNotEmpty
                  ? (Categories.byId(p.categories.first)?.name ??
                      p.categories.first)
                  : 'Profissional';
              return ProvCard(
                name: p.name,
                role: cat,
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
        );
      },
    );
  }
}
