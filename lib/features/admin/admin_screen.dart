import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_forms.dart';
import 'admin_paging.dart';
import 'data_migrations.dart';
import 'catalog_admin_tab.dart';
import 'finance_admin_tab.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/query_errors.dart';
import '../../shared/models/models.dart';
import '../../core/security/order_policy.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../support/tickets_screens.dart';

// ─────────────────────────────────────────────────────────────
// PAINEL ADMINISTRATIVO (Vol.6 – Painel Administrativo)
// Dashboard · Usuários · Validação · Categorias ·
// Financeiro · Marketing · Atendimento · Auditoria
// ─────────────────────────────────────────────────────────────
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminState();
}

class _AdminState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  static const _tabs = [
    'Usuários',
    'Validação',
    'Categorias',
    'Financeiro',
    'Pagamentos',
    'Marketing',
    'Atendimento',
    'Denúncias',
    'Auditoria',
    'Configurações'
  ];

  late Future<Map<String, dynamic>> _kpis;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _tabs.length, vsync: this);
    _kpis = FS.fetchDashboardKpis();
  }

  Widget _refreshKpis() => IconButton(
      key: const Key('admin-kpis-refresh'),
      tooltip: 'Atualizar indicadores',
      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
      onPressed: () => setState(() => _kpis = FS.fetchDashboardKpis()));

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverToBoxAdapter(
                child: GradHeader(
                    gradient: AppGradients.dark,
                    child: Column(children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('⚙️ Painel Admin',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22)),
                            Semantics(
                                button: true,
                                label: 'Fechar',
                                child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius:
                                            BorderRadius.circular(11)),
                                    child: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 20)))),
                          ]),
                      const SizedBox(height: 12),
                      // Indicadores agregados no servidor (sem ler coleções
                      // inteiras). Criado uma vez; "atualizar" refaz a chamada.
                      FutureBuilder<Map<String, dynamic>>(
                        future: _kpis,
                        builder: (_, snap) {
                          final k = snap.data;
                          final loading =
                              snap.connectionState == ConnectionState.waiting;
                          if (snap.hasError) {
                            return Row(children: [
                              const Expanded(
                                  child: Text(
                                      '⚠️ Indicadores indisponíveis (falha na consulta). Os números não são exibidos para não mostrar zeros falsos.',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12))),
                              _refreshKpis(),
                            ]);
                          }
                          // null = o servidor não conseguiu calcular.
                          String v(String key, [String Function(num)? f]) {
                            if (loading) return '…';
                            final n = k?[key];
                            if (n is! num) return 'indisponível';
                            return f != null ? f(n) : '$n';
                          }

                          return Row(children: [
                            _kpi(v('totalUsers'), 'Usuários'),
                            const SizedBox(width: 8),
                            _kpi(v('totalProviders'), 'Prestadores'),
                            const SizedBox(width: 8),
                            _kpi(v('revenue', (n) => PaySvc.fmt(n.toDouble())),
                                // Soma dos serviços concluídos (GMV), não receita da plataforma.
                                'Volume de serviços (GMV)'),
                            _refreshKpis(),
                          ]);
                        },
                      ),
                      const SizedBox(height: 14),
                      TabBar(
                        controller: _tab,
                        isScrollable: true,
                        indicatorColor: Colors.white,
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white60,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                        tabs: _tabs.map((t) => Tab(text: t)).toList(),
                      ),
                    ])))
          ],
          body: TabBarView(controller: _tab, children: [
            _UsersTab(),
            _ValidationTab(),
            const CatalogAdminTab(),
            _FinancialTab(),
            const FinanceAdminTab(),
            _MarketingTab(),
            _SupportTab(),
            _ReportsTab(),
            _AuditTab(),
            _SettingsTab(),
          ]),
        ),
      );

  Widget _kpi(String val, String lbl) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(val,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18))),
            const SizedBox(height: 2),
            Text(lbl,
                style: const TextStyle(color: Colors.white70, fontSize: 10))
          ])));
}

