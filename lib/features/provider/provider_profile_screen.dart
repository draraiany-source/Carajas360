import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/tap_guard.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';

enum _Tab { about, services, portfolio, reviews }

/// Rótulo de atendimento a partir de `modalities` (nunca inventa "online").
String _modalityLabel(String m) {
  switch (m) {
    case 'presential':
      return 'Atendimento presencial';
    case 'online':
      return 'Atendimento online';
    case 'home_care':
    case 'domiciliar':
      return 'Atendimento domiciliar';
    default:
      return '';
  }
}

IconData _modalityIcon(String m) {
  switch (m) {
    case 'online':
      return Icons.videocam_outlined;
    case 'home_care':
    case 'domiciliar':
      return Icons.home_outlined;
    default:
      return Icons.home_repair_service_outlined;
  }
}

/// Página pública de detalhes do profissional (Tela 03).
/// Mostra apenas dados existentes em `providers` e `reviews`.
class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  final ProviderModel? initial;
  const ProviderProfileScreen(
      {super.key, required this.providerId, this.initial});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  late final Stream<ProviderModel?> _provider;
  late final Stream<List<ReviewModel>> _reviews;
  final _quote = TextEditingController();
  final _quoteFocus = FocusNode();
  _Tab _tab = _Tab.about;
  String? _category;

  String get _id => widget.providerId.isNotEmpty
      ? widget.providerId
      : widget.initial?.id ?? '';

  @override
  void initState() {
    super.initState();
    _provider = _id.isEmpty
        ? Stream<ProviderModel?>.value(widget.initial)
        : FS.providerStream(_id);
    _reviews = _id.isEmpty || HomologCatalog.isDemoProvider(_id)
        ? Stream<List<ReviewModel>>.value(const [])
        : FS.providerReviewsStream(_id);
  }

  @override
  void dispose() {
    _quote.dispose();
    _quoteFocus.dispose();
    super.dispose();
  }

  static bool _isDemo(ProviderModel p) =>
      HomologCatalog.enabled && HomologCatalog.isDemoProvider(p.id);

  void _requestQuote(ProviderModel p) {
    if (_isDemo(p)) return;
    if (_quote.text.trim().isEmpty) {
      snack(context, 'Descreva o que você precisa para pedir o orçamento.');
      _quoteFocus.requestFocus();
      return;
    }
    final category = _category ??
        (p.categories.isNotEmpty ? p.categories.first : '');
    Navigator.pushNamed(context, Routes.requestService, arguments: {
      'providerId': providerAccountId(p),
      'providerName': p.name,
      'category': category,
      'remoteOnly': providerRemoteOnly(p),
      'description': _quote.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.isDark(context) ? null : Brand.background,
      body: SafeArea(
        child: StreamBuilder<ProviderModel?>(
          stream: _provider,
          initialData: widget.initial,
          builder: (context, snap) {
            final p = snap.data;
            if (p == null) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              return _NotFound(onBack: () => AppNav.safeBack(context));
            }
            final demo = _isDemo(p);
            return LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final tabs = _TabSection(
                provider: p,
                demo: demo,
                tab: _tab,
                reviews: _reviews,
                onTab: (t) => setState(() => _tab = t),
              );
              final side = Column(children: [
                _section(_QuoteCard(
                  provider: p,
                  demo: demo,
                  category: _category ??
                      (p.categories.isNotEmpty ? p.categories.first : null),
                  onCategory: (v) => setState(() => _category = v),
                  controller: _quote,
                  focus: _quoteFocus,
                  onSubmit: TapGuard.wrap(() => _requestQuote(p)),
                )),
                const SizedBox(height: 16),
                _section(_AreaCard(provider: p)),
              ]);
              return ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  BrandContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _section(_TopBar(wide: wide)),
                        const SizedBox(height: 12),
                        _section(_Hero(provider: p, demo: demo, wide: wide)),
                        if (demo) ...[
                          const SizedBox(height: 12),
                          const BrandDemoNotice(
                              message:
                                  'Perfil de demonstração: solicitações reais indisponíveis.'),
                        ],
                        const SizedBox(height: 16),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _section(tabs)),
                              const SizedBox(width: 16),
                              SizedBox(width: 360, child: side),
                            ],
                          )
                        else ...[
                          side,
                          const SizedBox(height: 16),
                          _section(tabs),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            });
          },
        ),
      ),
    );
  }
}

/// Sem fronteiras explícitas, o Flutter web junta todo o texto estático da
/// página no rótulo acessível do campo de texto.
Widget _section(Widget child) => Semantics(container: true, child: child);

