import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/catalog/catalog.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/models/models.dart';
import '../../shared/services/firebase_service.dart';
import '../../shared/widgets/widgets.dart';
import '../health/health_booking.dart';

/// Perfil público do prestador (Fase 6): só dados públicos de
/// `providers/{id}` (aprovado) e avaliações públicas. Nunca lê o perfil
/// privado em `users/`.
class ProviderProfileScreen extends StatefulWidget {
  final String providerId;
  /// Especialidade escolhida na busca: preservada na contratação.
  final String? category;
  const ProviderProfileScreen({super.key, required this.providerId, this.category});

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen> {
  String get providerId => widget.providerId;
  String? get category => widget.category;

  // Assinaturas criadas uma vez por prestador: antes, cada atualização do
  // documento do prestador recriava as de favorito e de avaliações.
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _provider;
  late Stream<bool> _favorite;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _reviews;

  void _subscribe() {
    _provider = FirebaseFirestore.instance.collection(Col.providers).doc(providerId).snapshots();
    _favorite = FS.isFavoriteStream(providerId);
    _reviews = FirebaseFirestore.instance
        .collection(Col.reviews)
        .where('providerId', isEqualTo: providerId)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(ProviderProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.providerId != widget.providerId) _subscribe();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: BackButton(onPressed: () => safeBack(context)),
            title: const Text('Profissional')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _provider,
          builder: (context, snap) {
            if (snap.hasError) {
              return const EmptyState(
                  emoji: '🔒', title: 'Perfil indisponível', subtitle: 'Este profissional não está disponível no momento.');
            }
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (!snap.data!.exists) {
              return const EmptyState(emoji: '🔍', title: 'Profissional não encontrado', subtitle: 'O perfil pode ter sido removido.');
            }
            final p = ProviderModel.fromMap(snap.data!.id, snap.data!.data()!);
            return MaxWidth(child: _body(context, p));
          },
        ),
      );

  Widget _body(BuildContext context, ProviderModel p) {
    final catalog = CatalogService.instance.catalog;
    final healthId = p.categories.cast<String?>().firstWhere(
        (c) => catalog.rootOf(c!)?.vertical == CatalogVertical.health,
        orElse: () => null);
    final otherUid = p.userId.isNotEmpty ? p.userId : p.id;
    final isMe = otherUid == AuthService.uid;
    return ListView(padding: pagePadding(context), children: [
      Row(children: [
        AppAvatar(url: p.photoUrl, name: p.name, size: 72, r: 20),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (p.verified)
            const Text('✓ Cadastro verificado', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
          Semantics(
              label: 'Nota ${p.rating.toStringAsFixed(1)} de 5, ${p.totalReviews} avaliações',
              child: ExcludeSemantics(
                  child: Text('⭐ ${p.rating.toStringAsFixed(1)} · ${p.totalReviews} avaliações',
                      style: const TextStyle(fontSize: 13)))),
          if (p.city != null && p.city!.isNotEmpty)
            Text('📍 ${p.city}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ])),
        if (!isMe && AuthService.isAuth)
          StreamBuilder<bool>(
            // p.id == providerId (documento lido acima).
            stream: _favorite,
            builder: (_, s) => IconButton(
              tooltip: s.data == true ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
              icon: Icon(s.data == true ? Icons.favorite : Icons.favorite_border, color: AppColors.error),
              onPressed: () =>
                  toggleFavoriteSafe(context, () => FS.toggleFavorite(p.id)),
            ),
          ),
      ]),
      if (p.bio != null && p.bio!.trim().isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(p.bio!, style: const TextStyle(height: 1.4)),
      ],
      const SizedBox(height: 14),
      const Text('Especialidades', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in p.categories)
          Chip(label: Text('${catalog.byId(c)?.icon ?? '🛠️'} ${catalog.nameOf(c)}', style: const TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 6),
      Text(
          'Atende: ${p.modalities.map((m) => const {'presential': 'presencial', 'online': 'online', 'home_care': 'domicílio'}[m] ?? m).join(', ')}'
          '${p.minPrice != null ? ' · a partir de R\$ ${p.minPrice!.toStringAsFixed(0)}' : ''}',
          style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
      const SizedBox(height: 16),
      if (!isMe)
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (healthId != null)
            ElevatedButton.icon(
                icon: const Icon(Icons.event_available),
                label: const Text('Agendar consulta'),
                onPressed: () => _requireLogin(context, () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => HealthBookingScreen(
                            providerId: p.id, providerName: p.name, catalogId: healthId, serviceName: catalog.nameOf(healthId)))))),
          if (healthId == null || p.categories.length > 1)
            ElevatedButton.icon(
                key: const Key('profile-hire'),
                icon: const Icon(Icons.handyman_outlined),
                label: const Text('Solicitar serviço'),
                onPressed: () => _requireLogin(
                    context,
                    () => Navigator.pushNamed(context, Routes.requestService, arguments: {
                          'providerId': p.id,
                          'providerName': p.name,
                          'category': (category != null && category!.isNotEmpty)
                              ? category
                              : p.categories.firstWhere((c) => c != healthId, orElse: () => p.categories.first),
                        }))),
          OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Conversar'),
              onPressed: () => _requireLogin(
                  context, () => ChatNav.open(context, otherUserId: otherUid, otherName: p.name, otherPhoto: p.photoUrl))),
        ]),
      const SizedBox(height: 20),
      const Text('Avaliações recentes', style: TextStyle(fontWeight: FontWeight.w800)),
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _reviews,
        builder: (_, s) {
          if (s.hasError) return QueryErrorView(error: s.error);
          if (!s.hasData) return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
          if (s.data!.docs.isEmpty) {
            return const Padding(padding: EdgeInsets.all(8), child: Text('Ainda sem avaliações.', style: TextStyle(color: AppColors.textLight)));
          }
          return Column(children: [
            for (final d in s.data!.docs)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: AppDecorations.card(r: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${'★' * ((d.data()['stars'] as num?)?.toInt() ?? 0)}  ${d.data()['clientName'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  if ((d.data()['comment'] as String?)?.isNotEmpty == true)
                    Text('${d.data()['comment']}', style: const TextStyle(fontSize: 13)),
                ]),
              ),
          ]);
        },
      ),
    ]);
  }

  void _requireLogin(BuildContext context, VoidCallback go) {
    if (AuthService.isAuth) {
      go();
    } else {
      AuthResume.set(Routes.providerProfile, {'providerId': providerId, if (category != null) 'category': category});
      Navigator.pushNamed(context, Routes.login);
    }
  }
}
