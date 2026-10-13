import 'dart:async';

import 'package:flutter/material.dart';
import 'health_booking.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/catalog/provider_search.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

class HealthScreen extends StatefulWidget {
  /// Especialidade pré-selecionada (ID do catálogo, vertical Saúde).
  final String? initialCatalogId;
  const HealthScreen({super.key, this.initialCatalogId});
  @override
  State<HealthScreen> createState() => _HealthState();
}

class _HealthState extends State<HealthScreen> {
  int _mode = 0;
  String? _sel;

  String _name = '';
  Timer? _debounce;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _sel = widget.initialCatalogId;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  static const _modes = [null, 'online', 'presential', 'home_care'];

  /// Consulta real na vertical Saúde: "Todos" = toda a categoria Saúde;
  /// especialidade = grupo do catálogo; modalidade e nome filtram de fato.
  ProviderQuery get _query => ProviderQuery(
      catalogToken: _sel != null ? 'g:$_sel' : 'c:cat_saude',
      modality: _modes[_mode],
      nameText: _name);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(
              child: GradHeader(
                  gradient: AppGradients.health,
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('🏥 SaúdeConecta',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22)),
                                Text('Médicos · Terapeutas · Home Care',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12))
                              ]),
                          Row(children: [
                            GestureDetector(
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AppointmentsScreen())),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(Icons.event_note_rounded,
                                        color: Colors.white, size: 18))),
                            const SizedBox(width: 8),
                            GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(
                                        Icons.arrow_back_ios_new_rounded,
                                        color: Colors.white,
                                        size: 18))),
                          ]),
                        ]),
                    const SizedBox(height: 16),
                    AppSearchBar(
                        hint: 'Buscar profissional pelo nome...',
                        onChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(const Duration(milliseconds: 350),
                              () => mounted ? setState(() => _name = v.trim()) : null);
                        }),
                    const SizedBox(height: 12),
                    TogglePills(
                        options: const [
                          'Todos',
                          '📹 Online',
                          '🏠 Presencial',
                          '🏡 HomeCare'
                        ],
                        selected: _mode,
                        onSelect: (i) => setState(() => _mode = i),
                        activeColor: AppColors.health),
                  ]))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                  child: CatalogBuilder(
                    compact: true,
                    builder: (_, catalog) {
                      final specs =
                          catalog.groupsOfVertical(CatalogVertical.health);
                      return SizedBox(
                        height: 58,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: specs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final sp = specs[i];
                            final sel = _sel == sp.id;
                            return Semantics(
                              button: true,
                              selected: sel,
                              label: sp.name,
                              child: ChoiceChip(
                                showCheckmark: false,
                                selected: sel,
                                selectedColor: AppColors.health,
                                backgroundColor: AppColors.white,
                                label: Text('${sp.icon}  ${sp.name}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : AppColors.textDark)),
                                onSelected: (_) =>
                                    setState(() => _sel = sel ? null : sp.id),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    // Emergência não é agendável: orienta o serviço público.
                    _action('🚨', 'Emergência', 'SAMU 192', AppColors.error,
                        () => showDialog(
                            context: context,
                            builder: (d) => AlertDialog(
                                  title: const Text('Emergência'),
                                  content: const Text(
                                      'Em caso de emergência, ligue 192 (SAMU) ou procure o pronto-socorro mais próximo. O app não faz atendimento de urgência.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(d),
                                        child: const Text('Entendi'))
                                  ],
                                ))),
                    const SizedBox(width: 8),
                    _action('📅', 'Agendar', 'Escolha abaixo', AppColors.health,
                        () => snack(context,
                            'Escolha um profissional na lista para ver os horários livres.',
                            bg: AppColors.health)),
                    const SizedBox(width: 8),
                    _action('🏡', 'Home Care', 'Domiciliar', AppColors.teal,
                        () => setState(() => _mode = 3)),
                  ]))),
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SecHeader(title: '👨‍⚕️ Profissionais disponíveis'))),
          SliverToBoxAdapter(
              child: FutureBuilder<ProviderPage>(
            key: ValueKey('${_query.key}|$_tick'),
            future: ProviderSearch().fetch(_query, pageSize: 20),
            builder: (_, snap) {
              if (snap.hasError) {
                return QueryErrorView(
                    error: snap.error, onRetry: () => setState(() => _tick++));
              }
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()));
              }
              final provs = snap.data!.items;
              if (provs.isEmpty)
                return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyState(
                        emoji: '🔍',
                        title: 'Nenhum profissional',
                        subtitle:
                            'Nenhum profissional de saúde aprovado com estes filtros.'));
              final catalog = CatalogService.instance.catalog;
              return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                      children: provs.map((p) {
                    final spId = p.categories.firstWhere(
                        (c) => catalog.rootOf(c)?.vertical == CatalogVertical.health,
                        orElse: () => p.categories.isNotEmpty ? p.categories.first : '');
                    final sp = catalog.byId(spId);
                    final spName = sp?.name ?? 'Saúde';
                    return ProvCard(
                        name: p.name,
                        role: '${sp?.icon ?? '🩺'} $spName',
                        badge: p.badge,
                        price: p.minPrice != null
                            ? 'A partir de R\$ ${p.minPrice!.toStringAsFixed(0)}'
                            : 'Consultar',
                        rating: p.rating,
                        reviews: p.totalReviews,
                        isOnline: p.modalities.contains('online'),
                        photo: p.photoUrl,
                        avatarBg: AppColors.health,
                        providerId: p.id,
                        onTap: () => _schedule(p.id, p.name, spId, spName),
                        onChat: () => ChatNav.open(context,
                            otherUserId:
                                p.userId.isNotEmpty ? p.userId : p.id,
                            otherName: p.name,
                            otherPhoto: p.photoUrl));
                  }).toList()));
            },
          )),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Container(
                      decoration: AppDecorations.card(r: 20),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Como funciona',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 14),
                            for (final step in [
                              [
                                '1️⃣',
                                'Escolha o profissional',
                                'Filtre por especialidade, avaliação e disponibilidade.'
                              ],
                              [
                                '2️⃣',
                                'Agende',
                                'Escolha data, horário e modalidade.'
                              ],
                              [
                                '3️⃣',
                                'Pague com segurança',
                                'PIX, cartão ou carteira digital.'
                              ],
                              [
                                '4️⃣',
                                'Consulta realizada',
                                'Online via vídeo ou presencial.'
                              ],
                              [
                                '5️⃣',
                                'Avalie o atendimento',
                                'Ajude outros pacientes.'
                              ]
                            ])
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(step[0],
                                            style:
                                                const TextStyle(fontSize: 18)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(step[1],
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13,
                                                      color:
                                                          AppColors.textDark)),
                                              Text(step[2],
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          AppColors.textLight,
                                                      height: 1.4))
                                            ]))
                                      ])),
                          ])))),
        ]),
      );

  Widget _action(String icon, String title, String sub, Color color,
          VoidCallback onTap) =>
      Expanded(
          child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: AppDecorations.gradient(
                    LinearGradient(
                        colors: [color, color.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    r: 16),
                child: Column(children: [
                  Text(icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                  Text(sub,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 9))
                ]),
              )));

  /// Agendamento real: profissional + especialidade + horário da agenda.
  void _schedule(String providerId, String name, String catalogId, String service) {
    if (!AuthService.isAuth) {
      snack(context, 'Faça login para agendar.');
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => HealthBookingScreen(
                providerId: providerId, providerName: name, catalogId: catalogId, serviceName: service)));
  }
}
