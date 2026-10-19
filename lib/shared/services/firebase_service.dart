import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/runtime_config.dart';
import '../../core/utils/firebase_bootstrap.dart';
import '../../firebase_options.dart';
import '../../core/utils/platform_info.dart';
import '../../core/security/order_policy.dart';
import '../../core/navigation/app_navigation.dart';
import 'apple_sign_in.dart';
import 'local_notifications.dart';

/// Erro de autenticação com mensagem amigável para a UI.
class AuthFailure implements Exception {
  final String message;
  final String? code;
  const AuthFailure(this.message, {this.code});
  @override
  String toString() => message;
}

class AuthService {
  static final _a = FirebaseAuth.instance;
  static User? get current => _a.currentUser;
  static String? get uid => _a.currentUser?.uid;
  static bool get isAuth => _a.currentUser != null;

  static Future<void> verifyPhone({
    required String phone,
    required void Function(String verId, int? token) onSent,
    required void Function(String error) onError,
    // Android: verificação automática do SMS já faz login.
    void Function(UserCredential cred)? onAutoVerified,
  }) async {
    try {
      await _a.verifyPhoneNumber(
        phoneNumber: '+55${phone.replaceAll(RegExp(r'\D'), '')}',
        timeout: const Duration(seconds: AppConst.otpTimeoutSeconds),
        verificationCompleted: (cred) async {
          try {
            final uc = await _a.signInWithCredential(cred);
            onAutoVerified?.call(uc);
          } on FirebaseAuthException catch (e) {
            onError(_mapAuthError(e));
          }
        },
        verificationFailed: (e) =>
            onError(e.message ?? 'Erro ao verificar telefone'),
        codeSent: (id, token) => onSent(id, token),
        codeAutoRetrievalTimeout: (_) {},
      );
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? 'Erro desconhecido');
    }
  }

  static Future<UserCredential?> confirmOtp(String verId, String otp) async {
    try {
      return await _a.signInWithCredential(
          PhoneAuthProvider.credential(verificationId: verId, smsCode: otp));
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  static Future<UserCredential> signInEmail(String email, String pass) async {
    try {
      return await _a.signInWithEmailAndPassword(
          email: email.trim(), password: pass);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  /// Cria conta com e-mail/senha no Firebase Auth.
  /// Já deixa o usuário autenticado (login automático).
  static Future<UserCredential> signUpEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _a.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      if (displayName != null && displayName.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(displayName.trim());
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  static String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado. Faça login.';
      case 'invalid-email':
        return 'Digite um e-mail válido.';
      case 'weak-password':
        return 'Senha muito fraca. Use ao menos 6 caracteres.';
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'E-mail ou senha incorretos.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde e tente novamente.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'operation-not-allowed':
        return 'Cadastro por e-mail não está habilitado no Firebase.';
      case 'missing-email':
        return 'Digite um e-mail válido.';
      case 'auth/invalid-continue-uri':
      case 'invalid-continue-uri':
        return 'Não foi possível enviar a recuperação de senha.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Erro de autenticação (${e.code}).';
    }
  }

  static Future<void> resetPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Digite seu e-mail.');
    }
    try {
      await _a.sendPasswordResetEmail(email: trimmed);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }

  // ── Login com Google (Vol.3: Login e Cadastro) ────────────────
  // Emulador / Web: fluxo federado do Firebase Auth (popup/provider),
  // que funciona no Auth Emulator sem Client ID OAuth real.
  // Mobile produção: google_sign_in 7.x + credencial Firebase.
  static final _google = GoogleSignIn.instance;
  static bool _googleInitialized = false;

  static Future<bool> _ensureGoogleInitialized() async {
    if (_googleInitialized) return true;
    try {
      await _google.initialize();
      _googleInitialized = true;
      return true;
    } catch (e) {
      _googleInitialized = true;
      debugPrint('Google Sign-In init falhou: $e');
      return false;
    }
  }

  static GoogleAuthProvider _googleProvider() {
    final provider = GoogleAuthProvider();
    provider.addScope('email');
    provider.addScope('profile');
    provider.setCustomParameters({'prompt': 'select_account'});
    return provider;
  }

  static Future<UserCredential?> signInGoogle() async {
    try {
      // Auth Emulator + Web: signInWithPopup/Provider abre o IdP fake.
      if (FirebaseBootstrap.shouldUseEmulator || kIsWeb) {
        try {
          if (kIsWeb) {
            return await _a.signInWithPopup(_googleProvider());
          }
          return await _a.signInWithProvider(_googleProvider());
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-closed-by-user' ||
              e.code == 'cancelled-popup-request' ||
              e.code == 'web-context-cancelled') {
            return null;
          }
          // Sem Client ID real no Web de produção, tenta plugin nativo.
          if (!FirebaseBootstrap.shouldUseEmulator) {
            debugPrint('Google federado falhou, tentando plugin: ${e.code}');
          } else {
            throw AuthFailure(_mapAuthError(e), code: e.code);
          }
        }
      }

      final ok = await _ensureGoogleInitialized();
      if (!ok && kIsWeb) {
        throw const AuthFailure(
            'Configure o Google Client ID Web (meta google-signin-client_id).');
      }
      final account = await _google.authenticate();
      final auth = account.authentication;
      final authorization = await account.authorizationClient
          .authorizationForScopes(const ['email', 'profile']);
      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: auth.idToken,
      );
      return await _a.signInWithCredential(credential);
    } on AuthFailure {
      rethrow;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw AuthFailure(
          'Não foi possível entrar com Google. Verifique a configuração OAuth.',
          code: e.code.name);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_mapAuthError(e), code: e.code);
    } catch (e) {
      debugPrint('Erro no login com Google: $e');
      throw const AuthFailure(
          'Não foi possível entrar com Google. Tente novamente.');
    }
  }

  // ── Login com Apple (Vol.3: Login e Cadastro) ─────────────────
  // Import condicional: no Web usa stub; no iOS/macOS usa o pacote nativo.
  static Future<UserCredential?> signInApple() async {
    if (!PlatformInfo.isApple) return null;
    return signInWithAppleNative();
  }

  static Future<void> signOut() async {
    SessionGuard.instance.markExplicitSignOut();
    // Aparelho compartilhado: quem entrar depois não recebe os avisos desta conta.
    await PushSvc.forget();
    try {
      if (_googleInitialized) await _google.signOut();
    } catch (e) {
      debugPrint('Erro ao sair do Google: $e');
    }
    await _a.signOut();
  }

  /// Exclusão definitiva da conta (LGPD). Pode exigir login recente.
  static Future<void> deleteAccount() async {
    final user = _a.currentUser;
    if (user == null) {
      throw const AuthFailure('Faça login para excluir a conta.');
    }
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthFailure(
            'Por segurança, entre novamente na sua conta e repita a exclusão.',
            code: 'requires-recent-login');
      }
      throw AuthFailure(_mapAuthError(e), code: e.code);
    }
  }
}

class FS {
  static final _db = FirebaseFirestore.instance;
  static String? get _uid => AuthService.uid;

