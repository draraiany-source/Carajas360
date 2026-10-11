import 'dart:convert';

/// Linha do carrinho. `unitPriceCents` é SÓ para exibição: o pedido é
/// recalculado no servidor (createMarketOrder) com preço, estoque e frete
/// atuais.
class CartLine {
  final String productId, storeId, storeName, name, emoji;
  final int unitPriceCents;
  final int qty;

  const CartLine({
    required this.productId,
    required this.storeId,
    required this.storeName,
    required this.name,
    this.emoji = '📦',
    required this.unitPriceCents,
    required this.qty,
  });

  static const maxQty = 99;

  CartLine copyWith({int? qty}) => CartLine(
      productId: productId,
      storeId: storeId,
      storeName: storeName,
      name: name,
      emoji: emoji,
      unitPriceCents: unitPriceCents,
      qty: qty ?? this.qty);

  int get subtotalCents => unitPriceCents * qty;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'storeId': storeId,
        'storeName': storeName,
        'name': name,
        'emoji': emoji,
        'unitPriceCents': unitPriceCents,
        'qty': qty,
      };

  static CartLine? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['productId'];
    final store = raw['storeId'];
    final qty = raw['qty'];
    if (id is! String || id.isEmpty || store is! String || qty is! num) {
      return null;
    }
    final q = qty.toInt().clamp(0, maxQty);
    if (q <= 0) return null;
    return CartLine(
      productId: id,
      storeId: store,
      storeName: (raw['storeName'] ?? '').toString(),
      name: (raw['name'] ?? '').toString(),
      emoji: (raw['emoji'] ?? '📦').toString(),
      unitPriceCents: (raw['unitPriceCents'] as num?)?.toInt() ?? 0,
      qty: q,
    );
  }
}

/// Estado imutável do carrinho + regras puras (testáveis sem Firebase).
class Cart {
  final List<CartLine> lines;
  const Cart([this.lines = const []]);

  static const empty = Cart();

  bool get isEmpty => lines.isEmpty;
  int get totalItems => lines.fold(0, (s, l) => s + l.qty);
  int qtyOf(String productId) =>
      lines.where((l) => l.productId == productId).fold(0, (s, l) => s + l.qty);

  /// Itens agrupados por loja (cada loja vira um pedido separado).
  Map<String, List<CartLine>> byStore() {
    final out = <String, List<CartLine>>{};
    for (final l in lines) {
      out.putIfAbsent(l.storeId, () => []).add(l);
    }
    return out;
  }

  Cart setQty(CartLine line, int qty) {
    final q = qty.clamp(0, CartLine.maxQty);
    final rest = lines.where((l) => l.productId != line.productId).toList();
    if (q <= 0) return Cart(rest);
    final idx = lines.indexWhere((l) => l.productId == line.productId);
    final updated = line.copyWith(qty: q);
    if (idx < 0) return Cart([...lines, updated]);
    final copy = [...lines];
    copy[idx] = updated;
    return Cart(copy);
  }

  /// Remove itens de uma loja (após pagamento CONFIRMADO do pedido).
  Cart removeProducts(Iterable<String> productIds) {
    final ids = productIds.toSet();
    return Cart(lines.where((l) => !ids.contains(l.productId)).toList());
  }

  /// União do carrinho local (visitante) com o salvo na conta: mesmo
  /// produto fica com a MAIOR quantidade (não soma, para não duplicar
  /// quando o mesmo carrinho já foi sincronizado antes).
  static Cart merge(Cart local, Cart remote) {
    final byId = <String, CartLine>{};
    for (final l in [...remote.lines, ...local.lines]) {
      final cur = byId[l.productId];
      byId[l.productId] = cur == null || l.qty > cur.qty ? l : cur;
    }
    return Cart(byId.values.toList());
  }

  String encode() => jsonEncode(lines.map((l) => l.toMap()).toList());

  static Cart decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      return fromList(jsonDecode(raw));
    } catch (_) {
      return empty;
    }
  }

  static Cart fromList(Object? list) {
    if (list is! List) return empty;
    final seen = <String>{};
    final out = <CartLine>[];
    for (final raw in list.take(100)) {
      final l = CartLine.fromMap(raw);
      if (l != null && seen.add(l.productId)) out.add(l);
    }
    return Cart(out);
  }
}
