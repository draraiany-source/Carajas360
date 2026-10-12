import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';

/// Atendimento do prestador (Fase 4): define em quais oportunidades do
/// Resolve ele entra — modalidades, raio a partir de uma localização
/// aproximada, dias/períodos disponíveis e pausa.
class ProviderAttendanceScreen extends StatefulWidget {
  const ProviderAttendanceScreen({super.key});
  @override
  State<ProviderAttendanceScreen> createState() => _ProviderAttendanceState();
}

class _ProviderAttendanceState extends State<ProviderAttendanceScreen> {
  static const _mods = {'presential': 'Presencial', 'home_care': 'No endereço do cliente', 'online': 'Online'};
  static const _days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
  static const _periods = {'morning': 'Manhã', 'afternoon': 'Tarde', 'evening': 'Noite'};

  bool _loaded = false, _saving = false;
  Set<String> _modalities = {'presential'};
  double _radius = 30;
  Map<String, double>? _geo;
  Set<int> _weekdays = {};
  Set<String> _periodSel = {};
  bool _accepting = true;
  DateTime? _until;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('providers').doc(AuthService.uid);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (AuthService.uid == null) return;
    final s = await _ref.get();
    final d = s.data() ?? const {};
    final av = (d['availability'] as Map?) ?? const {};
    final g = d['geo'] as Map?;
    if (!mounted) return;
    setState(() {
      _loaded = s.exists;
      _modalities = {...((d['modalities'] as List?) ?? const ['presential']).map((e) => '$e')};
      _radius = ((d['radiusKm'] as num?) ?? 30).toDouble().clamp(1, 200);
      _geo = g == null ? null : {'lat': (g['lat'] as num).toDouble(), 'lng': (g['lng'] as num).toDouble()};
      _weekdays = {...((av['weekdays'] as List?) ?? const []).map((e) => (e as num).toInt())};
      _periodSel = {...((av['periods'] as List?) ?? const []).map((e) => '$e')};
      _accepting = d['acceptingRequests'] != false;
      final u = d['unavailableUntil'] as String?;
      _until = u == null ? null : DateTime.tryParse(u);
    });
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final p = await Geolocator.getCurrentPosition();
      setState(() => _geo = {
            'lat': (p.latitude * 100).roundToDouble() / 100,
            'lng': (p.longitude * 100).roundToDouble() / 100,
          });
    } catch (_) {
      if (mounted) snack(context, 'Não foi possível obter a localização.');
    }
  }

  Future<void> _save() async {
    if (_modalities.isEmpty) {
      snack(context, 'Escolha ao menos uma modalidade', bg: AppColors.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await _ref.update({
        'modalities': _modalities.toList(),
        'radiusKm': _radius.round(),
        'geo': _geo,
        'availability': {'weekdays': (_weekdays.toList()..sort()), 'periods': _periodSel.toList()},
        'acceptingRequests': _accepting,
        'unavailableUntil': _until?.toIso8601String().substring(0, 10),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) snack(context, 'Atendimento atualizado', bg: AppColors.secondary);
    } catch (e) {
      if (mounted) snack(context, 'Não foi possível salvar: $e', bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meu atendimento')),
        bottomNavigationBar: SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                    onPressed: _saving || !_loaded ? null : _save,
                    child: Text(_saving ? 'Salvando…' : 'Salvar')))),
        body: !_loaded
            ? const EmptyState(
                emoji: '👷', title: 'Perfil de prestador não encontrado', subtitle: 'Cadastre-se como profissional.')
            : ListView(padding: const EdgeInsets.all(16), children: [
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recebendo novas oportunidades'),
                    subtitle: const Text('Desligue para pausar o Resolve sem sair da plataforma'),
                    value: _accepting,
                    onChanged: (v) => setState(() => _accepting = v)),
                _h('Modalidades'),
                Wrap(spacing: 8, children: [
                  for (final e in _mods.entries)
                    FilterChip(
                        label: Text(e.value),
                        selected: _modalities.contains(e.key),
                        onSelected: (on) => setState(() => on ? _modalities.add(e.key) : _modalities.remove(e.key))),
                ]),
                _h('Raio de atendimento: ${_radius.round()} km'),
                Slider(min: 1, max: 200, divisions: 199, value: _radius, onChanged: (v) => setState(() => _radius = v)),
                OutlinedButton.icon(
                    icon: Icon(_geo == null ? Icons.my_location : Icons.check_circle),
                    label: Text(_geo == null ? 'Definir minha base (localização aproximada)' : 'Base definida (≈1 km de precisão)'),
                    onPressed: _locate),
                const Text('Sem base definida, valem a cidade e as áreas do seu perfil.',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                _h('Dias disponíveis'),
                Wrap(spacing: 6, children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                        label: Text(_days[i]),
                        selected: _weekdays.contains(i),
                        onSelected: (on) => setState(() => on ? _weekdays.add(i) : _weekdays.remove(i))),
                ]),
                _h('Períodos'),
                Wrap(spacing: 6, children: [
                  for (final e in _periods.entries)
                    FilterChip(
                        label: Text(e.value),
                        selected: _periodSel.contains(e.key),
                        onSelected: (on) => setState(() => on ? _periodSel.add(e.key) : _periodSel.remove(e.key))),
                ]),
                const Text('Nada marcado = sem restrição de dia/período.',
                    style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                _h('Indisponível até'),
                Row(children: [
                  OutlinedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                            context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)),
                            initialDate: _until ?? now);
                        if (d != null) setState(() => _until = d);
                      },
                      child: Text(_until == null ? 'Sem período de ausência' : _until!.toIso8601String().substring(0, 10))),
                  if (_until != null)
                    IconButton(onPressed: () => setState(() => _until = null), icon: const Icon(Icons.close)),
                ]),
              ]),
      );
}
