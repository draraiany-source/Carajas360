import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/auth/sign_in_gate.dart';
import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/search/provider_search.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/tap_guard.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'widgets.dart';

/// Uid do prestador: pedidos e conversas são autorizados por ele nas regras.
String providerAccountId(ProviderModel p) =>
    p.userId.isNotEmpty ? p.userId : p.id;

/// Só atende a distância: endereço não é obrigatório na solicitação.
bool providerRemoteOnly(ProviderModel p) =>
    p.modalities.isNotEmpty && p.modalities.every((m) => m == 'online');

/// Abre a solicitação direta ao profissional.
void requestProviderService(BuildContext context, ProviderModel p,
        {String? description}) =>
    Navigator.pushNamed(
      context,
      Routes.requestService,
      arguments: {
        'providerId': providerAccountId(p),
        'providerName': p.name,
        'category': p.categories.isNotEmpty ? p.categories.first : '',
        'remoteOnly': providerRemoteOnly(p),
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

/// Conversa com o profissional; visitante entra e volta para cá.
Future<void> openProviderChat(BuildContext context, ProviderModel p) async {
  final ok = await ensureSignedIn(context,
      message: 'Entre na conta para conversar com profissionais.');
  if (!ok || !context.mounted) return;
  try {
    await ChatNav.open(
      context,
      otherUserId: providerAccountId(p),
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

/// Alterna o favorito; visitante entra e volta para cá.
Future<void> toggleProviderFavorite(
    BuildContext context, String providerId) async {
  final ok = await ensureSignedIn(context,
      message: 'Entre na conta para salvar favoritos.');
  if (!ok || !context.mounted) return;
  try {
    final nowFav = await FS.toggleFavorite(providerId);
    if (!context.mounted) return;
    snack(context,
        nowFav ? 'Adicionado aos favoritos' : 'Removido dos favoritos',
        bg: nowFav ? Brand.green : AppColors.textLight);
  } catch (_) {
    if (context.mounted) {
      snack(context, 'Não foi possível atualizar os favoritos agora.',
          bg: AppColors.error);
    }
  }
}

String providerCategoryName(ProviderModel p) =>
    ProviderSearch.specialtyLabel(p);

String formatStartingPrice(double v) {
  final cents = v != v.roundToDouble();
  final s = v.toStringAsFixed(cents ? 2 : 0).replaceAll('.', ',');
  return 'A partir de R\$ $s';
}

/// Selo só para verificação real (catálogo de homologação não conta).
bool providerShowsVerified(ProviderModel p) =>
    p.verified && !HomologCatalog.enabled;

String _areaLabel(ProviderModel p) {
  final city = p.city?.trim() ?? '';
  final others = p.serviceAreas
      .where((a) =>
          a.trim().isNotEmpty &&
          ProviderSearch.norm(a) != ProviderSearch.norm(city))
      .length;
  if (city.isEmpty) {
    return p.serviceAreas.isEmpty ? '' : p.serviceAreas.join(', ');
  }
  if (others == 0) return city;
  return '$city + $others ${others == 1 ? 'cidade' : 'cidades'}';
}

class BrandProviderPhoto extends StatelessWidget {
  final ProviderModel provider;
  final double fontSize;
  const BrandProviderPhoto(
      {super.key, required this.provider, this.fontSize = 22});

  @override
  Widget build(BuildContext context) {
    final initial = Container(
      decoration: const BoxDecoration(gradient: Brand.heroGradient),
      alignment: Alignment.center,
      child: Text(
        provider.name.isNotEmpty ? provider.name[0].toUpperCase() : '?',
        style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800),
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
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: Brand.surface(context),
        side: BorderSide(color: Brand.line(context)),
      ),
      icon: Icon(icon, size: 20, color: color),
    );
  }
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

class _DemoTag extends StatelessWidget {
  const _DemoTag();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Perfil de demonstração do ambiente de homologação',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Brand.goldLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('Demonstração',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7A5B00))),
      ),
    );
  }
}

/// Cartão de profissional do design system (Explorar, Home, Serviços).
///
/// [highlight] são os ids do filtro ativo: a especialidade exibida é a
/// que casou com a busca. O toque no cartão abre o perfil; favoritar,
/// conversar e pedir orçamento têm ação própria.
class BrandProviderCard extends StatelessWidget {
  final ProviderModel provider;
  final Set<String> highlight;

  /// Modo lista: informações à esquerda, preço e ações à direita.
  final bool horizontal;
  const BrandProviderCard(
      {super.key,
      required this.provider,
      this.highlight = const {},
      this.horizontal = false});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    final area = _areaLabel(p);
    final specialty = ProviderSearch.specialtyLabel(p, prefer: highlight);
    final bio = p.bio?.trim() ?? '';

    final header = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
            width: 52, height: 52, child: BrandProviderPhoto(provider: p)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(
              child: Text(p.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: ink)),
            ),
            if (providerShowsVerified(p)) ...[
              const SizedBox(width: 4),
              const Tooltip(
                message: 'Perfil verificado',
                child:
                    Icon(Icons.verified_rounded, size: 17, color: Brand.green),
              ),
            ],
          ]),
          const SizedBox(height: 2),
          Text(specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Brand.isDark(context) ? Brand.gold : Brand.green)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text.rich(
                TextSpan(children: [
                  const WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 2),
                      child: Icon(Icons.star_rounded,
                          size: 16, color: Brand.gold),
                    ),
                  ),
                  TextSpan(
                      text: p.totalReviews > 0
                          ? '${p.rating.toStringAsFixed(1).replaceAll('.', ',')} '
                              '(${p.totalReviews} ${p.totalReviews == 1 ? 'avaliação' : 'avaliações'})'
                          : 'Sem avaliações'),
                ]),
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: p.totalReviews > 0 ? ink : muted),
              ),
              if (HomologCatalog.enabled) const _DemoTag(),
            ],
          ),
        ]),
      ),
      const SizedBox(width: 6),
      BrandFavoriteButton(providerId: p.id),
    ]);

    final price = p.minPrice != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(formatStartingPrice(p.minPrice!),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Brand.isDark(context) ? Brand.gold : Brand.green)),
            Text('Valor inicial informado; o preço final vem no orçamento.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: muted)),
          ])
        : Text('Preço sob consulta',
            style: TextStyle(
                fontSize: 13.5, fontWeight: FontWeight.w800, color: ink));

    final actions = Row(children: [
      _RoundIconButton(
        icon: Icons.chat_bubble_outline_rounded,
        tooltip: 'Conversar com ${p.name}',
        onTap: () => openProviderChat(context, p),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton(
          onPressed: TapGuard.wrap(() => openProviderProfile(context, p)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Brand.green,
            side: const BorderSide(color: Brand.green),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ver perfil',
              maxLines: 1,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ElevatedButton(
          onPressed: TapGuard.wrap(() => requestProviderService(context, p)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Brand.green,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('Pedir orçamento',
                maxLines: 1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]);

    final details = <Widget>[
      if (area.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.location_on_outlined, size: 16, color: muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(area,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: muted)),
          ),
        ]),
      ],
      if (bio.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(bio,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, height: 1.35, color: ink)),
      ],
    ];

    final body = horizontal
        ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [header, ...details],
              ),
            ),
            const SizedBox(width: 18),
            SizedBox(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [price, const SizedBox(height: 12), actions],
              ),
            ),
          ])
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              ...details,
              const SizedBox(height: 10),
              const Spacer(),
              price,
              const SizedBox(height: 12),
              actions,
            ],
          );

    return Semantics(
      container: true,
      label: 'Profissional ${p.name}, $specialty',
      child: Material(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: TapGuard.wrap(() => openProviderProfile(context, p)),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Brand.line(context)),
            ),
            child: Padding(padding: const EdgeInsets.all(14), child: body),
          ),
        ),
      ),
    );
  }
}