  static Future<void> saveUser(UserModel u) async {
    final ref = _db.collection(Col.users).doc(u.id);
    var isNew = true;
    try {
      final existing = await ref.get(const GetOptions(source: Source.server));
      isNew = !existing.exists;
    } catch (e) {
      debugPrint('saveUser get: $e');
      try {
        final existing = await ref.get();
        isNew = !existing.exists;
      } catch (_) {
        isNew = true;
      }
    }
    // Campos privilegiados só na criação; updates não elevam privilégios.
    // Nulos são omitidos para não apagar dados existentes (ex.: foto do Google).
    final data = u.toMap()..removeWhere((_, v) => v == null);
    if (!isNew) {
      data.remove('type');
      data.remove('adminRole');
      data.remove('verified');
      data.remove('status');
      data.remove('plan');
      data.remove('xp');
    } else {
      data.remove('adminRole');
      if (data['type'] == 'admin') data['type'] = 'client';
    }
    await ref.set({
      ...data,
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<UserModel?> getUser([String? id]) async {
    final d = await _db.collection(Col.users).doc(id ?? _uid).get();
    return d.exists ? UserModel.fromMap(d.id, d.data()!) : null;
  }

  static Stream<UserModel?> userStream([String? id]) => _db
      .collection(Col.users)
      .doc(id ?? _uid)
      .snapshots()
      .map((s) => s.exists ? UserModel.fromMap(s.id, s.data()!) : null);

  static Future<void> updateUser(Map<String, dynamic> data) async {
    if (_uid == null) return;
    final sanitized = Map<String, dynamic>.from(data);
    for (final k in OrderPolicy.protectedUserFields) {
      sanitized.remove(k);
    }
    if (sanitized.isEmpty) return;
    await _db
        .collection(Col.users)
        .doc(_uid)
        .update({...sanitized, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Exportação LGPD (portabilidade) — perfil, pedidos e favoritos do usuário.
  static Future<Map<String, dynamic>> exportMyData() async {
    if (_uid == null) throw Exception('Não autenticado');
    final user = await getUser();
    final orders = await _db
        .collection(Col.orders)
        .where('clientId', isEqualTo: _uid)
        .limit(100)
        .get();
    final favs = await _db
        .collection(Col.favorites)
        .where('userId', isEqualTo: _uid)
        .limit(100)
        .get();
    final resolve = await _db
        .collection(Col.resolveRequests)
        .where('clientId', isEqualTo: _uid)
        .limit(50)
        .get();
    Map<String, dynamic> safe(Map<String, dynamic> m) => m.map((k, v) {
          if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
          if (v is Map) {
            return MapEntry(k, safe(Map<String, dynamic>.from(v)));
          }
          if (v is List) {
            return MapEntry(
                k,
                v.map((e) => e is Map
                    ? safe(Map<String, dynamic>.from(e as Map))
                    : e is Timestamp
                        ? e.toDate().toIso8601String()
                        : e).toList());
          }
          return MapEntry(k, v);
        });
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'user': user?.toMap() ?? {},
      'orders':
          orders.docs.map((d) => safe({'id': d.id, ...d.data()})).toList(),
      'favorites':
          favs.docs.map((d) => safe({'id': d.id, ...d.data()})).toList(),
      'resolveRequests':
          resolve.docs.map((d) => safe({'id': d.id, ...d.data()})).toList(),
    };
  }

  // Upload de foto de perfil do usuário (Vol.3: Cadastro de
  // Clientes). Usa bytes (putData) para funcionar no Web e no mobile.
  static Future<String?> uploadUserPhoto(Uint8List bytes, String fileName) async {
    if (_uid == null) return null;
    try {
      final ext = _extOf(fileName);
      final ref = FirebaseStorage.instance.ref().child(
          'users/$_uid/photo/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, _metaFor(fileName));
      final url = await ref.getDownloadURL();
      await updateUser({'photoUrl': url});
      return url;
    } catch (e) {
      debugPrint('Upload de foto de perfil falhou: $e');
      return null;
    }
  }

  static String _extOf(String name) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'bin';
  }

  static SettableMetadata _metaFor(String fileName) {
    final ext = _extOf(fileName);
    final type = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      'm4a' || 'aac' || 'mp4' => 'audio/mp4',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      _ => 'application/octet-stream',
    };
    return SettableMetadata(contentType: type);
  }

  static Future<void> updateFcmToken(String token) async {
    if (_uid == null) return;
    await _db.collection(Col.users).doc(_uid).update({'fcmToken': token});
  }

  static Future<void> clearFcmToken() async {
    if (_uid == null) return;
    await _db.collection(Col.users).doc(_uid).update({'fcmToken': FieldValue.delete()});
  }

  static Future<void> addXp(int xp) async {
    // XP só via Cloud Functions (review / cadastro). Client não incrementa.
    debugPrint('addXp ignorado no client (xp=$xp)');
  }

  /// Prestadores aprovados e disponíveis, ordenados por nota.
  ///
  /// [category]: um serviço específico (array-contains).
  /// [categories]: qualquer serviço de um grupo (array-contains-any, em
  /// blocos de 30 — limite do Firestore — mesclados no app).
  /// Índice: providers(active ASC, verified ASC, categories CONTAINS,
  /// rating DESC) — declarado em firestore.indexes.json.
  /// Erros de consulta são propagados no stream (sem fallback fictício).
  static Stream<List<ProviderModel>> providersStream(
      {String? category, List<String>? categories, int limit = 20}) {
    final allowed = category != null
        ? <String>{category}
        : (categories == null || categories.isEmpty
            ? null
            : categories.toSet());

    Query<Map<String, dynamic>> base() => _db
        .collection(Col.providers)
        .where('active', isEqualTo: true)
        .where('verified', isEqualTo: true);

    List<ProviderModel> parse(QuerySnapshot<Map<String, dynamic>> s) => s.docs
        .map((d) => ProviderModel.fromMap(d.id, d.data()))
        // Defesa extra: nunca exibir prestador de outro serviço.
        .where((p) =>
            allowed == null || p.categories.any((c) => allowed.contains(c)))
        .toList();

    if (category != null) {
      return base()
          .where('categories', arrayContains: category)
          .orderBy('rating', descending: true)
          .limit(limit)
          .snapshots()
          .map(parse);
    }
    if (allowed == null) {
      return base()
          .orderBy('rating', descending: true)
          .limit(limit)
          .snapshots()
          .map(parse);
    }
    final chunks = <List<String>>[];
    final list = allowed.toList();
    for (var i = 0; i < list.length; i += 30) {
      chunks.add(list.sublist(i, i + 30 > list.length ? list.length : i + 30));
    }
    final streams = chunks
        .map((c) => base()
            .where('categories', arrayContainsAny: c)
            .orderBy('rating', descending: true)
            .limit(limit)
            .snapshots()
            .map(parse))
        .toList();
    if (streams.length == 1) return streams.first;
    return mergeProviderStreams(streams, limit: limit);
  }

  /// Combina resultados de várias consultas (sem duplicar prestadores),
  /// mantendo ordenação por nota. Emite só depois que todas responderem.
  static Stream<List<ProviderModel>> mergeProviderStreams(
      List<Stream<List<ProviderModel>>> streams,
      {int limit = 20}) {
    late StreamController<List<ProviderModel>> ctrl;
    final latest = List<List<ProviderModel>?>.filled(streams.length, null);
    final subs = <StreamSubscription<List<ProviderModel>>>[];
    void emit() {
      if (latest.any((l) => l == null)) return;
      final byId = <String, ProviderModel>{};
      for (final l in latest) {
        for (final p in l!) {
          byId[p.id] = p;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.rating.compareTo(a.rating));
      ctrl.add(merged.take(limit).toList());
    }

    ctrl = StreamController<List<ProviderModel>>(
      onListen: () {
        for (var i = 0; i < streams.length; i++) {
          subs.add(streams[i].listen((v) {
            latest[i] = v;
            emit();
          }, onError: ctrl.addError));
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return ctrl.stream;
  }

  // Cria o perfil de prestador (coleção providers) vinculado ao usuário
  // recém-cadastrado. Fica com verified:false até aprovação no painel
  // admin (Vol.6: Validação de Profissionais), quando então passa a
  // aparecer em providersStream() para os clientes.
  static Future<void> createProviderProfile({
    required String userId,
    required String name,
    required List<String> categories,
    String? city,
    List<String> modalities = const ['presential'],
    double? minPrice,
    String? photoUrl,
    List<String> serviceAreas = const [],
  }) async {
    // Somente campos públicos. Documentos vão para private/verification
    // (ver updateProviderDocuments); nota, verificação e status são do
    // servidor/admin.
    await _db.collection(Col.providers).doc(userId).set({
      'userId': userId,
      'name': name,
      'categories': categories,
      'city': city,
      'modalities': modalities,
      'minPrice': minPrice,
      'photoUrl': photoUrl,
      'serviceAreas': serviceAreas,
      'rating': 0,
      'totalReviews': 0,
      'active': false,
      'verified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Especialidades declaradas pelo prestador (IDs do catálogo). O índice
  /// de busca é recalculado no servidor (onProviderIndex).
  static Future<void> updateProviderCategories(
          String providerId, List<String> categories) =>
      _db.collection(Col.providers).doc(providerId).update({
        'categories': categories,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Admin aprova ou recusa (motivo obrigatório na recusa) pelo servidor.
  static Future<void> reviewProvider(String providerId,
          {required bool approve, String? reason}) =>
      CloudFn.call('reviewProvider', {
        'providerId': providerId,
        'decision': approve ? 'approve' : 'reject',
        if (reason != null) 'reason': reason.trim(),
      });

  /// Prestador recusado pede nova análise depois de corrigir os dados.
  static Future<void> requestProviderReview() =>
      CloudFn.call('requestProviderReview', {});

  // Atualiza os dados enviados no onboarding do prestador. A foto e as
  // áreas atendidas são públicas; documento, selfie e certificados vão
  // para providers/{uid}/private/verification (somente dono e admin) e
  // guardam apenas o CAMINHO do Storage, nunca uma URL pública.
  static Future<void> updateProviderDocuments({
    String? photoUrl,
    String? documentPath,
    String? selfiePath,
    List<String> certificates = const [],
    List<String> serviceAreas = const [],
  }) async {
    if (_uid == null) return;
    final ref = _db.collection(Col.providers).doc(_uid);
    final batch = _db.batch();
    final public = <String, dynamic>{
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (serviceAreas.isNotEmpty) 'serviceAreas': serviceAreas,
    };
    if (public.isNotEmpty) {
      batch.update(ref, {...public, 'updatedAt': FieldValue.serverTimestamp()});
    }
    final private = <String, dynamic>{
      if (documentPath != null) 'documentPath': documentPath,
      if (selfiePath != null) 'selfiePath': selfiePath,
      if (certificates.isNotEmpty) 'certificates': certificates,
    };
    if (private.isNotEmpty) {
      batch.set(
          ref.collection('private').doc('verification'),
          {...private, 'submittedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Documentação privada (admin ou o próprio prestador).
  static Future<ProviderVerification?> getProviderVerification(
      String providerId) async {
    final d = await _db
        .collection(Col.providers)
        .doc(providerId)
        .collection('private')
        .doc('verification')
        .get();
    return d.exists ? ProviderVerification.fromMap(d.data()!) : null;
  }

  static Future<String> createOrder(Map<String, dynamic> data) async {
    final sanitized = Map<String, dynamic>.from(data);
    // Preço/total não vão na criação (regras negam): o prestador orça no aceite.
    for (final k in OrderPolicy.sensitiveFields) {
      if (k != 'providerId') sanitized.remove(k);
    }
    sanitized.remove('commission');
    sanitized.remove('platformFee');
    sanitized.remove('providerAmount');
    sanitized.remove('transactionId');
    sanitized.remove('cashbackGranted');
    final doc = await _db.collection(Col.orders).add({
      ...sanitized,
      'clientId': _uid,
      'status': 'pending',
      'paymentStatus': 'unpaid',
      'payoutProcessed': false,
      'payoutStatus': 'none',
      'createdAt': FieldValue.serverTimestamp()
    });
    return doc.id;
  }

  static Future<void> updateOrder(String orderId, Map<String, dynamic> data) {
    throw const CloudCallException(
        'Atualização direta de pedido bloqueada. Use as ações oficiais.',
        code: 'permission-denied');
  }

  static Future<Map<String, dynamic>> _transition(
      String orderId, String action, {Map<String, dynamic>? extra}) async {
    return CloudFn.call('transitionOrder', {
      'orderId': orderId,
      'action': action,
      ...?extra,
    });
  }

  /// Prestador marca como concluído: o pedido fica aguardando a
  /// confirmação do cliente (o servidor confirma sozinho após 72h).
  static Future<void> markOrderDoneByProvider(String orderId) async {
    await _transition(orderId, 'complete');
  }

  /// Cliente confirma a conclusão: conclui e libera o repasse.
  static Future<void> completeOrder(String orderId) async {
    await _transition(orderId, 'complete');
    try {
      await grantCashback(orderId);
    } catch (e) {
      debugPrint('cashback: $e');
    }
  }

  static Stream<List<OrderModel>> myOrdersStream() => _db
      .collection(Col.orders)
      .where('clientId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => OrderModel.fromMap(d.id, d.data())).toList());

  // ── Pedidos do lado do Prestador (Vol.3: Perfil do Profissional) ─
  // Pedidos endereçados diretamente a este prestador (providerId == uid).
  /// Perfil de prestador do usuário logado (null se não for prestador).
  static Stream<ProviderModel?> myProviderStream() {
    if (_uid == null) return Stream.value(null);
    return _db
        .collection(Col.providers)
        .where('userId', isEqualTo: _uid)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : ProviderModel.fromMap(s.docs.first.id, s.docs.first.data()));
  }

  /// Liga/desliga o prestador. Offline (active=false) sai da busca
  /// imediatamente, pois providersStream filtra por active == true.
  static Future<void> setProviderOnline(String providerId, bool online) =>
      _db.collection(Col.providers).doc(providerId).update({'active': online});

  static Stream<List<OrderModel>> providerOrdersStream(
      {List<OrderStatus>? statuses}) {
    Query q = _db
        .collection(Col.orders)
        .where('providerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);
    if (statuses != null && statuses.isNotEmpty) {
      q = q.where('status', whereIn: statuses.map((s) => s.name).toList());
    }
    return q.snapshots().map((s) => s.docs
        .map((d) => OrderModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  static Future<void> acceptOrder(String orderId, {double? price}) async {
    await _transition(orderId, 'accept', extra: {
      if (price != null) 'price': price,
    });
  }

  static Future<void> declineOrder(String orderId) async {
    await _transition(orderId, 'decline');
  }

  static Future<void> cancelOrder(String orderId) async {
    await _transition(orderId, 'cancel', extra: {'reason': 'Cancelado pelo cliente'});
  }

  static Future<void> startOrder(String orderId) async {
    await _transition(orderId, 'start');
  }

  /// Sala 1:1 com id canônico. Participantes são definidos só na
  /// criação (imutáveis pelas regras); não sobrescreve sala existente.
  static Future<String> getOrCreateRoom(String otherUserId) async {
    final me = _uid;
    if (me == null) {
      throw const CloudCallException('Faça login para conversar.',
          code: 'unauthenticated');
    }
    if (otherUserId.isEmpty || otherUserId == me) {
      throw const CloudCallException('Contato inválido.',
          code: 'invalid-argument');
    }
    final ids = [me, otherUserId]..sort();
    final id = ids.join('_');
    final ref = _db.collection(Col.chatRooms).doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set(
          {'participants': ids, 'createdAt': FieldValue.serverTimestamp()});
    }
    return id;
  }

  static Future<void> sendMessage(
      {required String roomId,
      required String senderName,
      required String text,
      String? mediaUrl,
      String? replyToText,
      String? replyToSender,
      String? orderId}) async {
    if (_uid == null) return;
    final batch = _db.batch();
    batch.set(
        _db
            .collection(Col.chatRooms)
            .doc(roomId)
            .collection(Col.messages)
            .doc(),
        {
          'senderId': _uid,
          'senderName': senderName,
          'text': text,
          'read': false,
          if (mediaUrl != null) 'mediaUrl': mediaUrl,
          if (replyToText != null) 'replyToText': replyToText,
          if (replyToSender != null) 'replyToSender': replyToSender,
          // Mensagem automática de pedido (o servidor não notifica de novo).
          if (orderId != null) 'orderId': orderId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    batch.set(
        _db.collection(Col.chatRooms).doc(roomId),
        {'lastMsg': text, 'lastMsgTime': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    await batch.commit();
  }

  // Apaga uma mensagem para todos: mantém o documento mas marca como
  // deletada (a UI mostra "mensagem apagada"), preservando a ordem.
  static Future<void> deleteMessageForAll(String roomId, String messageId) async {
    final room = _db.collection(Col.chatRooms).doc(roomId);
    final msgRef = room.collection(Col.messages).doc(messageId);
    final msg = (await msgRef.get()).data() ?? {};
    final batch = _db.batch()
      ..update(msgRef, {'deleted': true, 'text': '', 'mediaUrl': FieldValue.delete()});
    // A prévia da conversa não pode continuar mostrando o texto apagado.
    final last = (await room.get()).data()?['lastMsg'];
    if (last != null && last == msg['text']) batch.update(room, {'lastMsg': 'Mensagem apagada'});
    await batch.commit();
  }

  // Indicador "digitando...": grava/limpa o estado do usuário na sala.
  static Future<void> setTyping(String roomId, bool typing) {
    if (_uid == null) return Future.value();
    return _db
        .collection(Col.chatRooms)
        .doc(roomId)
        .set({'typing_$_uid': typing}, SetOptions(merge: true));
  }

  static Stream<bool> typingStream(String roomId, String otherUid) => _db
      .collection(Col.chatRooms)
      .doc(roomId)
      .snapshots()
      .map((s) => (s.data()?['typing_$otherUid'] as bool?) ?? false);

  // ── Upload de mídia (Vol.2/Vol.3: chat com fotos/vídeos/documentos) ─
  static Future<String?> uploadChatMedia(
      Uint8List bytes, String fileName, String roomId) async {
    if (_uid == null) return null;
    try {
      final ext = _extOf(fileName);
      final ref = FirebaseStorage.instance.ref().child(
          'chat_media/$roomId/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, _metaFor(fileName));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload de mídia falhou: $e');
      return null;
    }
  }

  // Upload de arquivos do cadastro de prestador. `photo` é pública e
  // retorna a download URL. `document`, `selfie` e `certificate` são
  // privados: retorna apenas o CAMINHO no Storage (o admin gera uma URL
  // temporária pela callable getVerificationFileUrl).
  static Future<String?> uploadProviderFile(
      Uint8List bytes, String fileName, String kind) async {
    if (_uid == null) return null;
    try {
      final ext = _extOf(fileName);
      final path =
          'providers/$_uid/$kind/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(bytes, _metaFor(fileName));
      if (kind == 'photo') return await ref.getDownloadURL();
      return path;
    } catch (e) {
      debugPrint('Upload de documento do prestador falhou: $e');
      return null;
    }
  }

  /// Admin: URL temporária para um documento privado de verificação.
  static Future<String?> verificationFileUrl(
      String providerId, String path) async {
    final r = await CloudFn.call(
        'getVerificationFileUrl', {'providerId': providerId, 'path': path});
    return r['url'] as String?;
  }

  static Stream<List<MessageModel>> messagesStream(String roomId) => _db
      .collection(Col.chatRooms)
      .doc(roomId)
      .collection(Col.messages)
      .orderBy('createdAt')
      .limitToLast(200)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => MessageModel.fromMap(d.id, d.data())).toList());

  // Marca como lidas todas as mensagens de outros remetentes na sala
  // (Vol.3: Chat — recibo de leitura ✓✓). Chamado ao abrir o chat.
  static Future<void> markMessagesRead(String roomId) async {
    if (_uid == null) return;
    final unread = await _db
        .collection(Col.chatRooms)
        .doc(roomId)
        .collection(Col.messages)
        .where('senderId', isNotEqualTo: _uid)
        .where('read', isEqualTo: false)
        .limit(400) // lote do Firestore tem limite de 500 escritas
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  static Stream<WalletModel?> walletStream() => _db
      .collection(Col.wallets)
      .doc(_uid)
      .snapshots()
      .map((s) => s.exists ? WalletModel.fromMap(s.data()!) : null);

  static Stream<List<TransactionModel>> txStream() => _db
      .collection(Col.transactions)
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(30)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList());

  static Future<bool> credit(double amount, String desc, String icon) async {
    // Crédito livre pelo client foi removido (fraude). Saldo só muda no
    // servidor: recarga (createWalletRecharge + startPayment), cashback e
    // repasse interno. Débito livre e saque também foram removidos.
    debugPrint(
        'FS.credit bloqueado no client ($amount / $desc). Use gateway/Functions.');
    return false;
  }

  static Future<bool> switchProfileType(String type) async {
    try {
      await CloudFn.call('switchProfileType', {'type': type});
      return true;
    } catch (e) {
      debugPrint('switchProfileType: $e');
      return false;
    }
  }

  static Future<bool> _walletOp({
    required String op,
    double? amount,
    String? description,
    String? icon,
    String? pixKey,
    String? orderId,
  }) async {
    if (_uid == null) return false;
    try {
      await CloudFn.call('walletOp', {
        'op': op,
        if (amount != null) 'amount': amount,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (pixKey != null) 'pixKey': pixKey,
        if (orderId != null) 'orderId': orderId,
      });
      return true;
    } catch (e) {
      debugPrint('walletOp error: $e');
      return false;
    }
  }

  static Future<void> saveReview(ReviewModel r) async {
    final reviewId = '${r.orderId}_${r.clientId}';
    await _db.collection(Col.reviews).doc(reviewId).set({
      'orderId': r.orderId,
      'clientId': r.clientId,
      'providerId': r.providerId,
      // Nome/foto do autor são preenchidos pelo servidor (perfil público).
      'stars': r.stars,
      'comment': r.comment,
      'tags': r.tags,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (r.orderId.isNotEmpty && r.orderId != 'demo') {
      await _db
          .collection(Col.orders)
          .doc(r.orderId)
          .update({'reviewed': true});
    }
  }

  static Future<void> pushNotif(
      String uid, String title, String body, String type) async {
    try {
      await CloudFn.call('createNotification', {
        'userId': uid,
        'title': title,
        'body': body,
        'type': type,
      });
    } catch (e) {
      debugPrint('createNotification error: $e');
    }
  }

  /// Marca todas as não lidas como lidas (lotes de até 400).
  static Future<int> markAllNotifsRead() async {
    if (_uid == null) return 0;
    final q = await _db
        .collection(Col.notifications)
        .where('userId', isEqualTo: _uid)
        .where('read', isEqualTo: false)
        .limit(400)
        .get();
    if (q.docs.isEmpty) return 0;
    final b = _db.batch();
    for (final d in q.docs) {
      b.update(d.reference, {'read': true});
    }
    await b.commit();
    return q.size;
  }

  static Stream<List<NotifModel>> notifStream() => _db
      .collection(Col.notifications)
      .where('userId', isEqualTo: _uid)
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => NotifModel.fromMap(d.id, d.data())).toList());

  static Future<void> markNotifRead(String id) =>
      _db.collection(Col.notifications).doc(id).update({'read': true});

  /// Cupons não são legíveis pelo client: validação via callable.
  static Future<CouponModel?> validateCoupon(String code) async {
    try {
      final r = await CloudFn.call(
          'checkCoupon', {'code': code.trim().toUpperCase()});
      return couponFromCheck(r);
    } catch (e) {
      debugPrint('checkCoupon: $e');
      return null;
    }
  }

  /// Valida o cupom e devolve o motivo da recusa quando o servidor informa
  /// (ex.: limite de usos atingido).
  static Future<({CouponModel? coupon, String? reason})> checkCoupon(
      String code) async {
    try {
      final r = await CloudFn.call(
          'checkCoupon', {'code': code.trim().toUpperCase()});
      return (coupon: couponFromCheck(r), reason: couponRejectReason(r));
    } on CloudCallException catch (e) {
      return (coupon: null, reason: e.message);
    } catch (e) {
      debugPrint('checkCoupon: $e');
      return (coupon: null, reason: null);
    }
  }

  static String? couponRejectReason(Map<String, dynamic> r) {
    if (r['valid'] == true) return null;
    final reason = (r['reason'] as String?)?.trim();
    return reason == null || reason.isEmpty ? null : reason;
  }

  /// Converte a resposta de `checkCoupon` (null se inválido).
  static CouponModel? couponFromCheck(Map<String, dynamic> r) {
    if (r['valid'] != true) return null;
    final ms = (r['expiresAtMs'] as num?)?.toInt();
    final minValue = (r['minValue'] as num?)?.toDouble();
    return CouponModel(
      id: (r['code'] ?? '').toString(),
      code: (r['code'] ?? '').toString(),
      description: (r['description'] ?? '').toString(),
      discount: (r['discount'] as num?)?.toDouble() ?? 0,
      isPercentage: r['isPercentage'] != false,
      minValue: minValue != null && minValue > 0 ? minValue : null,
      // Sem validade definida: trata como vigente.
      expiresAt: ms != null
          ? DateTime.fromMillisecondsSinceEpoch(ms)
          : DateTime.now().add(const Duration(days: 3650)),
    );
  }

  static Stream<Map<String, dynamic>?> gpsStream(String id) =>
      _db.collection(Col.deliveries).doc(id).snapshots().map((s) => s.data());

  // ── Saúde (Fase 5): agenda real no servidor ────────────────────
  /// Versão do termo de consentimento para dados de saúde (LGPD art. 11).
  static const healthConsentVersion = '2026-10';

  static Future<Map<String, dynamic>> healthSlots(
          {required String providerId, required String catalogId, required String date}) =>
      CloudFn.call('listHealthSlots', {'providerId': providerId, 'catalogId': catalogId, 'date': date});

  /// Agenda pelo servidor (profissional, especialidade, horário real e
  /// consentimento). Idempotente por [requestId].
  /// Devolve {id, reused, startMs, status, holdUntilMs, totalCents}. Com
  /// `status == 'pending_payment'` o horário fica retido até holdUntilMs.
  static Future<Map<String, dynamic>> bookHealthAppointment({
    required String requestId,
    required String providerId,
    required String catalogId,
    required int startMs,
    required String modality,
    String? reason,
    String? address,
  }) async {
    final r = await CloudFn.call('bookHealthAppointment', {
      'requestId': requestId,
      'providerId': providerId,
      'catalogId': catalogId,
      'startMs': startMs,
      'modality': modality,
      'consentVersion': healthConsentVersion,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
    });
    return r;
  }

  static Future<void> healthAppointmentAction(String id, String action,
          {String? reason, int? newStartMs}) =>
      CloudFn.call('healthAppointmentAction', {
        'appointmentId': id,
        'action': action,
        if (reason != null) 'reason': reason,
        if (newStartMs != null) 'newStartMs': newStartMs,
      });

  /// Agendamentos do usuário como paciente ([asProvider] = como profissional).
  static Stream<List<Map<String, dynamic>>> appointmentsStream({bool asProvider = false}) {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.appointments)
        .where(asProvider ? 'providerId' : 'clientId', isEqualTo: _uid)
        .orderBy('startMs', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Future<Map<String, dynamic>?> appointmentClinical(String id) async {
    final s = await _db.collection(Col.appointments).doc(id).collection('private').doc('clinical').get();
    return s.data();
  }

  static Future<Map<String, dynamic>?> myHealthSchedule() async {
    if (_uid == null) return null;
    return (await _db.collection('healthSchedules').doc(_uid).get()).data();
  }

  static Future<void> saveHealthSchedule(Map<String, dynamic> data) =>
      _db.collection('healthSchedules').doc(_uid).set({...data, 'updatedAt': FieldValue.serverTimestamp()});

  /// Abre um chamado e devolve o id (para abrir a conversa em seguida).
  static Future<String> createSupportTicket(String subject, String message) async {
    // Nome para a equipe saber com quem fala (antes ia vazio).
    final me = _uid == null ? null : (await _db.collection(Col.users).doc(_uid).get()).data();
    final ref = await _db.collection(Col.support).add({
      'userId': _uid,
      'userName': ((me?['name'] as String?) ?? FirebaseAuth.instance.currentUser?.displayName ?? '').trim(),
      'subject': subject,
      'message': message,
      'status': 'open',
      'priority': 'normal',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// "Meus chamados" do usuário logado (mais recentes primeiro).
  static Stream<List<TicketModel>> myTicketsStream() {
    if (_uid == null) return Stream.value(const []);
    return _db
        .collection(Col.support)
        .where('userId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((s) => s.docs.map((d) => TicketModel.fromMap(d.id, d.data())).toList());
  }

  static Stream<TicketModel?> ticketStream(String id) => _db
      .collection(Col.support)
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? TicketModel.fromMap(d.id, d.data()!) : null);

  static Stream<List<TicketMessage>> ticketMessagesStream(String ticketId) => _db
      .collection(Col.support)
      .doc(ticketId)
      .collection(Col.messages)
      .orderBy('createdAt')
      .limit(300)
      .snapshots()
      .map((s) => s.docs.map((d) => TicketMessage.fromMap(d.id, d.data())).toList());

  /// Dono abriu a conversa: limpa o "não lido" (callable markTicketRead).
  static Future<void> markTicketRead(String ticketId) async {
    await CloudFn.call('markTicketRead', {'ticketId': ticketId});
  }

  /// Resposta no chamado. As regras exigem exatamente estes campos e
  /// createdAt do servidor; o papel 'support' só vale para admin.
  static Future<void> sendTicketMessage(String ticketId, String text,
      {bool asSupport = false}) async {
    if (_uid == null) {
      throw const CloudCallException('Faça login para responder.', code: 'unauthenticated');
    }
    await _db.collection(Col.support).doc(ticketId).collection(Col.messages).add({
      'authorId': _uid,
      'authorRole': asSupport ? 'support' : 'user',
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Companies (Vol.5: coleção companies) ──────────────────────
  static Future<void> saveCompany(CompanyModel c) => _db
      .collection(Col.companies)
      .doc(c.id)
      .set(c.toMap(), SetOptions(merge: true));

  static Future<CompanyModel?> getCompanyByOwner(String ownerId) async {
    final q = await _db
        .collection(Col.companies)
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (q.docs.isEmpty) return null;
    return CompanyModel.fromMap(q.docs.first.id, q.docs.first.data());
  }

  static Stream<CompanyModel?> companyStream(String id) => _db
      .collection(Col.companies)
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? CompanyModel.fromMap(s.id, s.data()!) : null);

  // ── Equipe da empresa (Vol.15: Empresas — Funcionários) ────────
  static Future<void> addEmployee(
      {required String companyId,
      required String name,
      required String role,
      String? email,
      String? phone}) async {
    await _db.collection(Col.employees).add({
      'companyId': companyId,
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db
        .collection(Col.companies)
        .doc(companyId)
        .update({'teamSize': FieldValue.increment(1)});
  }

  static Future<void> removeEmployee(String id, String companyId) async {
    await _db.collection(Col.employees).doc(id).delete();
    await _db
        .collection(Col.companies)
        .doc(companyId)
        .update({'teamSize': FieldValue.increment(-1)});
  }

  static Stream<List<EmployeeModel>> employeesStream(String companyId) => _db
      .collection(Col.employees)
      .where('companyId', isEqualTo: companyId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => EmployeeModel.fromMap(d.id, d.data())).toList());

  // ── Filiais da empresa (Vol.15: Empresas — Filiais) ────────────
  static Future<void> addBranch(
          {required String companyId,
          required String name,
          required String address,
          required String city,
          required String state,
          String? phone}) =>
      _db.collection(Col.branches).add({
        'companyId': companyId,
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'phone': phone,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> removeBranch(String id) =>
      _db.collection(Col.branches).doc(id).delete();

  // ── Marketplace: lojas e produtos (Vol.12) ─────────────────────
  // Empresas cadastram uma loja e anunciam produtos. Carrinho, pedidos,
  // cupons, favoritos e avaliações já existentes são reaproveitados.

  /// Cria ou atualiza a loja do usuário logado. Retorna o id da loja.
  /// Campos de reputação/comissão: só o servidor altera.
  static Map<String, dynamic> stripServerFields(Map<String, dynamic> m) =>
      Map<String, dynamic>.from(m)
        ..remove('rating')
        ..remove('totalReviews')
        ..remove('verified')
        ..remove('commissionRate');

  static Future<String?> saveStore(StoreModel store) async {
    if (_uid == null) return null;
    final data = stripServerFields({...store.toMap(), 'ownerId': _uid});
    if (store.id.isEmpty) {
      final doc = await _db
          .collection(Col.stores)
          .add({...data, 'createdAt': FieldValue.serverTimestamp()});
      return doc.id;
    }
    await _db
        .collection(Col.stores)
        .doc(store.id)
        .set(data, SetOptions(merge: true));
    return store.id;
  }

  /// Frete/modos de entrega (usados pelo servidor no cálculo do pedido).
  static Future<bool> updateStoreDelivery(String storeId,
      {required int deliveryFeeCents,
      required bool deliveryEnabled,
      required bool pickupEnabled}) async {
    try {
      await _db.collection(Col.stores).doc(storeId).update({
        'deliveryFeeCents': deliveryFeeCents,
        'deliveryEnabled': deliveryEnabled,
        'pickupEnabled': pickupEnabled,
      });
      return true;
    } catch (e) {
      debugPrint('updateStoreDelivery: $e');
      return false;
    }
  }

  /// Loja do usuário logado (null se ainda não cadastrou).
  static Stream<StoreModel?> myStoreStream() {
    if (_uid == null) return Stream.value(null);
    return _db
        .collection(Col.stores)
        .where('ownerId', isEqualTo: _uid)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty
            ? null
            : StoreModel.fromMap(s.docs.first.id, s.docs.first.data()));
  }

  /// Envia logo ou banner da loja para o Storage e grava a URL.
  /// [kind] deve ser 'logo' ou 'banner'.
  static Future<String?> uploadStoreImage(
      String storeId, Uint8List bytes, String fileName, String kind) async {
    if (_uid == null) return null;
    try {
      final ext = _extOf(fileName);
      final ref = FirebaseStorage.instance.ref().child(
          'stores/$storeId/$kind/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, _metaFor(fileName));
      final url = await ref.getDownloadURL();
      await _db.collection(Col.stores).doc(storeId).set(
          {kind == 'logo' ? 'logoUrl' : 'bannerUrl': url},
          SetOptions(merge: true));
      return url;
    } catch (e) {
      debugPrint('Upload de imagem da loja falhou: $e');
      return null;
    }
  }

  // ── Locação: veículos e máquinas (Vol.13) ──────────────────────
  /// Cria ou atualiza um anúncio de locação do usuário logado.
  static Future<String?> saveRental(RentalModel r) async {
    if (_uid == null) return null;
    final data = stripServerFields({...r.toMap(), 'ownerId': _uid});
    if (r.id.isEmpty) {
      final doc = await _db
          .collection(Col.rentals)
          .add({...data, 'createdAt': FieldValue.serverTimestamp()});
      return doc.id;
    }
    await _db
        .collection(Col.rentals)
        .doc(r.id)
        .set(data, SetOptions(merge: true));
    return r.id;
  }

  static Future<void> removeRental(String id) =>
      _db.collection(Col.rentals).doc(id).delete();

  static Future<void> setRentalAvailability(String id, bool available) =>
      _db.collection(Col.rentals).doc(id).update({'available': available});

  /// Anúncios ativos, opcionalmente filtrados por tipo e categoria.
  static Stream<List<RentalModel>> rentalsStream(
      {RentalKind? kind, String? category}) {
    Query<Map<String, dynamic>> q =
        _db.collection(Col.rentals).where('active', isEqualTo: true);
    if (kind != null)
      q = q.where('kind',
          isEqualTo: kind == RentalKind.machine ? 'machine' : 'vehicle');
    if (category != null) q = q.where('category', isEqualTo: category);
    return q.snapshots().map(
        (s) => s.docs.map((d) => RentalModel.fromMap(d.id, d.data())).toList());
  }

  /// Anúncios do próprio usuário (para gerenciar).
  static Stream<List<RentalModel>> myRentalsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.rentals)
        .where('ownerId', isEqualTo: _uid)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => RentalModel.fromMap(d.id, d.data())).toList());
  }

  // ── Reservas de locação (Fase 5: servidor) ─────────────────────
  static Future<Map<String, dynamic>> quoteRentalBooking(
          {required String rentalId, required String period, required int quantity, required int startMs}) =>
      CloudFn.call('quoteRentalBooking',
          {'rentalId': rentalId, 'period': period, 'quantity': quantity, 'startMs': startMs});

  /// Cria a reserva no servidor (preço, total, fim e sobreposição
  /// calculados lá). O anunciante é notificado por evento.
  /// Devolve {id, status: 'pending_payment', holdUntilMs, totalCents}.
  static Future<Map<String, dynamic>> createRentalBooking({
    required String requestId,
    required String rentalId,
    required String period,
    required int quantity,
    required int startMs,
    String? note,
  }) async {
    final r = await CloudFn.call('createRentalBooking', {
      'requestId': requestId,
      'rentalId': rentalId,
      'period': period,
      'quantity': quantity,
      'startMs': startMs,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return r;
  }

  static Future<void> transitionRentalBooking(String id, String action, {String? reason}) =>
      CloudFn.call('transitionRentalBooking',
          {'bookingId': id, 'action': action, if (reason != null) 'reason': reason});

  /// Períodos ocupados do anúncio (sem dados de quem reservou).
  static Future<List<({DateTime start, DateTime end, bool pending})>> rentalBusy(String rentalId) async {
    final r = await CloudFn.call('rentalAvailability', {'rentalId': rentalId});
    return ((r['busy'] as List?) ?? const [])
        .whereType<Map>()
        .map((m) => (
              start: DateTime.fromMillisecondsSinceEpoch((m['startMs'] as num).toInt()),
              end: DateTime.fromMillisecondsSinceEpoch((m['endMs'] as num).toInt()),
              pending: m['status'] == 'pending' || m['status'] == 'pending_payment',
            ))
        .toList();
  }

  /// Reservas feitas pelo usuário (como locatário).
  static Stream<List<BookingModel>> myBookingsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.bookings)
        .where('clientId', isEqualTo: _uid)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList());
  }

  /// Reservas recebidas nos anúncios do usuário (como anunciante).
  static Stream<List<BookingModel>> receivedBookingsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.bookings)
        .where('ownerId', isEqualTo: _uid)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList());
  }

  /// Envia uma foto do anúncio e devolve a URL.
  static Future<String?> uploadRentalPhoto(
      String rentalId, Uint8List bytes, String fileName) async {
    if (_uid == null) return null;
    try {
      final ext = _extOf(fileName);
      // Pasta do dono: o anúncio novo ainda não existe no Firestore, então
      // a regra não consegue checar rentals/{id} (upload era sempre negado).
      final ref = FirebaseStorage.instance.ref().child(
          'rentalPhotos/$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putData(bytes, _metaFor(fileName));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload de foto do anúncio falhou: $e');
      return null;
    }
  }

  static Stream<List<StoreModel>> storesStream({String? category}) {
    Query<Map<String, dynamic>> q =
        _db.collection(Col.stores).where('active', isEqualTo: true);
    if (category != null) q = q.where('categories', arrayContains: category);
    return q.snapshots().map(
        (s) => s.docs.map((d) => StoreModel.fromMap(d.id, d.data())).toList());
  }

  static Future<String?> saveProduct(ProductModel p) async {
    if (_uid == null) return null;
    final data = stripServerFields(p.toMap());
    if (p.id.isEmpty) {
      final doc = await _db
          .collection(Col.products)
          .add({...data, 'createdAt': FieldValue.serverTimestamp()});
      await _db
          .collection(Col.stores)
          .doc(p.storeId)
          .update({'totalProducts': FieldValue.increment(1)});
      return doc.id;
    }
    await _db
        .collection(Col.products)
        .doc(p.id)
        .set(data, SetOptions(merge: true));
    return p.id;
  }

  static Future<void> removeProduct(String productId, String storeId) async {
    await _db.collection(Col.products).doc(productId).delete();
    await _db
        .collection(Col.stores)
        .doc(storeId)
        .update({'totalProducts': FieldValue.increment(-1)});
  }


  static Stream<List<ProductModel>> productsStream(
      {String? storeId, String? category}) {
    Query<Map<String, dynamic>> q =
        _db.collection(Col.products).where('active', isEqualTo: true);
    if (storeId != null) q = q.where('storeId', isEqualTo: storeId);
    if (category != null) q = q.where('category', isEqualTo: category);
    return q.snapshots().map((s) =>
        s.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
  }

  static Stream<List<BranchModel>> branchesStream(String companyId) => _db
      .collection(Col.branches)
      .where('companyId', isEqualTo: companyId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => BranchModel.fromMap(d.id, d.data())).toList());

  // ── Contratos da empresa (Vol.15: Empresas — Contratos) ────────
  static Future<void> createContract({
    required String companyId,
    required String clientName,
    required String title,
    String description = '',
    required double value,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _db.collection(Col.contracts).add({
        'companyId': companyId,
        'clientName': clientName,
        'title': title,
        'description': description,
        'value': value,
        'status': 'draft',
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'createdAt': FieldValue.serverTimestamp(),
      });

  static Future<void> updateContractStatus(String id, ContractStatus status) =>
      _db.collection(Col.contracts).doc(id).update({'status': status.name});

  static Stream<List<ContractModel>> contractsStream(String companyId) => _db
      .collection(Col.contracts)
      .where('companyId', isEqualTo: companyId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => ContractModel.fromMap(d.id, d.data())).toList());

  // ── Admin: usuários e pedidos ──────────────────────────────────
  static Stream<QuerySnapshot> adminUsersStream({int limit = 50}) => _db
      .collection(Col.users)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();
  static Stream<QuerySnapshot> adminOrdersStream({int limit = 50}) => _db
      .collection(Col.orders)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots();
  static Stream<QuerySnapshot> pendingProvidersStream() => _db
      .collection(Col.providers)
      .where('verified', isEqualTo: false)
      .snapshots();
  static Stream<QuerySnapshot> pendingCompaniesStream() => _db
      .collection(Col.companies)
      .where('verified', isEqualTo: false)
      .snapshots();

  // Dashboard KPIs em tempo real (Vol.6: usuários ativos, novos
  // cadastros, faturamento, serviços concluídos). Usa .count() do
  // Firestore, que agrega no servidor sem baixar os documentos.
  static Future<Map<String, dynamic>> fetchDashboardKpis() async {
    try {
      final usersCount = await _db.collection(Col.users).count().get();
      final providersCount = await _db
          .collection(Col.providers)
          .where('verified', isEqualTo: true)
          .count()
          .get();
      final completedOrders = await _db
          .collection(Col.orders)
          .where('status', isEqualTo: 'completed')
          .get();
      final revenue = completedOrders.docs.fold<double>(
          0, (sum, d) => sum + ((d.data()['price'] as num?)?.toDouble() ?? 0));
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final newUsers = await _db
          .collection(Col.users)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .count()
          .get();
      return {
        'totalUsers': usersCount.count ?? 0,
        'totalProviders': providersCount.count ?? 0,
        'revenue': revenue,
        'completedOrders': completedOrders.docs.length,
        'newUsersThisWeek': newUsers.count ?? 0,
      };
    } catch (e) {
      // Sem zeros falsos: a tela mostra que os números não carregaram.
      debugPrint('Erro ao buscar KPIs do dashboard: $e');
      rethrow;
    }
  }

  // Relatório financeiro real (Vol.6: Financeiro — comissões,
  // repasses, saques, estornos, assinaturas). Agrega orders (receita
  // bruta, comissão) e transactions (PIX, estornos).
  static Future<Map<String, dynamic>> fetchFinancialReport() async {
    try {
      final completed = await _db
          .collection(Col.orders)
          .where('status', isEqualTo: 'completed')
          .get();
      final grossRevenue = completed.docs.fold<double>(
          0, (sum, d) => sum + ((d.data()['price'] as num?)?.toDouble() ?? 0));
      // Comissão de cada pedido: a registrada no repasse; senão a taxa
      // gravada no pedido (financeTerms); pedidos antigos sem registro: 15%.
      final commission = completed.docs.fold<double>(0, (sum, d) {
        final m = d.data();
        final price = (m['price'] as num?)?.toDouble() ?? 0;
        final recorded = (m['commission'] as num?)?.toDouble();
        final bps = (m['financeTerms'] as Map?)?['commissionBps'] as num?;
        return sum + (recorded ?? (bps != null ? price * bps / 10000 : price * AppConst.commission));
      });
      final netToProviders = grossRevenue - commission;

      // Reembolsos confirmados (coleção refunds, em centavos). Antes lia um
      // campo de pedido que nada grava, e o total ficava sempre em R$ 0.
      final refundAgg = await _db
          .collection('refunds')
          .where('status', isEqualTo: 'approved')
          .aggregate(sum('amountCents'))
          .get();
      final refunds = (refundAgg.getSum('amountCents') ?? 0) / 100;

      // Recargas confirmadas (Fase 3: tipo 'recharge', em centavos).
      final pixTx = await _db
          .collection(Col.transactions)
          .where('type', isEqualTo: 'recharge')
          .get();
      final pixTotal = pixTx.docs.fold<double>(0, (sum, d) {
        final m = d.data();
        final c = (m['amountCents'] as num?)?.toDouble();
        return sum + (c != null ? c / 100 : ((m['amount'] as num?)?.toDouble() ?? 0));
      });

      return {
        'grossRevenue': grossRevenue,
        'commission': commission,
        'netToProviders': netToProviders,
        'pixProcessed': pixTotal,
        'refunds': refunds,
        'completedCount': completed.docs.length,
      };
    } catch (e) {
      debugPrint('Erro ao buscar relatório financeiro: $e');
      rethrow;
    }
  }

  // Suspensão no servidor: desativa o Auth, revoga tokens e grava status.
  static Future<void> suspendUser(String uid, {String? adminName}) async {
    // A auditoria é gravada pelo servidor (antes ficava em dobro).
    await CloudFn.call('setUserSuspended', {'userId': uid, 'suspended': true});
  }

  static Future<void> reactivateUser(String uid, {String? adminName}) async {
    await CloudFn.call('setUserSuspended', {'userId': uid, 'suspended': false});
  }

  static Future<void> approveCompany(String id, {String? adminName}) async {
    await _db
        .collection(Col.companies)
        .doc(id)
        .update({'verified': true, 'active': true});
    await logAdminAction('Aprovou empresa', target: id, adminName: adminName);
  }

  // ── Admin: marketing / banners (Vol.6) ─────────────────────────
  static Future<void> saveBanner(Map<String, dynamic> data,
      {String? id}) async {
    if (id != null) {
      await _db
          .collection(Col.banners)
          .doc(id)
          .set(data, SetOptions(merge: true));
    } else {
      await _db
          .collection(Col.banners)
          .add({...data, 'createdAt': FieldValue.serverTimestamp()});
    }
  }

  static Future<void> deleteBanner(String id) =>
      _db.collection(Col.banners).doc(id).delete();
  static Stream<List<BannerModel>> bannersStream() => _db
      .collection(Col.banners)
      .where('active', isEqualTo: true)
      .orderBy('order')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => BannerModel.fromMap(d.id, d.data())).toList());
  static Stream<QuerySnapshot> adminBannersStream() =>
      _db.collection(Col.banners).orderBy('order').snapshots();

  static Future<void> createCoupon(Map<String, dynamic> data) =>
      _db.collection(Col.coupons).add(
          {...data, 'active': true, 'createdAt': FieldValue.serverTimestamp()});
  static Stream<QuerySnapshot> adminCouponsStream() => _db
      .collection(Col.coupons)
      .orderBy('createdAt', descending: true)
      .snapshots();

  // ── Admin: atendimento / tickets (Vol.6) ───────────────────────
  static Stream<List<TicketModel>> adminTicketsStream({String? status}) {
    Query q =
        _db.collection(Col.support).orderBy('createdAt', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status);
    return q.snapshots().map((s) => s.docs
        .map((d) => TicketModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  static Future<void> updateTicketStatus(String id, String status,
      {String? adminName}) async {
    await _db.collection(Col.support).doc(id).update({'status': status});
    await logAdminAction('Atualizou chamado',
        target: id, adminName: adminName, details: {'status': status});
  }

  // ── Denúncias (Vol.20: Administração) ──────────────────────────
  // Qualquer usuário pode denunciar outro (prestador, cliente ou
  // conteúdo). O admin modera pelo painel (ver reportsStream abaixo).
  static Future<void> createReport({
    required String targetId,
    required String targetName,
    required String reason,
    String details = '',
  }) async {
    if (_uid == null) return;
    final me = await getUser();
    await _db.collection(Col.reports).add({
      'reporterId': _uid,
      'reporterName': me?.name ?? 'Usuário',
      'targetId': targetId,
      'targetName': targetName,
      'reason': reason,
      'details': details,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<ReportModel>> reportsStream({ReportStatus? status}) {
    Query q =
        _db.collection(Col.reports).orderBy('createdAt', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.snapshots().map((s) => s.docs
        .map((d) => ReportModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  static Future<void> updateReportStatus(String id, ReportStatus status,
      {String? adminName}) async {
    await _db.collection(Col.reports).doc(id).update({'status': status.name});
    await logAdminAction('Atualizou denúncia',
        target: id, adminName: adminName, details: {'status': status.name});
  }

  // ── Auditoria (Vol.6: toda ação crítica registrada) ────────────
  static Future<void> logAdminAction(String action,
          {required String target,
          String? adminName,
          Map<String, dynamic>? details}) =>
      _db.collection(Col.auditLogs).add({
        'adminId': _uid,
        'adminName': adminName ?? 'Admin',
        'action': action,
        'target': target,
        'details': details ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });

  // ── Configurações gerais da plataforma (Vol.20: Administração) ──
  // Documento único em config/platform. Lido pelo app inteiro (ex.:
  // AppConst.commission é o valor padrão de fallback caso este
  // documento ainda não exista) e editável apenas pelo admin.
  static Stream<Map<String, dynamic>> platformConfigStream() =>
      _db.collection('config').doc('platform').snapshots().map((d) =>
          d.data() ??
          {
            'commissionRate': AppConst.commission,
            'maintenanceMode': false,
          });

  /// Contato do suporte (config/platform). Sem contato configurado volta
  /// vazio: a tela orienta a abrir um chamado (nada de contato inventado).
  static Future<({String? email, String? phone})> supportContact() async {
    try {
      final d = (await _db.collection('config').doc('platform').get()).data();
      final email = (d?['supportEmail'] as String?)?.trim() ?? '';
      final phone = (d?['supportPhone'] as String?)?.trim() ?? '';
      return (
        email: email.isNotEmpty ? email : null,
        phone: phone.isNotEmpty ? phone : null,
      );
    } catch (e) {
      debugPrint('supportContact: $e');
      return (email: null, phone: null);
    }
  }

  /// Reservas (B15): prazo de retenção e limite de pendentes por cliente.
  static Stream<Map<String, dynamic>> bookingConfigStream() => _db
      .collection('config')
      .doc('booking')
      .snapshots()
      .map((d) => d.data() ?? const {});

  static Future<void> updateBookingConfig(
          {required int holdMinutes, required int maxPendingPerClient}) =>
      CloudFn.call('updateBookingConfig', {
        'holdMinutes': holdMinutes,
        'maxPendingPerClient': maxPendingPerClient,
      });

  static Future<void> updatePlatformConfig(Map<String, dynamic> data,
      {String? adminName}) async {
    await _db.collection('config').doc('platform').set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
    await logAdminAction('Atualizou configurações da plataforma',
        target: 'platform', adminName: adminName, details: data);
  }

  static Stream<List<AuditLogModel>> auditLogStream({int limit = 100}) => _db
      .collection(Col.auditLogs)
      .orderBy('timestamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) =>
          s.docs.map((d) => AuditLogModel.fromMap(d.id, d.data())).toList());

  // ── Favoritos (Vol.2/Vol.5: coleção favorites) ─────────────────
  static Future<bool> toggleFavorite(String providerId) async {
    if (_uid == null) return false;
    final ref = _db.collection(Col.favorites).doc('${_uid}_$providerId');
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      return false;
    } else {
      await ref.set({
        'userId': _uid,
        'providerId': providerId,
        'createdAt': FieldValue.serverTimestamp()
      });
      return true;
    }
  }

  static Stream<bool> isFavoriteStream(String providerId) => _db
      .collection(Col.favorites)
      .doc('${_uid}_$providerId')
      .snapshots()
      .map((s) => s.exists);

  /// Favoritos de produto não têm providerId: ignora esses documentos.
  static List<String> favoriteProviderIds(
          Iterable<Map<String, dynamic>> docs) =>
      docs
          .map((m) => m['providerId'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

  static Stream<List<ProviderModel>> favoritesStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.favorites)
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .asyncMap((favSnap) async {
      final providerIds = favoriteProviderIds(favSnap.docs.map((d) => d.data()));
      if (providerIds.isEmpty) return <ProviderModel>[];
      final providers = <ProviderModel>[];
      for (final id in providerIds) {
        final doc = await _db.collection(Col.providers).doc(id).get();
        if (doc.exists)
          providers.add(ProviderModel.fromMap(doc.id, doc.data()!));
      }
      return providers;
    });
  }

  // ── Favoritos de produtos (Vol.12: Marketplace) ────────────────
  // Usa o mesmo padrão dos favoritos de prestador, mas com prefixo
  // próprio no id do documento para não colidir e permitir listar
  // separadamente. Como os produtos do Marketplace ainda vivem numa
  // lista estática no client (não há coleção `products` no Firestore
  // ainda), aqui expomos só o conjunto de IDs favoritados; a tela
  // filtra a lista local por esses IDs.
  static Future<bool> toggleProductFavorite(String productId) async {
    if (_uid == null) return false;
    final ref = _db.collection(Col.favorites).doc('${_uid}_product_$productId');
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
      return false;
    } else {
      await ref.set({
        'userId': _uid,
        'productId': productId,
        'createdAt': FieldValue.serverTimestamp()
      });
      return true;
    }
  }

  static Stream<bool> isProductFavoriteStream(String productId) => _db
      .collection(Col.favorites)
      .doc('${_uid}_product_$productId')
      .snapshots()
      .map((s) => s.exists);

  static Stream<Set<String>> favoriteProductIdsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.favorites)
        .where('userId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs
            .map((d) => d.data()['productId'])
            .whereType<String>()
            .toSet());
  }

  // ── Histórico de pedidos do cliente (Vol.3: Perfil do Cliente) ──
  static Stream<List<OrderModel>> orderHistoryStream({OrderStatus? status}) {
    Query q = _db
        .collection(Col.orders)
        .where('clientId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true);
    if (status != null) q = q.where('status', isEqualTo: status.name);
    return q.snapshots().map((s) => s.docs
        .map((d) => OrderModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  // Cashback = 2% — taxa aplicada na Cloud Function walletOp.
  static Future<void> grantCashback(String orderId) async {
    await _walletOp(op: 'cashback', orderId: orderId);
  }

  // ── Resolve Carajás ─────────────────────────────────────────
  // A solicitação não é pública. Endereço/contato ficam em
  // resolveRequests/{id}/private/details (cliente, admin e prestador
  // escolhido). Prestadores compatíveis são notificados por evento no
  // servidor (onResolveRequestCreated) — falha de push não afeta o envio.
  /// Cria a solicitação pela callable (valida questionário e anexos no
  /// servidor). Idempotente: repetir com o mesmo [requestId] devolve a
  /// mesma solicitação.
  static Future<String> createResolveRequest({
    required String requestId,
    required String description,
    required String category,
    required String city,
    String modality = 'presential',
    String? preferredDate,
    String preferredPeriod = 'any',
    Map<String, double>? geo,
    String? address,
    String? phone,
    Map<String, Object?> answers = const {},
  }) async {
    if (_uid == null) {
      throw const CloudCallException('Faça login para pedir orçamento.',
          code: 'unauthenticated');
    }
    final r = await CloudFn.call('createResolveRequest', {
      'requestId': requestId,
      'description': description,
      'category': category,
      'city': city,
      'modality': modality,
      if (preferredDate != null) 'preferredDate': preferredDate,
      'preferredPeriod': preferredPeriod,
      if (geo != null) 'geo': geo,
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'answers': answers,
    });
    return (r['id'] ?? '').toString();
  }

  /// Envia um anexo do questionário para a pasta privada do usuário.
  /// Retorna o caminho no Storage (o servidor valida tipo e tamanho).
  static Future<String?> uploadResolveAttachment(
      Uint8List bytes, String fileName) async {
    if (_uid == null) return null;
    final ext = _extOf(fileName);
    if (!['jpg', 'jpeg', 'png', 'webp', 'pdf'].contains(ext)) return null;
    final path =
        'resolveUploads/$_uid/${DateTime.now().microsecondsSinceEpoch}/anexo.$ext';
    await FirebaseStorage.instance.ref(path).putData(bytes, _metaFor(fileName));
    return path;
  }

  static Future<Map<String, dynamic>?> resolveQuestionnaire(String id) async {
    final s = await _db.collection('serviceQuestionnaires').doc(id).get();
    if (!s.exists || s.data()?['status'] != 'published') return null;
    return {'id': s.id, ...s.data()!};
  }

  static Future<void> cancelResolveRequest(String requestId) =>
      CloudFn.call('cancelResolveRequest', {'requestId': requestId});

  static Future<String?> resolveAttachmentUrl(String requestId, int index) async {
    final r = await CloudFn.call(
        'getResolveAttachmentUrl', {'requestId': requestId, 'index': index});
    return r['url'] as String?;
  }

  static Stream<List<ResolveRequest>> myResolveRequestsStream() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection(Col.resolveRequests)
        .where('clientId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ResolveRequest.fromMap(d.id, d.data()))
            .toList());
  }

  static Stream<ResolveRequest?> resolveRequestStream(String id) => _db
      .collection(Col.resolveRequests)
      .doc(id)
      .snapshots()
      .map((s) =>
          s.exists ? ResolveRequest.fromMap(s.id, s.data()!) : null);

  /// Oportunidades para o prestador logado, filtradas no servidor por
  /// aprovação, conta ativa, serviço e região (sem endereço/contato).
  static Future<ResolveOpportunities> resolveOpportunities() async {
    final r = await CloudFn.call('listResolveOpportunities');
    final items = (r['items'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => ResolveOpportunity.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    return ResolveOpportunities(
        eligible: r['eligible'] == true,
        reason: r['reason'] as String?,
        items: items);
  }

  /// Proposta validada no servidor (prestador elegível, solicitação
  /// aberta, sem duplicidade). Nome/foto/nota vêm do perfil no servidor.
  static Future<String> submitResolveProposal({
    required String requestId,
    required double price,
    required int deadlineDays,
    String? message,
  }) async {
    final r = await CloudFn.call('submitResolveProposal', {
      'requestId': requestId,
      'price': price,
      'deadlineDays': deadlineDays,
      if (message != null) 'message': message,
    });
    return (r['id'] as String?) ?? '';
  }

  static Stream<List<ResolveProposal>> resolveProposalsStream(
          String requestId) =>
      _db
          .collection(Col.resolveProposals)
          .where('requestId', isEqualTo: requestId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs
              .map((d) => ResolveProposal.fromMap(d.id, d.data()))
              .toList());

  /// Aceite transacional no servidor: seleciona UMA proposta e cria o
  /// pedido operacional com chat, agenda e condições financeiras.
  /// Repetir devolve o mesmo pedido.
  static Future<Map<String, dynamic>> acceptResolveProposal({
    required String requestId,
    required String proposalId,
    // Valor exibido ao cliente: o servidor recusa se a proposta mudou.
    int? expectedPriceCents,
  }) =>
      CloudFn.call('acceptResolveProposal', {
        'requestId': requestId,
        'proposalId': proposalId,
        if (expectedPriceCents != null)
          'expectedPriceCents': expectedPriceCents,
      });

  static final Map<String, ({String name, String? photoUrl, String kind})> _pubCache = {};

  /// Nome/foto públicos de outra pessoa (publicProfiles, mantido pelo
  /// servidor). Nunca lê o perfil privado de terceiros.
  static Future<({String name, String? photoUrl, String kind})?> publicProfile(String uid) async {
    final cached = _pubCache[uid];
    if (cached != null) return cached;
    try {
      final s = await _db.collection('publicProfiles').doc(uid).get();
      final d = s.data();
      if (d == null) return null;
      final v = (name: (d['name'] as String?) ?? 'Usuário', photoUrl: d['photoUrl'] as String?, kind: (d['kind'] as String?) ?? 'client');
      _pubCache[uid] = v;
      return v;
    } catch (_) {
      return null;
    }
  }

  /// Nome do usuário logado para gravar em mensagens (nunca "Você").
  static Future<String> myDisplayName() async {
    final me = _uid;
    if (me == null) return 'Usuário';
    final p = await publicProfile(me);
    if (p != null && p.name.trim().isNotEmpty) return p.name;
    final n = AuthService.current?.displayName;
    return (n != null && n.trim().isNotEmpty) ? n : 'Usuário';
  }

  /// Lista salas do usuário autenticado (inbox unificado).
  static Stream<List<ChatRoomPreview>> chatRoomsStream() {
    if (_uid == null) return const Stream.empty();
    final me = _uid!;
    // Índice participants+lastMsgTime: as 50 conversas mais recentes.
    // Salas sem nenhuma mensagem (sem lastMsgTime) ficam de fora.
    return _db
        .collection(Col.chatRooms)
        .where('participants', arrayContains: me)
        .orderBy('lastMsgTime', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
      final out = <ChatRoomPreview>[];
      for (final d in snap.docs) {
        final data = d.data();
        final parts = List<String>.from(data['participants'] ?? []);
        final otherId = parts.firstWhere((p) => p != me, orElse: () => '');
        // Perfil público mínimo (o perfil em users/ é privado).
        String otherName = 'Usuário';
        String? otherPhoto;
        if (otherId.isNotEmpty) {
          final p = await publicProfile(otherId);
          if (p != null) {
            otherName = p.name;
            otherPhoto = p.photoUrl;
          }
        }
        out.add(ChatRoomPreview(
          id: d.id,
          otherUserId: otherId,
          otherName: otherName,
          otherPhoto: otherPhoto,
          lastMsg: (data['lastMsg'] as String?) ?? '',
          lastMsgTime: (data['lastMsgTime'] as Timestamp?)?.toDate(),
        ));
      }
      out.sort((a, b) {
        final ta = a.lastMsgTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = b.lastMsgTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return tb.compareTo(ta);
      });
      return out;
    });
  }
}

/// Callables autenticadas (região us-central1). Sem CORS aberto.
abstract final class CloudFn {
  static String get projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;
  static String get base =>
      'https://us-central1-$projectId.cloudfunctions.net';

  static FirebaseFunctions get _fn =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  static Future<Map<String, dynamic>> call(
      String name, [Map<String, dynamic>? data]) async {
    try {
      final result = await _fn.httpsCallable(name).call(data ?? {});
      final raw = result.data;
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return {'data': raw};
    } on FirebaseFunctionsException catch (e) {
      // Sessão inválida no servidor com usuário "logado" no app: expirou.
      if (e.code == 'unauthenticated' && AuthService.isAuth) {
        SessionGuard.instance.expired();
      }
      throw CloudCallException(e.message ?? 'Falha na operação',
          code: e.code);
    }
  }
}

class PaySvc {
  // Public Key do Mercado Pago via --dart-define=MERCADOPAGO_PUBLIC_KEY=...
  static String get _mpPublicKey => RuntimeConfig.mercadoPagoPublicKey;

  // ── Cartão de crédito (Vol.17: Pagamentos) ─────────────────────
  // Tokeniza o cartão direto com o Mercado Pago (nunca passa pelo
  // nosso backend em texto puro — exigência de PCI-DSS) e então
  // envia apenas o token para startPayment (Cloud Function) cobrar.
  static Future<String?> tokenizeCard({
    required String cardNumber,
    required String holderName,
    required String expMonth,
    required String expYear,
    required String cvv,
    required String docNumber,
  }) async {
    // Sem chave pública do gateway configurada, não tenta tokenizar.
    if (RuntimeConfig.hasPlaceholderMercadoPago) {
      debugPrint('Mercado Pago não configurado neste ambiente.');
      return null;
    }
    try {
      final r = await http
          .post(
            Uri.parse(
                'https://api.mercadopago.com/v1/card_tokens?public_key=$_mpPublicKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'card_number': cardNumber.replaceAll(' ', ''),
              'cardholder': {
                'name': holderName,
                'identification': {'type': 'CPF', 'number': docNumber}
              },
              'expiration_month': int.tryParse(expMonth) ?? 1,
              'expiration_year':
                  int.tryParse('20$expYear') ?? DateTime.now().year,
              'security_code': cvv,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200 || r.statusCode == 201)
        return (jsonDecode(r.body) as Map)['id'] as String?;
      debugPrint('Tokenização de cartão falhou: ${r.body}');
      return null;
    } catch (e) {
      debugPrint('Erro ao tokenizar cartão: $e');
      return null;
    }
  }

  static double fee(double amount) => amount * AppConst.commission;
  static String fmt(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
}

// ── Assistente de IA (Vol.28: IA e Automações) ────────────────
// Usa a Cloud Function `aiAssistant` (Claude API). Se o backend não
// estiver configurado ou a chamada falhar, retorna null e a tela de
// IA cai automaticamente no modo de respostas locais (fallback),
// garantindo que o assistente nunca trave para o usuário.
class AiSvc {
  static Future<String?> ask(
      String message, List<Map<String, dynamic>> history) async {
    try {
      final data = await CloudFn.call('aiAssistant', {
        'message': message,
        'history': history,
      });
      return data['reply'] as String?;
    } catch (e) {
      debugPrint('IA error: $e');
      return null;
    }
  }

  // ── Sugestão automática de descrição (Vol.11: IA) ──────────────
  // Usado em RequestServiceScreen: o cliente digita algumas palavras
  // soltas e a IA transforma em uma descrição profissional e clara
  // para o prestador entender o pedido.
  static Future<String?> suggestDescription(
      {required String category, required String draft}) async {
    if (draft.trim().isEmpty) return null;
    final prompt =
        'Reescreva a seguinte descrição de um pedido de serviço de $category de forma clara, '
        'profissional e objetiva, em no máximo 3 frases, sem inventar detalhes que não foram mencionados: "$draft"';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  // ── Sugestão de orçamento (Vol.11: IA) ──────────────────────────
  // Estima uma faixa de preço razoável com base na categoria e na
  // descrição do serviço, para orientar o cliente antes de negociar
  // com o prestador. Sempre deixa claro que é uma estimativa.
  static Future<String?> suggestBudget(
      {required String category, required String description}) async {
    final prompt =
        'Com base nesta descrição de serviço de $category: "$description", '
        'sugira uma faixa de preço razoável em reais para o mercado brasileiro atual. '
        'Responda em uma única frase curta, no formato "Entre R\$ X e R\$ Y", sem explicações adicionais.';
    final reply = await ask(prompt, const []);
    return reply?.trim();
  }

  // ── Busca inteligente (Vol.11: IA) ──────────────────────────────
  // Interpreta uma busca em linguagem natural (ex.: "preciso de
  // alguém pra consertar vazamento no banheiro amanhã") e devolve a
  // categoria mais próxima do catálogo do app, para pré-filtrar a
  // busca em vez do usuário navegar pelas categorias manualmente.
  static Future<String?> smartSearchCategory(
      String query, List<String> availableCategories) async {
    if (query.trim().isEmpty) return null;
    final prompt =
        'Dado o pedido do usuário: "$query", qual dessas categorias é a mais adequada? '
        'Responda APENAS com o nome exato de uma categoria da lista, nada mais: ${availableCategories.join(", ")}';
    final reply = await ask(prompt, const []);
    if (reply == null) return null;
    final cleaned = reply.trim().toLowerCase();
    return availableCategories
        .firstWhere((c) => cleaned.contains(c.toLowerCase()), orElse: () => '');
  }
}

class PushSvc {
  static Future<void> init() async {
    try {
      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('FCM permission: $e');
    }

    // Plugin nativo só via import condicional (stub no Web).
    // Sem google-services real / emulador, FCM pode falhar — nao derruba o app.
    if (!kIsWeb) {
      try {
        await initLocalNotificationsPlugin((_, __) {}, onTap: (payload) {
          try {
            if (payload != null) _open(Map<String, dynamic>.from(jsonDecode(payload) as Map));
          } catch (_) {}
        });
        FirebaseMessaging.onMessage.listen((msg) {
          if (msg.notification != null) {
            _show(msg.notification!.title ?? 'Carajás 360',
                msg.notification!.body ?? '', msg.data);
          }
        });
      } catch (e) {
        debugPrint('FCM/local notifications: $e');
      }
    }
    try {
      // Toque no aviso (app em segundo plano ou fechado) abre a tela certa.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _open(m.data));
      final first = await FirebaseMessaging.instance.getInitialMessage();
      if (first != null) _open(first.data);
      // Token trocado pelo sistema: atualiza para não perder avisos.
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        if (AuthService.isAuth) FS.updateFcmToken(t).catchError((_) {});
      });
    } catch (e) {
      debugPrint('FCM handlers: $e');
    }
  }

  /// Leva ao destino do aviso (mesmo mapa das notificações do app).
  static void _open(Map<String, dynamic> data) {
    final t = notificationTarget(data['type'] as String?, {
      if ((data['route'] ?? '') != '') 'route': data['route'],
      if ((data['id'] ?? '') != '') 'id': data['id'],
    });
    final nav = rootNavigatorKey.currentState;
    if (t == null || nav == null) return;
    if (!AuthService.isAuth) return; // a retomada pós-login cuida disso
    nav.pushNamed(t.route, arguments: t.args);
  }

  static Future<void> saveToken(String uid) async {
    try {
      final t = await FirebaseMessaging.instance.getToken();
      if (t != null) await FS.updateFcmToken(t);
    } catch (e) {
      debugPrint('FCM token: $e');
    }
  }

  /// Logout: tira o token do perfil e invalida o do aparelho.
  static Future<void> forget() async {
    try {
      if (AuthService.isAuth) await FS.clearFcmToken();
    } catch (e) {
      debugPrint('FCM clear: $e');
    }
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  static Future<void> _show(String title, String body, [Map<String, dynamic>? data]) async {
    if (kIsWeb) return;
    await showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: data == null || data.isEmpty ? null : jsonEncode(data),
    );
  }
}