// ─────────────────────────────────────────────────────────────
// Migalhas + hero
// ─────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool wide;
  const _TopBar({required this.wide});

  @override
  Widget build(BuildContext context) {
    final crumbs = BrandBreadcrumb(items: [
      (
        'Início',
        () => Navigator.pushNamedAndRemoveUntil(
            context, Routes.main, (_) => false)
      ),
      ('Explorar serviços', () => AppNav.safeBack(context)),
      ('Perfil profissional', null),
    ]);
    final back = BrandBackLink(
        label: 'Voltar aos resultados',
        onTap: () => AppNav.safeBack(context));
    if (!wide) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [crumbs, back]);
    }
    return Row(children: [Expanded(child: crumbs), back]);
  }
}

class _Hero extends StatelessWidget {
  final ProviderModel provider;
  final bool demo, wide;
  const _Hero({required this.provider, required this.demo, required this.wide});

  Widget _chip(IconData icon, String label, {bool light = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: light ? Brand.greenLight : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Brand.green),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Brand.greenDark)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final city = p.city?.trim() ?? '';
    final modalities = <String>[];
    for (final m in p.modalities) {
      final l = _modalityLabel(m);
      if (l.isNotEmpty && !modalities.any((x) => _modalityLabel(x) == l)) {
        modalities.add(m);
      }
    }
    final photoSize = wide ? 104.0 : 76.0;
    final chips = <Widget>[
      for (final m in modalities) _chip(_modalityIcon(m), _modalityLabel(m)),
      if (!demo && p.totalReviews > 0)
        _chip(Icons.star_rounded,
            '${p.rating.toStringAsFixed(1).replaceAll('.', ',')} · ${p.totalReviews} avaliações'),
      if (providerShowsVerified(p))
        _chip(Icons.verified_rounded, 'Perfil verificado'),
      if (demo) _chip(Icons.science_outlined, 'Perfil demonstrativo', light: true),
    ];
    return BrandPageHero(
      title: p.name,
      subtitle: [
        providerCategoryName(p),
        if (city.isNotEmpty) '$city • PA',
      ].where((s) => s.trim().isNotEmpty).join(' · '),
      height: wide ? 150 : 130,
      leading: Container(
        padding: const EdgeInsets.all(3),
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Colors.white),
        child: ClipOval(
          child: SizedBox(
            width: photoSize,
            height: photoSize,
            child: ExcludeSemantics(child: BrandProviderPhoto(provider: p)),
          ),
        ),
      ),
      trailing: wide ? _FavoriteButton(provider: p, demo: demo) : null,
      bottom: Wrap(spacing: 8, runSpacing: 8, children: [
        ...chips,
        if (!wide) _FavoriteButton(provider: p, demo: demo),
      ]),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  const _FavoriteButton({required this.provider, required this.demo});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final style = OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      disabledForegroundColor: Colors.white54,
      side: const BorderSide(color: Colors.white, width: 1.4),
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    if (demo) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.favorite_border_rounded, size: 19),
        label: const Text('Favoritar'),
        style: style.copyWith(
            side: WidgetStatePropertyAll(
                BorderSide(color: Colors.white.withValues(alpha: 0.4)))),
      );
    }
    return StreamBuilder<bool>(
      stream: FS.isFavoriteStream(p.id),
      builder: (context, snap) {
        final fav = snap.data ?? false;
        return OutlinedButton.icon(
          onPressed: () => toggleProviderFavorite(context, p.id),
          icon: Icon(
              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 19),
          label: Text(fav ? 'Favoritado' : 'Favoritar'),
          style: style,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Abas
// ─────────────────────────────────────────────────────────────

class _TabSection extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  final _Tab tab;
  final Stream<List<ReviewModel>> reviews;
  final ValueChanged<_Tab> onTab;
  const _TabSection({
    required this.provider,
    required this.demo,
    required this.tab,
    required this.reviews,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      _Tab.about: 'Sobre',
      _Tab.services: 'Serviços',
      _Tab.portfolio: 'Portfólio',
      _Tab.reviews: !demo && provider.totalReviews > 0
          ? 'Avaliações (${provider.totalReviews})'
          : 'Avaliações',
    };
    final body = switch (tab) {
      _Tab.about => _About(provider: provider, demo: demo),
      _Tab.services => _Services(provider: provider, demo: demo),
      _Tab.portfolio => _Portfolio(provider: provider),
      _Tab.reviews => _Reviews(provider: provider, demo: demo, stream: reviews),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandSoftCard(
          padding: const EdgeInsets.all(6),
          child: ScrollConfiguration(
            behavior: const BrandDragScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final t in _Tab.values)
                  _TabButton(
                    label: labels[t]!,
                    selected: t == tab,
                    onTap: () => onTab(t),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrandSoftCard(
          padding: const EdgeInsets.all(20),
          child: _section(body),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected ? true : null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? Brand.green : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Brand.ink(context))),
          ),
        ),
      ),
    );
  }
}

