import 'package:flutter/material.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/constants/app_assets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/brand.dart';
import '../../core/utils/app_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/brand_provider_card.dart';
import '../../shared/widgets/brand_shell.dart';
import '../../shared/widgets/widgets.dart';

/// Tela 08 — Saúde e bem-estar.
///
/// Profissionais reais (ou catálogo de homologação marcado como demo).
/// O painel "Solicitar agendamento" só abre uma solicitação real
/// (fluxo de orçamento): datas/períodos são preferências, nunca horários
/// livres ou confirmados.
class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthState();
}

class _HealthState extends State<HealthScreen> {
  int _mode = 0;
  String? _sel;
  String _q = '';
  String? _selectedProviderId;
  /// Stream estável — não recriar no build (evita freeze no Web).
  late Stream<List<ProviderModel>> _providers;

  static const _modeLabels = ['Todos', 'Online', 'Presencial', 'Domiciliar'];

  static const _specialties = [
    {'id': 'medico', 'name': 'Médico', 'icon': Icons.medical_services_outlined},
    {'id': 'psicologo', 'name': 'Psicólogo', 'icon': Icons.psychology_outlined},
    {
      'id': 'fisioterapeuta',
      'name': 'Fisioterapeuta',
      'icon': Icons.accessibility_new_outlined
    },
    {
      'id': 'enfermeiro',
      'name': 'Enfermeiro',
      'icon': Icons.health_and_safety_outlined
    },
    {
      'id': 'nutricionista',
      'name': 'Nutricionista',
      'icon': Icons.restaurant_outlined
    },
    {'id': 'home_care', 'name': 'Home Care', 'icon': Icons.home_outlined},
  ];

  static const _healthIds = {
    'medico',
    'psicologo',
    'fisioterapeuta',
    'enfermeiro',
    'nutricionista',
    'home_care',
  };

  static bool _isDemo(ProviderModel p) =>
      HomologCatalog.enabled && HomologCatalog.isDemoProvider(p.id);

  static String _specialtyName(ProviderModel p) {
    for (final s in _specialties) {
      if (p.categories.contains(s['id'])) return s['name'] as String;
    }
    return 'Saúde';
  }

  static String? _healthCategory(ProviderModel p) {
    for (final c in p.categories) {
      if (_healthIds.contains(c)) return c;
    }
    return p.categories.isNotEmpty ? p.categories.first : null;
  }