// ═══════════════════════════════════════════════════════════════
// 1. GESTÃO DE USUÁRIOS (Clientes, Profissionais, Empresas, Bloqueios)
// ═══════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _filter = 'all';
  // Filtro por tipo na própria consulta, paginada (50 por página).
  late PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> _users =
      _usersFor(_filter);

  PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> _usersFor(String f) =>
      pagedQuery(() => FS.adminUsersQuery(type: f == 'all' ? null : f))
        ..loadMore();

  void _setFilter(String f) {
    if (f == _filter) return;
    final old = _users;
    setState(() {
      _filter = f;
      _users = _usersFor(f);
    });
    old.dispose();
  }

  @override
  void dispose() {
    _users.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
            height: 44,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  for (final f in [
                    ['all', 'Todos'],
                    ['client', 'Clientes'],
                    ['provider', 'Prestadores'],
                    ['company', 'Empresas'],
                    ['deliverer', 'Entregadores']
                  ])
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                            key: Key('users-filter-${f[0]}'),
                            onTap: () => _setFilter(f[0]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: _filter == f[0]
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _filter == f[0]
                                          ? AppColors.primary
                                          : AppColors.border)),
                              child: Text(f[1],
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _filter == f[0]
                                          ? Colors.white
                                          : AppColors.textDark)),
                            ))),
                ])),
        Expanded(
            child: PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('users-$_filter'),
          controller: _users,
          empty: EmptyState(
              emoji: '👥',
              title: _filter != 'all' ? 'Nenhum deste tipo' : 'Sem usuários',
              subtitle: _filter != 'all'
                  ? 'Nenhum cadastro deste tipo.'
                  : 'Aguardando cadastros'),
          itemBuilder: (context, doc) {
            final d = doc.data();
            final isActive = d['status'] != 'suspended';
            return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: AppDecorations.card(r: 14),
                child: ListTile(
                  leading: AppAvatar(
                      name: d['name'] ?? '?',
                      size: 40,
                      bg: _typeColor(d['type']),
                      r: 12),
                  title: Text(
                      d['name']?.toString().isNotEmpty == true
                          ? d['name']
                          : '—',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(
                      '${_typeLabel(d['type'])} · ${d['city'] ?? 'sem cidade'}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.secondary.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(isActive ? 'ativo' : 'suspenso',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? AppColors.secondary
                                  : AppColors.error))),
                  onTap: () =>
                      _userActions(context, doc.id, d['name'] ?? '', isActive),
                ));
          },
        )),
      ]);

  String _typeLabel(String? t) {
    switch (t) {
      case 'provider':
        return '🔧 Prestador';
      case 'company':
        return '🏢 Empresa';
      case 'deliverer':
        return '🛵 Entregador';
      case 'admin':
        return '⚙️ Admin';
      default:
        return '👤 Cliente';
    }
  }

  Color _typeColor(String? t) {
    switch (t) {
      case 'provider':
        return AppColors.primary;
      case 'company':
        return AppColors.purple;
      case 'deliverer':
        return AppColors.delivery;
      default:
        return AppColors.secondary;
    }
  }

  void _userActions(
          BuildContext context, String uid, String name, bool isActive) =>
      showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const SheetHandle(),
                  const SizedBox(height: 12),
                  Text('Ações: $name',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  if (isActive)
                    ListTile(
                        leading: const Icon(Icons.block_rounded,
                            color: AppColors.error),
                        title: const Text('Suspender conta'),
                        onTap: () async {
                          try {
                            await FS.suspendUser(uid);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _users.refresh();
                              snack(context, 'Conta suspensa',
                                  bg: AppColors.error);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              snack(context, 'Falha ao suspender: $e',
                                  bg: AppColors.error);
                            }
                          }
                        })
                  else
                    ListTile(
                        leading: const Icon(Icons.refresh_rounded,
                            color: AppColors.secondary),
                        title: const Text('Reativar conta'),
                        onTap: () async {
                          try {
                            await FS.reactivateUser(uid);
                            if (context.mounted) {
                              Navigator.pop(context);
                              _users.refresh();
                              snack(context, 'Conta reativada',
                                  bg: AppColors.secondary);
                            }
                          } catch (e) {
                            if (context.mounted) {
                              snack(context, 'Falha ao reativar: $e',
                                  bg: AppColors.error);
                            }
                          }
                        }),
                ]),
              ));
}

// ═══════════════════════════════════════════════════════════════
// 2. VALIDAÇÃO DE PROFISSIONAIS E EMPRESAS
// ═══════════════════════════════════════════════════════════════
class _ValidationTab extends StatefulWidget {
  @override
  State<_ValidationTab> createState() => _ValidationTabState();
}

class _ValidationTabState extends State<_ValidationTab> {
  // Filas paginadas (sem snapshots da coleção inteira). Recusados saem da
  // fila até pedirem nova análise (filtro local, não afeta o cursor).
  final _providers = pagedQuery(FS.pendingProvidersQuery,
      keep: (d) => providerAwaitingReview(d.data()))
    ..loadMore();
  final _companies = pagedQuery(FS.pendingCompaniesQuery)..loadMore();
  final _stores = pagedQuery(FS.pendingStoresQuery)..loadMore();

