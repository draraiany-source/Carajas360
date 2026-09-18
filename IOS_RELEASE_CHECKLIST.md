# iOS — checklist de release (prep only)

**Não é um archive/TestFlight final.** Sem App Store Connect neste bloco.  
**Não inventar** Team ID, provisioning, APNs key ou secrets.

| Campo | Valor atual no repo |
|---|---|
| Display name | `Carajás 360` (`CFBundleDisplayName`) |
| `CFBundleName` | `Carajas360` |
| Bundle ID | `br.com.carajas360` |
| Firebase `PROJECT_ID` | `carajas360-a17c5` |
| Versão | `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)` ← `pubspec` `1.0.0+1` |
| Deploy mínimo | iOS **13.0** (`Podfile`) |
| Signing / Team | **ausente** no repo |
| `Runner.xcodeproj` / `.xcworkspace` | **ausentes** no Git |

## 1. Identidade

- [ ] Nome na home: **Carajás 360** (já no plist).
- [ ] Bundle ID **obrigatório** `br.com.carajas360` (Firebase / Sign in). `Info.plist` já atualizado mesmo sem `Runner.xcodeproj`.
- [ ] Ao restaurar o Xcode, alinhar `PRODUCT_BUNDLE_IDENTIFIER` a `br.com.carajas360`.
- [ ] Cadastrar o app iOS **`br.com.carajas360`** no Console (`carajas360-a17c5`). Este agente **não** registrou.

## 2. Xcode project (bloqueio real)

O diretório `ios/Runner.xcodeproj` **não está no repositório**. Sem ele não há `Archive`.

- [ ] A Raiany restaura o projeto (backup local ou `flutter create .` com cuidado para **não** sobrescrever `Info.plist` / `AppDelegate.swift` / `GoogleService-Info.plist`).
- [ ] Abrir `ios/Runner.xcworkspace` (não o `.xcodeproj` sozinho) após `pod install`.

## 3. Firebase

- [ ] `ios/Runner/GoogleService-Info.plist` no repo é **placeholder** (`GCM_SENDER_ID` `000000000000`, `API_KEY` `COLE_SUA_IOS_API_KEY_AQUI`).
- [ ] Baixar o plist real do app iOS `br.com.carajas360` no Console.
- [ ] `REVERSED_CLIENT_ID` no URL scheme do `Info.plist` ainda é `COLE_SEU_REVERSED_CLIENT_ID_AQUI` — Google Sign-In iOS não funciona até a Raiany colar o valor do plist real.

## 4. Permissões / privacy descriptions (já no `Info.plist`)

| Key | Texto atual |
|---|---|
| `NSLocationWhenInUseUsageDescription` | Usamos sua localização para encontrar profissionais próximos e rastrear serviços. |
| `NSCameraUsageDescription` | Câmera para fotos de perfil e documentação de serviços. |
| `NSPhotoLibraryUsageDescription` | Acesso às fotos para envio de imagens. |
| `NSMicrophoneUsageDescription` | Microfone usado para chamadas de vídeo e mensagens de voz no chat. |

Ainda **ausentes** (avaliar antes do review Apple):

- [ ] `NSPhotoLibraryAddUsageDescription` se formos salvar fotos.
- [ ] `NSUserTrackingUsageDescription` **somente** se ATT for usado (hoje não).
- [ ] `ITSAppUsesNonExemptEncryption` (export compliance) — a Raiany define.
- [ ] Revisitar texto do microfone: voz/vídeo é **stub** (Fase 2). Se não for ao ar, suavizar o texto para não prometer chamada.

## 5. Notificações

- [ ] `firebase_messaging` + pod `Firebase/Messaging` já no projeto.
- [ ] `FirebaseAppDelegateProxyEnabled = false` — conferir `AppDelegate` ao restaurar o Xcode.
- [ ] **Sem** `UIBackgroundModes` / entitlements de Push no repo.
- [ ] A Raiany: capability **Push Notifications** + **Background Modes → Remote notifications**.
- [ ] APNs key (.p8) no Firebase Cloud Messaging — **não versionar**.
- [ ] Pedido de permissão já existe em `PushSvc`.

## 6. Maps

- [ ] `GMSApiKey` no plist ainda é placeholder. `AppDelegate` só chama `GMSServices.provideAPIKey` se a key **não** contém `COLE_SUA`.
- [ ] Key iOS restrita por bundle `br.com.carajas360`.
- [ ] Directions no client: `--dart-define=GOOGLE_MAPS_API_KEY`. Callable servidor documentada em `BLOCO_F.md` (key de servidor ausente — não inventar).

## 7. Signing / capabilities (Raiany no Xcode)

- [ ] Team (Apple Developer) no target Runner.
- [ ] Automatically manage signing **ou** profiles manuais — não commitar `.mobileprovision`.
- [ ] Capabilities mínimas quando for o caso: Push, Sign in with Apple (se o fluxo nativo for usado), Maps (SDK via plist, sem capability especial).
- [ ] **Este agente não cria certificado, Team ID nem provisioning.**

## 8. Ícones e launch

- [ ] `AppIcon.appiconset` com tamanhos 20–1024.
- [ ] `LaunchScreen.storyboard` fundo azul + emoji 🔗 — validar se a marca visual está aceitável para Review.

## 9. Privacy / App Store Connect (quando for)

- [ ] Política com URL pública (hoje só e-mail `privacidade@servicoconecta.com.br`).
- [ ] Nutrition labels: localização, fotos, identificadores, dados de conta.
- [ ] Conta demo para review (staging, **sem** pagamento real).

## 10. Testes internos (gate)

- [ ] `flutter build ios --no-codesign` só para validar compile (sem archive).
- [ ] TestFlight **depois** do Xcode project + Team + plist reais.
- [ ] Não enviar build com keys `COLE_SUA_…`.

## Parado de propósito

- Archive / TestFlight / App Store.
- Inventar Team ID, APNs, `REVERSED_CLIENT_ID` ou Maps key.
- Ligar pagamentos reais.
