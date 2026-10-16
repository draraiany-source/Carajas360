# Carajás 360 — Implantação e reversão em HOMOLOGAÇÃO

> Somente o projeto de homologação. Produção (`servicoconecta` e qualquer projeto em `PROD_PROJECT_IDS`) **não** entra neste roteiro.
> Pagamentos: Mercado Pago **sandbox**, com usuário de teste.

## 0. Pré-requisitos

| Ferramenta | Versão |
|---|---|
| Node.js | 22 (functions `engines.node = 22`) |
| firebase-tools | ≥ 14 |
| Flutter | 3.47.7 (stable) |
| Java (Android) | 17 |
| Xcode (iOS) | 16+ |

Contas necessárias: projeto Firebase de homologação (Blaze, porque as Functions agendadas usam Cloud Scheduler), conta de testes do Mercado Pago e, para iOS, Apple Developer.

## 1. Conferir a configuração (sem expor segredos)

```bash
node tool/check_hml_config.js --project <id-hml>
```

O comando termina com código 0 só quando não restar nenhum modelo. Itens que ele confere:

**Firebase do app**
- `lib/firebase_options_hml.dart`: `flutterfire configure --project=<id-hml> --out=lib/firebase_options_hml.dart --android-package-name=br.com.servicoconecta.hml --ios-bundle-id=br.com.servicoconecta.hml`.
- `android/app/src/hml/google-services.json` e `config/ios/GoogleService-Info-hml.plist`: baixar do console.

**Login Google**
- Ativar o provedor Google em Authentication.
- Copiar o *Web client ID* para `web/index.html` (`google-signin-client_id`).
- Adicionar o domínio do Hosting de homologação aos *domínios autorizados*.

**App**
- `config/env/hml.json` (fora do Git), a partir de `config/env/hml.example.json`.
- Chave do Maps restrita ao app hml.
- *Public key* de **teste** do Mercado Pago.

**Functions**
- `functions/.env.<id-hml>`, a partir de `functions/.env.example`, com:
  - `PAYMENTS_GATEWAY=mercadopago`
  - `PAYMENTS_ENV=sandbox`
  - `MP_TEST_USER_CREDENTIALS=true`
  - `PROD_PROJECT_IDS=servicoconecta,carajas360-a17c5`
  - `PAYMENTS_WEBHOOK_URL=https://us-central1-<id-hml>.cloudfunctions.net/paymentsWebhook`
- Segredos somente no Secret Manager:
  ```bash
  firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN --project <id-hml>   # token do usuário de TESTE
  firebase functions:secrets:set MP_WEBHOOK_SECRET --project <id-hml>
  firebase functions:secrets:set ANTHROPIC_API_KEY --project <id-hml>          # opcional (assistente)
  ```

**Mercado Pago (painel de testes)**
- Webhook do tipo *Pagamentos* para `PAYMENTS_WEBHOOK_URL`.
- A assinatura gerada vai para `MP_WEBHOOK_SECRET`.
- O app não usa URLs de retorno: Pix e cartão são concluídos dentro do app, e a confirmação chega só pelo webhook ou pela conciliação.

**Notificações push**
- Android: o FCM funciona com o `google-services.json` do flavor hml.
- iOS: chave APNs (.p8) cadastrada no console do Firebase (Project settings → Cloud Messaging).

## 2. Ordem de implantação

```bash
git tag hml-$(date +%Y%m%d-%H%M)            # ponto de reversão
firebase use <id-hml>
firebase deploy --project <id-hml> --only firestore:indexes   # aguardar "Enabled" no console
firebase deploy --project <id-hml> --only firestore:rules,storage
firebase deploy --project <id-hml> --only functions
```

Depois, publicar o web:

```bash
flutter build web --release --dart-define-from-file=config/env/hml.json
firebase deploy --project <id-hml> --only hosting
```

O Android e o iOS são gerados pelo CI (veja `BUILD_MOBILE.md`).

### 2.1 Pelo GitHub Actions (recomendado): `.github/workflows/deploy-hml.yml`

Implanta a mesma sequência acima. Só roda manualmente: *Actions → Implantar em HOMOLOGAÇÃO (manual) → Run workflow*.

**Proteções:**
- O projeto precisa conter `hml`/`homolog`/`staging` e não pode ser `servicoconecta` nem `carajas360-a17c5`.
- O ID do projeto tem que ser digitado de novo em "confirmar".
- A conta de serviço tem que ser do mesmo projeto.
- `tool/check_hml_config.js --deploy` precisa sair sem pendências: nenhum arquivo modelo e `projectId` igual ao alvo.
- O web de homologação recebe `X-Robots-Tag: noindex`.

**Configuração única (você):**
1. Em *Settings → Environments*, crie o environment `homologacao`. Opcionalmente, exija aprovação de um revisor antes de cada execução.
2. Cadastre nesse environment os secrets abaixo. Nenhum valor fica no Git nem aparece no log.

