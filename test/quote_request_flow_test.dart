import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/features/orders/service_request_flow_screen.dart';

void main() {
  test('campos de imóvel só para limpeza', () {
    expect(categoryNeedsPropertyFields('diarista'), isTrue);
    expect(categoryNeedsPropertyFields('faxineira'), isTrue);
    expect(categoryNeedsPropertyFields('eletricista'), isFalse);
    expect(categoryNeedsPropertyFields('medico'), isFalse);
    expect(categoryNeedsPropertyFields('cabeleireiro'), isFalse);
  });
}