  @override
  void dispose() {
    _providers.dispose();
    _companies.dispose();
    _stores.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
            color: Colors.white,
            child: const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: '🔧 Prestadores'),
                  Tab(text: '🏢 Empresas'),
                  Tab(text: '🛍️ Lojas')
                ])),
        Expanded(
            child: TabBarView(children: [
          _pendingProviders(context),
          _pendingCompanies(context),
          _pendingStores(context)
        ])),
      ]));

  Widget _pendingProviders(BuildContext context) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: _providers,
          empty: const EmptyState(
              emoji: '✅',
              title: 'Sem pendências',
              subtitle: 'Nenhum cadastro aguardando análise'),
          itemBuilder: (context, doc) {
                final d = doc.data();
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppDecorations.card(r: 14),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            AppAvatar(
                                name: d['name'] ?? '?',
                                size: 44,
                                bg: AppColors.orange,
                                r: 12),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(d['name'] ?? '—',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  Text(
                                      d['verificationStatus'] == 'pending_review'
                                          ? '🔁 Nova análise solicitada${(d['rejectionReason'] ?? '').toString().isNotEmpty ? ' · recusa anterior: ${d['rejectionReason']}' : ''}'
                                          : '⏳ Aguardando aprovação · Verifique os documentos antes de aprovar',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600)),
                                ])),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                                child: OutlinedButton(
                                    onPressed: () =>
                                        _viewDocuments(context, doc.id, d),
                                    style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10)),
                                    child: const Text('Ver documentos',
                                        style: TextStyle(fontSize: 12)))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: OutlinedButton(
                                    onPressed: () =>
                                        _reject(context, doc.id, d['name'] ?? ''),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(color: AppColors.error),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10)),
                                    child: const Text('Recusar',
                                        style: TextStyle(fontSize: 12)))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await FS.reviewProvider(doc.id, approve: true);
                                        _providers.remove(doc.id);
                                        if (context.mounted)
                                          snack(context, '✅ Prestador aprovado!',
                                              bg: AppColors.secondary);
                                      } on CloudCallException catch (e) {
                                        if (context.mounted)
                                          snack(context, e.message, bg: AppColors.error);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.secondary,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10)),
                                    child: const Text('Aprovar',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)))),
                          ]),
                        ]));
          });

  /// Recusa com motivo (enviado ao prestador, que pode pedir nova análise).
  Future<void> _reject(BuildContext context, String providerId, String name) async {
    final c = TextEditingController();
    final reason = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
              title: Text('Recusar ${name.isEmpty ? 'cadastro' : name}?'),
              content: TextField(
                  key: const Key('reject-reason'),
                  controller: c,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                      hintText: 'Motivo (visível ao prestador, mín. 5 caracteres)')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(d), child: const Text('Voltar')),
                ElevatedButton(
                    onPressed: () {
                      if (c.text.trim().length < 5) {
                        snack(d, 'Informe o motivo (mín. 5 caracteres)', bg: AppColors.error);
                        return;
                      }
                      Navigator.pop(d, c.text.trim());
                    },
                    child: const Text('Recusar')),
              ],
            ));
    c.dispose();
    if (reason == null) return;
    try {
      await FS.reviewProvider(providerId, approve: false, reason: reason);
      _providers.remove(providerId);
      if (context.mounted) snack(context, 'Cadastro recusado. O prestador foi avisado.');
    } on CloudCallException catch (e) {
      if (context.mounted) snack(context, e.message, bg: AppColors.error);
    }
  }

  Widget _pendingCompanies(BuildContext context) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: _companies,
          empty: const EmptyState(
              emoji: '✅',
              title: 'Sem pendências',
              subtitle: 'Todas as empresas aprovadas'),
          itemBuilder: (context, doc) {
                final d = doc.data();
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppDecorations.card(r: 14),
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      AppAvatar(
                          name: d['name'] ?? '?',
                          size: 44,
                          bg: AppColors.purple,
                          r: 12),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(d['name'] ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                            Text('CNPJ: ${d['cnpj'] ?? '—'}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textLight)),
                          ])),
                      ElevatedButton(
                          onPressed: () => adminRun(context, () async {
                                await FS.approveCompany(doc.id);
                                _companies.remove(doc.id);
                              }, done: '✅ Empresa aprovada!'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8)),
                          child: const Text('Aprovar',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700))),
                    ]));
          });

  Widget _pendingStores(BuildContext context) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: _stores,
          empty: const EmptyState(
              emoji: '✅',
              title: 'Sem pendências',
              subtitle: 'Todas as lojas aprovadas'),
          itemBuilder: (context, doc) {
            final d = doc.data();
            return Container(
                key: Key('pending-store-${doc.id}'),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: AppDecorations.card(r: 14),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  AppAvatar(
                      name: d['name'] ?? '?',
                      size: 44,
                      bg: AppColors.secondary,
                      r: 12),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(d['name'] ?? '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        Text(
                            [d['category'], d['city']]
                                .whereType<String>()
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight)),
                      ])),
                  ElevatedButton(
                      onPressed: () => adminRun(context, () async {
                            await FS.approveStore(doc.id);
                            _stores.remove(doc.id);
                          },
                              confirm:
                                  'Aprovar a loja "${d['name'] ?? ''}"? Ela passa a vender no Mercado.',
                              done: '✅ Loja aprovada!'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8)),
                      child: const Text('Aprovar',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700))),
                ]));
          });

  // Documentação privada (providers/{id}/private/verification). Os
  // arquivos são abertos por URL temporária gerada no servidor.
  void _viewDocuments(BuildContext context, String providerId,
      Map<String, dynamic> providerData) {
    // Uma leitura por abertura (não a cada rebuild da folha).
    final verification = FS.getProviderVerification(providerId);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (sheetCtx) => Padding(
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<ProviderVerification?>(
                future: verification,
                builder: (_, snap) {
                  final v = snap.data;
                  final files = <MapEntry<String, String>>[
                    if (v?.documentPath != null)
                      MapEntry('Documento (RG/CNH)', v!.documentPath!),
                    if (v?.selfiePath != null)
                      MapEntry('Selfie de validação', v!.selfiePath!),
                    for (final p in v?.certificatePaths ?? const <String>[])
                      MapEntry('Certificado', p),
                  ];
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    const SheetHandle(),
                    const SizedBox(height: 16),
                    Text('Documentos: ${providerData['name'] ?? '—'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    if (snap.connectionState != ConnectionState.done)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator())
                    else if (snap.hasError)
                      EmptyState(
                          emoji: '⚠️',
                          title: 'Erro ao carregar documentos',
                          subtitle: '${snap.error}')
                    else if (v == null || v.isEmpty)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: EmptyState(
                              emoji: '📄',
                              title: 'Nenhum documento',
                              subtitle:
                                  'O prestador ainda não enviou documentos'))
                    else ...[
                      for (final f in files)
                        ListTile(
                          leading: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.primary),
                          title: Text(f.key,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(f.value.split('/').last,
                              style: const TextStyle(fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.open_in_new_rounded,
                              size: 18, color: AppColors.textLight),
                          onTap: () async {
                            try {
                              final url = await FS.verificationFileUrl(
                                  providerId, f.value);
                              if (url != null) {
                                await launchUrl(Uri.parse(url),
                                    mode: LaunchMode.externalApplication);
                              }
                            } catch (e) {
                              if (sheetCtx.mounted) {
                                snack(sheetCtx, 'Não foi possível abrir: $e',
                                    bg: AppColors.error);
                              }
                            }
                          },
                        ),
                      for (final c in v.certificates)
                        ListTile(
                          leading: const Icon(Icons.verified_outlined,
                              color: AppColors.textLight),
                          title: Text(c, style: const TextStyle(fontSize: 13)),
                          subtitle: const Text('Certificado informado (texto)',
                              style: TextStyle(fontSize: 11)),
                        ),
                    ],
                    const SizedBox(height: 12),
                  ]);
                },
              ),
            ));
  }
}

