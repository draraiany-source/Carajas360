import 'package:flutter/material.dart';
import '../../core/security/order_policy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../checkout/payment_screens.dart';
import '../checkout/payments_api.dart';

/// Datas e horários exibidos no fuso do serviço (America/Belem, UTC−3).
abstract final class HealthTime {
  static const offset = Duration(hours: -3);
  static DateTime local(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(offset);
  static String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static String label(int ms) {
    final d = local(ms);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} às ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  /// Próximos [n] dias a partir de hoje (no fuso do serviço).
  static List<String> nextDays(int n, {DateTime? now}) {
    final today = (now ?? DateTime.now().toUtc()).toUtc().add(offset);
    return List.generate(n, (i) => date(DateTime.utc(today.year, today.month, today.day + i)));
  }
}

const _modalityLabels = {'online': '📹 Online', 'presential': '🏥 Presencial', 'home_care': '🏡 Domiciliar'};

/// Seletor de horário real da agenda do profissional (dia → horários livres).
class HealthSlotPicker extends StatefulWidget {
  final String providerId, catalogId;
  final ValueChanged<({int startMs, Map<String, dynamic> info})> onPicked;
  const HealthSlotPicker({super.key, required this.providerId, required this.catalogId, required this.onPicked});
  @override
  State<HealthSlotPicker> createState() => _HealthSlotPickerState();
}

class _HealthSlotPickerState extends State<HealthSlotPicker> {
  final _days = HealthTime.nextDays(14);
  late String _day = _days.first;
  Future<Map<String, dynamic>>? _future;
  int? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        _picked = null;
        _future = FS.healthSlots(providerId: widget.providerId, catalogId: widget.catalogId, date: _day);
      });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final d in _days)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                      '${const ['dom', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb'][DateTime.parse(d).weekday % 7]} ${d.substring(8)}/${d.substring(5, 7)}'),
                  selected: d == _day,
                  onSelected: (_) {
                    _day = d;
                    _load();
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (_, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
            }
            if (s.hasError) {
              return EmptyState(
                  emoji: '⚠️',
                  title: 'Agenda indisponível',
                  subtitle: s.error is CloudCallException ? (s.error as CloudCallException).message : '${s.error}',
                  actionLabel: 'Tentar novamente',
                  onAction: _load);
            }
            final info = s.data!;
            final slots = ((info['slots'] as List?) ?? const []).whereType<Map>().toList();
            if (slots.isEmpty) {
              return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Sem horários livres neste dia. Escolha outra data.',
                      style: TextStyle(color: AppColors.textLight)));
            }
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final sl in slots)
                ChoiceChip(
                  label: Text('${sl['label']}'),
                  selected: _picked == (sl['startMs'] as num).toInt(),
                  onSelected: (_) {
                    final ms = (sl['startMs'] as num).toInt();
                    setState(() => _picked = ms);
                    widget.onPicked((startMs: ms, info: info));
                  },
                ),
            ]);
          },
        ),
      ]);
}

/// Agendamento: profissional + especialidade + data/horário real +
/// modalidade + motivo (privado) + consentimento. Nada é confirmado sem
/// profissional e horário válidos — o servidor revalida tudo.
class HealthBookingScreen extends StatefulWidget {
  final String providerId, providerName, catalogId, serviceName;
  const HealthBookingScreen(
      {super.key, required this.providerId, required this.providerName, required this.catalogId, required this.serviceName});
  @override
  State<HealthBookingScreen> createState() => _HealthBookingScreenState();
}

