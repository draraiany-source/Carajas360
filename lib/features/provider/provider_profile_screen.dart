import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/tap_guard.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/widgets.dart';

enum _Tab { about, services, reviews, area }

/// Página pública de detalhes do profissional (Tela 03 / Tela 08).
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

  String get _id => widget.providerId.isNotEmpty
      ? widget.providerId
      : widget.initial?.id ?? '';

  @override
  void initState() {
    super.initState();
    _provider = _id.isEmpty
        ? Stream<ProviderModel?>.value(widget.initial)
        : FS.providerStream(_id);
    _reviews = _id.isEmpty
        ? Stream<List<ReviewModel>>.value(const [])
        : FS.providerReviewsStream(_id);
  }

  @override
  void dispose() {
    _quote.dispose();
    _quoteFocus.dispose();
    super.dispose();
  }

  void _requestQuote(ProviderModel p) {
    if (_quote.text.trim().isEmpty) {
      snack(context, 'Descreva o que você precisa para pedir o orçamento.');
      _quoteFocus.requestFocus();
      return;
    }
    requestProviderService(context, p, description: _quote.text);
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
              return _NotFound(onBack: () => Navigator.maybePop(context));
            }
            return LayoutBuilder(builder: (context, c) {
              final wide = c.maxWidth >= 900;
              final pad = wide ? 28.0 : 16.0;
              final tabs = _TabSection(
                provider: p,
                tab: _tab,
                reviews: _reviews,
                onTab: (t) => setState(() => _tab = t),
              );
              final quote = _QuoteCard(
                controller: _quote,
                focus: _quoteFocus,
                onSubmit: TapGuard.wrap(() => _requestQuote(p)),
              );
              return ListView(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 40),
                children: [
                  Center(
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section(_Breadcrumb(provider: p)),
                          const SizedBox(height: 12),
                          _section(_Hero(provider: p, wide: wide)),
                          const SizedBox(height: 16),
                          if (wide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _section(tabs)),
                                const SizedBox(width: 16),
                                SizedBox(width: 340, child: _section(quote)),
                              ],
                            )
                          else ...[
                            _section(quote),
                            const SizedBox(height: 16),
                            _section(tabs),
                          ],
                        ],
                      ),
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

// ─────────────────────────────────────────────────────────────
// Cabeçalho
// ─────────────────────────────────────────────────────────────

/// Sem fronteiras explícitas, o Flutter web junta todo o texto estático da
/// página no rótulo acessível do campo de texto.
Widget _section(Widget child) => Semantics(container: true, child: child);

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
      color: Brand.surface(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Brand.line(context)),
      boxShadow: Brand.shadow(context),
    );

class _Breadcrumb extends StatelessWidget {
  final ProviderModel provider;
  const _Breadcrumb({required this.provider});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 12.5, color: Brand.inkMuted(context));
    return Row(children: [
      IconButton(
        tooltip: 'Voltar',
        onPressed: () => Navigator.maybePop(context),
        style: IconButton.styleFrom(
          backgroundColor: Brand.surface(context),
          side: BorderSide(color: Brand.line(context)),
        ),
        icon: const Icon(Icons.arrow_back_rounded, color: Brand.green),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: ExcludeSemantics(
          child: Text.rich(
            TextSpan(style: muted, children: [
              const TextSpan(text: 'Explorar Serviços  ›  '),
              TextSpan(text: '${providerCategoryName(provider)}  ›  '),
              TextSpan(
                  text: 'Detalhes',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Brand.ink(context))),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ]);
  }
}

class _Hero extends StatelessWidget {
  final ProviderModel provider;
  final bool wide;
  const _Hero({required this.provider, required this.wide});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: wide ? 300 : double.infinity,
        height: wide ? 230 : 190,
        child: ExcludeSemantics(child: BrandProviderPhoto(provider: p)),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Flexible(
            child: Text(p.name,
                style: TextStyle(
                    fontSize: wide ? 26 : 22,
                    fontWeight: FontWeight.w800,
                    color: Brand.ink(context))),
          ),
          if (p.verified) ...[
            const SizedBox(width: 8),
            const Tooltip(
              message: 'Perfil verificado',
              child: Icon(Icons.verified_rounded, color: Brand.green, size: 24),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Text(
          p.categories.isEmpty
              ? 'Profissional'
              : p.categories
                  .map((id) => Categories.byId(id)?.name ?? id)
                  .join(' · '),
          style: TextStyle(fontSize: 14, color: Brand.inkMuted(context)),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 18,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, color: Brand.gold, size: 20),
              const SizedBox(width: 4),
              Text(
                p.totalReviews > 0
                    ? '${p.rating.toStringAsFixed(1).replaceAll('.', ',')}  (${p.totalReviews} avaliações)'
                    : 'Novo no Carajás 360',
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Brand.ink(context)),
              ),
            ]),
            if (p.city != null && p.city!.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_outlined,
                    color: Brand.green, size: 18),
                const SizedBox(width: 4),
                Text(p.city!,
                    style:
                        TextStyle(fontSize: 13.5, color: Brand.ink(context))),
              ]),
          ],
        ),
        const SizedBox(height: 14),
        _Highlights(provider: p),
        const SizedBox(height: 16),
        _Actions(provider: p),
      ],
    );
    return Container(
      padding: EdgeInsets.all(wide ? 20 : 14),
      decoration: _cardDecoration(context),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                photo,
                const SizedBox(width: 24),
                Expanded(child: info)
              ],
            )
          : Column(children: [photo, const SizedBox(height: 14), info]),
    );
  }
}

