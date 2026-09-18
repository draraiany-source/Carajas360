# Identidade — Carajás 360 vs IDs técnicos

Nome de produto (display): **Carajás 360**.

## Decisão (autorizada pela Raiany)

Os IDs técnicos **foram migrados de propósito** neste PR. Não é um rename acidental.

| ID | Antes (legado) | Agora (código) |
|---|---|---|
| Dart package (`pubspec.yaml` `name`) | `servico_conecta` | `carajas_360` |
| Imports Dart | `package:servico_conecta/` | `package:carajas_360/` |
| Android `applicationId` / `namespace` | `br.com.servicoconecta` | `br.com.carajas360` |
| Android Kotlin package | `br.com.servicoconecta` | `br.com.carajas360` (`MainActivity.kt` movido) |
| iOS `CFBundleIdentifier` | `br.com.servicoconecta` | `br.com.carajas360` |
| Firebase `projectId` / `.firebaserc` default | `servicoconecta` | `carajas360-a17c5` |
| Storage bucket / authDomain (derivados do projectId) | `servicoconecta.appspot.com` / `servicoconecta.firebaseapp.com` | `carajas360-a17c5.appspot.com` / `carajas360-a17c5.firebaseapp.com` |
| Functions npm name | `servicoconecta-functions` | **não migrado** (metadado; residual A) |

Constantes no app: `AppInfo.dartPackage`, `AppInfo.applicationId`, `AppInfo.iosBundleId`, `AppInfo.firebaseProjectId`.

`ios/Runner.xcodeproj` continua **ausente** no Git. `Info.plist` e `GoogleService-Info.plist` foram atualizados mesmo assim. Ao restaurar o Xcode, alinhar `PRODUCT_BUNDLE_IDENTIFIER` a `br.com.carajas360`.

## O que este agente NÃO fez

- Não registrou apps no Firebase Console.
- Não rodou `flutterfire configure` (precisa da conta da Raiany).
- Não inventou API keys / `appId` / `messagingSenderId` / tokens — placeholders `COLE_SUA_…` permanecem.
- Não inventou e-mails `@carajas360.com.br`.
- Não publicou lojas, não merge em `main`, não produção.
- Não apagou logs históricos `analyze_*.txt` / `build_*.txt` por conterem o nome antigo.

## Próximo passo (Raiany, local)

1. Firebase Console → projeto **`carajas360-a17c5`**.
2. Cadastrar apps Android e iOS com ID **`br.com.carajas360`** (este agente não fez isso).
3. Baixar `google-services.json` e `GoogleService-Info.plist` reais e substituir os placeholders.
4. `flutterfire configure --project=carajas360-a17c5`.
5. Recadastrar SHA-1/256, OAuth, Google Sign-In (`REVERSED_CLIENT_ID`), restrições Maps no **novo** package/bundle.
6. Pull desta branch.

Apps antigos `br.com.servicoconecta` no Console, se existirem, **não** batem mais com este código.

## E-mails e domínio (residual A — intencional)

Textos de suporte/privacidade e PIX demo continuam `@servicoconecta.com.br` — **não inventamos** `@carajas360.com.br`. Quando houver domínio oficial, trocar `AppInfo.supportEmail` / `AppInfo.privacyEmail` e o e-mail demo da carteira.

## Deep links

Não há `servicoconecta://` / `carajas360://` no código. Único URL scheme iOS: Google Sign-In (`REVERSED_CLIENT_ID` placeholder). Nada a migrar além do valor oficial do plist real.

## Residuals intencionais (A)

Ver relatório da migração. Em resumo: e-mails `@servicoconecta.com.br`; npm `servicoconecta-functions`; relatórios/ZIPs/histórico (`RELATORIO_DE_COMPILACAO.md`, `ServicoConecta_v1.5_*`, `analyze_*.txt` / `build_*.txt` se existirem).