class _HealthBookingScreenState extends State<HealthBookingScreen> {
  int? _startMs;
  Map<String, dynamic>? _info;
  String? _modality;
  bool _consent = false, _saving = false;
  final _reason = TextEditingController();
  final _requestId = 'ap${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_startMs == null || _modality == null) return;
    setState(() => _saving = true);
    try {
      final r = await FS.bookHealthAppointment(
          requestId: _requestId,
          providerId: widget.providerId,
          catalogId: widget.catalogId,
          startMs: _startMs!,
          modality: _modality!,
          reason: _reason.text);
      if (!mounted) return;
      final appt = AppointmentModel.fromMap('${r['id'] ?? ''}', r);
      if (appt.pendingPayment && appt.holdUntilMs != null) {
        // Consulta com valor: horário retido até o pagamento (B15).
        final paid = await payReservation(
            context, PayTarget('health', appt.id, appt.totalCents, 'Consulta — ${widget.serviceName}'),
            holdUntilMs: appt.holdUntilMs);
        if (!mounted) return;
        snack(
            context,
            paid
                ? '✅ Pagamento recebido. A confirmação da consulta aparece em Agendamentos.'
                : 'Horário reservado. Pague até ${holdTimeLabel(appt.holdUntilMs!)} em Agendamentos para garantir.',
            bg: paid ? AppColors.health : AppColors.warning);
        Navigator.pop(context, true);
        return;
      }
      snack(context, '✅ Consulta agendada para ${HealthTime.label(_startMs!)}', bg: AppColors.health);
      Navigator.pop(context, true);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } catch (_) {
      if (mounted) {
        snack(context, 'Sem resposta do servidor. Tente de novo — o agendamento não será duplicado.', bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mods = ((_info?['modalities'] as List?) ?? const []).map((e) => '$e').toList();
    final ready = _startMs != null && _modality != null && _consent && !_saving;
    final priceCents = (_info?['priceCents'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar consulta'), backgroundColor: AppColors.health, foregroundColor: Colors.white),
      body: ListView(padding: pagePadding(context), children: [
        Text(widget.providerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        Text(widget.serviceName, style: const TextStyle(color: AppColors.textLight)),
        const SizedBox(height: 16),
        const Text('Escolha o dia e o horário (horário de Brasília/Belém)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        HealthSlotPicker(
            providerId: widget.providerId,
            catalogId: widget.catalogId,
            onPicked: (v) => setState(() {
                  _startMs = v.startMs;
                  _info = v.info;
                  final m = ((v.info['modalities'] as List?) ?? const []).map((e) => '$e').toList();
                  if (_modality == null || !m.contains(_modality)) _modality = m.length == 1 ? m.first : null;
                })),
        if (_startMs != null) ...[
          const SizedBox(height: 16),
          const Text('Modalidade', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final m in mods)
              ChoiceChip(label: Text(_modalityLabels[m] ?? m), selected: _modality == m, onSelected: (_) => setState(() => _modality = m)),
          ]),
          const SizedBox(height: 16),
          TextField(
            controller: _reason,
            maxLines: 3,
            maxLength: 1000,
            decoration: const InputDecoration(
                labelText: 'Motivo da consulta (opcional)',
                helperText: 'Visível apenas para você e para o profissional.',
                border: OutlineInputBorder()),
          ),
          Container(
            decoration: AppDecorations.card(r: 14),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _row('Data e horário', HealthTime.label(_startMs!)),
              _row('Duração', '${_info?['durationMin']} min'),
              _row('Valor', brl(priceCents)),
              Text(
                  priceCents > 0
                      ? 'Pagamento pelo app: o horário fica reservado por alguns minutos até o pagamento ser confirmado.'
                      : 'Consulta sem custo pelo app.',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            ]),
          ),
          CheckboxListTile(
            key: const Key('health-consent'),
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (v) => setState(() => _consent = v == true),
            title: const Text(
                'Autorizo o uso dos meus dados de saúde exclusivamente para este atendimento, pelo profissional escolhido (LGPD, art. 11).',
                style: TextStyle(fontSize: 12)),
          ),
        ],
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('health-confirm'),
          onPressed: ready ? _confirm : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.health, foregroundColor: Colors.white),
          child: Text(_saving
              ? 'Agendando…'
              : (_startMs != null && priceCents > 0 ? 'Reservar e pagar' : 'Confirmar agendamento')),
        ),
        if (_startMs == null)
          const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Escolha um horário para continuar.', style: TextStyle(fontSize: 12, color: AppColors.textLight))),
      ]),
    );
  }

  Widget _row(String a, String b) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
        Text(b, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ]));
}

const _statusLabels = {
  'pending_payment': '⏳ Aguardando pagamento',
  'expired': '⌛ Reserva expirada — horário liberado',
  'scheduled': '✅ Agendada',
  'cancelled_by_client': '❌ Cancelada por você/paciente',
  'cancelled_by_provider': '❌ Cancelada pelo profissional',
  'completed': '✔️ Realizada',
  'no_show': '⚠️ Falta',
};

/// Agendamentos (paciente ou profissional), com cancelar/reagendar e,
/// para o profissional, concluir/registrar falta — regras no servidor.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('Agendamentos'),
              backgroundColor: AppColors.health,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [Tab(text: 'Minhas consultas'), Tab(text: 'Como profissional')])),
          body: const TabBarView(children: [_ApptList(asProvider: false), _ApptList(asProvider: true)]),
        ),
      );
}

class _ApptList extends StatelessWidget {
  final bool asProvider;
  const _ApptList({required this.asProvider});

