import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/modules/platform_modules.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import 'brand_wordmark.dart';
import 'widgets.dart';

/// Destinos da navegação superior (desktop) alinhada às referências.
enum BrandNavDest { home, explore, orders, favorites }

/// Chrome compartilhado: barra superior, heróis, avisos e cartões suaves.
abstract final class BrandShell {
  static const maxWidth = 1240.0;
  static const contentPad = 28.0;
  static const mobilePad = 16.0;

  static double padFor(bool wide) => wide ? contentPad : mobilePad;

  static bool get demoMode => HomologCatalog.enabled;
}

/// Barra superior branca: marca + Início / Explorar / Pedidos / Favoritos.
class BrandTopNav extends StatelessWidget {
  final BrandNavDest? active;
  final String city;
  final UserModel? user;
  final VoidCallback? onCity;
  final ValueChanged<BrandNavDest>? onNav;
  final VoidCallback? onNotifications;
  final VoidCallback? onProfile;
  final bool dense;

  const BrandTopNav({
    super.key,
    this.active,
    required this.city,
    this.user,
    this.onCity,
    this.onNav,
    this.onNotifications,
    this.onProfile,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Brand.ink(context);
    final muted = Brand.inkMuted(context);
    final items = <(BrandNavDest, IconData, String)>[
      (BrandNavDest.home, Icons.home_rounded, 'Início'),
      (BrandNavDest.explore, Icons.explore_rounded, 'Explorar serviços'),
      (BrandNavDest.orders, Icons.receipt_long_rounded, 'Meus pedidos'),
      (BrandNavDest.favorites, Icons.favorite_border_rounded, 'Favoritos'),
    ];
    return Material(
      color: Brand.surface(context),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Brand.line(context))),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: BrandShell.maxWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: dense ? 16 : 28, vertical: dense ? 10 : 14),
                child: Row(children: [
                  InkWell(
                    onTap: () => onNav?.call(BrandNavDest.home),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                      child: BrandWordmark(size: 22),
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final (dest, icon, label) in items) ...[
                          _NavLink(
                            icon: icon,
                            label: label,
                            selected: active == dest,
                            onTap: () => onNav?.call(dest),
                          ),
                          const SizedBox(width: 4),
                        ],
                      ]),
                    ),
                  ),
                  InkWell(
                    onTap: onCity,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.location_on_outlined,
                            size: 18, color: Brand.green),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: Text(
                            city.isEmpty
                                ? RegionCities.defaultCity
                                : '$city • PA',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ink),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: 18, color: muted),
                      ]),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notificações',
                    onPressed: onNotifications ??
                        () => Navigator.pushNamed(context, Routes.notifications),
                    icon: Icon(Icons.notifications_none_rounded,
                        color: muted),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onProfile ??
                        () => Navigator.pushNamed(context, Routes.profile),
                    borderRadius: BorderRadius.circular(24),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AppAvatar(
                        url: user?.photoUrl,
                        name: user?.name.isNotEmpty == true
                            ? user!.name
                            : 'Conta',
                        size: 36,
                        bg: Brand.green,
                        r: 18,
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded, size: 18, color: muted),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  const _NavLink(
      {required this.icon,
      required this.label,
      required this.selected,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? Brand.green : Brand.inkMuted(context);
    return Semantics(
      button: true,
      selected: selected ? true : null,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: selected ? Brand.green : Colors.transparent, width: 2),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: color)),
          ]),
        ),
      ),
    );
  }
}

/// Faixa de aviso só no modo demonstração / homologação.
class BrandDemoNotice extends StatelessWidget {
  final String message;
  const BrandDemoNotice(
      {super.key,
      this.message =
          'Modo demonstração • perfis e ações ilustrativas. Pedidos reais só com profissionais cadastrados.'});

  @override
  Widget build(BuildContext context) {
    if (!BrandShell.demoMode) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Brand.goldLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.gold.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Brand.goldDeep),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B5500),
                  height: 1.3)),
        ),
      ]),
    );
  }
}

