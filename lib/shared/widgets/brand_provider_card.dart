import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/tap_guard.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'widgets.dart';
import 'micro_interactions.dart';

/// Abre a solicitação direta ao profissional.
void requestProviderService(BuildContext context, ProviderModel p,
        {String? description}) =>
    Navigator.pushNamed(
      context,
      Routes.requestService,
      arguments: {
        'providerId': p.id,
        'providerName': p.name,
        'category': p.categories.isNotEmpty ? p.categories.first : '',
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

void openProviderProfile(BuildContext context, ProviderModel p) =>
    Navigator.pushNamed(
      context,
      Routes.providerProfile,
      arguments: {'providerId': p.id, 'provider': p},
    );

/// Conversa com o profissional (visitante é levado ao login).
Future<void> openProviderChat(BuildContext context, ProviderModel p) async {
  if (AuthService.uid == null) {
    snack(context, 'Entre na conta para conversar com profissionais.');
    Navigator.pushNamed(context, Routes.login);
    return;
  }
  try {
    await ChatNav.open(
      context,
      otherUserId: p.userId.isNotEmpty ? p.userId : p.id,
      otherName: p.name,
      otherPhoto: p.photoUrl,
    );
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Não foi possível abrir a conversa agora.',
          bg: AppColors.error);
    }
  }
}

String providerCategoryName(ProviderModel p) => p.categories.isNotEmpty
    ? (Categories.byId(p.categories.first)?.name ?? p.categories.first)
    : 'Profissional';

class BrandProviderPhoto extends StatelessWidget {
  final ProviderModel provider;
  const BrandProviderPhoto({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      decoration: const BoxDecoration(gradient: Brand.heroGradient),
      alignment: Alignment.center,
      child: Text(
        provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
      ),
    );
    final url = provider.photoUrl;
    if (url == null || url.isEmpty) return initial;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => initial,
      errorWidget: (_, __, ___) => initial,
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = Brand.green,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: Colors.white.withValues(alpha: 0.95),
          shape: const CircleBorder(),
          elevation: 1,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon, size: 18, color: color)),
          ),
        ),
      ),
    );
  }
}

/// Alterna o favorito (visitante é levado ao login).
Future<void> toggleProviderFavorite(
    BuildContext context, String providerId) async {
  if (AuthService.uid == null) {
    snack(context, 'Entre na conta para salvar favoritos.');
    Navigator.pushNamed(context, Routes.login);
    return;
  }
  final nowFav = await FS.toggleFavorite(providerId);
  if (!context.mounted) return;
  snack(context, nowFav ? 'Adicionado aos favoritos' : 'Removido dos favoritos',
      bg: nowFav ? Brand.green : AppColors.textLight);
}

class BrandFavoriteButton extends StatelessWidget {
  final String providerId;
  const BrandFavoriteButton({super.key, required this.providerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: FS.isFavoriteStream(providerId),
      builder: (_, snap) {
        final isFav = snap.data ?? false;
        return _RoundIconButton(
          icon: isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: isFav ? AppColors.error : Brand.green,
          tooltip: isFav ? 'Remover dos favoritos' : 'Favoritar',
          onTap: () => toggleProviderFavorite(context, providerId),
        );
      },
    );
  }
}

/// Cartão de profissional do design system (Home, Explorar, listas).
class BrandProviderCard extends StatelessWidget {
  final ProviderModel provider;
  const BrandProviderCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final price = p.minPrice != null
        ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
        : 'Valor sob consulta';
    void request() => requestProviderService(context, p);
    return TapScale(
      onTap: TapGuard.wrap(() => openProviderProfile(context, p)),
      child: Container(
        decoration: BoxDecoration(
          color: Brand.surface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Brand.line(context)),
          boxShadow: Brand.shadow(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 124,
            child: Stack(children: [
              Positioned.fill(child: BrandProviderPhoto(provider: p)),
              Positioned(
                right: 8,
                top: 8,
                child: Row(children: [
                  _RoundIconButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      tooltip: 'Conversar com ${p.name}',
                      onTap: () => openProviderChat(context, p)),
                  const SizedBox(width: 6),
                  BrandFavoriteButton(providerId: p.id),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: Brand.ink(context))),
                    ),
                    if (p.verified) ...[
                      const SizedBox(width: 4),
                      const Tooltip(
                        message: 'Perfil verificado',
                        child: Icon(Icons.verified_rounded,
                            size: 16, color: Brand.green),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(providerCategoryName(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Brand.inkMuted(context))),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 16, color: Brand.gold),
                    const SizedBox(width: 2),
                    Text(
                        p.totalReviews > 0
                            ? p.rating.toStringAsFixed(1)
                            : 'Novo',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Brand.ink(context))),
                    if (p.totalReviews > 0)
                      Text(' (${p.totalReviews})',
                          style: TextStyle(
                              fontSize: 11.5, color: Brand.inkMuted(context))),
                  ]),
                  if (p.city != null && p.city!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 14, color: Brand.inkMuted(context)),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(p.city!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Brand.inkMuted(context))),
                      ),
                    ]),
                  ],
                  const Spacer(),
                  Text(price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Brand.isDark(context)
                              ? Brand.gold
                              : Brand.green)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: TapGuard.wrap(request),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Brand.green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(0, 38),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11)),
                      ),
                      child: const Text('Solicitar serviço',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