// 3. CATÁLOGO: ver catalog_admin_tab.dart (fonte única administrável).

// ═══════════════════════════════════════════════════════════════
// 4. FINANCEIRO (comissões, repasses, saques, estornos, assinaturas)
// ═══════════════════════════════════════════════════════════════
class _FinancialTab extends StatefulWidget {
  @override
  State<_FinancialTab> createState() => _FinancialTabState();
}

class _FinancialTabState extends State<_FinancialTab> {
  // Período do relatório em dias (null = desde o início).
  int? _days;
  late Future<Map<String, dynamic>> _report = FS.fetchFinancialReport();

  void _load(int? days) => setState(() {
        _days = days;
        _report = FS.fetchFinancialReport(periodDays: days);
      });

  // null = o servidor não conseguiu calcular: "indisponível", nunca R$ 0.
  static String _money(Object? v) =>
      v is num ? PaySvc.fmt(v.toDouble()) : 'indisponível';

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _report,
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            return EmptyState(
                emoji: '⚠️',
                title: 'Relatório indisponível',
                subtitle: e is CloudCallException
                    ? e.message
                    : friendlyQueryError(e),
                actionLabel: 'Tentar novamente',
                onAction: () => _load(_days));
          }
          final r = snap.data ?? {};
          final missing = (r['ordersWithoutCommission'] as num?)?.toInt();
          final rows = [
            [
              '💰',
              'Volume de serviços (GMV) — concluídos',
              _money(r['grossRevenue']),
              AppColors.secondary
            ],
            [
              '📊',
              'Comissão da plataforma (registrada no repasse)',
              _money(r['commission']),
              AppColors.primary
            ],
            [
              '🏦',
              'Repasses a prestadores',
              _money(r['netToProviders']),
              AppColors.secondary
            ],
            [
              '💳',
              'Recargas de carteira confirmadas',
              _money(r['pixProcessed']),
              AppColors.pix
            ],
            [
              '↩️',
              'Reembolsos aprovados',
              _money(r['refunds']),
              AppColors.error
            ],
            [
              '✅',
              'Serviços concluídos',
              r['completedCount'] is num
                  ? '${r['completedCount']}'
                  : 'indisponível',
              AppColors.gold
            ],
          ];
          return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(
                          child: Text('Visão geral',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 16))),
                      IconButton(
                          key: const Key('finance-report-refresh'),
                          tooltip: 'Atualizar',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => _load(_days)),
                    ]),
                    Wrap(spacing: 8, children: [
                      for (final p in const [
                        [null, 'Todo o período'],
                        [30, '30 dias'],
                        [7, '7 dias']
                      ])
                        ChoiceChip(
                            label: Text(p[1] as String),
                            selected: _days == p[0],
                            onSelected: (_) => _load(p[0] as int?)),
                    ]),
                    const SizedBox(height: 10),
                    for (final row in rows)
                      Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: AppDecorations.card(r: 14),
                          child: ListTile(
                            leading: Text(row[0] as String,
                                style: const TextStyle(fontSize: 22)),
                            title: Text(row[1] as String,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: Text(row[2] as String,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: row[3] as Color)),
                          )),
                    if (missing != null && missing > 0)
                      Text(
                          'Comissão e repasses parciais: $missing serviço(s) concluído(s) antigo(s) sem repasse registrado não entram nesses totais.',
                          key: const Key('finance-commission-partial'),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.warning)),
                    Text(
                        'Calculado no servidor${_days != null ? ' · últimos $_days dias (concluídos, recargas e reembolsos pela data de cada evento)' : ''}.',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 16),
                    const Text('Ações rápidas',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () =>
                                  _exportReport(context, rows, csv: true),
                              icon: const Icon(Icons.receipt_long_outlined,
                                  size: 18),
                              label: const Text('Exportar CSV',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)))),
                      const SizedBox(width: 8),
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () =>
                                  _exportReport(context, rows, csv: false),
                              icon: const Icon(Icons.picture_as_pdf_outlined,
                                  size: 18),
                              label: const Text('Exportar PDF',
                                  style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.textDark,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12)))),
                    ]),
                  ]));
        },
      );

  Future<void> _exportReport(BuildContext context, List<List<Object>> rows,
      {required bool csv}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      if (csv) {
        final buffer = StringBuffer('Relatório,Valor\n');
        for (final row in rows) {
          buffer.writeln('"${row[1]}","${row[2]}"');
        }
        final bytes = utf8.encode(buffer.toString());
        final name = 'relatorio_financeiro_$timestamp.csv';
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(Uint8List.fromList(bytes),
                name: name, mimeType: 'text/csv'),
          ],
          text: 'Relatório financeiro — Carajás 360',
        ));
      } else {
        final doc = pw.Document();
        doc.addPage(pw.Page(
          build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Relatório Financeiro',
                    style: pw.TextStyle(
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Carajás 360 — ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700)),
                pw.SizedBox(height: 20),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2)
                  },
                  children: [
                    pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.blue800),
                        children: [
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Descrição',
                                  style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Padding(
                              padding: const pw.EdgeInsets.all(8),
                              child: pw.Text('Valor',
                                  style: pw.TextStyle(
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold))),
                        ]),
                    for (final row in rows)
                      pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${row[0]} ${row[1]}')),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${row[2]}')),
                      ]),
                  ],
                ),
              ]),
        ));
        final pdfBytes = await doc.save();
        final name = 'relatorio_financeiro_$timestamp.pdf';
        await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(pdfBytes, name: name, mimeType: 'application/pdf'),
          ],
          text: 'Relatório financeiro — Carajás 360',
        ));
      }
    } catch (e) {
      if (context.mounted)
        snack(context, 'Erro ao gerar relatório: $e', bg: AppColors.error);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 5. MARKETING (banners, cupons, campanhas, push)
// ═══════════════════════════════════════════════════════════════
class _MarketingTab extends StatefulWidget {
  @override
  State<_MarketingTab> createState() => _MarketingTabState();
}

class _MarketingTabState extends State<_MarketingTab> {
  final _bannerList = pagedQuery(FS.adminBannersQuery)..loadMore();
  final _couponList = pagedQuery(FS.adminCouponsQuery)..loadMore();

  @override
  void dispose() {
    _bannerList.dispose();
    _couponList.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
            color: Colors.white,
            child: const TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(text: '🖼️ Banners (em breve)'),
                  Tab(text: '🎟️ Cupons')
                ])),
        Expanded(
            child:
                TabBarView(children: [_banners(context), _coupons(context)])),
      ]));

  // Nenhuma tela do app exibe banners ainda: criação desabilitada e aviso
  // "Em breve" para não sugerir que aparecem na home.
  Widget _banners(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        body: PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
            controller: _bannerList,
            header: const InfoBanner(
                key: Key('banners-soon'),
                icon: '🚧',
                text: 'Em breve — banners ainda não são exibidos no app.',
                bg: Color(0xFFFFF8E1),
                fg: AppColors.textDark),
            empty: const EmptyState(
                emoji: '🖼️',
                title: 'Sem banners',
                subtitle: 'A exibição de banners na home chega em breve.'),
            itemBuilder: (context, doc) {
                    final d = doc.data();
                    return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: AppDecorations.card(r: 14),
                        child: ListTile(
                          leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_outlined,
                                  color: AppColors.primary)),
                          title: Text(d['title'] ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                              d['active'] == true ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: d['active'] == true
                                      ? AppColors.secondary
                                      : AppColors.textLight)),
                          trailing: IconButton(
                              tooltip: 'Excluir banner',
                              icon: const Icon(Icons.delete_outline,
                                  color: AppColors.error),
                              onPressed: () => adminRun(context, () async {
                                    await FS.deleteBanner(doc.id);
                                    _bannerList.remove(doc.id);
                                  },
                                  confirm: 'Excluir este banner?',
                                  done: 'Banner excluído.')),
                        ));
            }),
      );

  Widget _coupons(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
            tooltip: 'Novo cupom',
            onPressed: () => _newCoupon(context),
            backgroundColor: AppColors.primary,
            mini: true,
            child: const Icon(Icons.add, color: Colors.white)),
        body: PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
            controller: _couponList,
            empty: const EmptyState(
                emoji: '🎟️',
                title: 'Sem cupons',
                subtitle: 'Crie cupons promocionais'),
            itemBuilder: (context, doc) {
                    final d = doc.data();
                    return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: AppDecorations.card(r: 14),
                        child: ListTile(
                          leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: const Icon(Icons.local_offer_outlined,
                                  color: AppColors.gold)),
                          title: Text(d['code'] ?? '—',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13)),
                          subtitle: Text(
                              [
                                if ((d['description'] ?? '').toString().isNotEmpty) d['description'],
                                if (d['maxUses'] is int) 'usos: ${d['usedCount'] ?? 0}/${d['maxUses']}',
                                if (d['perUserLimit'] is int) 'por cliente: ${d['perUserLimit']}',
                                if (d['expiresAt'] is Timestamp)
                                  'válido até ${fmtDate((d['expiresAt'] as Timestamp).toDate())}',
                              ].join(' · '),
                              style: const TextStyle(fontSize: 11)),
                          // Cupom não pode ser excluído (regras): desative-o.
                          trailing: Tooltip(
                            message: 'Ativo',
                            child: Switch(
                                key: Key('coupon-active-${doc.id}'),
                                value: d['active'] == true,
                                onChanged: (v) => adminRun(context, () async {
                                      await FirebaseFirestore.instance
                                          .collection(Col.coupons)
                                          .doc(doc.id)
                                          .update({'active': v});
                                      // Lista paginada (sem tempo real): recarrega.
                                      await _couponList.refresh();
                                    },
                                    done: v ? 'Cupom ativado.' : 'Cupom desativado.')),
                          ),
                        ));
            }),
      );

  Future<void> _newCoupon(BuildContext context) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _NewCouponSheet());
    // Cupom novo aparece no topo (createdAt desc).
    if (mounted) _couponList.refresh();
  }
}

