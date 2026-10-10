import 'package:cloud_firestore/cloud_firestore.dart';

import '../../shared/services/firebase_service.dart' show CloudFn;
import 'catalog.dart';

/// Operações administrativas do catálogo. Todas passam pelas Cloud
/// Functions (validação no servidor + auditoria); o app não grava
/// catalogNodes diretamente (regras: write false).
abstract final class CatalogAdmin {
  static Future<Map<String, dynamic>> upsert(CatalogNode node,
          {required bool isNew}) =>
      CloudFn.call('catalogUpsert', {'node': node.toUpsert(), 'isNew': isNew});

  static Future<Map<String, dynamic>> setActive(String id, bool active) =>
      CloudFn.call('catalogSetActive', {'id': id, 'active': active});

  static Future<Map<String, dynamic>> reorder(
          String? parentId, List<String> orderedIds) =>
      CloudFn.call(
          'catalogReorder', {'parentId': parentId, 'orderedIds': orderedIds});

  static Future<Map<String, dynamic>> migrate({required bool dryRun}) =>
      CloudFn.call('migrateCatalogV1', {'dryRun': dryRun});

  static Future<Map<String, dynamic>> saveQuestionnaire(
          Map<String, dynamic> data) =>
      CloudFn.call('questionnaireSave', data);

  /// Questionários (rascunhos e publicados) de um item — somente admin.
  static Stream<List<Map<String, dynamic>>> questionnaires(String serviceId) =>
      FirebaseFirestore.instance
          .collection('serviceQuestionnaires')
          .where('serviceId', isEqualTo: serviceId)
          .snapshots()
          .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList()
            ..sort((a, b) => ((b['version'] as num?) ?? 0)
                .compareTo((a['version'] as num?) ?? 0)));

  static Future<Map<String, dynamic>?> lastMigration() async {
    final d = await FirebaseFirestore.instance
        .collection('catalogMigrations')
        .doc('v1')
        .get();
    return d.data();
  }
}
