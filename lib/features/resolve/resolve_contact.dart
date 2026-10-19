import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// Endereço e telefone do cliente de um pedido Resolve
/// (resolveRequests/{id}/private/details). As regras liberam a leitura
/// só para o cliente, o admin e o prestador escolhido (matchedProviderId).
/// Informe [requestId] ou, a partir do pedido, [orderId] (resolveRequestId).
class ResolveClientContact extends StatefulWidget {
  final String? requestId;
  final String? orderId;
  const ResolveClientContact({super.key, this.requestId, this.orderId})
      : assert(requestId != null || orderId != null);

  @override
  State<ResolveClientContact> createState() => _ResolveClientContactState();
}

class _ResolveClientContactState extends State<ResolveClientContact> {
  late Future<Map<String, dynamic>?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final db = FirebaseFirestore.instance;
    var rid = widget.requestId;
    if (rid == null) {
      final o = await db.collection(Col.orders).doc(widget.orderId).get();
      rid = o.data()?['resolveRequestId'] as String?;
    }
    if (rid == null || rid.isEmpty) return null;
    final d = await db
        .collection(Col.resolveRequests)
        .doc(rid)
        .collection('private')
        .doc('details')
        .get();
    return d.data();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
        future: _future,
        builder: (_, snap) {
          const muted = TextStyle(fontSize: 12, color: AppColors.textLight);
          if (snap.connectionState != ConnectionState.done) {
            return const Text('Carregando contato do cliente…', style: muted);
          }
          if (snap.hasError) {
            return Row(children: [
              const Expanded(
                  child: Text('Não foi possível carregar o contato do cliente.',
                      style: TextStyle(fontSize: 12, color: AppColors.error))),
              TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('Tentar de novo')),
            ]);
          }
          final d = snap.data ?? const {};
          String s(String k) => (d[k] ?? '').toString().trim();
          final address = s('address'), reference = s('reference'), phone = s('phone');
          if (address.isEmpty && phone.isEmpty) {
            return const Text('O cliente não informou endereço nem telefone. Combine pelo chat.',
                key: Key('resolve-contact-empty'), style: muted);
          }
          return Column(
              key: const Key('resolve-contact'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (address.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(reference.isEmpty ? address : '$address ($reference)',
                            style: const TextStyle(fontSize: 12, color: AppColors.textDark))),
                  ]),
                if (phone.isNotEmpty)
                  InkWell(
                    onTap: () => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[^0-9+]'), ''))),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
              ]);
        },
      );
}
