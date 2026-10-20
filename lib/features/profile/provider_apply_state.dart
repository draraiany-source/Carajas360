import '../../shared/models/models.dart';

// ─────────────────────────────────────────────────────────────
// "Quero ser prestador" (Perfil de conta cliente): situação do pedido
// para virar prestador, calculada só a partir do que o servidor grava
// em providers/{uid} (verified/verificationStatus/rejectionReason são
// do admin — reviewProvider — e o app não consegue gravá-los). Lógica
// pura, sem Firebase, para teste.
// ─────────────────────────────────────────────────────────────
enum ProviderApplyStatus {
  /// Sem perfil de prestador: abre a escolha de especialidades.
  notStarted,

  /// Perfil criado, mas documento e selfie ainda não enviados
  /// ("Completar depois"): o admin só aprova quem enviou.
  incomplete,

  /// Na fila do admin (primeira análise ou nova análise pedida).
  inReview,

  /// Recusado pelo admin: mostra o motivo e "Pedir nova análise".
  rejected,

  /// Aprovado (verified == true): leva à Área do Prestador.
  approved,
}

/// [hasDocuments]: documento e selfie em providers/{uid}/private/verification
/// (null = ainda não lido; nesse caso não acusa pendência).
ProviderApplyStatus providerApplyStatus(ProviderModel? p, {bool? hasDocuments}) {
  if (p == null) return ProviderApplyStatus.notStarted;
  if (p.verified) return ProviderApplyStatus.approved;
  if (p.rejected) return ProviderApplyStatus.rejected;
  if (hasDocuments == false) return ProviderApplyStatus.incomplete;
  return ProviderApplyStatus.inReview;
}

/// Documento e selfie enviados (mesma exigência do "Enviar para aprovação").
bool providerDocumentsSent(ProviderVerification? v) =>
    v != null &&
    (v.documentPath ?? '').isNotEmpty &&
    (v.selfiePath ?? '').isNotEmpty;

/// Título e subtítulo do item no Perfil.
({String title, String subtitle}) providerApplyLabel(
    ProviderApplyStatus s, ProviderModel? p) {
  switch (s) {
    case ProviderApplyStatus.notStarted:
      return (
        title: 'Quero ser prestador',
        subtitle: 'Cadastre suas especialidades e envie documentos para análise'
      );
    case ProviderApplyStatus.incomplete:
      return (
        title: 'Quero ser prestador',
        subtitle: 'Cadastro incompleto: envie documento e selfie'
      );
    case ProviderApplyStatus.inReview:
      return (
        title: 'Quero ser prestador',
        subtitle: 'Em análise pela equipe · você recebe um aviso'
      );
    case ProviderApplyStatus.rejected:
      final reason = (p?.rejectionReason ?? '').trim();
      return (
        title: 'Quero ser prestador',
        subtitle: reason.isEmpty
            ? 'Não aprovado · toque para corrigir e pedir nova análise'
            : 'Não aprovado: $reason'
      );
    case ProviderApplyStatus.approved:
      return (
        title: 'Área do Prestador',
        subtitle: 'Cadastro aprovado · pedidos recebidos e agenda'
      );
  }
}
