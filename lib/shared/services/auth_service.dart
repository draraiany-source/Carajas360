import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/auth/dev_bypass_auth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/security/order_policy.dart';
import '../../core/utils/firebase_bootstrap.dart';
import '../../core/utils/platform_info.dart';
import 'apple_sign_in.dart';
import 'cloud_fn.dart';

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

  /// Firebase Auth real. Nunca inventa um [User] no bypass.
  static User? get current {
    try {
      return _a.currentUser;
    } catch (_) {
      return null;
    }
  }

  static String? get uid {
    final real = current?.uid;
    if (real != null) return real;
    if (DevBypassAuth.enabled) return DevBypassAuth.uid;
    return null;
  }

  static bool get isAuth => current != null || DevBypassAuth.enabled;

  static Future<void> verifyPhone({
    required String phone,
    required void Function(String verId, int? token) onSent,
    required void Function(String error) onError,
  }) async {
    try {
      await _a.verifyPhoneNumber(
        phoneNumber: '+55${phone.replaceAll(RegExp(r'\D'), '')}',
        timeout: const Duration(seconds: AppConst.otpTimeoutSeconds),
        verificationCompleted: (cred) async =>
            await _a.signInWithCredential(cred),
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

  static Future<UserCredential?> signInApple() async {
    if (!PlatformInfo.isApple) return null;
    return signInWithAppleNative();
  }

  static Future<void> signOut() async {
    try {
      if (_googleInitialized) await _google.signOut();
    } catch (e) {
      debugPrint('Erro ao sair do Google: $e');
    }
    try {
      await _a.signOut();
    } catch (e) {
      debugPrint('signOut Firebase: $e');
    }
  }

  /// Exclusão LGPD: Cloud Function anonimiza e remove o Auth.
  static Future<void> deleteAccount() async {
    if (DevBypassAuth.enabled && current == null) {
      throw const AuthFailure('Modo teste: não há conta real para excluir.');
    }
    if (current == null) {
      throw const AuthFailure('Faça login para excluir a conta.');
    }
    try {
      await CloudFn.call('deleteMyAccount');
    } on CloudCallException catch (e) {
      throw AuthFailure(e.message, code: e.code);
    }
    try {
      await signOut();
    } catch (e) {
      debugPrint('signOut após exclusão: $e');
    }
  }
}
