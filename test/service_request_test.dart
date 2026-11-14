import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:carajas_360/core/orders/service_request.dart';
import 'package:carajas_360/shared/models/models.dart';
import 'package:carajas_360/shared/widgets/brand_provider_card.dart';

void main() {
  group('bloqueios antes de gravar', () {
    test('visitante precisa entrar', () {
      expect(ServiceRequest.blockReason(uid: null, providerId: 'p1'),
          isNotNull);
    });

    test('profissional não identificado', () {
      expect(ServiceRequest.blockReason(uid: 'c1', providerId: ' '),
          contains('não identificado'));
    });

    test('não permite pedir para si mesmo', () {
      expect(ServiceRequest.blockReason(uid: 'u1', providerId: 'u1'),
          contains('próprio'));
    });

    test('perfil de demonstração não gera pedido', () {
      expect(
          ServiceRequest.blockReason(
              uid: 'c1', providerId: 'h1', demoProvider: true),
          contains('demonstração'));
    });

    test('cliente e profissional distintos podem enviar', () {
      expect(ServiceRequest.blockReason(uid: 'c1', providerId: 'p1'), isNull);
    });
  });

  group('validação conforme o tipo de atendimento', () {
    test('título e descrição obrigatórios', () {
      expect(ServiceRequest.titleError('  '), isNotNull);
      expect(ServiceRequest.titleError('Troca de tomada'), isNull);
      expect(ServiceRequest.descriptionError(''), isNotNull);
      expect(ServiceRequest.descriptionError('curto'), isNotNull);
      expect(ServiceRequest.descriptionError('Trocar 3 tomadas na sala'),
          isNull);
    });

    test('endereço só é exigido no presencial', () {
      expect(ServiceRequest.addressError('', remoteOnly: false), isNotNull);
      expect(ServiceRequest.addressError('', remoteOnly: true), isNull);
      expect(ServiceRequest.addressError('Rua A, 10', remoteOnly: false),
          isNull);
    });
  });

  test('payload liga o profissional e não leva preço', () {
    final data = ServiceRequest.payload(
      providerId: 'prov-uid',
      category: 'eletricista',
      title: ' Tomada ',
      description: ' Trocar tomadas ',
      address: ' Rua A ',
      urgent: true,
      remoteOnly: false,
    );
    expect(data['providerId'], 'prov-uid');
    expect(data['title'], 'Tomada');
    expect(data['address'], 'Rua A');
    expect(data.keys, isNot(contains('price')));
    expect(data.keys, isNot(contains('clientId')));
    final remote = ServiceRequest.payload(
      providerId: 'p',
      category: 'advogado',
      title: 't',
      description: 'd',
      address: 'Rua B',
      urgent: false,
      remoteOnly: true,
    );
    expect(remote['address'], '');
  });

  test('SubmitGuard ignora envio repetido enquanto grava', () async {
    final guard = SubmitGuard();
    final gate = Completer<void>();
    var calls = 0;
    final first = guard.run(() async {
      calls++;
      await gate.future;
      return 'order-1';
    });
    expect(guard.busy, isTrue);
    final second = await guard.run(() async {
      calls++;
      return 'order-2';
    });
    expect(second, isNull);
    gate.complete();
    expect(await first, 'order-1');
    expect(calls, 1);
    expect(guard.busy, isFalse);
  });

  test('SubmitGuard libera após erro para nova tentativa', () async {
    final guard = SubmitGuard();
    await expectLater(
        guard.run<String>(() async => throw StateError('rede')),
        throwsStateError);
    expect(guard.busy, isFalse);
    expect(await guard.run(() async => 'ok'), 'ok');
  });

  group('dados do cartão', () {
    ProviderModel p({String userId = 'uid1', List<String> mod = const []}) =>
        ProviderModel(
            id: 'doc1',
            userId: userId,
            name: 'X',
            modalities: mod,
            createdAt: DateTime(2025));

    test('pedido e conversa usam o uid do profissional', () {
      expect(providerAccountId(p()), 'uid1');
      expect(providerAccountId(p(userId: '')), 'doc1');
    });

    test('somente online quando todas as modalidades são online', () {
      expect(providerRemoteOnly(p(mod: ['online'])), isTrue);
      expect(providerRemoteOnly(p(mod: ['online', 'presential'])), isFalse);
      expect(providerRemoteOnly(p(mod: [])), isFalse);
    });

    test('preço inicial formatado sem inventar centavos', () {
      expect(formatStartingPrice(80), 'A partir de R\$ 80');
      expect(formatStartingPrice(79.9), 'A partir de R\$ 79,90');
    });
  });
}