/// Folha "Novo cupom": dona dos campos (descartados ao fechar).
class _NewCouponSheet extends StatefulWidget {
  const _NewCouponSheet();
  @override
  State<_NewCouponSheet> createState() => _NewCouponSheetState();
}

class _NewCouponSheetState extends State<_NewCouponSheet> {
  final code = TextEditingController();
  final desc = TextEditingController();
  final discount = TextEditingController();
  final maxUses = TextEditingController();
  // Padrão: um uso por cliente.
  final perUser = TextEditingController(text: '1');
  // Validade em dias a partir de hoje.
  final validDays = TextEditingController(text: '30');
  var isPercentage = true;
  String? error;
  var saving = false;

  @override
  void dispose() {
    for (final c in [code, desc, discount, maxUses, perUser, validDays]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          const SheetHandle(),
          const SizedBox(height: 16),
          const Text('Novo cupom',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextFormField(
              controller: code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'CÓDIGO')),
          const SizedBox(height: 10),
          TextFormField(
              controller: desc,
              decoration:
                  const InputDecoration(hintText: 'Descrição')),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(isPercentage
                ? 'Desconto percentual (%)'
                : 'Desconto em valor (R\$)'),
            value: isPercentage,
            onChanged: (v) => setState(() => isPercentage = v),
          ),
          TextFormField(
              key: const Key('coupon-discount'),
              controller: discount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  hintText: isPercentage
                      ? 'Desconto (%) — até 100'
                      : 'Desconto (R\$)')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: TextFormField(
                    key: const Key('coupon-max-uses'),
                    controller: maxUses,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Limite total de usos',
                        helperText: 'Vazio = sem limite'))),
            const SizedBox(width: 10),
            Expanded(
                child: TextFormField(
                    key: const Key('coupon-per-user'),
                    controller: perUser,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Limite por cliente',
                        helperText: 'Vazio = sem limite'))),
          ]),
          const SizedBox(height: 10),
          TextFormField(
              key: const Key('coupon-valid-days'),
              controller: validDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Validade (dias)',
                  helperText: 'De 1 a 365 dias a partir de hoje')),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(error!,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final err = validateCouponInput(
                              code: code.text,
                              discount: discount.text,
                              isPercentage: isPercentage,
                              maxUses: maxUses.text,
                              perUserLimit: perUser.text);
                          final days = int.tryParse(validDays.text.trim());
                          final daysErr = days == null || days < 1 || days > 365
                              ? 'Validade: informe de 1 a 365 dias'
                              : null;
                          if (err != null || daysErr != null) {
                            setState(() => error = err ?? daysErr);
                            return;
                          }
                          setState(() {
                            error = null;
                            saving = true;
                          });
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          try {
                            await FS.createCoupon({
                              'code': code.text.trim().toUpperCase(),
                              'description': desc.text.trim(),
                              'discount': double.parse(discount.text
                                  .trim()
                                  .replaceAll(',', '.')),
                              'isPercentage': isPercentage,
                              if (maxUses.text.trim().isNotEmpty)
                                'maxUses': int.parse(maxUses.text.trim()),
                              if (perUser.text.trim().isNotEmpty)
                                'perUserLimit':
                                    int.parse(perUser.text.trim()),
                              'usedCount': 0,
                              'expiresAt': Timestamp.fromDate(DateTime.now()
                                  .add(Duration(days: days!)))
                            });
                          } catch (e) {
                            // Folha fechada durante o envio.
                            if (!mounted) return;
                            setState(() {
                              saving = false;
                              error = 'Não foi possível salvar: $e';
                            });
                            return;
                          }
                          if (!mounted) return;
                          nav.pop();
                          messenger.showSnackBar(const SnackBar(
                              content: Text('✅ Cupom criado!'),
                              backgroundColor:
                                  AppColors.secondary));
                        },
                  child: Text(saving ? 'Salvando…' : 'Criar cupom'))),
        ]),
      ),
    );
}

