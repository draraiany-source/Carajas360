# Checklist — Firebase Staging (Carajás 360)

**Não inventamos chaves, App IDs, SHA-1 nem tokens.** Os arquivos no repositório são *placeholders* de forma decente para o app compilar em debug/emulador. Staging real só depois que a Raiany colar os arquivos oficiais do Console Firebase.

Projeto referenciado no código (não alterado neste bloco): `servicoconecta`.  
IDs técnicos do app: Android `br.com.servicoconecta` · iOS `br.com.servicoconecta`.  
**Não troque esses IDs sem ler `IDENTIDADE_TECNICA.md`** — quebram Firebase, Maps, Play/App Store e OAuth.

Pagamentos reais: **desligados** (`PAYMENTS_ENABLED=false`). Não publicar produção neste bloco.

---

## Estado atual no Git (auditoria)

| Item | Arquivo | Estado | Pode ir para o Git? | Secret? |
|---|---|---|---|---|
| FlutterFire options | `lib/firebase_options.dart` | Placeholders `COLE_SUA_*_API_KEY`, `appId`/`senderId` fictícios, `projectId: servicoconecta` | Sim **enquanto for placeholder**. Depois do `flutterfire configure`, o arquivo contém API keys *de cliente* — aceitável no Git se o app for só staging e as keys estiverem restritas; **não** commitar se for produção sem restrição | Cliente (não é service account). Tratar como confidencial de produção |
| Android Google Services | `android/app/google-services.json` | `project_number` 000…, API key placeholder, package `br.com.servicoconecta` | Idem: placeholder sim; arquivo real de **produção** preferir `assume-unchanged` / CI secret | Cliente |
| iOS GoogleService | `ios/Runner/GoogleService-Info.plist` | Mesmos placeholders, `BUNDLE_ID` `br.com.servicoconecta` | Idem | Cliente |
| Reversed client ID (Google Sign-In iOS) | `ios/Runner/Info.plist` → `CFBundleURLSchemes` | `COLE_SEU_REVERSED_CLIENT_ID_AQUI` | Placeholder sim. Valor real vem do plist (`REVERSED_CLIENT_ID`) | Cliente |
| Web OAuth client | `web/index.html` `google-signin-client_id` | Placeholder | Placeholder sim | Cliente |
| Service account / Admin SDK | — | **Ausente (correto)** | **Nunca** | **Sim** |
| Functions env | `functions/.env` | Não versionado (só `.env.example`) | Não | Sim |
| App Check site keys / debug tokens | — | Não existem no repo (correto) | Não | Debug token = secret; reCAPTCHA site key é cliente |
| `MERCADOPAGO_ACCESS_TOKEN` / `ANTHROPIC_API_KEY` | env / Secret Manager | Só nomes em `.env.example` | **Nunca** o valor | **Sim** |

`FirebaseBootstrap` (`lib/core/utils/firebase_bootstrap.dart`):

- Detecta placeholders (`COLE_SUA` / `demo-api-key`).
- Em **debug/profile** com placeholder (ou `--dart-define=USE_FIREBASE_EMULATOR=true`) aponta Auth `9099`, Firestore `8080`, Storage `9199`, Functions `us-central1` `5001`.
- Em **release** com placeholder: **falha de propósito** (`StateError`) — impede loja com config fake.
- Emulador **nunca** em `kReleaseMode`.

---

## O que a Raiany precisa fornecer (e onde obter)

### 1. Projeto Firebase de STAGING

