import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/catalog/catalog_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/chat_nav.dart';
import '../../shared/widgets/widgets.dart';

/// Perfil público de empresa (somente verificadas e ativas). Mostra
/// apenas dados públicos: nome, cidade, descrição e serviços.
class CompanyPublicScreen extends StatefulWidget {
  final String companyId;
  const CompanyPublicScreen({super.key, required this.companyId});

  @override
  State<CompanyPublicScreen> createState() => _CompanyPublicScreenState();
}

class _CompanyPublicScreenState extends State<CompanyPublicScreen> {
  // Lido uma vez (antes, a cada rebuild).
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _company =
      FirebaseFirestore.instance.collection('companies').doc(widget.companyId).get();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Empresa')),
        body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: _company,
          builder: (_, snap) {
            if (snap.hasError) return QueryErrorView(error: snap.error);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final d = snap.data!.data();
            if (d == null || d['verified'] != true || d['active'] != true) {
              return const EmptyState(
                  emoji: '🏢',
                  title: 'Perfil indisponível',
                  subtitle: 'Esta empresa não possui perfil público ativo.');
            }
            final cats = List<String>.from(d['categories'] ?? const []);
            return ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                AppAvatar(url: d['logoUrl'] as String?, name: (d['name'] ?? '') as String, size: 64, r: 16),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((d['name'] ?? '') as String,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if (d['city'] != null)
                    Text('📍 ${d['city']}', style: const TextStyle(color: AppColors.textLight)),
                ])),
              ]),
              if ((d['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(d['description'].toString()),
              ],
              if (cats.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Serviços', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in cats) Chip(label: CatalogLabel(c, withIcon: true)),
                ]),
              ],
              const SizedBox(height: 24),
              if ((d['ownerId'] ?? '').toString().isNotEmpty)
                ElevatedButton.icon(
                    onPressed: () => ChatNav.open(context,
                        otherUserId: d['ownerId'] as String,
                        otherName: (d['name'] ?? 'Empresa') as String),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Conversar')),
            ]);
          },
        ),
      );
}
