import 'package:flutter/material.dart';

import '../../core/theme/brand.dart';
import 'carajas_ia_assets.dart';

/// Avatar circular oficial da Carajás IA (chat / FAB / header).
class CarajasIaAvatar extends StatelessWidget {
  final double size;
  final bool showRing;
  final String? semanticLabel;

  const CarajasIaAvatar({
    super.key,
    this.size = 40,
    this.showRing = true,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final child = Semantics(
      label: semanticLabel ?? 'Carajás IA, assistente virtual',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showRing
              ? Border.all(color: Brand.gold.withValues(alpha: 0.85), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Brand.green.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            CarajasIaAssets.avatar,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: Brand.greenLight,
              child: Icon(Icons.auto_awesome_rounded,
                  color: Brand.green, size: size * 0.45),
            ),
          ),
        ),
      ),
    );
    if (reduce) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// Personagem de recepção (corpo/retrato/horizontal Web) com saudação leve.
class CarajasIaReceptionHero extends StatefulWidget {
  final bool compact;
  final bool webWide;
  const CarajasIaReceptionHero({
    super.key,
    this.compact = false,
    this.webWide = false,
  });

  @override
  State<CarajasIaReceptionHero> createState() => _CarajasIaReceptionHeroState();
}

class _CarajasIaReceptionHeroState extends State<CarajasIaReceptionHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!reduce) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final String asset;
    final double h;
    final BoxFit fit;
    if (widget.webWide) {
      asset = CarajasIaAssets.webHorizontal;
      h = 160;
      fit = BoxFit.cover;
    } else if (widget.compact) {
      asset = CarajasIaAssets.portrait;
      h = 112;
      fit = BoxFit.contain;
    } else {
      asset = CarajasIaAssets.fullBody;
      h = 220;
      fit = BoxFit.contain;
    }
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(widget.webWide ? 16 : 12),
      child: Image.asset(
        asset,
        height: h,
        width: widget.webWide ? double.infinity : null,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(
          height: h,
          child: const Center(child: CarajasIaAvatar(size: 96)),
        ),
      ),
    );
    if (reduce) return img;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: img,
    );
  }
}

/// Indicador de “digitando” com avatar.
class CarajasIaTypingIndicator extends StatelessWidget {
  const CarajasIaTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CarajasIaAvatar(size: 28, showRing: false),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Brand.surface(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Brand.line(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                child: _Dot(delayMs: i * 160),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatefulWidget {
  final int delayMs;
  const _Dot({required this.delayMs});
  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (mounted && !reduce) {
        _c.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Opacity(
        opacity: 0.35 + (_c.value * 0.65),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Brand.green,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