Widget _sectionTitle(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Brand.ink(context))),
    );

Widget _fact(BuildContext context, IconData icon, String text) =>
    Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Brand.green, size: 22),
      const SizedBox(width: 8),
      Flexible(
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Brand.ink(context))),
      ),
    ]);

const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', //
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

class _About extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  const _About({required this.provider, required this.demo});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final bio = p.bio?.trim() ?? '';
    final since = '${_months[p.createdAt.month - 1]} de ${p.createdAt.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Sobre o profissional'),
        Text(
          bio.isNotEmpty
              ? bio
              : '${p.name} ainda não escreveu uma apresentação.',
          style: TextStyle(
              fontSize: 14, height: 1.5, color: Brand.inkMuted(context)),
        ),
        const SizedBox(height: 16),
        Divider(color: Brand.line(context), height: 1),
        const SizedBox(height: 16),
        Wrap(spacing: 28, runSpacing: 12, children: [
          if (!demo)
            _fact(context, Icons.event_available_outlined,
                'No Carajás 360 desde $since'),
          if (!demo && p.totalReviews > 0)
            _fact(context, Icons.star_outline_rounded,
                '${p.totalReviews} avaliações de clientes'),
          if (p.city != null && p.city!.isNotEmpty)
            _fact(context, Icons.location_on_outlined, 'Atende em ${p.city}'),
          if (p.certificates.isNotEmpty)
            _fact(
                context,
                Icons.workspace_premium_outlined,
                p.certificates.length == 1
                    ? '1 certificado informado'
                    : '${p.certificates.length} certificados informados'),
        ]),
      ],
    );
  }
}

class _Services extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  const _Services({required this.provider, required this.demo});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final price = !demo && p.minPrice != null
        ? formatStartingPrice(p.minPrice!)
        : 'Valor sob consulta';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Serviços oferecidos'),
        if (p.categories.isEmpty)
          Text('O profissional ainda não informou os serviços.',
              style: TextStyle(color: Brand.inkMuted(context)))
        else
          for (final id in p.categories)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Brand.isDark(context) ? null : Brand.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Brand.line(context)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: Brand.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(Categories.byId(id)?.name ?? id,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Brand.ink(context))),
                ),
              ]),
            ),
        const SizedBox(height: 8),
        Divider(color: Brand.line(context), height: 1),
        const SizedBox(height: 14),
        _fact(context, Icons.sell_outlined, price),
        const SizedBox(height: 8),
        Text(
          'O valor final é combinado com o profissional após ele avaliar o pedido.',
          style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context)),
        ),
      ],
    );
  }
}

/// Não há campo de portfólio no cadastro; mostramos apenas certificados
/// informados pelo profissional (texto), sem imagens inventadas.
class _Portfolio extends StatelessWidget {
  final ProviderModel provider;
  const _Portfolio({required this.provider});

