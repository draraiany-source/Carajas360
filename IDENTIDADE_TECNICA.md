# Identidade — Carajás 360 vs IDs técnicos

Nome de produto (display): **Carajás 360**.  
Este bloco atualiza textos, splash, onboarding, compartilhamento, Manifest/plist **visíveis**.  

## IDs que NÃO foram alterados

| ID | Valor atual | Por quê não mudar automaticamente |
|---|---|---|
| Dart package (`pubspec.yaml` `name`) | `servico_conecta` | Todos os `import 'package:servico_conecta/...'` quebram; testes, ferramentas e `widget_test` usam esse nome |
| Android `applicationId` / `namespace` | `br.com.servicoconecta` | Liga `google-services.json`, OAuth, SHA-1, Maps, FCM, Play Console. App novo na Play se mudar |
| Android Kotlin package | `br.com.servicoconecta` | Precisa mover `MainActivity.kt` e o manifesto |
| iOS `CFBundleIdentifier` | `br.com.servicoconecta` | Liga `GoogleService-Info.plist`, Sign in with Apple, Maps, App Store |
| Firebase `projectId` | `servicoconecta` | Auth/Firestore/Functions/Storage/FCM do projeto atual |
| Storage bucket / authDomain | `servicoconecta.appspot.com` / `servicoconecta.firebaseapp.com` | Vêm do projeto Firebase |
| Functions npm name | `servicoconecta-functions` | Só metadado; irrelevante para o app. Descrição atualizada para Carajás 360 |

**Impacto se a Raiany quiser IDs `br.com.carajas360` / projeto `carajas360` no futuro:**

1. Criar apps novos no Firebase (ou migrar) e gerar `google-services.json` + `GoogleService-Info.plist` + `firebase_options.dart` novos.
2. Recadastrar SHA-1, OAuth clients, Google Sign-In reversed URL scheme, Apple Service ID.
3. Recriar restrições das keys de Maps.
4. App Check do zero.
5. Play Console: novo `applicationId` = **app novo** (não é rename in-place). Transferência de usuários não é automática.
6. App Store: novo bundle = app novo, salvo fluxo oficial de change (raro e burocrático).
7. Cloud Functions / FCM tokens antigos deixam de valer para o app novo.
8. Deep links / Intent filters (hoje só o scheme do Google Sign-In placeholder) teriam de ser republicados.

**Não execute essa migração neste PR.** Só com decisão explícita da proprietária e janela de publicação.

## E-mails e domínio

Textos de suporte/privacidade continuam `@servicoconecta.com.br` — **não inventamos** `@carajas360.com.br`. Quando houver domínio oficial, trocar `AppInfo.supportEmail` / `AppInfo.privacyEmail`.

## Deep links

Não há `servicoconecta://` / `carajas360://` no código. Único URL scheme iOS: Google Sign-In (`REVERSED_CLIENT_ID` placeholder). Nada a migrar além desse valor oficial.
