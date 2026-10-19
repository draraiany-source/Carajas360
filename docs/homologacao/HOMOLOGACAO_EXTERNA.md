# Carajás 360 — Homologação externa: o que está pronto e o que falta (19/10/2026)

Este documento é sobre o projeto Firebase de homologação (`carajas360-hml`) e o Mercado Pago sandbox.

Nesta etapa nada foi publicado: nenhuma implantação, nenhuma alteração em produção e nenhuma credencial inventada.

Para conferir o estado a qualquer momento, rode:

```
node tool/check_hml_config.js
```

O comando não imprime nenhum segredo.

## 1. Feito no código e na configuração

| Item | Situação |
|---|---|
| **Separação de ambientes** | O ambiente é escolhido no build (`APP_ENV`). Cada ambiente tem seu arquivo `firebase_options_*`, seu flavor Android (`.dev` / `.hml` / produção) e seu `google-services.json`. A guarda do Hosting recusa produção. |
| **iOS por ambiente** | Configurações `Debug/Release/Profile-hml` e scheme `hml`, com bundle id `br.com.servicoconecta.hml`. O plist do Firebase é escolhido por `APP_ENV`. O CI compila `--flavor hml` e falha se o bundle id sair igual ao de produção. **Validado no GitHub Actions (macOS), execução 39229441736.** |
| **Login Google na web** | O login usa o popup do Firebase Auth, com o cliente OAuth do próprio projeto. O client id de exemplo foi removido do `index.html`. Erros de domínio não autorizado e de pop-up bloqueado aparecem com mensagem clara. |
| **`authDomain`** | O padrão é `<projeto>.firebaseapp.com`: em homologação, `carajas360-hml.firebaseapp.com`. Para usar domínio próprio, defina `FIREBASE_AUTH_DOMAIN` em `config/env/<amb>.json`. O domínio precisa estar no Hosting do mesmo projeto e na lista de domínios autorizados. |
| **Push web** | O service worker e a chave VAPID por ambiente (`FCM_VAPID_KEY`) estão descritos no relatório da etapa. Sem a chave, o push web fica desligado, sem erro. |
| **Pagamentos** | O gateway Mercado Pago só liga com `PAYMENTS_GATEWAY=mercadopago`, `PAYMENTS_ENV=sandbox` e credencial de usuário de teste. Projetos de produção são bloqueados por `PROD_PROJECT_IDS`. |

## 2. Dados externos necessários, que só você pode fornecer

### Firebase `carajas360-hml`

Pode ser outro id; nesse caso, atualize o alias `hml` em `.firebaserc`.

1. Criar o projeto e ativar Authentication (e-mail, Google e Apple), Firestore, Storage, Functions (plano Blaze) e Hosting.
2. Gerar `lib/firebase_options_hml.dart`:
   ```
   flutterfire configure --project=carajas360-hml --out=lib/firebase_options_hml.dart --android-package-name=br.com.servicoconecta.hml --ios-bundle-id=br.com.servicoconecta.hml
   ```
3. Baixar `android/app/src/hml/google-services.json` e `ios/config/GoogleService-Info-hml.plist`. Os dois ficam fora do Git.
4. Em Authentication › Domínios autorizados, incluir `carajas360-hml.web.app` e o domínio próprio, se houver.
5. Em Cloud Messaging:
   - gerar o par de chaves web (VAPID) e colocá-lo em `FCM_VAPID_KEY`, no `config/env/hml.json`;
   - enviar a chave APNs (.p8) da conta Apple.
6. Criar `config/env/hml.json` a partir de `hml.example.json`. Ele contém:
   - a chave do Maps restrita ao app hml;
   - a public key de **teste** do Mercado Pago;
   - `FCM_VAPID_KEY`.

### Mercado Pago sandbox

1. Criar um usuário de teste vendedor e pegar o access token de **teste**.
2. Criar o arquivo `functions/.env.carajas360-hml`, com:
   - `PAYMENTS_GATEWAY=mercadopago`
   - `PAYMENTS_ENV=sandbox`
   - `PROD_PROJECT_IDS=servicoconecta,carajas360-a17c5`
   - `PAYMENTS_WEBHOOK_URL`
   - `MP_TEST_USER_CREDENTIALS=true`
3. Guardar no Secret Manager: `MERCADOPAGO_ACCESS_TOKEN` (teste), `MP_WEBHOOK_SECRET` e `ANTHROPIC_API_KEY`.
4. Cadastrar o webhook `https://us-central1-<hml>.cloudfunctions.net/paymentsWebhook` no painel de testes.

### Apple, para distribuir o iOS

1. Apple Developer Program.
2. Bundle id `br.com.servicoconecta.hml`, com as capacidades Push Notifications e Sign in with Apple.
3. Provisioning profiles para o TestFlight.

### GitHub

1. Environment `homologacao` restrito à branch protegida, com revisor.
2. Secret de implantação do projeto hml, para o workflow manual `deploy-hml.yml`.

## 3. Testes bloqueados até haver credenciais

- Login Google e Apple reais (web, Android e iOS).
- Pagamento Pix e cartão no sandbox do Mercado Pago e recebimento do webhook real.
- Push real em aparelho e navegador:
  - com o app aberto, em segundo plano e encerrado;
  - o clique na notificação web.
- Download de anexo do chat por URL assinada real. No emulador, a URL é a do próprio emulador.
- Execução das migrações de dados em homologação:
  - anexos do chat;
  - contador e status de lojas;
  - `expiresAt` dos pedidos;
  - tokens por dispositivo.
- Link público de homologação: **não existe**. O Hosting hml depende do projeto acima.

## 4. Decisões que dependem de você

- **Projeto de produção:** o `.firebaserc` e o `firebase_options_prod` apontam para `servicoconecta`, mas os ramos antigos usam `carajas360-a17c5`. A escolha define o `authDomain` de produção e os ids dos apps. Produção não foi alterada.
- **Domínio próprio para o login**, por exemplo `auth.carajas360.com.br`. É opcional.