  Future<void> _act(BuildContext context, AppointmentModel a, String action) async {
    String? reason;
    int? newStart;
    if (action == 'cancel' && asProvider) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
                title: const Text('Motivo do cancelamento'),
                content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Informe ao paciente')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Voltar')),
                  ElevatedButton(onPressed: () => Navigator.pop(d, true), child: const Text('Cancelar consulta')),
                ],
              ));
      reason = c.text;
      c.dispose();
      if (ok != true) return;
    }
    if (action == 'reschedule') {
      if (!context.mounted) return;
      newStart = await showModalBottomSheet<int>(
          context: context,
          isScrollControlled: true,
          builder: (s) => Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Novo horário', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 8),
                  HealthSlotPicker(
                      providerId: a.providerId,
                      catalogId: a.catalogId,
                      onPicked: (v) => Navigator.pop(s, v.startMs)),
                ]),
              ));
      if (newStart == null) return;
    }
    try {
      await FS.healthAppointmentAction(a.id, action, reason: reason, newStartMs: newStart);
      if (context.mounted) snack(context, 'Agendamento atualizado', bg: AppColors.health);
    } on CloudCallException catch (e) {
      if (context.mounted) snack(context, e.message, bg: AppColors.error);
    }
  }

  Future<void> _pay(BuildContext context, AppointmentModel a) => payReservation(
      context,
      PayTarget('health', a.id, a.totalCents, 'Consulta — ${a.serviceName.isEmpty ? 'Saúde' : a.serviceName}'),
      holdUntilMs: a.holdUntilMs);

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Map<String, dynamic>>>(
        stream: FS.appointmentsStream(asProvider: asProvider),
        builder: (context, snap) {
          if (snap.hasError) return QueryErrorView(error: snap.error);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!
              .where((m) => m['startMs'] is num)
              .map((m) => AppointmentModel.fromMap('${m['id']}', m))
              .toList();
          if (items.isEmpty) {
            return const EmptyState(emoji: '📅', title: 'Nenhum agendamento', subtitle: 'Seus agendamentos aparecerão aqui');
          }
          final now = DateTime.now();
          return ListView(padding: pagePadding(context), children: [
            for (final a in items)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: AppDecorations.card(r: 16),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      '${a.serviceName.isEmpty ? 'Consulta' : a.serviceName} — ${asProvider ? 'paciente' : (a.providerName.isEmpty ? 'profissional' : a.providerName)}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${HealthTime.label(a.startMs)} · ${_modalityLabels[a.modality] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  Text(appointmentStatusText(a, asProvider: asProvider, now: now),
                      style: TextStyle(
                          fontSize: 12,
                          color: a.canPay(now) ? AppColors.warning : null,
                          fontWeight: a.pendingPayment ? FontWeight.w700 : null)),
                  if (!asProvider && a.canPay(now))
                    Wrap(spacing: 6, children: [
                      ElevatedButton(
                          onPressed: () => _pay(context, a),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.health, foregroundColor: Colors.white),
                          child: Text('Pagar ${brl(a.totalCents)}')),
                      TextButton(
                          onPressed: () => _act(context, a, 'cancel'),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.error))),
                    ]),
                  if (a.status == 'scheduled')
                    Wrap(spacing: 6, children: [
                      TextButton(onPressed: () => _act(context, a, 'reschedule'), child: const Text('Reagendar')),
                      TextButton(
                          onPressed: () => _act(context, a, 'cancel'),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.error))),
                      if (asProvider && a.startMs <= now.millisecondsSinceEpoch) ...[
                        TextButton(onPressed: () => _act(context, a, 'complete'), child: const Text('Realizada')),
                        TextButton(onPressed: () => _act(context, a, 'no_show'), child: const Text('Falta')),
                      ],
                    ]),
                ]),
              ),
            const Text('Paciente: cancelamento e reagendamento até 2 h antes (no máximo 2 reagendamentos).',
                style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          ]);
        },
      );
}

/// Situação exibida na lista (inclui retenção aguardando pagamento).
String appointmentStatusText(AppointmentModel a, {bool asProvider = false, DateTime? now}) {
  if (a.pendingPayment) {
    // Prazo vencido: o horário já está livre (a tarefa grava 'expired' depois).
    if (!a.canPay(now)) return _statusLabels['expired']!;
    if (asProvider) return '⏳ Aguardando pagamento do paciente';
    return '⏳ Aguardando pagamento até ${holdTimeLabel(a.holdUntilMs!)}';
  }
  if (a.expired && a.lateRefund) return '↩️ Valor devolvido — o horário não estava mais disponível';
  return _statusLabels[a.status] ?? a.status;
}