class _Highlights extends StatelessWidget {
  final ProviderModel provider;
  const _Highlights({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final items = <(IconData, String)>[
      if (p.verified) (Icons.verified_user_outlined, 'Profissional verificado'),
      if (p.modalities.contains('presential'))
        (Icons.home_repair_service_outlined, 'Atendimento presencial'),
      if (p.modalities.contains('online'))
        (Icons.videocam_outlined, 'Atendimento online'),
      if (p.certificates.isNotEmpty)
        (
          Icons.workspace_premium_outlined,
          p.certificates.length == 1
              ? '1 certificado enviado'
              : '${p.certificates.length} certificados enviados'
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border.symmetric(
            horizontal: BorderSide(color: Brand.line(context))),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 10,
        children: [
          for (final (icon, label) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: Brand.green, size: 22),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Brand.ink(context))),
            ]),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final ProviderModel provider;
  const _Actions({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const size = Size(0, 46);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      ElevatedButton.icon(
        onPressed: TapGuard.wrap(() => requestProviderService(context, p)),
        icon: const Icon(Icons.event_available_rounded, size: 20),
        label: const Text('Solicitar serviço'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.green,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          shape: shape,
        ),
      ),
      OutlinedButton.icon(
        onPressed: TapGuard.wrap(() => openProviderChat(context, p)),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
        label: const Text('Conversar no chat'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Brand.green,
          side: const BorderSide(color: Brand.green, width: 1.4),
          minimumSize: size,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          shape: shape,
        ),
      ),
      StreamBuilder<bool>(
        stream: FS.isFavoriteStream(p.id),
        builder: (context, snap) {
          final fav = snap.data ?? false;
          return OutlinedButton.icon(
            onPressed: () => toggleProviderFavorite(context, p.id),
            icon: Icon(
                fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 19,
                color: fav ? Colors.redAccent : Brand.green),
            label: Text(fav ? 'Favoritado' : 'Favoritar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Brand.ink(context),
              side: BorderSide(color: Brand.line(context), width: 1.4),
              minimumSize: size,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              shape: shape,
            ),
          );
        },
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────
// Abas
// ─────────────────────────────────────────────────────────────

class _TabSection extends StatelessWidget {
  final ProviderModel provider;
  final _Tab tab;
  final Stream<List<ReviewModel>> reviews;
  final ValueChanged<_Tab> onTab;
  const _TabSection({
    required this.provider,
    required this.tab,
    required this.reviews,
    required this.onTab,
  });

  @override
  Widget build(BuildContext context) {
    final labels = {
      _Tab.about: 'Sobre',
      _Tab.services: 'Serviços',
      _Tab.reviews: 'Avaliações (${provider.totalReviews})',
      _Tab.area: 'Área de atendimento',
    };
    final body = switch (tab) {
      _Tab.about => _About(provider: provider),
      _Tab.services => _Services(provider: provider),
      _Tab.reviews => _Reviews(provider: provider, stream: reviews),
      _Tab.area => _Area(provider: provider),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: _cardDecoration(context),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(context),
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
      Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Brand.ink(context))),
    ]);

const _months = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', //
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

class _About extends StatelessWidget {
  final ProviderModel provider;
  const _About({required this.provider});

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
          _fact(context, Icons.event_available_outlined,
              'No Carajás 360 desde $since'),
          if (p.totalReviews > 0)
            _fact(context, Icons.star_outline_rounded,
                '${p.totalReviews} avaliações de clientes'),
          if (p.city != null && p.city!.isNotEmpty)
            _fact(context, Icons.location_on_outlined, 'Atende em ${p.city}'),
        ]),
      ],
    );
  }
}

