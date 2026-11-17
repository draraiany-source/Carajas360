import 'dart:typed_data';

import 'package:carajas_360/core/orders/order_photos.dart';
import 'package:carajas_360/core/orders/service_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes de fluxo (sem Firebase) — payload + validação + intro do chat.
void main() {
  group('fluxo orçamento com fotos (lógica)', () {
    test('payload inclui photoUrls, photoCount e visita técnica', () {
      final p = ServiceRequest.payload(
        providerId: 'pro1',
        category: 'eletricista',
        title: 'Troca de chuveiro',
        description: 'Preciso trocar o chuveiro do banheiro social.',
        address: 'Rua A, 10',
        urgent: false,
        remoteOnly: false,
        siteVisitRequested: true,
        photoUrls: List.generate(3, (i) => 'https://example.com/$i.jpg'),
      );
      expect(p['siteVisitRequested'], isTrue);
      expect(p['photoUrls'], hasLength(3));
      expect(p['photoCount'], 3);
      expect(p.containsKey('price'), isFalse);
    });

    test('payload corta em 10 fotos', () {
      final urls = List.generate(15, (i) => 'https://x/$i.jpg');
      final p = ServiceRequest.payload(
        providerId: 'pro1',
        category: 'hidraulica',
        title: 'Vazamento',
        description: 'Vazamento sob a pia da cozinha, preciso de orçamento.',
        address: 'Rua B',
        urgent: true,
        remoteOnly: false,
        photoUrls: urls,
      );
      expect(p['photoCount'], OrderPhotos.maxCount);
      expect((p['photoUrls'] as List).length, OrderPhotos.maxCount);
    });

    test('chatIntro menciona fotos e visita', () {
      final t = ServiceRequest.chatIntro('Título', 'Descrição detalhada aqui',
          photoCount: 4, siteVisit: true);
      expect(t, contains('4 foto'));
      expect(t.toLowerCase(), contains('visita'));
    });

    test('simula fila de upload com validação', () {
      final drafts = <OrderPhotoDraft>[];
      for (var i = 0; i < 3; i++) {
        final bytes = Uint8List.fromList(List.filled(500 + i, 7));
        final name = 'ambiente_$i.jpg';
        expect(OrderPhotos.fileError(fileName: name, byteLength: bytes.length),
            isNull);
        drafts.add(OrderPhotoDraft(
            id: '$i', fileName: name, bytes: bytes));
      }
      expect(OrderPhotos.countError(drafts.length, 0), isNull);
      // após "upload" bem-sucedido, URLs associadas
      final urls =
          drafts.map((d) => 'https://storage.example/orders/o1/photos/${d.id}.jpg');
      final attached = urls.toList();
      expect(attached, hasLength(3));
      expect(attached.every((u) => u.contains('/orders/')), isTrue);
    });
  });
}
