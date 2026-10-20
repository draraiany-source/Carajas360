import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:servico_conecta/features/admin/paged_list.dart';

/// Fonte simulada: lista ordenada; o cursor é o último item recebido.
PageFetcher<int> source(List<int> all, {List<int>? calls}) => (after, limit) async {
      calls?.add(after ?? -1);
      final start = after == null ? 0 : all.indexOf(after) + 1;
      return all.sublist(start, (start + limit).clamp(0, all.length));
    };

void main() {
  test('concatena páginas na ordem, sem duplicar, e para na página incompleta', () async {
    final all = List.generate(130, (i) => i);
    final calls = <int>[];
    final c = PagedList<int>(fetch: source(all, calls: calls), idOf: (i) => '$i', pageSize: 50);
    await c.loadMore();
    expect(c.items.length, 50);
    expect(c.hasMore, isTrue);
    await c.loadMore();
    await c.loadMore();
    expect(c.items, all);
    expect(c.items.toSet().length, 130);
    expect(c.hasMore, isFalse, reason: '3ª página veio com 30 < 50');
    await c.loadMore(); // fim: não busca de novo
    expect(calls, [-1, 49, 99]);
  });

  test('página cheia exata exige mais uma busca vazia para encerrar', () async {
    final c = PagedList<int>(fetch: source(List.generate(100, (i) => i)), idOf: (i) => '$i', pageSize: 50);
    await c.loadMore();
    await c.loadMore();
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.items.length, 100);
    expect(c.hasMore, isFalse);
  });

  test('itens repetidos entre páginas (dado mudou) não duplicam', () async {
    var n = 0;
    final c = PagedList<int>(
        fetch: (after, limit) async => n++ == 0 ? [1, 2, 3] : [3, 4],
        idOf: (i) => '$i',
        pageSize: 3);
    await c.loadMore();
    await c.loadMore();
    expect(c.items, [1, 2, 3, 4]);
    expect(c.hasMore, isFalse);
  });

  test('keep filtra no aparelho sem mudar cursor nem fim da lista', () async {
    final calls = <int>[];
    final c = PagedList<int>(
        fetch: source(List.generate(120, (i) => i), calls: calls),
        idOf: (i) => '$i',
        pageSize: 50,
        keep: (i) => i.isEven);
    await c.loadMore();
    expect(c.items.length, 25);
    expect(c.hasMore, isTrue);
    await c.loadMore();
    await c.loadMore();
    expect(c.items.length, 60);
    expect(c.hasMore, isFalse);
    expect(calls, [-1, 49, 99]);
  });

  test('loadMore concorrente é ignorado; refresh descarta resposta antiga', () async {
    final pending = <Completer<List<int>>>[];
    final c = PagedList<int>(
        fetch: (after, limit) {
          final cp = Completer<List<int>>();
          pending.add(cp);
          return cp.future;
        },
        idOf: (i) => '$i',
        pageSize: 2);
    final f1 = c.loadMore();
    final f2 = c.loadMore();
    expect(pending.length, 1, reason: 'segunda chamada ignorada enquanto carrega');
    expect(c.loading, isTrue);
    final f3 = c.refresh();
    expect(pending.length, 2);
    pending[0].complete([9, 8]); // resposta da busca antiga
    pending[1].complete([1]);
    await Future.wait([f1, f2, f3]);
    expect(c.items, [1]);
    expect(c.hasMore, isFalse);
  });

  test('erro fica visível e permite tentar de novo da mesma posição', () async {
    var fail = true;
    final calls = <int>[];
    final base = source(List.generate(60, (i) => i), calls: calls);
    final c = PagedList<int>(
        fetch: (after, limit) async {
          if (after != null && fail) {
            fail = false;
            throw StateError('rede');
          }
          return base(after, limit);
        },
        idOf: (i) => '$i',
        pageSize: 50);
    await c.loadMore();
    await c.loadMore();
    expect(c.error, isA<StateError>());
    expect(c.items.length, 50);
    expect(c.hasMore, isTrue);
    await c.loadMore();
    expect(c.error, isNull);
    expect(c.items.length, 60);
    expect(c.hasMore, isFalse);
  });

  test('remove tira o item tratado da lista', () async {
    final c = PagedList<int>(fetch: source([1, 2, 3]), idOf: (i) => '$i', pageSize: 50);
    await c.loadMore();
    c.remove('2');
    expect(c.items, [1, 3]);
  });
}
