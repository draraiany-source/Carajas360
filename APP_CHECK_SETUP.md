# App Check — setup de staging

Firebase App Check protege Auth, Firestore, Storage e Cloud Functions contra tráfego não autorizado. **Neste repositório App Check está preparado mas desligado** — não inventamos site keys nem debug tokens.

Referência: `FirebaseBootstrap.maybeActivateAppCheck()` em `lib/core/utils/firebase_bootstrap.dart`.

## Estado atual

| Peça | Comportamento |
|---|---|
| `APP_CHECK_ENABLED` | `--dart-define`, default **false** |
| `ENFORCE_APP_CHECK` | Functions env, manter **false** até keys reais |
| `maybeActivateAppCheck()` | Não chama `activate()` sem credenciais reais |

## Android (Play Integrity + debug)

1. Console → App Check → Android `br.com.carajas360`
2. Play Integrity para release; Debug provider em `kDebugMode`
3. Registrar debug token no Console (não commitar)

## iOS (App Attest / DeviceCheck)

1. Console → App Check → iOS `br.com.carajas360`
2. App Attest (release); DeviceCheck fallback se necessário
3. Debug token para builds locais

## Web (reCAPTCHA v3)

1. Site key via `--dart-define=APP_CHECK_WEB_RECAPTCHA_SITE_KEY=...`
2. Secret key **somente** no Firebase Console

## Ordem segura

1. Registrar providers (sem ENFORCE)
2. `APP_CHECK_ENABLED=true` + `activate()` com keys reais
3. Testar callables
4. Só então `ENFORCE_APP_CHECK=true`

Ver `CHECKLIST_FIREBASE_STAGING.md`.
