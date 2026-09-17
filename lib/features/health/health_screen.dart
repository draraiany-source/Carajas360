import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/demo_data.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});
  @override
  State<HealthScreen> createState() => _HealthState();
}

class _HealthState extends State<HealthScreen> {
  int _mode = 0;
  String? _sel;

  static const _specialties = [
    {'id': 'medico', 'name': 'Médico', 'emoji': '🩺'},
    {'id': 'psicologo', 'name': 'Psicólogo', 'emoji': '🧠'},
    {'id': 'fisioterapeuta', 'name': 'Fisioterapeuta', 'emoji': '🦴'},
    {'id': 'enfermeiro', 'name': 'Enfermeiro', 'emoji': '💉'},
    {'id': 'nutricionista', 'name': 'Nutricionista', 'emoji': '🥗'},
    {'id': 'home_care', 'name': 'Home Care', 'emoji': '🏠'},
  ];

  static final _demos = [
    ProviderModel(
        id: 'h1',
        userId: 'u1',
        name: 'Dra. Ana Lima',
        categories: ['medico'],
        rating: 5.0,
        totalReviews: 480,
        modalities: ['online', 'presential'],
        minPrice: 120,
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'h2',
        userId: 'u2',
        name: 'Dr. Carlos Matos',
        categories: ['psicologo'],
        rating: 4.9,
        totalReviews: 310,
        modalities: ['online'],
        minPrice: 150,
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'h3',
        userId: 'u3',
        name: 'Fis. Juliana',
        categories: ['fisioterapeuta'],
        rating: 4.8,
        totalReviews: 220,
        modalities: ['presential'],
        minPrice: 100,
        createdAt: DateTime.now()),
    ProviderModel(
        id: 'h4',
        userId: 'u4',
        name: 'Enf. Roberto',
        categories: ['enfermeiro'],
        rating: 4.7,
        totalReviews: 180,
        modalities: ['presential'],
        minPrice: 80,
        createdAt: DateTime.now()),
  ];

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
                    const AppSearchBar(
                        hint: 'Buscar especialidade ou profissional...'),
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
                  child: SizedBox(
                      height: 58,
                      child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: _specialties.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final s = _specialties[i];
                            final sel = _sel == s['id'];
                            return GestureDetector(
                                onTap: () =>
                                    setState(() => _sel = sel ? null : s['id']),
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: sel
                                            ? AppColors.health
                                            : AppColors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: sel
                                                ? AppColors.health
                                                : AppColors.border)),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(s['emoji']!,
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          const SizedBox(width: 6),
                                          Text(s['name']!,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: sel
                                                      ? Colors.white
                                                      : AppColors.textDark))
                                        ])));
                          })))),
          SliverToBoxAdapter(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(children: [
                    _action('🚨', 'Urgente', 'Agora', AppColors.error,
                        () => _schedule('Consulta Urgente', 0)),
                    const SizedBox(width: 8),
                    _action('📅', 'Agendar', 'Escolha data', AppColors.health,
                        () => _schedule('Consulta', 150)),
                    const SizedBox(width: 8),
                    _action('🏡', 'Home Care', 'Domiciliar', AppColors.teal,
                        () => _schedule('Home Care', 200)),
                  ]))),
          const SliverToBoxAdapter(
              child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SecHeader(title: '👨‍⚕️ Profissionais disponíveis'))),
          SliverToBoxAdapter(
              child: StreamBuilder<List<ProviderModel>>(
            stream: _sel != null
                ? FS.providersStream(category: _sel, limit: 10)
                : const Stream.empty(),
            builder: (_, snap) {
              final provs = DemoData.orEmpty(
                  snap.data,
                  _demos
                      .where((p) => _sel == null || p.categories.contains(_sel))
                      .toList());
              if (provs.isEmpty)
                return const Padding(
                    padding: EdgeInsets.all(20),
                    child: EmptyState(
                        emoji: '🔍',
                        title: 'Nenhum profissional',
                        subtitle: 'Tente outra especialidade'));
              return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                      children: provs.map((p) {
                    final sp = _specialties.firstWhere(
                        (s) => p.categories.contains(s['id']),
                        orElse: () => {'name': 'Saúde', 'emoji': '🩺'});
                    return ProvCard(
                        name: p.name,
                        role: '${sp['emoji']} ${sp['name']}',
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
                        onTap: () => _schedule(
                            sp['name'] as String, p.minPrice?.toInt() ?? 150),
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

  void _schedule(String type, int price) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleSheet(type: type, price: price));
}

class _ScheduleSheet extends StatefulWidget {
  final String type;
  final int price;
  const _ScheduleSheet({required this.type, required this.price});
  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  int _step = 0;
  String? _time, _mode;
  bool _loading = false;
  final _times = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00'
  ];

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          const SheetHandle(),
          const SizedBox(height: 16),
          Text('Agendar ${widget.type}',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          if (_step == 0) ...[
            const Text('Modalidade do atendimento:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              for (final m in ['📹 Online', '🏠 Presencial', '🏡 Domiciliar'])
                Expanded(
                    child: GestureDetector(
                        onTap: () => setState(() {
                              _mode = m;
                              _step = 1;
                            }),
                        child: Container(
                            margin: EdgeInsets.only(
                                right: m == '🏡 Domiciliar' ? 0 : 8),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: AppDecorations.gradient(
                                AppGradients.health,
                                r: 14),
                            child: Text(m,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11)))))
            ]),
          ] else if (_step == 1) ...[
            Text('Modo: $_mode',
                style: const TextStyle(
                    color: AppColors.health, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('Escolha o horário:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: _times
                    .map((t) => GestureDetector(
                        onTap: () => setState(() {
                              _time = t;
                              _step = 2;
                            }),
                        child: Container(
                            decoration: AppDecorations.outlined(
                                r: 10,
                                color: _time == t ? AppColors.health : null),
                            alignment: Alignment.center,
                            child: Text(t,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _time == t
                                        ? AppColors.health
                                        : AppColors.textDark)))))
                    .toList()),
          ] else ...[
            Text('Modalidade: $_mode — Horário: $_time',
                style: const TextStyle(
                    color: AppColors.health, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Container(
                decoration: AppDecorations.card(r: 16),
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('Serviço', widget.type),
                  _row('Modo', _mode ?? ''),
                  _row('Horário', _time ?? ''),
                  _row('Valor', PaySvc.fmt(widget.price.toDouble())),
                  const Divider(),
                  _row('Total', PaySvc.fmt(widget.price.toDouble()),
                      bold: true),
                ])),
            const SizedBox(height: 14),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          await FS.createAppointment({
                            'type': widget.type,
                            'mode': _mode,
                            'time': _time,
                            'price': widget.price
                          });
                          final uid = AuthService.uid;
                          if (uid != null)
                            await FS.pushNotif(uid, '🏥 Consulta agendada!',
                                '${widget.type} às $_time', 'health');
                          if (mounted) {
                            Navigator.pop(context);
                            snack(context, '✅ Consulta agendada com sucesso!',
                                bg: AppColors.health);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.health,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('✓ Confirmar agendamento',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: Colors.white)),
                )),
          ],
        ]),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: AppColors.textDark))
      ]));
}

// ─────────────────────────────────────────────────────────────
// MEUS AGENDAMENTOS (Vol.14: Saúde/Home Care — Agenda)
// Lista os agendamentos criados pelo usuário e permite cancelar.
// ─────────────────────────────────────────────────────────────
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Meus agendamentos'),
            backgroundColor: AppColors.health,
            foregroundColor: Colors.white),
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
                                    color: AppColors.health.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12)),
                                alignment: Alignment.center,
                                child: const Text('🏥',
                                    style: TextStyle(fontSize: 20))),
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
                                        if (context.mounted)
                                          snack(
                                              context, 'Agendamento cancelado',
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