  @override
  Widget build(BuildContext context) {
    final certs =
        provider.certificates.where((c) => c.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Portfólio'),
        Text(
          'Este profissional ainda não publicou fotos de trabalhos.',
          style: TextStyle(color: Brand.inkMuted(context)),
        ),
        if (certs.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: Brand.line(context), height: 1),
          const SizedBox(height: 16),
          _sectionTitle(context, 'Certificados e formações informados'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in certs)
              Chip(
                avatar: const Icon(Icons.workspace_premium_outlined,
                    size: 18, color: Brand.green),
                label: Text(c),
                backgroundColor:
                    Brand.isDark(context) ? null : Brand.greenLight,
                side: BorderSide.none,
              ),
          ]),
        ],
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  final Stream<List<ReviewModel>> stream;
  const _Reviews(
      {required this.provider, required this.demo, required this.stream});

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return StreamBuilder<List<ReviewModel>>(
      stream: stream,
      builder: (context, snap) {
        final list = snap.data ?? const <ReviewModel>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, 'Avaliações'),
            if (!demo && p.totalReviews > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _fact(
                    context,
                    Icons.star_rounded,
                    'Nota média ${p.rating.toStringAsFixed(1).replaceAll('.', ',')} '
                    'em ${p.totalReviews} avaliações'),
              ),
            if (snap.connectionState == ConnectionState.waiting &&
                list.isEmpty &&
                !demo)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              Text('Não foi possível carregar os comentários agora.',
                  style: TextStyle(color: Brand.inkMuted(context)))
            else if (list.isEmpty)
              Text(
                !demo && p.totalReviews > 0
                    ? 'Os comentários das avaliações ainda não estão disponíveis para leitura.'
                    : 'Ainda sem avaliações',
                style: TextStyle(color: Brand.inkMuted(context)),
              )
            else
              for (final r in list)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Brand.isDark(context) ? null : Brand.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Brand.line(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(r.clientName,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Brand.ink(context))),
                        ),
                        Text(_date(r.createdAt),
                            style: TextStyle(
                                fontSize: 12, color: Brand.inkMuted(context))),
                      ]),
                      const SizedBox(height: 4),
                      Semantics(
                        label: '${r.stars} de 5 estrelas',
                        excludeSemantics: true,
                        child: Row(children: [
                          for (var i = 0; i < 5; i++)
                            Icon(
                                i < r.stars
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 17,
                                color: Brand.gold),
                        ]),
                      ),
                      if (r.comment.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(r.comment,
                            style: TextStyle(
                                height: 1.4, color: Brand.ink(context))),
                      ],
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Lateral: orçamento + região
// ─────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final ProviderModel provider;
  final bool demo;
  final String? category;
  final ValueChanged<String?> onCategory;
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback? onSubmit;
  const _QuoteCard({
    required this.provider,
    required this.demo,
    required this.category,
    required this.onCategory,
    required this.controller,
    required this.focus,
    required this.onSubmit,
  });

  OutlineInputBorder _border(BuildContext context, {Color? color, double w = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color ?? Brand.line(context), width: w),
      );

  @override
  Widget build(BuildContext context) {
    final p = provider;
    return BrandSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Solicitar orçamento',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          const SizedBox(height: 4),
          Text('O valor depende do que você precisa e é combinado com o profissional.',
              style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context))),
          const SizedBox(height: 14),
          if (p.categories.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Serviço',
                border: _border(context),
                enabledBorder: _border(context),
                focusedBorder: _border(context, color: Brand.green, w: 1.6),
                floatingLabelStyle: const TextStyle(color: Brand.green),
              ),
              items: [
                for (final id in p.categories)
                  DropdownMenuItem(
                      value: id, child: Text(Categories.byId(id)?.name ?? id)),
              ],
              onChanged: demo ? null : onCategory,
            ),
            const SizedBox(height: 12),
          ],
          _section(TextField(
            controller: controller,
            focusNode: focus,
            enabled: !demo,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'O que você precisa?',
              hintText: 'Descreva o serviço desejado',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Brand.isDark(context) ? null : Brand.background,
              border: _border(context),
              enabledBorder: _border(context),
              focusedBorder: _border(context, color: Brand.green, w: 1.6),
              floatingLabelStyle: const TextStyle(color: Brand.green),
            ),
          )),
          const SizedBox(height: 6),
          BrandPrimaryButton(
            label: demo ? 'Indisponível na demonstração' : 'Solicitar orçamento',
            icon: demo ? null : Icons.arrow_forward_rounded,
            locked: demo,
            onPressed: demo ? null : onSubmit,
          ),
          const SizedBox(height: 10),
          Text(
            demo
                ? 'Pedidos serão liberados para profissionais reais cadastrados.'
                : 'Você revisa o pedido antes de enviar. Nenhuma cobrança é feita nesta etapa.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Brand.inkMuted(context)),
          ),
          const SizedBox(height: 10),
          BrandPrimaryButton(
            label: 'Conversar no chat',
            icon: Icons.chat_bubble_outline_rounded,
            outlined: true,
            locked: demo,
            onPressed: demo
                ? null
                : TapGuard.wrap(() => openProviderChat(context, p)),
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline_rounded,
                size: 16, color: Brand.inkMuted(context)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Seu endereço só é enviado ao profissional quando você confirma a solicitação. Não compartilhe senhas ou documentos pelo chat.',
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Brand.inkMuted(context)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final ProviderModel provider;
  const _AreaCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final places = <String>{
      if (p.city != null && p.city!.isNotEmpty) p.city!,
      ...p.serviceAreas.where((s) => s.trim().isNotEmpty),
    };
    return BrandSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Região de atendimento',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          const SizedBox(height: 12),
          if (places.isEmpty)
            Text('O profissional ainda não informou a área de atendimento.',
                style: TextStyle(color: Brand.inkMuted(context)))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final place in places)
                Chip(
                  avatar: const Icon(Icons.location_on_outlined,
                      size: 18, color: Brand.green),
                  label: Text(place),
                  backgroundColor:
                      Brand.isDark(context) ? null : Brand.greenLight,
                  side: BorderSide.none,
                ),
            ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(left: 10),
            decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Brand.gold, width: 3))),
            child: Text(
              'Endereço exato compartilhado apenas na contratação.',
              style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  final VoidCallback onBack;
  const _NotFound({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_search_outlined,
              size: 48, color: Brand.green),
          const SizedBox(height: 12),
          Text('Profissional não encontrado',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Brand.ink(context))),
          const SizedBox(height: 6),
          Text('Este perfil pode ter sido removido ou estar indisponível.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Brand.inkMuted(context))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Voltar'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Brand.green, foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }
}
