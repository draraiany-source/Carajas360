import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/profile/provider_apply_state.dart';
import 'package:servico_conecta/features/support/support_screens.dart';
import 'package:servico_conecta/shared/models/models.dart';

ProviderModel prov(Map<String, dynamic> m) =>
    ProviderModel.fromMap('u1', {'userId': 'u1', 'name': 'Ana', ...m});

void main() {
  group('Perfil › Quero ser prestador: estado', () {
    test('sem perfil de prestador → não iniciado', () {
      expect(providerApplyStatus(null), ProviderApplyStatus.notStarted);
      expect(providerApplyLabel(ProviderApplyStatus.notStarted, null).title,
          'Quero ser prestador');
    });

    test('perfil criado sem documentos → incompleto; sem leitura → em análise', () {
      final p = prov({'verified': false, 'active': false});
      expect(providerApplyStatus(p, hasDocuments: false),
          ProviderApplyStatus.incomplete);
      expect(providerApplyStatus(p, hasDocuments: true),
          ProviderApplyStatus.inReview);
      expect(providerApplyStatus(p), ProviderApplyStatus.inReview);
    });

    test('nova análise pedida → em análise', () {
      final p = prov({'verified': false, 'verificationStatus': 'pending_review', 'rejectionReason': 'Foto ilegível'});
      expect(providerApplyStatus(p, hasDocuments: true),
          ProviderApplyStatus.inReview);
    });

    test('recusado → mostra o motivo (com ou sem documentos)', () {
      final p = prov({'verified': false, 'verificationStatus': 'rejected', 'rejectionReason': 'Documento ilegível'});
      final s = providerApplyStatus(p, hasDocuments: false);
      expect(s, ProviderApplyStatus.rejected);
      expect(providerApplyLabel(s, p).subtitle, 'Não aprovado: Documento ilegível');
      final semMotivo = prov({'verified': false, 'verificationStatus': 'rejected'});
      expect(providerApplyLabel(ProviderApplyStatus.rejected, semMotivo).subtitle,
          contains('pedir nova análise'));
    });

    test('aprovado (verified do servidor) → Área do Prestador', () {
      final p = prov({'verified': true, 'active': true, 'verificationStatus': 'approved'});
      final s = providerApplyStatus(p, hasDocuments: false);
      expect(s, ProviderApplyStatus.approved);
      expect(providerApplyLabel(s, p).title, 'Área do Prestador');
    });

    test('somente verified aprova: status "approved" gravado sem verified não aprova', () {
      final p = prov({'verified': false, 'verificationStatus': 'approved'});
      expect(providerApplyStatus(p, hasDocuments: true),
          ProviderApplyStatus.inReview);
    });

    test('documentos: exige documento e selfie', () {
      expect(providerDocumentsSent(null), isFalse);
      expect(providerDocumentsSent(const ProviderVerification(documentPath: 'providers/u1/document/1.jpg')), isFalse);
      expect(
          providerDocumentsSent(const ProviderVerification(
              documentPath: 'providers/u1/document/1.jpg',
              selfiePath: 'providers/u1/selfie/1.jpg')),
          isTrue);
    });
  });

  test('FAQ menciona Perfil › Quero ser prestador', () {
    final all = SupportScreen.faq.map((e) => '${e['q']} ${e['a']}').join(' ');
    expect(all, contains('Perfil › Quero ser prestador'));
    expect(all, contains('Pedir nova análise'));
  });
}
