import 'package:flutter/material.dart';

/// Destino da navegação principal.
class NavDest {
  final IconData icon;
  final String label;
  const NavDest(this.icon, this.label);
}

/// Navegação principal adaptativa: barra inferior no celular e navegação
/// lateral (NavigationRail) a partir de [railBreakpoint] (tablet/desktop).
class AdaptiveNavScaffold extends StatelessWidget {
  final List<NavDest> destinations;
  final int index;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget Function(BuildContext) bottomBar;
  final double railBreakpoint;
  const AdaptiveNavScaffold({
    super.key,
    required this.destinations,
    required this.index,
    required this.onSelect,
    required this.body,
    required this.bottomBar,
    this.railBreakpoint = 900,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxWidth < railBreakpoint) {
          return Scaffold(body: body, bottomNavigationBar: bottomBar(context));
        }
        final extended = c.maxWidth >= 1200;
        return Scaffold(
          body: Row(children: [
            Semantics(
              container: true,
              label: 'Navegação principal',
              child: NavigationRail(
                key: const Key('main-rail'),
                selectedIndex: index,
                onDestinationSelected: onSelect,
                extended: extended,
                labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ]),
        );
      });
}