/// Grade responsiva: colunas pela largura disponível e linhas com a mesma
/// altura (sem altura fixa, então textos maiores não são cortados).
class BrandProviderGrid extends StatelessWidget {
  final List<ProviderModel> list;
  final Set<String> highlight;
  final double minCardWidth;
  final int? maxColumns;

  /// Lista: uma coluna; em telas largas o cartão fica horizontal.
  final bool asList;
  const BrandProviderGrid({
    super.key,
    required this.list,
    this.highlight = const {},
    this.minCardWidth = 280,
    this.maxColumns,
    this.asList = false,
  });

  static int columnsFor(double width, {double minCardWidth = 280, int max = 4}) {
    const gap = 14.0;
    return ((width + gap) / (minCardWidth + gap)).floor().clamp(1, max);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 14.0;
      final cols = asList
          ? 1
          : columnsFor(c.maxWidth,
              minCardWidth: minCardWidth, max: maxColumns ?? 4);
      final horizontal = asList && c.maxWidth >= 680;
      final rows = <Widget>[];
      for (var i = 0; i < list.length; i += cols) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: gap));
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) const SizedBox(width: gap),
                Expanded(
                  child: i + j < list.length
                      ? BrandProviderCard(
                          provider: list[i + j],
                          highlight: highlight,
                          horizontal: horizontal)
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ));
      }
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
    });
  }
}
