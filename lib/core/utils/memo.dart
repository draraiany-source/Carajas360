/// Guarda um valor (em geral um Stream/Future do Firestore) e só o recria
/// quando a chave muda. Usado em build() para não refazer a assinatura ou a
/// leitura a cada rebuild (leituras repetidas, piscadas, listeners extras).
///
/// Cada Memo deve alimentar um único StreamBuilder/FutureBuilder: os streams
/// do Firestore são broadcast e um segundo ouvinte tardio não recebe o
/// primeiro snapshot.
class Memo<T> {
  Object? _key;
  late T _value;
  bool _has = false;

  T of(Object? key, T Function() create) {
    if (!_has || key != _key) {
      _key = key;
      _value = create();
      _has = true;
    }
    return _value;
  }
}
