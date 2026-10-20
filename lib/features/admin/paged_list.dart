import 'package:flutter/foundation.dart';

/// Busca uma página: itens depois de [after] (null = início), no máximo
/// [limit]. No app é `query.startAfterDocument(after).limit(limit).get()`.
typedef PageFetcher<D> = Future<List<D>> Function(D? after, int limit);

/// Lista paginada por cursor (lógica pura, testável sem Firestore).
/// Concatena páginas sem repetir ids, para quando uma página vem
/// incompleta e descarta respostas de buscas antigas após [refresh].
/// [keep] filtra no aparelho sem afetar o cursor nem o fim da lista
/// (decidido pelo tamanho da página bruta).
class PagedList<D> extends ChangeNotifier {
  PagedList({
    required this.fetch,
    required this.idOf,
    this.pageSize = 50,
    this.keep,
  });

  final PageFetcher<D> fetch;
  final String Function(D) idOf;
  final int pageSize;
  final bool Function(D)? keep;

  final List<D> _items = [];
  final Set<String> _ids = {};
  D? _cursor;
  bool _hasMore = true, _loading = false, _loadedOnce = false, _disposed = false;
  Object? _error;
  int _gen = 0;

  List<D> get items => List.unmodifiable(_items);
  bool get hasMore => _hasMore;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  Object? get error => _error;

  /// Recomeça do início (filtro trocado, "atualizar" ou após uma ação).
  Future<void> refresh() {
    _gen++;
    _items.clear();
    _ids.clear();
    _cursor = null;
    _hasMore = true;
    _loading = false;
    _loadedOnce = false;
    _error = null;
    return loadMore();
  }

  /// Próxima página; ignorada se já está carregando ou chegou ao fim.
  Future<void> loadMore() async {
    if (_loading || !_hasMore || _disposed) return;
    final gen = _gen;
    _loading = true;
    _error = null;
    _notify();
    try {
      final page = await fetch(_cursor, pageSize);
      if (gen != _gen || _disposed) return;
      if (page.isNotEmpty) _cursor = page.last;
      for (final d in page) {
        if ((keep?.call(d) ?? true) && _ids.add(idOf(d))) _items.add(d);
      }
      _hasMore = page.length >= pageSize;
      _loadedOnce = true;
    } catch (e) {
      if (gen != _gen || _disposed) return;
      _error = e;
    } finally {
      if (gen == _gen && !_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Tira um item já tratado (ex.: prestador aprovado sai da fila).
  void remove(String id) {
    if (_ids.remove(id)) {
      _items.removeWhere((d) => idOf(d) == id);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
