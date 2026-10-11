import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart.dart';

/// Carrinho persistente: sobrevive a fechar/atualizar o app
/// (SharedPreferences) e acompanha a conta (`carts/{uid}`). Ao entrar,
/// o carrinho de visitante é unido ao da conta. Abrir a tela de pagamento
/// NÃO limpa o carrinho: itens só saem quando o pedido é confirmado pago.
class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  static const _prefsKey = 'cart_v1';
  static const _intentKey = 'pending_intent_v1';

  Cart _cart = Cart.empty;
  Cart get cart => _cart;
  bool _started = false;
  String? _uid;
  StreamSubscription<User?>? _authSub;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final p = await SharedPreferences.getInstance();
      _cart = Cart.decode(p.getString(_prefsKey));
      notifyListeners();
    } catch (e) {
      debugPrint('cart load: $e');
    }
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    } catch (e) {
      debugPrint('cart auth: $e'); // Firebase indisponível: só local.
    }
  }

  Future<void> _onAuth(User? u) async {
    if (u == null) {
      if (_uid != null) {
        // Saiu da conta: o carrinho fica salvo na conta, não no aparelho.
        _uid = null;
        await _set(Cart.empty, sync: false);
      }
      return;
    }
    if (_uid == u.uid) return;
    _uid = u.uid;
    try {
      final snap = await _doc(u.uid).get();
      final remote = Cart.fromList(snap.data()?['items']);
      await _set(Cart.merge(_cart, remote));
    } catch (e) {
      debugPrint('cart merge: $e');
      await _sync();
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('carts').doc(uid);

  Future<void> _set(Cart c, {bool sync = true}) async {
    _cart = c;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, c.encode());
    } catch (e) {
      debugPrint('cart save: $e');
    }
    if (sync) await _sync();
  }

  Future<void> _sync() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _doc(uid).set({
        'items': _cart.lines.map((l) => l.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('cart sync: $e');
    }
  }

  Future<void> setQty(CartLine line, int qty) => _set(_cart.setQty(line, qty));

  Future<void> removeProducts(Iterable<String> ids) =>
      _set(_cart.removeProducts(ids));

  // ── Ação pendente (voltar ao checkout após o login) ──────────────
  static Future<void> setPendingCheckout(String storeId) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_intentKey, 'checkout:$storeId');
  }

  /// Lê e consome a ação pendente. Retorna o storeId do checkout.
  static Future<String?> takePendingCheckout() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_intentKey);
      if (v == null || !v.startsWith('checkout:')) return null;
      await p.remove(_intentKey);
      return v.substring('checkout:'.length);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
