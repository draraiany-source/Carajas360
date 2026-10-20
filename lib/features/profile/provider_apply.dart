import 'package:flutter/material.dart';
import '../../core/catalog/catalog_widgets.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../provider/provider_home_screen.dart';
import 'provider_apply_state.dart';

// ─────────────────────────────────────────────────────────────
// Perfil › "Quero ser prestador" (conta cliente). Reaproveita o mesmo
// cadastro do registro: especialidades (createProviderProfile, sempre
// verified/active false), documentos na mesma tela de onboarding e a
// mesma fila de aprovação do admin (reviewProvider). Sem autoaprovação:
// as regras recusam verified/active/verificationStatus vindos do app.
// O tipo da conta (users.type) não muda aqui; o acesso de prestador
// depende só de providers/{uid}.verified (servidor e regras).
// ─────────────────────────────────────────────────────────────
class ProviderApplyItems extends StatefulWidget {
  final UserModel user;
  const ProviderApplyItems({super.key, required this.user});
  @override
  State<ProviderApplyItems> createState() => _ProviderApplyItemsState();
}

class _ProviderApplyItemsState extends State<ProviderApplyItems> {
  late final Stream<ProviderModel?> _provider = FS.myProviderStream();
  Future<bool>? _docs;
  String? _docsFor;

  // Documentos enviados (lidos uma vez por perfil/estado; relidos ao voltar
  // do onboarding).
  Future<bool> _docsOf(ProviderModel p) {
    final key = '${p.id}:${p.verificationStatus}';
    if (_docs == null || _docsFor != key) {
      _docsFor = key;
      _docs = FS
          .getProviderVerification(p.id)
          .then(providerDocumentsSent)
          .catchError((_) => true); // sem leitura: não acusa pendência
    }
    return _docs!;
  }

  Future<void> _openOnboarding() async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const ProviderOnboardingScreen(fromProfile: true)));
    if (mounted) setState(() => _docs = null);
  }

  void _onTap(ProviderApplyStatus s, ProviderModel? p) {
    switch (s) {
      case ProviderApplyStatus.notStarted:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ProviderApplyScreen(user: widget.user)));
      case ProviderApplyStatus.incomplete:
        _openOnboarding();
      case ProviderApplyStatus.inReview:
        snack(context,
            'Seu cadastro está em análise. Você recebe um aviso assim que for avaliado.');
      case ProviderApplyStatus.rejected:
        _showRejected(p!);
      case ProviderApplyStatus.approved:
        Navigator.pushNamed(context, Routes.providerHome);
    }
  }

  void _showRejected(ProviderModel p) => showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Mesmo aviso da Área do Prestador (motivo + nova análise).
                    Container(
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.all(6),
                        child: ProviderReviewBanner(provider: p)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                        key: const Key('provider-apply-resend-docs'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openOnboarding();
                        },
                        icon: const Icon(Icons.upload_file_rounded),
                        label: const Text('Reenviar documentos')),
                  ]),
            ),
          ));

  @override
  Widget build(BuildContext context) => StreamBuilder<ProviderModel?>(
        stream: _provider,
        builder: (_, snap) {
          if (snap.hasError) return const SizedBox.shrink();
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const SizedBox.shrink();
          }
          final p = snap.data;
          if (p == null || p.verified || p.rejected) {
            return _tiles(providerApplyStatus(p), p);
          }
          return FutureBuilder<bool>(
              future: _docsOf(p),
              builder: (_, d) => _tiles(
                  providerApplyStatus(p, hasDocuments: d.data), p));
        },
      );

  Widget _tiles(ProviderApplyStatus s, ProviderModel? p) {
    final l = providerApplyLabel(s, p);
    final icon = switch (s) {
      ProviderApplyStatus.approved => '🔧',
      ProviderApplyStatus.rejected => '⚠️',
      ProviderApplyStatus.inReview => '⏳',
      _ => '🧰',
    };
    return Column(children: [
      ListTile(
        key: Key('provider-apply-${s.name}'),
        leading: Text(icon, style: const TextStyle(fontSize: 20)),
        title: Text(l.title,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textDark)),
        subtitle: Text(l.subtitle,
            style: TextStyle(
                fontSize: 11,
                color: s == ProviderApplyStatus.rejected
                    ? AppColors.error
                    : AppColors.textLight)),
        trailing:
            const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
        onTap: () => _onTap(s, p),
      ),
      if (s == ProviderApplyStatus.approved)
        ListTile(
          leading: const Text('⚡', style: TextStyle(fontSize: 20)),
          title: const Text('Oportunidades Resolve',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textDark)),
          subtitle: const Text('Enviar propostas a pedidos abertos',
              style: TextStyle(fontSize: 11, color: AppColors.textLight)),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: AppColors.textLight),
          onTap: () => Navigator.pushNamed(context, Routes.resolveOpportunities),
        ),
    ]);
  }
}

/// Primeiro passo para cliente: especialidades (mesmo seletor do cadastro).
/// Cria providers/{uid} pendente e segue para documentos e selfie.
class ProviderApplyScreen extends StatefulWidget {
  final UserModel user;
  const ProviderApplyScreen({super.key, required this.user});
  @override
  State<ProviderApplyScreen> createState() => _ProviderApplyScreenState();
}

class _ProviderApplyScreenState extends State<ProviderApplyScreen> {
  final _selected = <String>{};
  bool _loading = false;

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      snack(context, 'Selecione ao menos uma categoria de atuação');
      return;
    }
    setState(() => _loading = true);
    try {
      await FS.createProviderProfile(
          userId: widget.user.id,
          name: widget.user.name,
          categories: _selected.toList(),
          city: widget.user.city);
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => const ProviderOnboardingScreen(fromProfile: true)));
    } catch (e) {
      debugPrint('Quero ser prestador: $e');
      if (mounted) snack(context, genericActionError, bg: AppColors.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Quero ser prestador')),
        body: LoadingOverlay(
          loading: _loading,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'Escolha o que você atende. Depois, envie documento e selfie: '
                'seu perfil só aparece na busca e recebe pedidos depois da '
                'aprovação da equipe.',
                style: TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            CatalogBuilder(
                compact: true,
                builder: (_, catalog) => CatalogMultiSelect(
                    catalog: catalog,
                    selected: _selected,
                    onChanged: (v) => setState(() => _selected
                      ..clear()
                      ..addAll(v)))),
            const SizedBox(height: 20),
            ElevatedButton(
                key: const Key('provider-apply-continue'),
                onPressed: _loading ? null : _continue,
                child: const Text('Continuar para documentos')),
          ]),
        ),
      );
}