// ═══════════════════════════════════════════════════════════════
// 6. ATENDIMENTO (chamados, FAQ, relatórios de suporte)
// ═══════════════════════════════════════════════════════════════
class _SupportTab extends StatefulWidget {
  @override
  State<_SupportTab> createState() => _SupportTabState();
}

class _SupportTabState extends State<_SupportTab> {
  String? _statusFilter;
  // Recriado só quando o filtro muda.
  late PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> _tickets =
      _ticketsFor(null);

  PagedList<QueryDocumentSnapshot<Map<String, dynamic>>> _ticketsFor(
          String? status) =>
      pagedQuery(() => FS.adminTicketsQuery(status: status))..loadMore();

  void _setFilter(String? f) {
    if (f == _statusFilter) return;
    final old = _tickets;
    setState(() {
      _statusFilter = f;
      _tickets = _ticketsFor(f);
    });
    old.dispose();
  }

  @override
  void dispose() {
    _tickets.dispose();
    super.dispose();
  }

  // Ação no chamado e recarga da lista (sem tempo real).
  Future<void> _ticketAction(Future<void> Function() run, {String? done}) =>
      adminRun(context, () async {
        await run();
        await _tickets.refresh();
      }, done: done);

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
            height: 44,
            child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  for (final f in [
                    [null, 'Todos'],
                    ['open', 'Abertos'],
                    ['answered', 'Respondidos'],
                    ['inProgress', 'Em atendimento'],
                    ['resolved', 'Resolvidos']
                  ])
                    Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                            onTap: () => _setFilter(f[0]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  color: _statusFilter == f[0]
                                      ? AppColors.primary
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _statusFilter == f[0]
                                          ? AppColors.primary
                                          : AppColors.border)),
                              child: Text(f[1]!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _statusFilter == f[0]
                                          ? Colors.white
                                          : AppColors.textDark)),
                            ))),
                ])),
        Expanded(
            child: PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey('tickets-$_statusFilter'),
          controller: _tickets,
          empty: const EmptyState(
              emoji: '🎧',
              title: 'Sem chamados',
              subtitle: 'Nenhum chamado nesta categoria'),
          itemBuilder: (context, doc) {
                  final t = TicketModel.fromMap(doc.id, doc.data());
                  return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => TicketDetailScreen(
                                  ticketId: t.id, initial: t, asSupport: true))),
                      child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: AppDecorations.card(r: 14),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text(t.subject,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14))),
                              Text(t.statusLabel,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 4),
                            Text(t.message,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMedium),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Row(children: [
                              if (t.status != TicketStatus.inProgress)
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: () => _ticketAction(
                                            () => FS.updateTicketStatus(
                                                t.id, 'inProgress')),
                                        style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8)),
                                        child: const Text('Atender',
                                            style: TextStyle(fontSize: 11)))),
                              if (t.status != TicketStatus.inProgress)
                                const SizedBox(width: 8),
                              Expanded(
                                  child: ElevatedButton(
                                      onPressed: () => _ticketAction(
                                          () => FS.updateTicketStatus(
                                              t.id, 'resolved'),
                                          done: 'Chamado resolvido.'),
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.secondary,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8)),
                                      child: const Text('Resolver',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)))),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                t.lastMessageBy == 'user'
                                    ? '💬 Nova mensagem do usuário · toque para responder'
                                    : 'Toque para ver a conversa e responder',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: t.lastMessageBy == 'user'
                                        ? AppColors.primary
                                        : AppColors.textLight)),
                          ])));
          },
        )),
      ]);
}