  List<ProviderModel> _applyLocalFilters(List<ProviderModel> source) {
    var list = List<ProviderModel>.from(source);
    if (_sel != null) {
      list = list.where((p) => p.categories.contains(_sel)).toList();
    } else {
      list = list.where((p) => p.categories.any(_healthIds.contains)).toList();
    }
    switch (_mode) {
      case 1:
        list = list.where((p) => p.modalities.contains('online')).toList();
        break;
      case 2:
        list = list.where((p) => p.modalities.contains('presential')).toList();
        break;
      case 3:
        list = list
            .where((p) =>
                p.categories.contains('home_care') ||
                p.modalities.contains('home_care'))
            .toList();
        break;
    }
    if (_q.trim().isNotEmpty) {
      final q = _q.toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              _specialtyName(p).toLowerCase().contains(q) ||
              p.categories.any((c) => c.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    // Uma inscrição; filtros de especialidade/modalidade/texto são locais.
    _providers = HomologCatalog.enabled
        ? Stream<List<ProviderModel>>.value(HomologCatalog.healthProviders())
            .asBroadcastStream()
        : FS.providersStream(limit: 60);
  }

  List<ProviderModel> _visible(List<ProviderModel> raw) =>
      _applyLocalFilters(raw);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: Brand.isDark(context) ? null : Brand.background,
      body: SafeArea(
        child: StreamBuilder<List<ProviderModel>>(
          stream: _providers,
          builder: (context, snap) {
            final waiting = snap.connectionState == ConnectionState.waiting &&
                !snap.hasData;
            final provs = _visible(snap.data ?? const <ProviderModel>[]);
            ProviderModel? selected;
            for (final p in provs) {
              if (p.id == _selectedProviderId) selected = p;
            }
            selected ??= provs.isNotEmpty ? provs.first : null;

            final list = _ProviderList(
              waiting: waiting,
              hasError: snap.hasError,
              providers: provs,
              selectedId: selected?.id,
              wide: wide,
              specialtyName: _specialtyName,
              onSelect: (p) => setState(() => _selectedProviderId = p.id),
              onRequest: (p) {
                setState(() => _selectedProviderId = p.id);
                if (!wide) _openPanelSheet(context, p);
              },
              onRetry: () {
                FS.resetProvidersStreams();
                setState(() {
                  _providers = HomologCatalog.enabled
                      ? Stream<List<ProviderModel>>.value(
                              HomologCatalog.healthProviders())
                          .asBroadcastStream()
                      : FS.providersStream(limit: 60);
                });
              },
            );
            final panel = selected == null
                ? const _EmptyPanel()
                : _BookingPanel(
                    key: ValueKey(selected.id),
                    provider: selected,
                    specialty: _specialtyName(selected),
                    category: _healthCategory(selected),
                  );

            return ListView(
              padding: const EdgeInsets.only(bottom: 48),
              children: [
                BrandContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: BrandBreadcrumb(items: [
                            (
                              'Início',
                              () => Navigator.pushNamedAndRemoveUntil(
                                  context, Routes.main, (_) => false)
                            ),
                            ('Saúde', null),
                          ]),
                        ),
                        BrandBackLink(onTap: () => AppNav.safeBack(context)),
                      ]),
                      const SizedBox(height: 12),
                      BrandPageHero(
                        title: 'Saúde e bem-estar',
                        subtitle:
                            'Encontre profissionais e solicite um horário.',
                        height: 120,
                        bottom: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: AppSearchBar(
                              hint: 'Nome ou especialidade',
                              onChanged: (v) => setState(() => _q = v)),
                        ),
                      ),
                      if (HomologCatalog.enabled) ...[
                        const SizedBox(height: 12),
                        const BrandDemoNotice(
                            message:
                                'Modo demonstração • profissionais ilustrativos. Nenhum agendamento real será realizado.'),
                      ],
                      const SizedBox(height: 14),
                      _specialtyChips(),
                      const SizedBox(height: 10),
                      _modeChips(),
                      const SizedBox(height: 16),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: list),
                            const SizedBox(width: 16),
                            SizedBox(width: 380, child: panel),
                          ],
                        )
                      else
                        list,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openPanelSheet(BuildContext context, ProviderModel p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.isDark(context) ? null : Brand.background,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: _BookingPanel(
            provider: p,
            specialty: _specialtyName(p),
            category: _healthCategory(p),
          ),
        ),
      ),
    );
  }

  Widget _chip(
      {required String label,
      IconData? icon,
      required bool selected,
      required VoidCallback onTap}) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? Brand.greenLight : Brand.surface(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: selected ? Brand.green : Brand.line(context),
                  width: selected ? 1.6 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: Brand.green),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? Brand.green : Brand.ink(context))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _specialtyChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip(
              label: 'Todas',
              icon: Icons.grid_view_rounded,
              selected: _sel == null,
              onTap: () => setState(() => _sel = null)),
          for (final s in _specialties) ...[
            const SizedBox(width: 8),
            _chip(
                label: s['name'] as String,
                icon: s['icon'] as IconData,
                selected: _sel == s['id'],
                onTap: () => setState(() {
                      final id = s['id'] as String;
                      _sel = _sel == id ? null : id;
                    })),
          ],
        ]),
      );

  Widget _modeChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Text('Atendimento:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Brand.inkMuted(context))),
          ),
          for (var i = 0; i < _modeLabels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _chip(
                label: _modeLabels[i],
                selected: _mode == i,
                onTap: () => setState(() => _mode = i)),
          ],
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// Lista de profissionais
// ─────────────────────────────────────────────────────────────

