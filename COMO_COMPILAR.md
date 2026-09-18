# Carajás 360 — Como compilar (staging)

Os IDs técnicos (`br.com.servicoconecta`, projeto Firebase `servicoconecta`) **não** são o nome de vitrine. Ver `IDENTIDADE_TECNICA.md`.
Checklists: `CHECKLIST_FIREBASE_STAGING.md`, `CHECKLIST_GOOGLE_MAPS.md`.

## 1. Firebase (15 min)
1. https://console.firebase.google.com → criar projeto
2. Ative: Authentication (Phone + Email), Firestore, Storage, Cloud Messaging
3. Adicione app Android (`br.com.servicoconecta`) → baixe `google-services.json` → substitua em `android/app/`
4. Adicione app iOS (`br.com.servicoconecta`) → baixe `GoogleService-Info.plist` → substitua em `ios/Runner/`
5. Rode: `dart pub global activate flutterfire_cli && flutterfire configure --project=SEU_PROJETO`
   Isso substitui `lib/firebase_options.dart` automaticamente.
6. No Firebase Console → Authentication → Sign-in method → ative também o **Google**.
7. Publique as regras de segurança:
   ```bash
   firebase deploy --only firestore:rules,storage:rules
   ```
8. **Login com Google — passo obrigatório no iOS:**
   Após rodar `flutterfire configure`, abra o `GoogleService-Info.plist` real gerado e copie o
   valor da chave `REVERSED_CLIENT_ID`. Cole em `ios/Runner/Info.plist`, substituindo
   `COLE_SEU_REVERSED_CLIENT_ID_AQUI`. Sem isso, o login com Google não retorna ao app no iOS.
   No Android não é necessário nenhum passo extra além do `google-services.json` real.

## 2. Google Maps + Geolocalização (10 min)

Siga `CHECKLIST_GOOGLE_MAPS.md`. Resumo:

1. console.cloud.google.com → ative Maps SDK Android, Maps SDK iOS e Directions API.
2. Crie keys **restritas** (não a mesma key irrestrita para tudo).
3. Android: `MAPS_API_KEY` em `android/local.properties` (gitignored). Modelo: `android/local.properties.example`.
4. iOS: `GMSApiKey` em `ios/Runner/Info.plist`. `AppDelegate` ignora placeholder.
5. Directions: `--dart-define=GOOGLE_MAPS_API_KEY=...` (`RuntimeConfig`). Sem key, a tela GPS usa linha reta e **não quebra**.
6. **Não** cole a key no Manifest, no AppDelegate ou no Dart.

**Nota sobre custo:** a Directions API é cobrada por chamada após a cota gratuita. Sem key ou com falha, o app cai na linha reta.

## 3. Mercado Pago / Cloud Functions (pagamentos)

Pagamentos reais ficam **desligados** (`PAYMENTS_ENABLED=false`). Ver `PAGAMENTOS_STAGING.md`.

```bash
cd functions
npm install
# NÃO use functions.config() (depreciado).
# firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN   # só sandbox TEST-, se a Raiany autorizar
# Nunca commitar o token. Nunca ligar PAYMENTS_ENABLED neste bloco.
```

Public key de teste (cliente): `--dart-define=MERCADOPAGO_PUBLIC_KEY=TEST-...`  
**Nunca** coloque o Access Token no app.

## 4. Assistente de IA (Claude API)

```bash
# firebase functions:secrets:set ANTHROPIC_API_KEY
```

Sem essa chave, o assistente continua com respostas locais (fallback). O app não trava.

## 5. Instalar dependências e rodar
```bash
flutter pub get
flutter run
```
Sem Firebase configurado, o app abre em modo demonstração (dados fictícios) sem travar.

## 6. Testes
```bash
flutter analyze
flutter test
```
O projeto inclui testes unitários reais em `test/models_test.dart` cobrindo:
- Sistema de XP/gamificação (níveis, progresso)
- Formatação de moeda e cálculo de comissão (PaySvc)
- Integridade das 60+ categorias de serviço (sem duplicatas, campos obrigatórios)
- Parsing de `UserModel`, `OrderModel`, `CompanyModel`, `CouponModel`, `ProviderModel`, `TicketModel`

## 7. Assinatura de release Android (obrigatório antes de publicar)
O AAB de release **precisa** ser assinado com uma chave própria — a Play Store rejeita builds
assinados com a chave de debug. Gere seu keystore e configure:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Crie `android/key.properties` (já está no `.gitignore`, nunca versione este arquivo):
```
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=/caminho/absoluto/para/upload-keystore.jks
```
Sem esse arquivo, o build cai automaticamente na assinatura de debug (funciona para testar, mas
não pode ser enviado à loja).

## 8. Gerar builds de produção
```bash
# Android (APK para testes)
flutter build apk --release

# Android (App Bundle para Play Store — use este para publicar)
flutter build appbundle --release

# iOS (requer macOS + Xcode)
flutter build ios --release

# Web
flutter build web --release
```

Os artefatos ficam em:
- `build/app/outputs/flutter-apk/app-release.apk`
- `build/app/outputs/bundle/release/app-release.aab`
- `build/web/`

## 9. Publicação nas lojas
**Google Play Store:**
1. Crie uma conta de desenvolvedor (taxa única): https://play.google.com/console
2. Crie o app, preencha a ficha da loja (descrição, screenshots, categoria)
3. Faça upload do `app-release.aab` gerado no passo 8
4. Preencha o questionário de conteúdo e a política de privacidade (obrigatório — o app coleta
   localização e dados pessoais)
5. Envie para revisão

**Apple App Store:**
1. Conta Apple Developer Program (anual): https://developer.apple.com
2. Abra `ios/Runner.xcworkspace` no Xcode (não o `.xcodeproj`)
3. Configure o Team/Signing em Runner → Signing & Capabilities
4. Product → Archive → Distribute App → App Store Connect
5. Preencha a ficha no App Store Connect e envie para revisão

Os ícones do app (Android: `mipmap-*/ic_launcher.png`; iOS: `Assets.xcassets/AppIcon.appiconset/`)
já estão incluídos neste projeto com a identidade visual da marca (gradiente azul/verde). Substitua
por uma versão profissional de design antes da publicação final, se desejar.

## Observação sobre este pacote
Este projeto foi desenvolvido e validado por análise estática rigorosa (balanceamento de sintaxe,
resolução de imports, resolução de símbolos, checagem de dependências circulares) em um ambiente
sem o Flutter SDK instalado. Antes de builds de produção, rode `flutter pub get && flutter analyze`
localmente para confirmar que não há avisos específicos de versão de pacote.

