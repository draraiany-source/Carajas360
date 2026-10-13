import 'package:flutter/material.dart';
import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Agenda do profissional de saúde (Fase 5): faixas semanais, duração e
/// preço por especialidade, modalidades e dias bloqueados. Os horários
/// oferecidos aos pacientes são calculados no servidor a partir daqui.
class HealthScheduleEditorScreen extends StatefulWidget {
  const HealthScheduleEditorScreen({super.key});
  @override
  State<HealthScheduleEditorScreen> createState() => _EditorState();
}

class _Range {
  final TextEditingController start, end;
  _Range(String a, String b)
      : start = TextEditingController(text: a),
        end = TextEditingController(text: b);
}

class _Svc {
  final String catalogId, name;
  bool enabled;
  final TextEditingController duration, price;
  Set<String> modalities;
  _Svc(this.catalogId, this.name, {this.enabled = false, int durationMin = 30, int priceCents = 0, Set<String>? mods})
      : duration = TextEditingController(text: '$durationMin'),
        price = TextEditingController(text: (priceCents / 100).toStringAsFixed(2)),
        modalities = mods ?? {'presential'};
}

class _EditorState extends State<HealthScheduleEditorScreen> {
  static const _days = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  static const _mods = {'online': 'Online', 'presential': 'Presencial', 'home_care': 'Domiciliar'};
  final Map<int, List<_Range>> _weekly = {};
  int _slot = 30;
  final List<String> _blocked = [];
  final List<_Svc> _services = [];
  bool _loading = true, _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = await FS.myProviderStream().first;
    final cur = await FS.myHealthSchedule() ?? const {};
    final catalog = CatalogService.instance.catalog;
    final healthIds = (provider?.categories ?? const <String>[])
        .where((c) => catalog.rootOf(c)?.vertical == CatalogVertical.health)
        .toList();
    final saved = {
      for (final s in ((cur['services'] as List?) ?? const []).whereType<Map>()) '${s['catalogId']}': s
    };
    final weekly = (cur['weekly'] as Map?) ?? const {};
    if (!mounted) return;
    setState(() {
      for (var d = 0; d < 7; d++) {
        final list = ((weekly['$d'] as List?) ?? const []).whereType<Map>().toList();
        _weekly[d] = list.map((r) => _Range('${r['start']}', '${r['end']}')).toList();
      }
      _slot = (cur['slotMinutes'] as num?)?.toInt() ?? 30;
      _blocked.addAll(((cur['blockedDates'] as List?) ?? const []).map((e) => '$e'));
      for (final id in healthIds) {
        final s = saved[id];
        _services.add(_Svc(id, catalog.nameOf(id),
            enabled: s != null,
            durationMin: (s?['durationMin'] as num?)?.toInt() ?? 30,
            priceCents: (s?['priceCents'] as num?)?.toInt() ?? 0,
            mods: s == null ? null : {...((s['modalities'] as List?) ?? const []).map((e) => '$e')}));
      }
      _loading = false;
    });
  }

  static final _hm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  Future<void> _save() async {
    final weekly = <String, List<Map<String, String>>>{};
    for (final e in _weekly.entries) {
      final ranges = <Map<String, String>>[];
      for (final r in e.value) {
        final a = r.start.text.trim(), b = r.end.text.trim();
        if (!_hm.hasMatch(a) || !_hm.hasMatch(b) || a.compareTo(b) >= 0) {
          snack(context, '${_days[e.key]}: horário inválido ($a–$b). Use HH:MM.', bg: AppColors.error);
          return;
        }
        ranges.add({'start': a, 'end': b});
      }
      if (ranges.isNotEmpty) weekly['${e.key}'] = ranges;
    }
    final services = <Map<String, dynamic>>[];
    for (final s in _services.where((s) => s.enabled)) {
      final dur = int.tryParse(s.duration.text) ?? 0;
      final price = ((double.tryParse(s.price.text.replaceAll(',', '.')) ?? -1) * 100).round();
      if (dur < 10 || dur > 240 || price < 0 || s.modalities.isEmpty) {
        snack(context, '${s.name}: duração (10–240 min), valor e modalidade obrigatórios.', bg: AppColors.error);
        return;
      }
      services.add({'catalogId': s.catalogId, 'durationMin': dur, 'priceCents': price, 'modalities': s.modalities.toList()});
    }
    setState(() => _saving = true);
    try {
      await FS.saveHealthSchedule(
          {'weekly': weekly, 'slotMinutes': _slot, 'minLeadHours': 2, 'blockedDates': _blocked, 'services': services});
      if (mounted) snack(context, 'Agenda publicada', bg: AppColors.health);
    } catch (e) {
      if (mounted) snack(context, 'Não foi possível salvar: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Minha agenda (Saúde)'), backgroundColor: AppColors.health, foregroundColor: Colors.white),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(onPressed: _loading || _saving ? null : _save, child: Text(_saving ? 'Salvando…' : 'Publicar agenda')))),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Especialidades atendidas pela agenda', style: TextStyle(fontWeight: FontWeight.w800)),
                if (_services.isEmpty)
                  const Text('Cadastre especialidades de Saúde em "Minhas especialidades" primeiro.',
                      style: TextStyle(color: AppColors.textLight)),
                for (final s in _services)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(s.name),
                                value: s.enabled,
                                onChanged: (v) => setState(() => s.enabled = v)),
                            if (s.enabled) ...[
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        controller: s.duration,
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(labelText: 'Duração (min)'))),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: TextField(
                                        controller: s.price,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '))),
                              ]),
                              Wrap(spacing: 6, children: [
                                for (final m in _mods.entries)
                                  FilterChip(
                                      label: Text(m.value),
                                      selected: s.modalities.contains(m.key),
                                      onSelected: (on) =>
                                          setState(() => on ? s.modalities.add(m.key) : s.modalities.remove(m.key))),
                              ]),
                            ],
                          ]))),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Text('Intervalo entre horários', style: TextStyle(fontWeight: FontWeight.w800))),
                  DropdownButton<int>(
                      value: _slot,
                      items: const [15, 20, 30, 45, 60].map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
                      onChanged: (v) => setState(() => _slot = v ?? 30)),
                ]),
                const SizedBox(height: 8),
                const Text('Horários por dia (HH:MM, fuso de Belém)', style: TextStyle(fontWeight: FontWeight.w800)),
                for (var d = 0; d < 7; d++)
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(_days[d])),
                      TextButton(
                          onPressed: () => setState(() => _weekly[d]!.add(_Range('08:00', '12:00'))),
                          child: const Text('+ faixa')),
                    ]),
                    for (final r in [..._weekly[d]!])
                      Row(children: [
                        Expanded(child: TextField(controller: r.start, decoration: const InputDecoration(labelText: 'Início'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: r.end, decoration: const InputDecoration(labelText: 'Fim'))),
                        IconButton(onPressed: () => setState(() => _weekly[d]!.remove(r)), icon: const Icon(Icons.close)),
                      ]),
                  ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Text('Dias bloqueados', style: TextStyle(fontWeight: FontWeight.w800))),
                  TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                            context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
                        if (d != null) {
                          setState(() => _blocked.add(
                              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'));
                        }
                      },
                      child: const Text('+ bloquear dia')),
                ]),
                Wrap(spacing: 6, children: [
                  for (final b in _blocked) InputChip(label: Text(b), onDeleted: () => setState(() => _blocked.remove(b))),
                ]),
              ]),
      );
}

/// Atalho para o painel do prestador.
class HealthScheduleTile extends StatelessWidget {
  final ProviderModel? provider;
  const HealthScheduleTile({super.key, this.provider});
  @override
  Widget build(BuildContext context) => TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: Colors.white),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthScheduleEditorScreen())),
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: const Text('Agenda de Saúde'));
}