1. [Firebase Console](https://console.firebase.google.com/) → projeto de staging (se o ID real **não** for `servicoconecta`, avisar antes de trocar `projectId`).
2. Ativar: **Authentication**, **Firestore**, **Storage**, **Functions**, **Cloud Messaging**, **Crashlytics**, **Analytics**, **App Check** (depois).
3. Apps: Android `br.com.servicoconecta` + iOS `br.com.servicoconecta` (+ Web se for usar).

### 2. Arquivos de cliente

| O quê | Onde obter | Onde colocar | Git? |
|---|---|---|---|
| `google-services.json` | Console → Project settings → Android app → Download | `android/app/google-services.json` | Placeholder atual: sim. Arquivo **real de produção**: não commitar |
| `GoogleService-Info.plist` | Idem, app iOS | `ios/Runner/GoogleService-Info.plist` | Idem |
| `firebase_options.dart` | `dart pub global activate flutterfire_cli` + `flutterfire configure --project=<ID>` | `lib/firebase_options.dart` (substitui o placeholder) | Idem |
| `REVERSED_CLIENT_ID` | chave no plist iOS | `ios/Runner/Info.plist` → `CFBundleURLSchemes` | Cliente |
| Web client ID | Google Cloud → APIs & Services → Credentials (OAuth Web) | `web/index.html` `google-signin-client_id` | Cliente |

Comando (máquina da Raiany, com Flutter):

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=servicoconecta
```

Não rodamos isso aqui: exigiria login Google e criaria IDs reais.

### 3. SHA-1 / SHA-256 (Android — Auth Google + App Check + Maps)

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
# Release: o keystore de upload (NÃO versionado; ver android/key.properties.example)
```

Colar em Firebase → Android app → Add fingerprint. Sem SHA, Google Sign-In e App Check Play Integrity falham.

### 4. Authentication

Ativar provedores usados pelo app: **E-mail/senha**, **Google**, **Apple** (iOS), **Telefone** (se o fluxo de OTP estiver em uso).  
Apple: Service ID + key no Apple Developer (só a Raiany).  
Não inventamos `GOOGLE_WEB_CLIENT_ID`.

Como testar: emulador Auth (`firebase emulators:start`) ou staging com os arquivos reais → cadastro e-mail + Google.

### 5. Firestore / Storage / Functions / FCM

| Serviço | Config no repo | Variável / secret | Como testar |
|---|---|---|---|
| Firestore | `firestore.rules`, `firestore.indexes.json` | — | `firebase emulators:start --only firestore` + rules |
| Storage | `storage.rules` | — | emulador Storage `9199` |
| Functions | `functions/` runtime **nodejs20**, 1ª geração `onCall` | `PAYMENTS_ENABLED=false` (obrigatório em staging). Secrets: `MERCADOPAGO_ACCESS_TOKEN`, `ANTHROPIC_API_KEY` via Secret Manager — **nunca no Git** | `cd functions && npm test && npm run lint`; emulador `5001` |
| FCM | `firebase_messaging` + `PushSvc.init()` | Não há server key no client (correto; usa Admin SDK nas Functions) | Token salvo em `users/{uid}` após login; notificação de teste pelo Console |
| Crashlytics | plugin Android `com.google.firebase.crashlytics`; `main.dart` liga `recordFlutterFatalError` fora da Web | — | Build não-web com Firebase real; forçar `FirebaseCrashlytics.instance.crash()` só em debug |
| Analytics | `FirebaseAnalyticsObserver` em `MaterialApp` | `measurementId` web ainda `G-XXXXXXXXXX` | Console Analytics após `flutterfire configure` |
| App Check | **não ativado** (sem keys). Flag `--dart-define=APP_CHECK_ENABLED=true` só depois do passo abaixo. Functions: `ENFORCE_APP_CHECK=false` | Debug token = secret. reCAPTCHA **site** key = cliente; **secret** reCAPTCHA = secret | Ver secção App Check |

Deploy de Functions/rules: **não executado neste bloco** (staging da Raiany).

---

## App Check (preparado, sem keys inventadas)

**Não há Play Integrity / DeviceCheck / reCAPTCHA no repositório. Não inventamos.**

Código:

- `RuntimeConfig.appCheckEnabled` lê `--dart-define=APP_CHECK_ENABLED=true` (padrão **false**).
- `RuntimeConfig.appCheckWebRecaptchaSiteKey` lê `--dart-define=APP_CHECK_WEB_RECAPTCHA_SITE_KEY=...` (vazio = não usar Web).
- `FirebaseBootstrap` **não** chama `activate()` sem a flag. Emulador também pula.
- Functions já aceitam `ENFORCE_APP_CHECK=true` (`assertCallableAuth`). **Deixe false** até os apps estarem registrados, senão todas as callables quebram.

Passos da Raiany (quando for a hora):

1. Console Firebase → App Check → registrar Android (Play Integrity) e iOS (App Attest / DeviceCheck).
2. Web: reCAPTCHA v3 — **site key** no dart-define; **secret** só no Console (nunca no Git).
3. Debug: usar o token impresso no log (`Enter this debug secret`) → registrar no Console. **Não commitar o token.**
4. Adicionar dependência `firebase_app_check` e o `activate()` abaixo **só depois** das chaves reais:

```dart
await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
  webProvider: ReCaptchaV3Provider(RuntimeConfig.appCheckWebRecaptchaSiteKey),
);
```

5. Só então: Secret/env `ENFORCE_APP_CHECK=true` nas Functions de staging.

Como testar: callable `transitionOrder` com App Check debug token; sem token deve falhar quando `ENFORCE_APP_CHECK=true`.

---

## Variáveis / dart-defines (client)

| Variável | Onde | Default | Git? |
|---|---|---|---|
| `USE_FIREBASE_EMULATOR` | `--dart-define` | false (true implícito se key placeholder em debug) | n/a |
| `APP_CHECK_ENABLED` | `--dart-define` | false | n/a |
| `APP_CHECK_WEB_RECAPTCHA_SITE_KEY` | `--dart-define` | vazio | não versionar valor real |
| `GOOGLE_MAPS_API_KEY` | `--dart-define` (Directions) | placeholder | ver `CHECKLIST_GOOGLE_MAPS.md` |
| `MAPS_API_KEY` | `android/local.properties` | placeholder | **não** versionar `local.properties` |
| `MERCADOPAGO_PUBLIC_KEY` | `--dart-define` | placeholder | chave **pública** de teste (TEST-…) ok em CI; **não** access token |

## Variáveis Functions (server)

| Variável | Valor staging | Secret? |
|---|---|---|
| `PAYMENTS_ENABLED` | `false` | não (flag) |
| `ENFORCE_APP_CHECK` | `false` até App Check real | não (flag) |
| `MERCADOPAGO_ACCESS_TOKEN` | **não preencher** até sandbox controlado | **sim** — `firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN` |
| `ANTHROPIC_API_KEY` | opcional, IA | **sim** |

Não usamos `functions.config()` (depreciado). Só `process.env` / Secret Manager.

---

## Como validar staging (ordem segura)

1. `firebase emulators:start` + `flutter run --dart-define=USE_FIREBASE_EMULATOR=true` (debug).
2. Substituir os 3 arquivos de cliente pelos oficiais **de staging**.
3. `flutter run` **sem** emulador apontando para o projeto staging.
4. Auth e-mail → Firestore write de perfil → Storage upload de foto → callable `switchProfileType`.
5. Crashlytics/Analytics no Console após um evento.
6. **Não** ligar `PAYMENTS_ENABLED`. **Não** publicar Play/App Store neste bloco.

---

## O que NÃO foi feito (bloqueado de propósito)

- Não geramos `flutterfire configure` (precisa da conta da Raiany).
- Não criamos projeto Firebase novo.
- Não inventamos API keys, `appId`, `measurementId`, SHA-1, OAuth client IDs.
- Não ativamos App Check enforce.
- Não fizemos deploy.
- Não mudamos `applicationId` / `bundleId` / `projectId`.
