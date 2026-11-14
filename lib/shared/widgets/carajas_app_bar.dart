import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_nav.dart';

/// AppBar padrao Carajas 360 — telas internas com voltar obrigatorio.
class CarajasAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool implyLeading;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  final Widget? titleWidget;

  const CarajasAppBar({
    super.key,
    required this.title,
    this.actions,
    this.implyLeading = true,
    this.backgroundColor,
    this.bottom,
    this.titleWidget,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final showBack = implyLeading && AppNav.isInnerPage(context);
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: AppColors.white,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => AppNav.safeBack(context),
            )
          : null,
      title: titleWidget ??
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
      actions: actions,
      bottom: bottom,
    );
  }
}