/// Migalhas de navegação.
class BrandBreadcrumb extends StatelessWidget {
  final List<(String, VoidCallback?)> items;
  const BrandBreadcrumb({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final muted = Brand.inkMuted(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('/', style: TextStyle(color: muted, fontSize: 12.5)),
            ),
          InkWell(
            onTap: items[i].$2,
            borderRadius: BorderRadius.circular(4),
            child: Text(items[i].$1,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        i == items.length - 1 ? FontWeight.w800 : FontWeight.w600,
                    color: i == items.length - 1
                        ? Brand.ink(context)
                        : muted)),
          ),
        ],
      ],
    );
  }
}

/// Hero verde-esmeralda com título, subtítulo e ilustração opcional.
class BrandPageHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;
  final double height;

  /// Conteúdo abaixo do título (ex.: busca + cidade + botão).
  final Widget? bottom;

  const BrandPageHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.leading,
    this.padding,
    this.height = 148,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      padding: padding ??
          const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Brand.shadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(
          right: -20,
          top: -30,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.18,
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Brand.gold,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 40,
          bottom: -40,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.15)),
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35)),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 16),
                  trailing!
                ],
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: 16), bottom!],
          ],
        ),
      ]),
    );
  }
}

/// Cartão branco com sombra discreta (padrão das referências).
class BrandSoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final VoidCallback? onTap;
  final Border? border;

  const BrandSoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final side = BorderSide(color: Brand.line(context));
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: Brand.shadow(context),
      ),
      child: Material(
        color: color ?? Brand.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: side,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Passos 1–2–3 do fluxo de solicitação.
class BrandStepper extends StatelessWidget {
  final int step; // 1-based
  final List<String> labels;
  const BrandStepper({super.key, required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < labels.length; i++) ...[
        if (i > 0)
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: i < step ? Brand.green : Brand.line(context),
            ),
          ),
        _StepDot(
          index: i + 1,
          label: labels[i],
          done: i + 1 < step,
          active: i + 1 == step,
        ),
      ],
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final bool done, active;
  const _StepDot(
      {required this.index,
      required this.label,
      required this.done,
      required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = done || active ? Brand.green : Brand.surface(context);
    final fg = done || active ? Colors.white : Brand.inkMuted(context);
    return Column(children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(
              color: active || done ? Brand.green : Brand.line(context),
              width: 2),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text('$index',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Brand.green : Brand.inkMuted(context))),
    ]);
  }
}

/// Conteúdo centralizado na largura máxima da marca.
class BrandContentWidth extends StatelessWidget {
  final Widget child;
  final double? pad;
  const BrandContentWidth({super.key, required this.child, this.pad});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BrandShell.maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: pad ?? BrandShell.padFor(wide)),
          child: child,
        ),
      ),
    );
  }
}

/// Botão compacto padrão (altura 44).
class BrandPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;
  final bool outlined;
  final bool locked;

  const BrandPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expanded = true,
    this.outlined = false,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !locked;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (locked)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.lock_outline_rounded, size: 18),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18),
          ),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
      ],
    );
    final btn = outlined
        ? OutlinedButton(
            onPressed: enabled ? onPressed : null,
            style: OutlinedButton.styleFrom(
              minimumSize: Size(expanded ? double.infinity : 0, 44),
              foregroundColor: Brand.green,
              side: const BorderSide(color: Brand.green),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: child,
          )
        : ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(expanded ? double.infinity : 0, 44),
              backgroundColor: Brand.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.border,
              disabledForegroundColor: AppColors.textLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: child,
          );
    return btn;
  }
}

/// Voltar seguro com rótulo (perfil → resultados).
class BrandBackLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const BrandBackLink(
      {super.key, this.label = 'Voltar', this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap ?? () => AppNav.safeBack(context),
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Brand.green,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
