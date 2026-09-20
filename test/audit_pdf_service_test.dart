import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/services/audit_pdf_service.dart';

void main() {
  final sample = [
    AuditLogModel(
      id: 'a1',
      adminId: 'uid-1',
      adminName: 'Admin Teste',
      action: 'Atualizou configuracoes da plataforma',
      target: 'platform',
      timestamp: DateTime(2026, 9, 19, 14, 30),
      details: {'commissionRate': 0.08},
    ),
    AuditLogModel(
      id: 'a2',
      adminId: 'uid-2',
      adminName: 'Raiany',
      action: 'Processou estorno',
      target: 'order-99',
      timestamp: DateTime(2026, 9, 18, 9, 5),
      details: {'amount': 50},
    ),
  ];

  test('buildCsv inclui cabecalho e registros', () {
    final csv = AuditPdfService.buildCsv(sample);
    expect(csv, contains('Data/Hora,Acao,Admin,AdminId,Alvo,Detalhes'));
    expect(csv, contains('Admin Teste'));
    expect(csv, contains('Processou estorno'));
    expect(csv, contains('order-99'));
  });

  test('buildPdf gera bytes PDF validos', () async {
    final bytes = await AuditPdfService.buildPdf(sample);
    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('formatDateTime e detailsText', () {
    expect(
      AuditPdfService.formatDateTime(DateTime(2026, 9, 19, 8, 5)),
      '19/09/2026 08:05',
    );
    expect(AuditPdfService.detailsText(null), '-');
    expect(AuditPdfService.detailsText({}), '-');
    expect(AuditPdfService.detailsText({'a': 1}), contains('"a":1'));
  });
}