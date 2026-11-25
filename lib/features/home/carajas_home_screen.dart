import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/c360_nav.dart';
import '../../shared/widgets/c360_ui.dart';
import '../profile/plans_screen.dart';
import '../provider/provider_home_screen.dart';
import 'home_screen.dart';
import 'provider_profile_screen.dart';

/// Home da plataforma Carajás 360 (mockups Início v1 e v2).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _banner = PageController();
  int _bannerPage = 0;

  @override
  void dispose() {
    _banner.dispose();
    super.dispose();
  }

  void _openCategory(C360Category category) {
    if (category.route != null) {
      Navigator.pushNamed(context, category.route!);
      return;
    }
    if (category.categoryId == null) {
      c360Go(context, C360Dest.explore, Routes.search);
      return;
    }
    c360Open(
      context,
      route: Routes.search,
      arguments: {'category': category.categoryId},
      page: SearchScreen(initialCategory: category.categoryId),
    );
  }

  void _openProfile(ProviderModel provider) {
    c360Open(
      context,
      route: Routes.providerProfile,
      arguments: {
        'providerId': provider.id,
        'providerName': provider.name,
        'category':
            provider.categories.isNotEmpty ? provider.categories.first : '',
        'style': 'profile',
      },
      page: ProviderProfileScreen(
        providerId: provider.id,
        providerName: provider.name,
        category:
            provider.categories.isNotEmpty ? provider.categories.first : '',
        style: ProviderDetailStyle.profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: StreamBuilder<List<ProviderModel>>(
        stream: c360Stream(() => FS.providersStream(limit: 12)),
        builder: (context, snap) {
          final providers = snap.hasError ? <ProviderModel>[] : (snap.data ?? []);
          return LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;
            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
                if (mounted) setState(() {});
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  _Hero(
                    controller: _banner,
                    page: _bannerPage,
                    onPage: (i) => setState(() => _bannerPage = i),
                    onSearch: () =>
                        c360Go(context, C360Dest.explore, Routes.search),
                  ),
                  const SizedBox(height: 22),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: _mainColumn(providers, wide)),
                        const SizedBox(width: 16),
                        SizedBox(width: 300, child: _rail()),
                      ],
                    )
                  else ...[
                    _mainColumn(providers, wide),
                    const SizedBox(height: 16),
                    _rail(),
                  ],
                  const SizedBox(height: 18),
                  C360TrustStrip(activeProviders: providers.length),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  Widget _mainColumn(List<ProviderModel> providers, bool wide) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      C360SectionHeader(
        title: 'Categorias de Serviços',
        action: 'Ver todas',
        onAction: () => c360Go(context, C360Dest.explore, Routes.search),
      ),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: C360Categories.home.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: wide ? 5 : 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: wide ? 1.05 : 1.15,
        ),
        itemBuilder: (_, i) {
          final category = C360Categories.home[i];
          return C360CategoryTile(
            category: category,
            onTap: () => _openCategory(category),
          );
        },
      ),
      const SizedBox(height: 22),
      C360SectionHeader(
        title: 'Profissionais em Destaque',
        icon: Icons.star_rounded,
        action: 'Ver todas',
        onAction: () =>
            c360Go(context, C360Dest.professionals, Routes.search),
      ),
      const SizedBox(height: 12),
      if (providers.isEmpty)
        const C360Card(
          child: Text(
            'Os profissionais verificados da região aparecem aqui assim que estiverem disponíveis.',
            style: TextStyle(color: AppColors.textMedium, height: 1.4),
          ),
        )
      else
        SizedBox(
          height: 248,
          child: ValueListenableBuilder<String>(
            valueListenable: RegionController.instance.city,
            builder: (_, city, __) => ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: providers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final provider = providers[i];
                final role = provider.categories.isNotEmpty
                    ? (Categories.byId(provider.categories.first)?.name ??
                        provider.categories.first)
                    : 'Profissional';
                return C360HighlightCard(
                  name: provider.name,
                  role: role,
                  rating: provider.rating,
                  reviews: provider.totalReviews,
                  photoUrl: provider.photoUrl,
                  verified: provider.verified,
                  place: c360Place(provider, city),
                  providerId: provider.id,
                  onProfile: () => _openProfile(provider),
                );
              },
            ),
          ),
        ),
      const SizedBox(height: 8),
      _modules(),
    ]);
  }

  Widget _modules() {
    final soon =
        PlatformModules.all.where((m) => !m.isAvailable).take(4).toList();
    if (soon.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      const C360SectionHeader(title: 'Em breve na região'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final module in soon)
            Chip(
              avatar: Text(module.emoji),
              label: Text(module.label),
              backgroundColor: AppColors.white,
              side: const BorderSide(color: AppColors.border),
            ),
        ],
      ),
    ]);
  }

  Widget _rail() {
    return Column(children: [
      _promo(
        title: 'Cadastre seu serviço',
        text: 'Divulgue seu trabalho e conquiste mais clientes.',
        button: 'Anunciar agora',
        yellow: true,
        onTap: () => c360Open(
          context,
          route: Routes.providerHome,
          page: const ProviderHomeScreen(),
        ),
      ),
      const SizedBox(height: 12),
      C360Card(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          _shortcut(Icons.receipt_long_rounded, 'Acompanhe seus pedidos',
              'Veja o status dos seus serviços.', () {
            c360Go(context, C360Dest.orders, Routes.myOrders);
          }),
          const Divider(height: 1),
          _shortcut(Icons.chat_bubble_outline_rounded, 'Mensagens',
              'Converse com clientes e profissionais.', () {
            c360Go(context, C360Dest.messages, Routes.chatInbox);
          }),
          const Divider(height: 1),
          _shortcut(Icons.favorite_border_rounded, 'Meus Favoritos',
              'Seus profissionais e serviços salvos.', () {
            c360Go(context, C360Dest.favorites, Routes.favorites);
          }),
        ]),
      ),
      const SizedBox(height: 12),
      _promo(
        title: 'Carajás360 para Empresas',
        text: 'Soluções em manutenção, mão de obra, máquinas e contratos contínuos.',
        button: 'Conheça os planos',
        yellow: false,
        onTap: () => c360Open(
          context,
          route: Routes.companyProfile,
          page: const PlansScreen(),
        ),
      ),
    ]);
  }

  Widget _shortcut(
      IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primarySoft,
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }

  Widget _promo({
    required String title,
    required String text,
    required String button,
    required bool yellow,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: yellow ? null : AppGradients.hero,
        color: yellow ? AppColors.primary : null,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 6),
        Text(text,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.35)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: yellow ? AppColors.yellow : AppColors.white,
            foregroundColor: AppColors.sidebar,
          ),
          child: Text(button),
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  final PageController controller;
  final int page;
  final ValueChanged<int> onPage;
  final VoidCallback onSearch;
  const _Hero({
    required this.controller,
    required this.page,
    required this.onPage,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 250,
        child: Stack(children: [
          PageView(
            controller: controller,
            onPageChanged: onPage,
            children: const [
              _HeroSlide(
                title: 'Encontre o profissional ideal para o seu dia a dia',
                subtitle:
                    'Serviços, mão de obra, máquinas e muito mais em Canaã dos Carajás.',
              ),
              _HeroSlide(
                title: 'Serviços confiáveis, perto de você',
                subtitle:
                    'Profissionais verificados, pagamento seguro e suporte na região.',
              ),
            ],
          ),
          Positioned(
            left: 22,
            bottom: 18,
            child: Row(children: [
              ElevatedButton.icon(
                onPressed: onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.yellow,
                  foregroundColor: AppColors.sidebar,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Buscar serviços agora'),
              ),
              const SizedBox(width: 16),
              for (var i = 0; i < 2; i++)
                Container(
                  width: i == page ? 16 : 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 5),
                  decoration: BoxDecoration(
                    color: i == page
                        ? AppColors.yellow
                        : Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _HeroSlide extends StatelessWidget {
  final String title;
  final String subtitle;
  const _HeroSlide({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: Stack(children: [
        const Positioned.fill(child: CustomPaint(painter: C360LandscapePainter())),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('CANAÃ DOS CARAJÁS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.4)),
              const SizedBox(height: 8),
              Text(subtitle,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      height: 1.35)),
            ],
          ),
        ),
      ]),
    );
  }
}