class _ProviderList extends StatelessWidget {
  final bool waiting, hasError, wide;
  final List<ProviderModel> providers;
  final String? selectedId;
  final String Function(ProviderModel) specialtyName;
  final ValueChanged<ProviderModel> onSelect, onRequest;
  final VoidCallback onRetry;

  const _ProviderList({
    required this.waiting,
    required this.hasError,
    required this.wide,
    required this.providers,
    required this.selectedId,
    required this.specialtyName,
    required this.onSelect,
    required this.onRequest,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (waiting) {
      body = const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()));
    } else if (hasError) {
      body = Column(children: [
        const EmptyState(
            emoji: '⚠️',
            title: 'Não foi possível carregar',
            subtitle: 'Verifique a conexão e tente novamente.'),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Tentar novamente'),
        ),
      ]);
    } else if (providers.isEmpty) {
      body = const EmptyState(
          emoji: '🔍',
          title: 'Nenhum profissional encontrado',
          subtitle:
              'Tente outra especialidade ou limpe a busca. Novos profissionais verificados aparecem aqui.');
    } else {
      body = Column(children: [
        for (final p in providers)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HealthCard(
              provider: p,
              specialty: specialtyName(p),
              selected: p.id == selectedId,
              wide: wide,
              onSelect: () => onSelect(p),
              onRequest: () => onRequest(p),
            ),
          ),
      ]);
    }
    return BrandSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Profissionais disponíveis na busca',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Brand.ink(context))),
        const SizedBox(height: 4),
        Text(
            'Atendimento de saúde envolve dados sensíveis; uso sujeito a consentimento e LGPD.',
            style: TextStyle(fontSize: 12, color: Brand.inkMuted(context))),
        const SizedBox(height: 14),
        body,
        const SizedBox(height: 4),
        const _TrackCard(),
      ]),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool soft;
  const _Tag(this.icon, this.label, {this.soft = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: soft ? Brand.greenLight : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: soft ? null : Border.all(color: Brand.line(context)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: Brand.green),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: soft ? Brand.greenDark : Brand.ink(context))),
        ]),
      );
}

class _HealthCard extends StatelessWidget {
  final ProviderModel provider;
  final String specialty;
  final bool selected, wide;
  final VoidCallback onSelect, onRequest;

  const _HealthCard({
    required this.provider,
    required this.specialty,
    required this.selected,
    required this.wide,
    required this.onSelect,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final demo = _HealthState._isDemo(p);
    final city = p.city?.trim() ?? '';
    final price = !demo && p.minPrice != null
        ? formatStartingPrice(p.minPrice!)
        : 'Valor sob consulta';

    final tags = <Widget>[
      if (p.modalities.contains('presential'))
        const _Tag(Icons.storefront_outlined, 'Presencial'),
      if (p.modalities.contains('online'))
        const _Tag(Icons.laptop_mac_rounded, 'Online'),
      if (p.modalities.contains('home_care') ||
          p.categories.contains('home_care'))
        const _Tag(Icons.home_outlined, 'Domiciliar'),
      if (demo)
        const _Tag(Icons.science_outlined, 'Perfil demonstrativo', soft: true),
    ];

    final photo = ClipOval(
      child: SizedBox(
        width: 68,
        height: 68,
        child: ExcludeSemantics(child: BrandProviderPhoto(provider: p)),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Brand.ink(context))),
        Text(specialty,
            style: TextStyle(fontSize: 13.5, color: Brand.inkMuted(context))),
        if (city.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on_outlined,
                  size: 15, color: Brand.green),
              const SizedBox(width: 3),
              Flexible(
                child: Text('$city • PA',
                    style: TextStyle(
                        fontSize: 12.5, color: Brand.inkMuted(context))),
              ),
            ]),
          ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: tags),
        ],
      ],
    );
    final priceText = Text(price,
        style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Brand.inkMuted(context)));
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      BrandPrimaryButton(
        label: 'Ver perfil',
        outlined: true,
        expanded: false,
        onPressed: () => openProviderProfile(context, p),
      ),
      if (!wide)
        BrandPrimaryButton(
          label: 'Solicitar agendamento',
          expanded: false,
          onPressed: onRequest,
        ),
    ]);

    return Semantics(
      container: true,
      selected: selected,
      child: Material(
        color: Brand.surface(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onSelect,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected && wide ? Brand.green : Brand.line(context),
                  width: selected && wide ? 1.8 : 1),
              color: selected && wide
                  ? Brand.greenLight
                      .withValues(alpha: Brand.isDark(context) ? 0.12 : 0.55)
                  : null,
            ),
            child: wide
                ? Row(children: [
                    photo,
                    const SizedBox(width: 14),
                    Expanded(child: info),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          priceText,
                          const SizedBox(height: 8),
                          actions,
                        ]),
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            photo,
                            const SizedBox(width: 12),
                            Expanded(child: info),
                          ]),
                      const SizedBox(height: 10),
                      priceText,
                      const SizedBox(height: 8),
                      actions,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Brand.line(context)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          spacing: 12,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.event_note_rounded,
                  color: Brand.green, size: 30),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acompanhe suas solicitações',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Brand.ink(context))),
                      Text(
                          'Consulte solicitações e confirmações em Meus pedidos.',
                          style: TextStyle(
                              fontSize: 12.5, color: Brand.inkMuted(context))),
                    ]),
              ),
            ]),
            Wrap(spacing: 8, runSpacing: 8, children: [
              BrandPrimaryButton(
                label: 'Ver meus pedidos',
                outlined: true,
                expanded: false,
                onPressed: () => Navigator.pushNamed(context, Routes.myOrders),
              ),
              BrandPrimaryButton(
                label: 'Agendamentos antigos',
                outlined: true,
                expanded: false,
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.appointments),
              ),
            ]),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// Painel "Solicitar agendamento"
