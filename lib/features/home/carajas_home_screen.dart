import 'package:flutter/material.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/memo.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../../shared/widgets/micro_interactions.dart';

/// Home da plataforma Carajás 360.
/// O hub legado (Serviço Conecta) permanece em [ServicesHubScreen].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _city = RegionCities.defaultCity;
  // Puxar para atualizar: recria os streams da tela.
  int _refreshTick = 0;

  /// Compara cidades ignorando caixa e acentos.
  static String _cityKey(String? c) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const to = 'aaaaaeeeeiiiiooooouuuuc';
    final buf = StringBuffer();
    for (final ch in (c ?? '').trim().toLowerCase().split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }

  // Assinaturas criadas uma vez (por usuário, cidade e "puxar para
  // atualizar"), não a cada rebuild — a de notificações ficava dentro do
  // builder do perfil e era recriada a cada atualização dele.
  final _header = Memo<Stream<UserModel?>>();
  final _notifs = Memo<Stream<List<NotifModel>>>();
  final _near = Memo<Stream<List<ProviderModel>>>();

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
          if (mounted) setState(() => _refreshTick++);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: StreamBuilder<UserModel?>(
              stream: _header.of('$uid-$_refreshTick',
                  () => uid != null ? FS.userStream(uid) : const Stream.empty()),
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
                                  user?.firstName.isNotEmpty == true
                                      ? 'Olá, ${user!.firstName}'
                                      : 'Olá! Bem-vindo(a)',
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
                            stream: _notifs.of(
                                '$uid-$_refreshTick', FS.notifStream),
                            builder: (_, nSnap) {
                              final unread = (nSnap.data ?? [])
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
                                    r: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppSearchBar(
                        hint: 'O que você precisa hoje?',
                        readOnly: true,
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.search),
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
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: PlatformModules.all.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
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
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 22),
              child: SecHeader(
                title: 'Profissionais em $_city',
                action: 'Ver serviços →',
                onAction: () =>
                    Navigator.pushNamed(context, Routes.servicesHub),
              ),
            ),
          ),
          SliverToBoxAdapter(
            // Sem filtro de cidade no servidor: busca mais e filtra aqui.
            child: StreamBuilder<List<ProviderModel>>(
              key: ValueKey('near-$_city-$_refreshTick'),
              // Mesma chave do StreamBuilder: um stream novo para cada
              // StreamBuilder novo (cidade/atualizar).
              stream: _near.of('near-$_city-$_refreshTick',
                  () => FS.providersStream(limit: 30)),
              builder: (_, snap) {
                final cityKey = _cityKey(_city);
                final list = (snap.data ?? [])
                    .where((p) => _cityKey(p.city) == cityKey)
                    .take(5)
                    .toList();
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(16), child: ShimCard());
                }
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: InfoBanner(
                      icon: '📍',
                      text:
                          'Ainda não há profissionais cadastrados em $_city. Abra Serviços para explorar.',
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
                          ? CatalogService.instance.catalog
                              .nameOf(p.categories.first)
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
                        onTap: () => Navigator.pushNamed(context, Routes.providerProfile, arguments: {
                              'providerId': p.id,
                              'providerName': p.name,
                              'category': p.categories.isNotEmpty
                                  ? p.categories.first
                                  : '',
                            }),
                        onChat: () => ChatNav.open(context,
                            otherUserId:
                                p.userId.isNotEmpty ? p.userId : p.id,
                            otherName: p.name,
                            otherPhoto: p.photoUrl),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categorias reais do catálogo administrável.
                  const SecHeader(title: 'Categorias de serviço'),
                  const SizedBox(height: 10),
                  CatalogBuilder(
                    compact: true,
                    showCacheBanner: false,
                    builder: (_, catalog) {
                      final cats = catalog.categories();
                      return SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: cats.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final c = cats[i];
                            return CatChip(
                              emoji: c.icon,
                              name: c.name,
                              categoryId: c.id,
                              color: catalogColor(c),
                              selected: false,
                              onTap: () => Navigator.pushNamed(
                                  context, Routes.search,
                                  arguments: {'catalogId': c.id}),
                            );
                          },
                        ),
                      );
                    },
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
                  emoji: '💼',
                  title: 'Novas vagas',
                  text:
                      'Em desenvolvimento — oportunidades locais em breve.',
                ),
                const SizedBox(height: 10),
                const _SoftBlock(
                  emoji: '🏷️',
                  title: 'Ofertas da região',
                  text:
                      'Em desenvolvimento — campanhas e destaques locais.',
                ),
                const SizedBox(height: 10),
                _SoftBlock(
                  emoji: '⚡',
                  title: 'Precisa resolver agora?',
                  text:
                      'Descreva o problema e receba propostas de profissionais.',
                  action: 'Pedir orçamento',
                  onAction: () =>
                      Navigator.pushNamed(context, Routes.resolve),
                ),
                const SizedBox(height: 10),
                const _SoftBlock(
                  emoji: '🌙',
                  title: 'Serviços 24 horas',
                  text:
                      'Em desenvolvimento — plantão e urgências da região.',
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
            const Text('⚡ Resolva agora',
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: AppColors.navy.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(module.emoji, style: const TextStyle(fontSize: 26)),
              const Spacer(),
              if (soon)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Em breve',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning)),
                ),
            ]),
            const Spacer(),
            Text(module.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(module.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}

class _SoftBlock extends StatelessWidget {
  final String emoji, title, text;
  final String? action;
  final VoidCallback? onAction;
  const _SoftBlock({
    required this.emoji,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$emoji  $title',
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textMedium, height: 1.35)),
        if (action != null && onAction != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onAction,
            child: Text(action!,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ]),
    );
  }
}
