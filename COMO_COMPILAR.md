# ✅ ServiçoConecta — Como compilar

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
1. console.cloud.google.com → ative "Maps SDK for Android", "Maps SDK for iOS" e **"Directions API"**
2. Crie uma API Key
3. Cole em `android/app/src/main/AndroidManifest.xml` (campo `COLE_SUA_GOOGLE_MAPS_API_KEY_AQUI`)
4. Cole em `ios/Runner/AppDelegate.swift` (mesmo campo)
5. Cole a mesma key em `lib/features/gps/gps_screen.dart`, método `_fetchRoute` (campo `COLE_SUA_GOOGLE_MAPS_API_KEY_AQUI`) — é usada para calcular a rota real seguindo ruas e o tempo estimado de chegada via Directions API.
6. As permissões de localização (`ACCESS_FINE_LOCATION`, `NSLocationWhenInUseUsageDescription`) já estão
   configuradas no Android/iOS. O app usa a localização real do usuário na tela de rastreamento (GPS).

**Nota sobre custo:** a Directions API é cobrada por chamada após a cota gratuita mensal do Google Cloud
(consulte a página de preços atual). Se a chave não estiver configurada ou a chamada falhar, o app usa
automaticamente uma rota em linha reta como alternativa — nunca trava a tela.

## 3. Mercado Pago / Cloud Functions (pagamentos)
```bash
cd functions
npm install
firebase functions:config:set mercadopago.token="SEU_ACCESS_TOKEN"
firebase deploy --only functions
```
Depois, atualize a constante `_base` em `lib/shared/services/firebase_service.dart` (classe `PaySvc`) com a URL do seu projeto.

**Pagamento com cartão de crédito:** além do Access Token acima (usado só no backend), o app
tokeniza o cartão direto com o Mercado Pago usando a **Public Key** (chave pública, segura para
expor no client — equivalente à `publishable_key` do Stripe). Pegue-a em
https://www.mercadopago.com.br/developers/panel/app e cole em `_mpPublicKey`, na mesma classe
`PaySvc`. **Nunca** use a Access Token secreta no app — ela fica só na Cloud Function.

## 4. Assistente de IA (Claude API)
```bash
firebase functions:config:set anthropic.key="SUA_API_KEY_ANTHROPIC"
firebase deploy --only functions
```
Atualize a constante `_base` em `lib/shared/services/firebase_service.dart` (classe `AiSvc`) com a URL do seu projeto.
**Sem essa chave configurada, o assistente de IA continua funcionando** com respostas locais por palavra-chave (fallback automático) — o app nunca trava.

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