// ─────────────────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) => BrandSoftCard(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Solicitar agendamento',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Brand.ink(context))),
          const SizedBox(height: 8),
          Text('Selecione um profissional na lista para continuar.',
              style: TextStyle(color: Brand.inkMuted(context))),
          const SizedBox(height: 14),
          const BrandPrimaryButton(
              label: 'Solicitar agendamento', locked: true),
        ]),
      );
}

class _BookingPanel extends StatefulWidget {
  final ProviderModel provider;
  final String specialty;
  final String? category;
  const _BookingPanel({
    super.key,
    required this.provider,
    required this.specialty,
    required this.category,
  });

  @override
  State<_BookingPanel> createState() => _BookingPanelState();
}

class _BookingPanelState extends State<_BookingPanel> {
  String? _mode; // 'presential' | 'online' | 'home_care'
  DateTime? _date;
  String? _period;

  static const _periods = ['Manhã', 'Tarde', 'Noite', 'Flexível'];

  List<String> get _modes {
    final p = widget.provider;
    final m = <String>[];
    if (p.modalities.contains('presential')) m.add('presential');
    if (p.modalities.contains('online')) m.add('online');
    if (p.modalities.contains('home_care') ||
        p.categories.contains('home_care')) {
      m.add('home_care');
    }
    return m;
  }

