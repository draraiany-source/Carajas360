import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/search/provider_search.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';

/// Tela 09 — Favoritos (dados reais do stream do usuário).
///
/// Contagens e filtros partem da lista real de favoritos; nada é inventado.
/// O coração otimista vive em [BrandFavoriteButton] (cartão do profissional).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  String _q = '';
  String? _group; // null = todos; senão, grupo de Categories
  bool _grid = true;

  /// Stream fixo: reconstruir a tela não reassina o Firestore.
  late final Stream<List<ProviderModel>> _favorites =
      FS.favoritesStream().asBroadcastStream();

  static Set<String> _groupsOf(ProviderModel p) => {
        for (final id in p.categories)
          if (Categories.byId(id)?.group != null) Categories.byId(id)!.group,
      };

  bool _inGroup(ProviderModel p, String g) => _groupsOf(p).contains(g);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.isDark(context)
          ? Theme.of(context).scaffoldBackgroundColor
          : Brand.background,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<List<ProviderModel>>(
          stream: _favorites,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError && !snap.hasData) {
              return const EmptyState(
                emoji: '⚠️',
                title: 'Falha ao carregar favoritos',
                subtitle: 'Verifique a conexão e tente novamente.',
              );
            }
            return _content(context, snap.data ?? const <ProviderModel>[]);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<ProviderModel> all) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final inner = AppNav.isInnerPage(context);

    final groups = <String>{for (final p in all) ..._groupsOf(p)}.toList()
      ..sort();
    // Grupo que sumiu (ex.: último favorito do grupo removido): volta a Todos.
    final group = groups.contains(_group) ? _group : null;

    final filtered = all
        .where((p) =>
            (group == null || _inGroup(p, group)) &&
            ProviderSearch.matchesQuery(p, _q))
        .toList();

    final countLabel = all.isEmpty
        ? 'Nenhum profissional salvo'
        : '${filtered.length} ${filtered.length == 1 ? 'perfil' : 'perfis'}'
            '${filtered.length != all.length ? ' de ${all.length}' : ''}';

    final search = TextField(
      onChanged: (v) => setState(() => _q = v),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Buscar nos favoritos',
        prefixIcon: const Icon(Icons.search_rounded, color: Brand.green),
        isDense: true,
        filled: true,
        fillColor: Brand.surface(context),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Brand.line(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Brand.line(context)),
        ),
      ),
    );

    final chips = Wrap(spacing: 8, runSpacing: 8, children: [
      _chip(context, 'Todos (${all.length})', group == null,
          () => setState(() => _group = null)),
      for (final g in groups)
        _chip(
            context,
            '$g (${all.where((p) => _inGroup(p, g)).length})',
            group == g,
            () => setState(() => _group = g)),
    ]);

    final toggle = Container(
      decoration: BoxDecoration(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Brand.line(context)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (g, icon, tip) in [
          (true, Icons.grid_view_rounded, 'Ver em grade'),
          (false, Icons.view_list_rounded, 'Ver em lista'),
        ])
          IconButton(
            tooltip: tip,
            isSelected: _grid == g,
            onPressed: () => setState(() => _grid = g),
            style: IconButton.styleFrom(
              backgroundColor: _grid == g ? Brand.green : Colors.transparent,
              foregroundColor:
                  _grid == g ? Colors.white : Brand.inkMuted(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(icon, size: 20),
          ),
      ]),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        BrandContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: wide ? 16 : 12),
              if (wide) ...[
                BrandBreadcrumb(items: [
                  (
                    'Início',
                    () => Navigator.pushNamedAndRemoveUntil(
                        context, Routes.main, (_) => false)
                  ),
                  ('Favoritos', null),
                ]),
                const SizedBox(height: 12),
              ],
              BrandPageHero(
                title: 'Seus favoritos',
                subtitle:
                    'Encontre com facilidade os profissionais que você salvou.',
                leading: inner
                    ? Material(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Voltar',
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          onPressed: () => AppNav.safeBack(context),
                        ),
                      )
                    : null,
                trailing: Icon(Icons.favorite_rounded,
                    size: wide ? 56 : 38,
                    color: Brand.gold.withValues(alpha: 0.9)),
              ),
              if (HomologCatalog.enabled) ...[
                const SizedBox(height: 12),
                const BrandDemoNotice(
                    message:
                        'Modo demonstração • perfis e favoritos ilustrativos.'),
              ],
              const SizedBox(height: 16),
              if (all.isNotEmpty) ...[
                if (wide)
                  Row(children: [
                    Expanded(flex: 3, child: search),
                    const SizedBox(width: 12),
                    Flexible(flex: 5, child: chips),
                    const SizedBox(width: 12),
                    toggle,
                  ])
                else ...[
                  search,
                  const SizedBox(height: 12),
                  chips,
                ],
                const SizedBox(height: 18),
                Row(children: [
                  Semantics(
                    header: true,
                    child: Text('Profissionais salvos',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Brand.ink(context))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(countLabel,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Brand.inkMuted(context))),
                    ),
                  ),
                  if (!wide) toggle,
                ]),
                const SizedBox(height: 14),
              ],
              if (all.isEmpty)
                _emptyState(context)
              else if (filtered.isEmpty)
                _noResults(context)
              else
                BrandProviderGrid(list: filtered, asList: !_grid),
              if (all.isNotEmpty) ...[
                const SizedBox(height: 24),
                _footerCta(context),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, String label, bool sel, VoidCallback onTap) =>
      FilterChip(
        label: Text(label),
        selected: sel,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: Brand.greenLight,
        backgroundColor: Brand.surface(context),
        side: BorderSide(color: sel ? Brand.green : Brand.line(context)),
        labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
            color: sel ? Brand.green : Brand.ink(context)),
      );

  Widget _emptyState(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(children: [
          const Icon(Icons.favorite_border_rounded,
              size: 52, color: Brand.green),
          const SizedBox(height: 12),
          Text('Nenhum favorito ainda',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          const SizedBox(height: 6),
          Text(
              'Toque no coração de um profissional para salvá-lo aqui e '
              'encontrá-lo com facilidade depois.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, height: 1.4, color: Brand.inkMuted(context))),
          const SizedBox(height: 18),
          BrandPrimaryButton(
            label: 'Explorar profissionais',
            icon: Icons.search_rounded,
            expanded: false,
            onPressed: () => Navigator.pushNamed(context, Routes.search),
          ),
        ]),
      );

  Widget _noResults(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(children: [
          Icon(Icons.search_off_rounded,
              size: 40, color: Brand.inkMuted(context)),
          const SizedBox(height: 10),
          Text('Nenhum favorito com esta busca ou filtro',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink(context))),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() {
              _q = '';
              _group = null;
            }),
            style: OutlinedButton.styleFrom(
                foregroundColor: Brand.green,
                side: const BorderSide(color: Brand.green)),
            child: const Text('Limpar busca e filtros'),
          ),
        ]),
      );

  Widget _footerCta(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Brand.goldLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Brand.gold.withValues(alpha: 0.45)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 16,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite_border_rounded,
                  color: Brand.greenDark),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Salvou, encontrou.',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Brand.greenDark)),
                    Text('Use o coração nos perfis para organizar seus favoritos.',
                        style: TextStyle(
                            fontSize: 12.5, color: Color(0xFF5C4400))),
                  ],
                ),
              ),
            ]),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, Routes.search),
              style: OutlinedButton.styleFrom(
                foregroundColor: Brand.greenDark,
                side: const BorderSide(color: Brand.greenDark),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Explorar mais profissionais',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