class _Services extends StatelessWidget {
  final ProviderModel provider;
  const _Services({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final price = p.minPrice != null
        ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(2).replaceAll('.', ',')}'
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
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: Brand.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(Categories.byId(id)?.name ?? id,
                      style:
                          TextStyle(fontSize: 14, color: Brand.ink(context))),
                ),
              ]),
            ),
        const SizedBox(height: 8),
        Divider(color: Brand.line(context), height: 1),
        const SizedBox(height: 14),
        _fact(context, Icons.sell_outlined, 'Preço inicial: $price'),
        const SizedBox(height: 8),
        Text(
          'O valor final é combinado com o profissional após ele avaliar o pedido.',
          style: TextStyle(fontSize: 12.5, color: Brand.inkMuted(context)),
        ),
      ],
    );
  }
}

class _Reviews extends StatelessWidget {
  final ProviderModel provider;
  final Stream<List<ReviewModel>> stream;
  const _Reviews({required this.provider, required this.stream});

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
            if (p.totalReviews > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _fact(
                    context,
                    Icons.star_rounded,
                    'Nota média ${p.rating.toStringAsFixed(1).replaceAll('.', ',')} '
                    'em ${p.totalReviews} avaliações'),
              ),
            if (snap.connectionState == ConnectionState.waiting && list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snap.hasError)
              Text('Não foi possível carregar os comentários agora.',
                  style: TextStyle(color: Brand.inkMuted(context)))
            else if (list.isEmpty)
              Text(
                p.totalReviews > 0
                    ? 'Os comentários das avaliações ainda não estão disponíveis para leitura.'
                    : 'Este profissional ainda não recebeu avaliações.',
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

class _Area extends StatelessWidget {
  final ProviderModel provider;
  const _Area({required this.provider});

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final places = <String>{
      if (p.city != null && p.city!.isNotEmpty) p.city!,
      ...p.serviceAreas.where((s) => s.trim().isNotEmpty),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, 'Área de atendimento'),
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
        const SizedBox(height: 14),
        Wrap(spacing: 22, runSpacing: 10, children: [
          if (p.modalities.contains('presential'))
            _fact(context, Icons.home_repair_service_outlined,
                'Atende no local do cliente'),
          if (p.modalities.contains('online'))
            _fact(context, Icons.videocam_outlined, 'Atende online'),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Orçamento rápido e estados
// ─────────────────────────────────────────────────────────────

class _QuoteCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback? onSubmit;
  const _QuoteCard(
      {required this.controller, required this.focus, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Brand.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.request_quote_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text('Orçamento rápido',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Brand.ink(context))),
          ]),
          const SizedBox(height: 12),
          _section(TextField(
            controller: controller,
            focusNode: focus,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Descreva o que você precisa',
              hintText: 'Ex.: instalação de chuveiro, troca de tomada...',
              alignLabelWithHint: true,
              filled: true,
              fillColor: Brand.isDark(context) ? null : Brand.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Brand.line(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Brand.green, width: 1.6),
              ),
              floatingLabelStyle: const TextStyle(color: Brand.green),
            ),
          )),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onSubmit,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Solicitar orçamento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Brand.gold,
                foregroundColor: Brand.greenDark,
                elevation: 0,
                minimumSize: const Size(0, 46),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Você revisa o pedido antes de enviar. Nenhuma cobrança é feita nesta etapa.',
            style: TextStyle(fontSize: 11.5, color: Brand.inkMuted(context)),
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
