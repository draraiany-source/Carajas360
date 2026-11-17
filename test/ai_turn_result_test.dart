import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/shared/services/ai_service.dart';

void main() {
  test('AiTurnResult parseia providers e consent', () {
    final t = AiTurnResult.fromMap({
      'reply': 'Olá',
      'source': 'consent_required',
      'mode': 'health',
      'conversationId': 'c1',
      'cost': {'usd': 0.001},
      'providers': [
        {
          'id': 'p1',
          'name': '[TESTE] Ana',
          'city': 'Marabá',
          'rating': 4.5,
          'categories': ['medico'],
          'isTestSeed': true,
        }
      ],
    });
    expect(t.consentRequired, isTrue);
    expect(t.providers, hasLength(1));
    expect(t.providers.first.id, 'p1');
    expect(t.costUsd, 0.001);
  });
}