// ═══════════════════════════════════════════════════════════════
// 7. AUDITORIA (todas as ações críticas registradas — Vol.6)
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// DENÚNCIAS (Vol.20: Administração — moderação de conteúdo/usuários)
// ═══════════════════════════════════════════════════════════════
class _ReportsTab extends StatefulWidget {
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final _reports = pagedQuery(FS.reportsQuery)..loadMore();

  @override
  void dispose() {
    _reports.dispose();
    super.dispose();
  }

  Future<void> _set(String id, ReportStatus st) => adminRun(context, () async {
        await FS.updateReportStatus(id, st);
        await _reports.refresh();
      });

  @override
  Widget build(BuildContext context) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: _reports,
          empty: const EmptyState(
              emoji: '🚩',
              title: 'Sem denúncias',
              subtitle: 'Denúncias de usuários aparecerão aqui'),
          itemBuilder: (context, doc) {
                final r = ReportModel.fromMap(doc.id, doc.data());
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: AppDecorations.card(r: 16),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(r.reason,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14))),
                          AppTag(r.statusLabel,
                              bg: AppColors.background, fg: AppColors.textDark),
                        ]),
                        const SizedBox(height: 6),
                        Text('Denunciado: ${r.targetName}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textDark)),
                        Text('Por: ${r.reporterName} · ${fmtDate(r.createdAt)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textLight)),
                        if (r.details.isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(r.details,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMedium))),
                        if (r.status == ReportStatus.pending ||
                            r.status == ReportStatus.reviewing)
                          Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(children: [
                                if (r.status == ReportStatus.pending)
                                  Expanded(
                                      child: OutlinedButton(
                                          onPressed: () => _set(
                                              r.id, ReportStatus.reviewing),
                                          style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8)),
                                          child: const Text('Analisar',
                                              style: TextStyle(fontSize: 12)))),
                                if (r.status == ReportStatus.reviewing) ...[
                                  Expanded(
                                      child: OutlinedButton(
                                          onPressed: () => _set(
                                              r.id, ReportStatus.dismissed),
                                          style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8)),
                                          child: const Text('Arquivar',
                                              style: TextStyle(fontSize: 12)))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: ElevatedButton(
                                          onPressed: () => _set(
                                              r.id, ReportStatus.resolved),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.secondary,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8)),
                                          child: const Text('Resolver',
                                              style: TextStyle(fontSize: 12)))),
                                ],
                              ])),
                      ]),
                );
          });
}

class _AuditTab extends StatefulWidget {
  @override
  State<_AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<_AuditTab> {
  final _logs = pagedQuery(FS.auditLogQuery)..loadMore();

  @override
  void dispose() {
    _logs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      PagedListView<QueryDocumentSnapshot<Map<String, dynamic>>>(
          controller: _logs,
          empty: const EmptyState(
              emoji: '📜',
              title: 'Sem registros',
              subtitle: 'As ações administrativas aparecerão aqui'),
          itemBuilder: (context, doc) {
                final l = AuditLogModel.fromMap(doc.id, doc.data());
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: AppDecorations.card(r: 14),
                    child: ListTile(
                      leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                              color: AppColors.textDark.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: const Icon(Icons.history_rounded,
                              color: AppColors.textDark, size: 18)),
                      title: Text(l.action,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('${l.adminName} · alvo: ${l.target}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textLight)),
                      trailing: Text(fmtDate(l.timestamp),
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textLight)),
                    ));
          });
}

// ═══════════════════════════════════════════════════════════════
// CONFIGURAÇÕES GERAIS DA PLATAFORMA (Vol.20: Administração)
// ═══════════════════════════════════════════════════════════════
class _SettingsTab extends StatefulWidget {
  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _maintenanceMsgCtrl = TextEditingController();
  bool _maintenanceMode = false;
  bool _loaded = false, _saving = false;
  // Assinado uma vez (não a cada rebuild); cancelado pelo StreamBuilder.
  final _config = FS.platformConfigStream();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _maintenanceMsgCtrl.dispose();
    super.dispose();
  }

