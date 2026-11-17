import 'dart:typed_data';

import 'package:carajas_360/core/orders/order_photos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrderPhotos', () {
    test('limite de 10 fotos', () {
      expect(OrderPhotos.countError(9, 1), isNull);
      expect(OrderPhotos.countError(10, 1), contains('Máximo'));
      expect(OrderPhotos.countError(8, 3), contains('Máximo'));
    });

    test('rejeita extensão inválida e tamanho excessivo', () {
      expect(
        OrderPhotos.fileError(fileName: 'a.gif', byteLength: 100),
        contains('Formato'),
      );
      expect(
        OrderPhotos.fileError(fileName: 'a.jpg', byteLength: 0),
        contains('inválido'),
      );
      expect(
        OrderPhotos.fileError(
            fileName: 'a.png', byteLength: OrderPhotos.maxBytes + 1),
        contains('8 MB'),
      );
      expect(
        OrderPhotos.fileError(fileName: 'foto.JPEG', byteLength: 1200),
        isNull,
      );
    });

    test('prompt de IA não pede preço nem diagnóstico', () {
      final p = OrderPhotos.iaPromptHint(
        draftDescription: 'torneira pingando',
        photoCount: 2,
      );
      expect(p.toLowerCase(), contains('sem inventar'));
      expect(p.toLowerCase(), isNot(contains('cobre r\$')));
      expect(p, contains('2 foto'));
    });

    test('isAllowedBytes', () {
      final ok = Uint8List.fromList(List.filled(100, 1));
      expect(OrderPhotos.isAllowedBytes(ok, 'x.webp'), isTrue);
      expect(OrderPhotos.isAllowedBytes(ok, 'x.exe'), isFalse);
    });
  });
}
