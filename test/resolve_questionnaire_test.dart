import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/resolve/questionnaire.dart';
import 'package:servico_conecta/shared/models/models.dart';

final qn = Questionnaire.fromMap('q', {
  'title': 'Tomadas',
  'version': 2,
  'questions': [
    {'id': 'tipo', 'type': 'single_choice', 'label': 'Tipo', 'required': true, 'options': ['instalar', 'consertar']},
    {'id': 'qtd', 'type': 'number', 'label': 'Quantidade', 'required': true, 'showIf': {'questionId': 'tipo', 'op': 'equals', 'value': 'instalar'}},
    {'id': 'defeito', 'type': 'long_text', 'label': 'Defeito', 'required': true, 'showIf': {'questionId': 'tipo', 'op': 'equals', 'value': 'consertar'}},
    {'id': 'foto', 'type': 'attachment', 'label': 'Foto', 'showIf': {'questionId': 'defeito', 'op': 'answered'}},
  ],
});

void main() {
  group('Questionário condicional (mesmas regras do servidor)', () {
    test('mostra só perguntas cujas condições valem', () {
      expect(qn.visible({}).map((q) => q.id), ['tipo']);
      expect(qn.visible({'tipo': 'instalar'}).map((q) => q.id), ['tipo', 'qtd']);
      expect(qn.visible({'tipo': 'consertar'}).map((q) => q.id), ['tipo', 'defeito']);
      expect(qn.visible({'tipo': 'consertar', 'defeito': 'Desarma'}).map((q) => q.id),
          ['tipo', 'defeito', 'foto']);
      expect(qn.visible({'tipo': 'instalar', 'defeito': 'oculta'}).map((q) => q.id), ['tipo', 'qtd'],
          reason: 'condição depende de pergunta visível');
    });

    test('collect: obrigatórias visíveis e descarte de respostas ocultas', () {
      var r = qn.collect({'tipo': 'instalar'});
      expect(r.errors, ['Responda: Quantidade']);
      r = qn.collect({'tipo': 'instalar', 'qtd': 3, 'defeito': 'ignorar'});
      expect(r.errors, isEmpty);
      expect(r.answers, {'tipo': 'instalar', 'qtd': 3});
      expect(qn.collect({}).errors, ['Responda: Tipo']);
      expect(qn.collect({'tipo': '  '}).errors, ['Responda: Tipo'], reason: 'texto em branco não conta');
    });

    test('operadores in/not_equals/answered com múltipla escolha', () {
      const c = QuestionCondition('x', 'in', ['a', 'b']);
      expect(Questionnaire.holds(c, {'x': 'b'}), isTrue);
      expect(Questionnaire.holds(c, {'x': ['c', 'a']}), isTrue);
      expect(Questionnaire.holds(c, {'x': 'z'}), isFalse);
      expect(Questionnaire.holds(const QuestionCondition('x', 'not_equals', 'a'), {}), isFalse);
      expect(Questionnaire.holds(const QuestionCondition('x', 'not_equals', 'a'), {'x': 'b'}), isTrue);
      expect(Questionnaire.holds(const QuestionCondition('x', 'answered', null), {'x': []}), isFalse);
    });
  });

  group('Modelos do Resolve', () {
    test('solicitação contratada expõe pedido, chat, agenda e respostas públicas', () {
      final r = ResolveRequest.fromMap('rr1', {
        'clientId': 'c', 'description': 'Trocar tomadas', 'category': 'svc', 'city': 'Marabá',
        'status': 'matched', 'modality': 'home_care', 'preferredDate': '2026-10-20', 'preferredPeriod': 'morning',
        'publicAnswers': [{'label': 'Quantidade', 'value': '3'}], 'attachmentCount': 2,
        'orderId': 'rs_rr1', 'chatRoomId': 'a_b', 'acceptedTerms': {'price': 180.5},
      });
      expect(r.status, ResolveStatus.matched);
      expect(r.orderId, 'rs_rr1');
      expect(r.chatRoomId, 'a_b');
      expect(r.answers.single['value'], '3');
      expect(r.acceptedPrice, 180.5);
      expect(r.modality, 'home_care');
    });

    test('oportunidade traz distância e respostas, nunca endereço', () {
      final o = ResolveOpportunity.fromMap({
        'id': 'rr1', 'description': 'd', 'category': 'svc', 'city': 'Marabá', 'distanceKm': 2.4,
        'answers': [{'label': 'Tipo', 'value': 'instalar'}], 'address': 'Rua X',
      });
      expect(o.distanceKm, 2.4);
      expect(o.answers.single['label'], 'Tipo');
    });

    test('pedido de serviço: status de pagamento separado do status do pedido', () {
      final o = OrderModel.fromMap('rs_1', {'clientId': 'c', 'status': 'accepted', 'paymentStatus': 'paid', 'source': 'resolve', 'price': 200});
      expect(o.status, OrderStatus.accepted);
      expect(o.isPaid, isTrue);
      expect(o.source, 'resolve');
    });
  });
}
