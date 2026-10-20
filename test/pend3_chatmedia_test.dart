import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/shared/models/models.dart';

// Anexos do chat (LGPD): mensagens antigas com download URL viram caminho
// no Storage; o link com token nunca é usado diretamente.
void main() {
  group('chatMediaPathFromUrl', () {
    test('URL de produção com token -> caminho', () {
      expect(
          chatMediaPathFromUrl(
              'https://firebasestorage.googleapis.com/v0/b/proj.appspot.com/o/chat_media%2Fa_b%2F1712.jpg?alt=media&token=abc-123'),
          'chat_media/a_b/1712.jpg');
    });
    test('URL do emulador -> caminho', () {
      expect(
          chatMediaPathFromUrl(
              'http://127.0.0.1:9199/v0/b/demo.appspot.com/o/chat_media%2Fx_y%2Faudio.m4a?alt=media'),
          'chat_media/x_y/audio.m4a');
    });
    test('links externos, outras pastas e caminhos estranhos são ignorados', () {
      expect(chatMediaPathFromUrl(null), isNull);
      expect(chatMediaPathFromUrl('https://golpe.example.com/premio.jpg'), isNull);
      expect(
          chatMediaPathFromUrl(
              'https://firebasestorage.googleapis.com/v0/b/p/o/users%2Fb%2Fdoc.jpg'),
          isNull);
      expect(
          chatMediaPathFromUrl(
              'https://firebasestorage.googleapis.com/v0/b/p/o/chat_media%2Fa_b%2F..%2F..%2Fusers%2Fx.jpg'),
          isNull);
      expect(
          chatMediaPathFromUrl(
              'https://firebasestorage.googleapis.com/v0/b/p/o/chat_media%2Fa_b%2Fsub%2Fx.jpg'),
          isNull);
    });
  });

  group('MessageModel', () {
    final now = Timestamp.now();
    test('formato novo: mediaPath + tipo + nome', () {
      final m = MessageModel.fromMap('m1', {
        'senderId': 'a',
        'text': '📄 contrato.pdf',
        'createdAt': now,
        'mediaPath': 'chat_media/a_b/a_1.pdf',
        'mediaType': 'document',
        'mediaName': 'contrato.pdf',
      });
      expect(m.hasMedia, isTrue);
      expect(m.storagePath, 'chat_media/a_b/a_1.pdf');
      expect(m.mediaKind, 'document');
      expect(m.mediaName, 'contrato.pdf');
    });
    test('mensagem antiga (só mediaUrl) usa o caminho e o tipo pelo texto', () {
      final m = MessageModel.fromMap('m2', {
        'senderId': 'a',
        'text': '🎤 Mensagem de voz',
        'createdAt': now,
        'mediaUrl':
            'https://firebasestorage.googleapis.com/v0/b/p/o/chat_media%2Fa_b%2F9.m4a?alt=media&token=t',
      });
      expect(m.hasMedia, isTrue);
      expect(m.storagePath, 'chat_media/a_b/9.m4a');
      expect(m.mediaKind, 'audio');
    });
    test('mediaUrl externo não vira anexo; texto sem anexo também não', () {
      final ext = MessageModel.fromMap('m3', {
        'text': '📷 Foto',
        'createdAt': now,
        'mediaUrl': 'https://golpe.example.com/x.jpg',
      });
      expect(ext.hasMedia, isFalse);
      final plain = MessageModel.fromMap('m4', {'text': 'oi', 'createdAt': now});
      expect(plain.hasMedia, isFalse);
      expect(plain.mediaKind, 'image');
    });
  });
}
