import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/brand.dart';
import 'ai_screen.dart';
import 'carajas_ia_character.dart';

/// Botão flutuante discreto da Carajás IA.
/// Web largo: abre painel lateral. Mobile: navega para a Central.
class CarajasIaFab extends StatelessWidget {
  final bool embedPanel;
  const CarajasIaFab({super.key, this.embedPanel = true});

  static Future<void> open(
    BuildContext context, {
    bool preferPanel = true,
    String? initialMessage,
  }) async {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (preferPanel && wide) {
      await showGeneralDialog(
        context: context,
        barrierLabel: 'Fechar Carajás IA',
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.28),
        transitionDuration:
            (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
                ? Duration.zero
                : const Duration(milliseconds: 280),
        pageBuilder: (ctx, a1, a2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                      maxHeight: 720,
                    ),
                    child: _AiSidePanel(initialMessage: initialMessage),
                  ),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim, _, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween(begin: const Offset(0.12, 0), end: Offset.zero)
                .animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
      return;
    }
    await Navigator.pushNamed(
      context,
      Routes.aiAssistant,
      arguments: {
        if (initialMessage != null && initialMessage.trim().isNotEmpty)
          'initialMessage': initialMessage.trim(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Tooltip(
      message: 'Abrir Carajás 360 IA',
      child: Semantics(
        button: true,
        label: 'Abrir Carajás 360 IA',
        excludeSemantics: true,
        child: Material(
          elevation: 8,
          shadowColor: Brand.green.withValues(alpha: 0.40),
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(wide ? 28 : 999),
          child: InkWell(
            borderRadius: BorderRadius.circular(wide ? 28 : 999),
            onTap: () => open(context, preferPanel: embedPanel),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(wide ? 28 : 999),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFF8E7), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Brand.gold.withValues(alpha: 0.9)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(wide ? 8 : 4, 4, wide ? 14 : 4, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CarajasIaAvatar(size: 52, showRing: true),
                    if (wide) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'Carajás 360 IA',
                        style: TextStyle(
                          color: Brand.greenDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiSidePanel extends StatelessWidget {
  final String? initialMessage;
  const _AiSidePanel({this.initialMessage});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Brand.isDark(context) ? Brand.surface(context) : Brand.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Brand.line(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(-4, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AiAssistantScreen(
          embedded: true,
          initialMessage: initialMessage,
        ),
      ),
    );
  }
}