  void _loadOnce(Map<String, dynamic> config) {
    if (_loaded) return;
    _loaded = true;
    _emailCtrl.text = config['supportEmail'] ?? '';
    _phoneCtrl.text = config['supportPhone'] ?? '';
    _maintenanceMode = config['maintenanceMode'] ?? false;
    _maintenanceMsgCtrl.text = config['maintenanceMessage'] ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Comissão/cashback: aba "Pagamentos" (config/finance, só servidor).
    try {
      await FS.updatePlatformConfig({
        'supportEmail': _emailCtrl.text.trim(),
        'supportPhone': _phoneCtrl.text.trim(),
        'maintenanceMode': _maintenanceMode,
        'maintenanceMessage': _maintenanceMsgCtrl.text.trim(),
      });
      if (mounted) {
        snack(context, '✅ Configurações salvas!', bg: AppColors.secondary);
      }
    } on FirebaseException catch (e) {
      // config/platform: só admin master grava (regras).
      if (mounted) {
        snack(
            context,
            e.code == 'permission-denied'
                ? 'Sem permissão: somente o administrador master altera manutenção e contatos.'
                : 'Não foi possível salvar: ${e.message ?? e.code}',
            bg: AppColors.error);
      }
    } catch (e) {
      if (mounted) {
        snack(context, 'Não foi possível salvar: $e', bg: AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: _config,
        builder: (_, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          _loadOnce(snap.data!);
          return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Comissão, cashback e parcelamento ficam na aba "Pagamentos" (versionados no servidor).',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textLight)),
                    const SizedBox(height: 20),
                    const Text('Contato de suporte',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.email_outlined),
                            hintText: 'E-mail de atendimento (opcional)')),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: 'Telefone de atendimento (opcional)')),
                    const SizedBox(height: 4),
                    const Text(
                        'Em branco: o app orienta o usuário a abrir um chamado.',
                        style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 20),
                    Container(
                        decoration: AppDecorations.card(r: 14),
                        child: SwitchListTile(
                          title: const Text('Modo manutenção',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text(
                              'Bloqueia o acesso de clientes e prestadores temporariamente',
                              style: TextStyle(fontSize: 11)),
                          value: _maintenanceMode,
                          activeColor: AppColors.error,
                          onChanged: (v) =>
                              setState(() => _maintenanceMode = v),
                        )),
                    const SizedBox(height: 10),
                    TextFormField(
                        controller: _maintenanceMsgCtrl,
                        maxLines: 2,
                        maxLength: 300,
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.info_outline),
                            hintText: 'Mensagem exibida durante a manutenção (opcional)')),
                    const Text(
                        'Manutenção e contatos: somente administrador master.',
                        style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                    const SizedBox(height: 24),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Salvar configurações',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                        )),
                    const SizedBox(height: 24),
                    const BookingConfigCard(),
                    const SizedBox(height: 24),
                    const DataMigrationsCard(),
                  ]));
        },
      );
}

/// Reservas de Saúde e Locação (config/booking): prazo para pagar e
/// limite de reservas pendentes por cliente. Grava pela callable
/// updateBookingConfig (validada e versionada no servidor).
class BookingConfigCard extends StatefulWidget {
  const BookingConfigCard({super.key});
  @override
  State<BookingConfigCard> createState() => _BookingConfigCardState();
}

class _BookingConfigCardState extends State<BookingConfigCard> {
  final _hold = TextEditingController();
  final _max = TextEditingController();
  bool _loaded = false, _saving = false;
  final _config = FS.bookingConfigStream();

  @override
  void dispose() {
    _hold.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = validateBookingConfigInput(_hold.text, _max.text);
    if (err != null) {
      snack(context, err, bg: AppColors.error);
      return;
    }
    setState(() => _saving = true);
    try {
      await FS.updateBookingConfig(
          holdMinutes: int.parse(_hold.text.trim()),
          maxPendingPerClient: int.parse(_max.text.trim()));
      if (mounted) snack(context, '✅ Reservas atualizadas', bg: AppColors.secondary);
    } on CloudCallException catch (e) {
      if (mounted) snack(context, e.message, bg: AppColors.error);
    } catch (_) {
      if (mounted) snack(context, genericActionError, bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<String, dynamic>>(
        stream: _config,
        builder: (context, snap) {
          final d = snap.data;
          if (d != null && !_loaded) {
            _loaded = true;
            // Ausente: padrões do servidor (15 min, 3 pendentes).
            _hold.text = '${(d['holdMinutes'] as num?)?.toInt() ?? 15}';
            _max.text = '${(d['maxPendingPerClient'] as num?)?.toInt() ?? 3}';
          }
          return Container(
            decoration: AppDecorations.card(r: 14),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reservas (Saúde e Locação)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                  snap.hasError
                      ? 'Não foi possível ler os valores atuais.'
                      : d == null
                          ? 'Carregando…'
                          : 'Atual: ${(d['holdMinutes'] as num?)?.toInt() ?? 15} min para pagar · até ${(d['maxPendingPerClient'] as num?)?.toInt() ?? 3} reservas pendentes por cliente',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        key: const Key('booking-hold'),
                        controller: _hold,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Prazo para pagar (min)', helperText: '5 a 120'))),
                const SizedBox(width: 10),
                Expanded(
                    child: TextFormField(
                        key: const Key('booking-max'),
                        controller: _max,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Pendentes por cliente', helperText: '1 a 10'))),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                    onPressed: _saving || d == null ? null : _save,
                    child: Text(_saving ? 'Salvando…' : 'Salvar reservas')),
              ),
            ]),
          );
        },
      );
}

/// Executa uma ação do admin com confirmação opcional e snackbar de erro.
Future<void> adminRun(BuildContext context, Future<void> Function() run,
    {String? confirm, String? done}) async {
  if (confirm != null) {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              content: Text(confirm),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Confirmar')),
              ],
            ));
    if (ok != true || !context.mounted) return;
  }
  try {
    await run();
    if (done != null && context.mounted) {
      snack(context, done, bg: AppColors.secondary);
    }
  } on CloudCallException catch (e) {
    if (context.mounted) snack(context, e.message, bg: AppColors.error);
  } catch (e) {
    if (context.mounted) {
      snack(context, 'Não foi possível concluir: $e', bg: AppColors.error);
    }
  }
}
