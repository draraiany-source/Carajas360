import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/shared/models/models.dart';
import 'package:servico_conecta/shared/services/firebase_service.dart';

ProviderModel _p(String id, double rating, List<String> cats) => ProviderModel(
    id: id,
    userId: id,
    name: id,
    categories: cats,
    rating: rating,
    createdAt: DateTime(2026));

void main() {
  test('mescla blocos de consulta sem duplicar e ordena por nota', () async {
    final a = Stream.value([_p('x', 4.0, ['a']), _p('y', 5.0, ['a', 'b'])]);
    final b = Stream.value([_p('y', 5.0, ['a', 'b']), _p('z', 4.5, ['b'])]);
    final out = await FS.mergeProviderStreams([a, b], limit: 10).first;
    expect(out.map((p) => p.id), ['y', 'z', 'x']);
  });

  test('respeita o limite', () async {
    final a = Stream.value([_p('x', 4.0, ['a']), _p('y', 5.0, ['a'])]);
    final b = Stream.value([_p('z', 4.5, ['b'])]);
    final out = await FS.mergeProviderStreams([a, b], limit: 2).first;
    expect(out.length, 2);
  });

  test('erro de consulta é propagado (sem lista fictícia)', () async {
    final a = Stream<List<ProviderModel>>.error(StateError('index missing'));
    final b = Stream.value(<ProviderModel>[]);
    expect(FS.mergeProviderStreams([a, b]).first, throwsA(isA<StateError>()));
  });
}
