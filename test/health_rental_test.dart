import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/health/health_booking.dart';
import 'package:servico_conecta/shared/models/models.dart';

void main() {
  group('Saúde: horário no fuso do serviço (America/Belem, UTC−3)', () {
    test('rótulo de horário independe do fuso do aparelho', () {
      // 12/10/2026 08:00 em Belém = 11:00 UTC
      final ms = DateTime.utc(2026, 10, 12, 11).millisecondsSinceEpoch;
      expect(HealthTime.label(ms), '12/10 às 08:00');
      expect(HealthTime.date(HealthTime.local(ms)), '2026-10-12');
    });

    test('próximos dias começam "hoje" no fuso local, inclusive perto da meia-noite UTC', () {
      // 13/10 01:00 UTC ainda é 12/10 22:00 em Belém.
      final days = HealthTime.nextDays(3, now: DateTime.utc(2026, 10, 13, 1));
      expect(days, ['2026-10-12', '2026-10-13', '2026-10-14']);
      expect(HealthTime.nextDays(2, now: DateTime.utc(2026, 12, 31, 12)), ['2026-12-31', '2027-01-01']);
    });
  });

  group('Locação: total vem do servidor (centavos)', () {
    test('BookingModel usa totalCents quando presente; legado em reais segue legível', () {
      final novo = BookingModel.fromMap('b', {'totalCents': 70000, 'total': 1, 'status': 'confirmed'});
      expect(novo.total, 700);
      expect(novo.status, BookingStatus.confirmed);
      expect(BookingModel.fromMap('b', {'total': 350.5}).total, 350.5);
    });
  });
}
