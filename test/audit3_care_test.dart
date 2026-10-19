import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/chat/chat_screen.dart';
import 'package:servico_conecta/features/rental/rental_screen.dart';
import 'package:servico_conecta/features/support/support_screens.dart';

void main() {
  group('Locação: categorias legadas', () {
    test('slug antigo vira rótulo em português', () {
      expect(rentalCategoryLabel('pickup'), 'Picape');
      expect(rentalCategoryLabel('truck'), 'Caminhão');
      expect(rentalCategoryLabel('house'), 'Casa');
    });
    test('desconhecido vira "Outros"; nome do catálogo tem prioridade', () {
      expect(rentalCategoryLabel('xyz'), 'Outros');
      expect(rentalCategoryLabel(null), 'Outros');
      expect(rentalCategoryLabel('aluguel_carro', 'Carros'), 'Carros');
      // nameOf devolve o próprio id quando não acha: não mostrar slug.
      expect(rentalCategoryLabel('pickup', 'pickup'), 'Picape');
    });
  });

  group('Locação: horário de Belém (UTC−3)', () {
    test('início calculado em Belém, independente do aparelho', () {
      final ms = rentalStartMs(DateTime(2026, 7, 17), 8, 0);
      expect(ms, DateTime.utc(2026, 7, 17, 11).millisecondsSinceEpoch);
      expect(rentalDate(ms), '17/07/2026');
    });
    test('período formatado em Belém', () {
      final a = DateTime.utc(2026, 7, 17, 11);
      final b = DateTime.utc(2026, 7, 18, 2, 30); // 17/07 23:30 em Belém
      expect(rentalRange(a, b), '17/07 às 08:00 – 17/07 às 23:30');
    });
    test('erro da cotação vira uma frase amigável', () {
      expect(rentalQuoteErrorText('início deve ser de 1 hora a 365 dias a partir de agora; quantidade entre 1 e 30'),
          'Escolha um início com pelo menos 1 hora de antecedência (até 1 ano).');
      expect(rentalQuoteErrorText('anúncio pausado pelo anunciante'),
          'Este anúncio não está disponível para reserva no momento.');
      expect(rentalQuoteErrorText('qualquer coisa'), isNot(contains(';')));
    });
  });

  group('Chat', () {
    test('só a mensagem gerada pelo app vira bolha de localização', () {
      const ok = '📍 Localização compartilhada\nhttps://maps.google.com/?q=-5.37,-49.11';
      expect(chatLocationUrl(ok), 'https://maps.google.com/?q=-5.37,-49.11');
      expect(chatLocationUrl('veja maps.google.com.evil.com/x'), isNull);
      expect(chatLocationUrl('📍 Localização compartilhada\nhttps://maps.google.com.evil.com/?q=1,2'), isNull);
      expect(chatLocationUrl('$ok\nhttps://evil.com'), isNull);
    });
    test('respostas rápidas neutras', () {
      expect(chatQuickReplies, isNot(contains('Sim, pode vir! 👍')));
      expect(chatQuickReplies, contains('Olá!'));
    });
  });

  group('FAQ', () {
    test('sem promessas que o app não cumpre', () {
      final all = SupportScreen.faq.map((e) => '${e['q']} ${e['a']}').join(' ');
      expect(all, isNot(contains('24h')));
      expect(all, isNot(contains('notificação para avaliar')));
      expect(all, isNot(contains('Adicionar cupom')));
      expect(all, contains('Saúde'));
      expect(all, contains('Locação'));
    });
  });
}
