# Carajás 360 — Builds Android, iOS e web (homologação)

## CI (GitHub Actions) — `.github/workflows/homologacao.yml`

O workflow roda em *push* nas branches `fase1-seguranca-ambientes-filtros` e `homologacao-ci`, ou manualmente (*Run workflow*). Nada é publicado.

| Job | Gera | Artefato (30 dias) |
|---|---|---|
| Android | APK **hml** release + AAB **prod** release (só validação). Ambos com keystore **descartável de teste** | `carajas360-hml-apk` (APK + `build-info.txt` + manifesto), `carajas360-prod-aab-test-signed` |
| iOS | `flutter build ios --release --no-codesign` (macOS) | `carajas360-ios-build-log` (resumo + log) |
| Web | `flutter build web --release` (hml) | `carajas360-web-hml` |

`build-info.txt` registra:
- versão (`pubspec.yaml`), *build number* (= número do run) e commit;
- `applicationId` (`br.com.servicoconecta.hml` / `br.com.servicoconecta`);
- versionName/versionCode e SHA-256 dos arquivos;
- resultado da verificação de manifesto.

**Verificação de rede de emulador fora do release:**
- `android/app/src/dev/AndroidManifest.xml` e `res/xml/network_security_config.xml` existem só no *flavor* `dev`.
- O job falha se `networkSecurityConfig` ou `usesCleartextTraffic=true` aparecer:
  - no APK hml;
  - no AAB prod;
  - nos manifestos mesclados de release.

## Assinatura

- **CI:** um keystore PKCS12 gerado no próprio job, válido por 30 dias, com senha aleatória mascarada e apagada no fim. Serve para instalar o APK de teste. **Não é** a *upload key* da Play Store, e o AAB do CI não pode ser enviado à loja.
- **Real:** `android/key.properties` (fora do Git, ver `key.properties.example`) ou as variáveis `CARAJAS_KEYSTORE_PATH`, `CARAJAS_KEYSTORE_PASSWORD`, `CARAJAS_KEY_ALIAS` e `CARAJAS_KEY_PASSWORD`. Guarde a *upload key* fora do repositório e cadastre-a no Play App Signing.

## Configuração por ambiente (arquivos reais ficam fora do Git ou são gerados)

| Plataforma | hml | prod |
|---|---|---|
| Dart | `lib/firebase_options_hml.dart` (`flutterfire configure`) | `lib/firebase_options_prod.dart` |
| Android | `android/app/src/hml/google-services.json` | `android/app/google-services.json` |
| iOS | `ios/config/GoogleService-Info-hml.plist`. Em Info.plist, trocar `PLACEHOLDER-REVERSED-CLIENT-ID` pelo `REVERSED_CLIENT_ID` | idem prod |
| Maps | `android/local.properties` → `MAPS_API_KEY=…`; iOS: `ios/Flutter/MapsKey.xcconfig` → `MAPS_API_KEY=…` (sem chave, os mapas ficam desligados, sem crash) | idem |

O Firebase é inicializado **só pelo Dart**, com as opções do `APP_ENV`. O iOS não chama `FirebaseApp.configure()`, para não misturar ambientes. O token APNs chega ao Messaging pelo *proxy* do AppDelegate.

`node tool/check_hml_config.js` aponta o que ainda é modelo.

## Comandos locais

```bash
# Android (precisa do Android SDK + Java 17)
flutter build apk --release --flavor hml --dart-define-from-file=config/env/hml.json
flutter build appbundle --release --flavor prod --dart-define-from-file=config/env/prod.json
# iOS (macOS + Xcode 16+)
cd ios && pod install && cd .. && flutter build ipa --release --dart-define-from-file=config/env/hml.json
# Web
flutter build web --release --dart-define-from-file=config/env/hml.json
```

## iOS: um *bundle id* só (pendente, auditoria 2)

O projeto iOS usa `br.com.servicoconecta` em todas as configurações. O build do CI com `APP_ENV=hml` usa as opções do Firebase hml, mas é instalado com o id de produção. Por isso:
- o login Google e o push (APNs) do app hml não casam com o app iOS `br.com.servicoconecta.hml` do Firebase;
- o build hml substitui o de produção no aparelho.

**Correção planejada (exige macOS/Xcode para validar e a conta Apple para assinar):**
1. Criar as configurações `Debug-hml`/`Release-hml` e o *scheme* `hml`, com `PRODUCT_BUNDLE_IDENTIFIER = br.com.servicoconecta.hml`.
2. Passar a gerar o build com `flutter build ipa --flavor hml`.
3. Tirar `aps-environment` das entitlements fixas e defini-lo por configuração.

Até lá, o IPA de homologação não deve ser distribuído.

## Bloqueios iOS restantes (precisam de conta Apple)

1. Apple Developer Program, *bundle id* `br.com.servicoconecta(.hml)` e *provisioning profiles* de desenvolvimento e distribuição.
2. Capacidades no portal: **Push Notifications** e **Sign in with Apple**. As entitlements já existem em `ios/Runner/Runner.entitlements`; em distribuição, `aps-environment` passa a `production`.
3. Chave **APNs (.p8)** cadastrada no Firebase (Cloud Messaging) do projeto hml.
4. `GoogleService-Info` real do hml e `REVERSED_CLIENT_ID` (Google Sign-In).
5. Chave do Maps restrita ao *bundle id*.

Com isso: `flutter build ipa` com assinatura e distribuição pelo TestFlight.