  static String _modeName(String m) {
    switch (m) {
      case 'online':
        return 'Online';
      case 'home_care':
        return 'Domiciliar';
      default:
        return 'Presencial';
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _submit() {
    final p = widget.provider;
    final modes = _modes;
    final mode = _mode ?? (modes.length == 1 ? modes.first : null);
    if (mode == null) {
      snack(context, 'Escolha o tipo de atendimento.');
      return;
    }
    final modeName = _modeName(mode);
    Navigator.pushNamed(context, Routes.requestService, arguments: {
      'providerId': providerAccountId(p),
      'providerName': p.name,
      'category': widget.category ?? '',
      'remoteOnly': mode == 'online',
      'description':
          'Solicito agendamento de ${widget.specialty} (atendimento $modeName). Aguardo confirmação de disponibilidade.',
      if (_date != null) 'preferredDate': _date,
      if (_period != null) 'period': _period,
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final demo = _HealthState._isDemo(p);
    final modes = _modes;
    final mode = _mode ?? (modes.length == 1 ? modes.first : null);
    final muted = TextStyle(fontSize: 12, color: Brand.inkMuted(context));

    return BrandSoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Solicitar agendamento',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Brand.ink(context))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Brand.isDark(context) ? null : Brand.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            ClipOval(
              child: SizedBox(
                width: 44,
                height: 44,
                child: ExcludeSemantics(child: BrandProviderPhoto(provider: p)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Brand.ink(context))),
                    Text(widget.specialty, style: muted),
                  ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text('Atendimento',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: Brand.ink(context))),
        const SizedBox(height: 8),
        if (modes.isEmpty)
          Text('O profissional não informou o tipo de atendimento.',
              style: muted)
        else
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in modes)
              ChoiceChip(
                label: Text(_modeName(m)),
                selected: mode == m,
                selectedColor: Brand.greenLight,
                onSelected: (_) => setState(() => _mode = m),
              ),
          ]),
        const SizedBox(height: 14),
        Text('Data de preferência',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: Brand.ink(context))),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(_date == null ? 'Escolher data' : _fmt(_date!)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Brand.green,
            side: BorderSide(color: Brand.line(context)),
            minimumSize: const Size(double.infinity, 44),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        Text('Período de preferência',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: Brand.ink(context))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final pr in _periods)
            ChoiceChip(
              label: Text(pr),
              selected: _period == pr,
              selectedColor: Brand.greenLight,
              onSelected: (v) => setState(() => _period = v ? pr : null),
            ),
        ]),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: Brand.inkMuted(context)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  'Preferências; não representam agenda real. Não há horários livres exibidos aqui.',
                  style: muted)),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Brand.goldLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 17, color: Brand.goldDeep),
            SizedBox(width: 8),
            Expanded(
              child: Text('A confirmação do horário depende do profissional.',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B5500))),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        BrandPrimaryButton(
          label:
              demo ? 'Indisponível na demonstração' : 'Solicitar agendamento',
          icon: demo ? null : Icons.arrow_forward_rounded,
          locked: demo,
          onPressed: demo || modes.isEmpty ? null : _submit,
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
              demo
                  ? 'Nenhum agendamento real será realizado.'
                  : 'Você revisa o pedido antes de enviar. Nenhuma cobrança é feita agora.',
              textAlign: TextAlign.center,
              style: muted),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MEUS AGENDAMENTOS (Vol.14: Saúde/Home Care — Agenda)
// Lista os agendamentos criados pelo usuário e permite cancelar.
// ─────────────────────────────────────────────────────────────
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const CarajasAppBar(
            title: 'Meus agendamentos', backgroundColor: AppColors.health),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: FS.appointmentsStream(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            final items = snap.data ?? [];
            if (items.isEmpty)
              return const EmptyState(
                  emoji: '📅',
                  title: 'Nenhum agendamento',
                  subtitle: 'Seus agendamentos de saúde aparecerão aqui',
                  asset: AppAssets.ilListaVazia);
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final a = items[i];
                  final status = a['status'] as String? ?? 'scheduled';
                  final cancelled = status == 'cancelled';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: AppDecorations.card(r: 16),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                    color: AppColors.health
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.center,
                                child: const Icon(Icons.favorite_rounded,
                                    color: AppColors.health, size: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(a['type']?.toString() ?? 'Consulta',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  if (a['time'] != null)
                                    Text('Horário: ${a['time']}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textLight)),
                                ])),
                            AppTag(cancelled ? '❌ Cancelado' : '✅ Agendado',
                                bg: AppColors.background,
                                fg: cancelled
                                    ? AppColors.error
                                    : AppColors.health),
                          ]),
                          if (!cancelled)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () async {
                                        await FS.cancelAppointment(
                                            a['id'] as String);
                                        if (!context.mounted) return;
                                        snack(context, 'Agendamento cancelado',
                                            bg: AppColors.error);
                                      },
                                      child: const Text('Cancelar',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.error)),
                                    ))),
                        ]),
                  );
                });
          },
        ),
      );
}
