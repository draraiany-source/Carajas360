import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/catalog/homolog_catalog.dart';
import '../../core/catalog/service_taxonomy.dart';
import '../../core/constants/app_constants.dart';
import '../../core/search/universal_search.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/widgets.dart';
import '../services/service_marketplace_screen.dart';

/// Busca universal: "O que voce precisa?"
class UniversalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const UniversalSearchScreen({super.key, this.initialQuery});

  @override
  State<UniversalSearchScreen> createState() => _UniversalSearchScreenState();
}

class _UniversalSearchScreenState extends State<UniversalSearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _q = '';
  List<UniversalHit> _hits = const [];
  List<String> _suggestions = const [];
  List<String> _history = const [];
  bool _loading = false;

  static const _historyKey = 'carajas360_universal_search_history_v1';

  @override
  void initState() {
    super.initState();
    _ctrl.text = widget.initialQuery ?? '';
    _q = _ctrl.text;
    _loadHistory();
    if (_q.isNotEmpty) _runSearch(_q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? const [];
    if (mounted) setState(() => _history = list);
  }

  Future<void> _pushHistory(String q) async {
    final t = q.trim();
    if (t.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final next = [t, ..._history.where((e) => e.toLowerCase() != t.toLowerCase())]
        .take(12)
        .toList();
    await prefs.setStringList(_historyKey, next);
    if (mounted) setState(() => _history = next);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (mounted) setState(() => _history = const []);
  }

  List<CompanyModel> get _homologCompanies {
    if (!HomologCatalog.enabled) return const [];
    return [
      CompanyModel(
        id: 'hc1',
        ownerId: 'hc1',
        name: 'Construtora Serra Norte',
        cnpj: '00.000.000/0001-00',
        city: 'Canaa dos Carajas',
        categories: const ['pedreiro', 'pintor'],
        verified: true,
        createdAt: DateTime(2025, 1, 1),
      ),
      CompanyModel(
        id: 'hc2',
        ownerId: 'hc2',
        name: 'Auto Center Carajas',
        cnpj: '00.000.000/0001-01',
        city: 'Parauapebas',
        categories: const ['mecanica_geral', 'funilaria'],
        verified: true,
        createdAt: DateTime(2025, 2, 1),
      ),
      CompanyModel(
        id: 'hc3',
        ownerId: 'hc3',
        name: 'Agro Servicos PA',
        cnpj: '00.000.000/0001-02',
        city: 'Canaa dos Carajas',
        categories: const ['tecnico_agricola'],
        verified: true,
        createdAt: DateTime(2025, 3, 1),
      ),
    ];
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _q = v;
        _loading = v.trim().isNotEmpty;
        _suggestions = UniversalSearch.suggest(query: v);
      });
      _runSearch(v);
    });
  }

  void _runSearch(String v) {
    final providers =
        HomologCatalog.enabled ? HomologCatalog.providers() : const <ProviderModel>[];
    final hits = UniversalSearch.search(
      query: v,
      providers: providers,
      companies: _homologCompanies,
    );
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _loading = false;
    });
  }

  Future<void> _openHit(UniversalHit hit) async {
    await _pushHistory(hit.title);
    if (!mounted) return;
    switch (hit.kind) {
      case UniversalHitKind.service:
        final svc = ServiceTaxonomy.serviceById(hit.serviceId ?? hit.id);
        if (svc != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceRequestFlowScreen(service: svc),
            ),
          );
          return;
        }
        break;
      case UniversalHitKind.group:
        final g = ServiceTaxonomy.groupById(hit.groupId ?? hit.id);
        if (g != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceListScreen(group: g)),
          );
          return;
        }
        break;
      case UniversalHitKind.vertical:
        final v = ServiceTaxonomy.verticalById(hit.verticalId ?? hit.id);
        if (v?.independentRoute != null) {
          Navigator.pushNamed(context, v!.independentRoute!);
          return;
        }
        if (v != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServiceGroupsScreen(vertical: v)),
          );
          return;
        }
        break;
      case UniversalHitKind.provider:
        Navigator.pushNamed(context, Routes.requestService, arguments: {
          'providerId': hit.id,
          'providerName': hit.title,
          'category': hit.categoryId ?? '',
        });
        return;
      case UniversalHitKind.company:
        Navigator.pushNamed(context, Routes.companyProfile);
        return;
      case UniversalHitKind.category:
        break;
    }
    if (hit.categoryId != null) {
      Navigator.pushNamed(context, Routes.search,
          arguments: {'category': hit.categoryId});
    }
  }

  IconData _iconFor(UniversalHitKind k) => switch (k) {
        UniversalHitKind.vertical => Icons.category_outlined,
        UniversalHitKind.group => Icons.account_tree_outlined,
        UniversalHitKind.service => Icons.handyman_outlined,
        UniversalHitKind.category => Icons.label_outline,
        UniversalHitKind.provider => Icons.person_outline,
        UniversalHitKind.company => Icons.storefront_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final showIdle = _q.trim().isEmpty;
    return Scaffold(
      appBar: CarajasAppBar(
        title: 'O que voce precisa?',
        titleWidget: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: (v) {
            _pushHistory(v);
            _runSearch(v);
          },
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: const InputDecoration(
            hintText: 'Servico, categoria, profissional...',
            hintStyle: TextStyle(color: Colors.white54, fontSize: 14),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _ctrl.clear();
                setState(() {
                  _q = '';
                  _hits = const [];
                  _suggestions = const [];
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Busca so profissionais',
            onPressed: () => Navigator.pushNamed(context, Routes.search),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: showIdle
              ? _buildIdle()
              : _loading && _hits.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _hits.isEmpty
                      ? EmptyState(
                          emoji: '🔎',
                          title: 'Nenhum resultado',
                          subtitle:
                              'Tente outro termo. Ex.: freios, diarista, guincho, advogado.',
                          actionLabel: 'Limpar busca',
                          onAction: () {
                            _ctrl.clear();
                            setState(() {
                              _q = '';
                              _hits = const [];
                            });
                          },
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          children: [
                            if (_suggestions.isNotEmpty) ...[
                              const Text('Sugestoes',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _suggestions
                                    .map((s) => ActionChip(
                                          label: Text(s),
                                          onPressed: () {
                                            _ctrl.text = s;
                                            _ctrl.selection =
                                                TextSelection.fromPosition(
                                                    TextPosition(
                                                        offset: s.length));
                                            _onChanged(s);
                                            _pushHistory(s);
                                          },
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Text('${_hits.length} resultado(s)',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textLight)),
                            const SizedBox(height: 8),
                            ..._hits.map(_hitTile),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildIdle() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'Busque servicos, categorias, subcategorias, profissionais e empresas da regiao.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text('Recentes',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            if (_history.isNotEmpty)
              TextButton(onPressed: _clearHistory, child: const Text('Limpar')),
          ],
        ),
        if (_history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhuma busca recente ainda.',
                style: TextStyle(color: AppColors.textLight)),
          )
        else
          ..._history.map((h) => ListTile(
                leading: const Icon(Icons.history),
                title: Text(h),
                onTap: () {
                  _ctrl.text = h;
                  _onChanged(h);
                },
              )),
        const SizedBox(height: 12),
        const Text('Explorar categorias',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ServiceTaxonomy.verticals
              .take(12)
              .map((v) => ActionChip(
                    avatar: Text(v.emoji),
                    label: Text(v.name),
                    onPressed: () {
                      if (v.independentRoute != null &&
                          (v.id == 'saude' || v.id == 'maquinas')) {
                        Navigator.pushNamed(context, v.independentRoute!);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ServiceGroupsScreen(vertical: v),
                        ),
                      );
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _hitTile(UniversalHit hit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Icon(_iconFor(hit.kind), color: AppColors.primary, size: 20),
        ),
        title: Text(hit.title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(hit.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openHit(hit),
      ),
    );
  }
}