| Secret | Conteúdo |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_HML` | JSON da conta de serviço do projeto hml. Papéis: Firebase Admin, Cloud Functions Admin, Service Account User, Secret Manager Viewer |
| `HML_FIREBASE_OPTIONS_DART` | Saída do `flutterfire configure` (`lib/firebase_options_hml.dart`) |
| `HML_ENV_JSON` | `config/env/hml.json`: chave do Maps e *public key* de **teste** do Mercado Pago |
| `HML_FUNCTIONS_ENV` | `functions/.env.<id-hml>` (§1), sem segredos |
| `HML_GOOGLE_WEB_CLIENT_ID` | *Web client ID* do login Google |

Os segredos das Functions continuam no Secret Manager (§1).

**Execução:**
- Em `alvo`, escolha `tudo`, `backend` ou `web`.
- No fim, o resumo do job mostra o link `https://<id-hml>.web.app`.
- Antes de rodar, crie a tag de reversão (`hml-AAAAMMDD-HHMM`).

O `firebase.json` agora tem a seção `hosting`, servindo `build/web` com *rewrite* de SPA e cabeçalhos de segurança. Sem ela, o `--only hosting` acima falhava.

As tarefas agendadas sobem junto com as Functions (Cloud Scheduler):

| Tarefa | Frequência |
|---|---|
| `expireBookingHolds` | 5 min |
| `paymentsMaintenance` | 10 min |
| `autoConfirmServiceOrders` | 60 min |
| `marketReleaseDue` | 60 min |
| `rentalMaintenance` | 60 min |
| `cleanupOldOrders` | 24 h |

## 3. Pós-implantação (admin master, pelo app ou por um script com a credencial de serviço do hml)

1. Rodar as migrações, primeiro com `{dryRun: true}` e depois de verdade:
   - `migratePhase1Privacy`
   - `migrateCatalogV1`
   - `migratePublicProfiles`
   - `migrateReviewAuthors`
2. Definir as reservas: `updateBookingConfig({holdMinutes: 15, maxPendingPerClient: 3})`.
3. Preencher os contatos de suporte reais em `config/platform` (`supportEmail`, `supportPhone`), pelo painel admin com um admin master. Enquanto estiverem vazios, o app mostra só "abra um chamado".
4. Criar as contas de teste:
   ```bash
   GOOGLE_APPLICATION_CREDENTIALS=<sa-hml.json> node tool/seed_hml_accounts.js --project <id-hml>
   ```
   As senhas aparecem uma única vez no terminal. Guarde-as num cofre de senhas e compartilhe por ele, nunca por chat ou e-mail.
5. Fazer o *smoke test*, conforme `REGISTRO_PENDENCIAS.md` § Roteiro manual.

## 4. Reversão

| O que | Como |
|---|---|
| Functions | `git checkout <tag-anterior> && (cd functions && npm ci) && firebase deploy --project <id-hml> --only functions` |
| Regras | Console do Firestore → Regras → histórico → publicar a versão anterior; ou `firebase deploy --only firestore:rules,storage` a partir da tag anterior |
| Índices | Índices a mais não quebram nada; não precisa remover |
| Web | Console do Firebase → Hosting → histórico de versões → *Reverter* na versão anterior; ou rodar o workflow com `alvo = web` a partir da tag anterior |
| Android/iOS | Reinstalar o APK/IPA do build anterior (artefatos do CI por 30 dias) |

**Antes de voltar as Functions para uma versão anterior a esta entrega:**
1. Ligue o **modo manutenção** (`config/platform.maintenanceMode = true`). Novas reservas e pagamentos param.
2. Aguarde o prazo das retenções (15 min) e rode `adminRunMaintenance({jobs: ['expireBookingHolds']})`.
3. Confira no painel financeiro se há pagamento aprovado de reserva sem confirmação e reembolse pelo painel.

Isso é necessário porque as versões anteriores não conhecem os estados `pending_payment`/`expired` das consultas e reservas, nem os tipos de cobrança `health`/`rental`. Um webhook de uma dessas cobranças falharia e ficaria em nova tentativa.

Por último, desligue o modo manutenção.

## 5. Dependências (estado atual)

- `firebase-functions` 7.4 com a API **v1** explícita (`require('firebase-functions/v1')`), sem migração para v2.
- `firebase-admin` 13.10. A versão 14 removeu a API `admin.firestore()`/`admin.auth()`, usada em todo o servidor, e exige Node 22 também no runtime.
- `npm audit --omit=dev`: 8 alertas **moderados**, todos de `uuid@9` (via `google-gax`, `gaxios` e `teeny-request`). O alerta (GHSA-w5hq-g745-h8pq) cobre `v3/v5/v6` com o parâmetro `buf`. Essas bibliotecas só chamam `uuid.v4()`, então o código não está exposto. O alerta some quando o firebase-admin trouxer google-gax/gaxios com uuid ≥ 11.
