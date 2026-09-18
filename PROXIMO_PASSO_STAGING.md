# Próximo passo — depois de STAGING READY

**PR:** https://github.com/draraiany-source/Carajas360/pull/1  
**Branch:** `cursor/bloco-a-security-staging-c199`  
**Classificação vigente:** **STAGING READY** (`RELATORIO_POS_CORRECAO_CARAJAS360.md`)  
**CI (HEAD da branch):** **verde** — 6/6 (Functions lint+test, Flutter analyze+test, Firestore rules audit). Sem job vermelho.

Sem features novas neste passo. Sem merge. Sem `PAYMENTS_ENABLED=true`. Sem inventar secrets.

---

## 1. Go / No-go do PR #1

### Verdict: **NO-GO para merge em `main` agora**

O código está **seguro para ensaio em staging**. `main` ainda é o ramo de referência do produto; misturar placeholders Firebase + App Check off + iOS sem Xcode **na default branch** não é o próximo passo. Primeiro: review humana → deploy **só no projeto Firebase de staging** a partir desta branch → smoke. Merge em `main` **depois** disso, com decisão explícita da Raiany.

| | |
|---|---|
| **Pode agora** | Review do PR; `firebase deploy` de rules/storage/functions **no projeto staging** (não produção); `flutter run --debug` com arquivos Firebase reais de staging. |
| **Não pode agora** | Merge em `main`; Play/App Store; `PAYMENTS_ENABLED=true`; AAB/archive. |

### Blockers reais (impedem merge/`main` e loja)

1. `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart` ainda **placeholder** (`COLE_SUA_…`). Release crash se publicar assim.
2. App Check **não** enforce (`ENFORCE_APP_CHECK=false`, sem plugin/keys).
3. `ios/Runner.xcodeproj` **ausente** — iOS não arquiva.
4. Keystore / `key.properties` **fora do Git** (certo) e **ainda não gerados** na máquina da Raiany — Android release não assina.
5. Sem URL pública de privacidade.
6. Staging Firebase **ainda não validado** com smoke (este agente não fez deploy).

### Nice-to-have (não bloqueiam o ensaio staging)

- Mover Directions do client para Function (callable já recusa; GPS ainda HTTP).
- Rules no emulador no CI (hoje: audit estático).
- Mover o corpo de `FS` (~1694 linhas) para as fachadas.
- Adaptive icon Android; entitlements iOS; job de expurgo LGPD 5 anos.
- Refund/split Mercado Pago de verdade.

---

## 2. Review humana — o que olhar

Dez pontos. Uma verificação cada.

| # | Onde | Verificar |
|---|---|---|
| 1 | `firestore.rules` | `wallets`/`payments`/`transactions` **write false**; `users` delete false; `plan`/`xp` protegidos; catch-all deny. |
| 2 | `storage.rules` | Upload só do dono; paths `providers/{uid}/…`; sem write público. |
| 3 | `functions/index.js` + `orderPolicy.js` | `transitionOrder`/`processPayout` exigem auth; payout idempotente; HTTP PIX/cartão = **410**. |
| 4 | `functions/index.js` (`generatePix`, `processCardPayment`, `requirePaymentsGateway`) | Sem token + `PAYMENTS_ENABLED` false → recusa; **não** credita. |
| 5 | `functions/webhookSandbox.js` | Mesmo HMAC válido: `charged:false`, `applied:false`. |
| 6 | `functions/accountDeletion.js` + `deleteMyAccount` | Anonimiza; **não** apaga pedidos/pagamentos; retenção 5 anos. |
| 7 | `lib/core/auth/access_control.dart` | `AdminGate`: claim admin **ou** `type==admin`; `adminRole` sozinho **não** passa. |
| 8 | `lib/core/utils/demo_data.dart` | `enabledFor(releaseMode: true)` sempre false; `orEmpty` não substitui `[]` real. |
| 9 | `functions/.env.example` + `PAGAMENTOS_STAGING.md` | `PAYMENTS_ENABLED=false`; nenhum `APP_USR-` / access token no Git. |
| 10 | `lib/shared/services/firestore_facade.dart` (`credit`/`debit`/`saveUser`) | Client não grava saldo, XP, plan, `verified`. |

---

## 3. Deploy staging — ordem exata (Raiany)

Confirme no Console que o projeto é **staging** (`carajas360-a17c5`). IDs do app: `br.com.carajas360`. Ver `IDENTIDADE_TECNICA.md` e `CHECKLIST_FIREBASE_STAGING.md`.

### 3.1 Arquivos de cliente

1. Firebase Console → cadastrar apps Android e iOS **`br.com.carajas360`** no projeto `carajas360-a17c5` (este agente **não** registrou).
2. Ativar: Authentication, Firestore, Storage, Functions, FCM, Crashlytics, Analytics. **App Check depois** (passo 3.2).
3. Baixar `google-services.json` → `android/app/google-services.json`.
4. Baixar `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`.
5. Na máquina com Flutter:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=carajas360-a17c5
   ```
   Isso substitui `lib/firebase_options.dart`.
6. Copiar `REVERSED_CLIENT_ID` do plist para `ios/Runner/Info.plist` (`CFBundleURLSchemes`).
7. SHA-1 e SHA-256 do **debug** no app Android (Firebase → fingerprints).
8. Auth: e-mail/senha, Google, Apple, telefone.

### 3.2 Secrets / env (Functions)

No **Secret Manager / env do projeto staging** (nunca no Git):

| Nome | Valor agora |
|---|---|
| `PAYMENTS_ENABLED` | **`false`** |
| `ENFORCE_APP_CHECK` | **`false`** até Play Integrity / DeviceCheck reais |
| `MERCADOPAGO_ACCESS_TOKEN` | **não preencher** (ou só `TEST-` se for experimentar PIX depois — **ainda assim** deixar `PAYMENTS_ENABLED=false`) |
| `ANTHROPIC_API_KEY` | opcional; só se for testar o assistente |
| `MERCADOPAGO_WEBHOOK_SECRET` / `GOOGLE_MAPS_SERVER_KEY` | **não inventar**; webhook/Directions já recusam sem secret |

### 3.3 Deploy backend (staging)

Na pasta do repo, **logada no projeto staging** (`firebase use` / `.firebaserc`):

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage,functions
```

Confirme no Console: Functions Node **20**; `PAYMENTS_ENABLED` não true; HTTP `generatePixHttp` responde **410**.

### 3.4 Maps (GPS real; senão pule)

1. Key Android: package `br.com.carajas360` + SHA debug; só Maps SDK Android.
2. Key iOS: bundle `br.com.carajas360`; só Maps SDK iOS.
3. `android/local.properties` → `MAPS_API_KEY=…` (arquivo gitignored).
4. iOS: `GMSApiKey` no plist **sem** commitar key irrestrita.
5. Debug:
   ```bash
   flutter run --debug --dart-define=GOOGLE_MAPS_API_KEY=AIza…   # key restrita, local
   ```
6. **Não** ligar o HTTP `getDirections` no servidor (evita cobrança Maps). Sem key, o GPS já cai em linha reta.

### 3.5 Smoke tests manuais (pagamentos off)

```bash
flutter pub get
flutter run --debug
```

| # | Fluxo | Resultado esperado |
|---|---|---|
| 1 | Abrir Perfil/Chat/Pedidos **sem** login | CTA Entrar; **não** lista fake de produção |
| 2 | Login e-mail (e Google se SHA ok) / logout | Sessão ok; erro de rede genérico, sem stack |
| 3 | Solicitar serviço (endereço) | Pedido `pending`; **não** dá para o client mudar `price`/`providerId` no Firestore |
| 4 | Abrir `/admin` com user comum | “Acesso negado”; sem painel |
| 5 | Carteira / PIX | Callable recusa ou QR **demo** com aviso; saldo **não** sobe sozinho |
| 6 | Exclusão de conta — **mindset dry-run** | Ler `LGPD_DATA_RETENTION.md`. Se for testar de verdade: **conta descartável**. Confirmar: perfil anonimizado; pedidos/pagamentos **ainda existem**; Auth some. **Não** usar conta real da Raiany. |

Release com `COLE_SUA` no Firebase **deve falhar** — isso é correto.

---

## 4. NÃO fazer ainda

- Merge cego do PR #1 em `main`.
- Play Store / App Store / TestFlight de produção.
- `PAYMENTS_ENABLED=true`.
- Token Mercado Pago `APP_USR-` (produção).
- Versionar `key.properties`, `.jks`, `google-services.json` de **produção**, APNs `.p8`, debug token de App Check.
- Criar keystore **neste** repositório/CI.
- `ENFORCE_APP_CHECK=true` antes das keys reais (quebra todas as callables).
- Trocar `applicationId` / bundle / `projectId` sem `IDENTIDADE_TECNICA.md`.
- Inventar Maps/MP/Firebase keys.
- OCR pago, voz/vídeo, Google/Apple Pay, SMS/WhatsApp (`BACKLOG_FASE_2.md`).
- Chamar Directions Google na Function (cobrança).

---

## 5. Critério para RELEASE CANDIDATE

Só sair de **STAGING READY** quando **todos** abaixo estiverem verdes. Até lá, **não** é RC.

- [ ] Arquivos Firebase **reais** de staging no app; debug smoke (secção 3.5) passou.
- [ ] `PAYMENTS_ENABLED` continua **false** até decisão explícita; se PIX sandbox: só token `TEST-`.
- [ ] App Check registrado (Play Integrity + DeviceCheck) **e** enforce só depois de um build interno ok.
- [ ] Keystore de upload gerado **fora do Git**; `bundleRelease` local ok (não publicar).
- [ ] `Runner.xcodeproj` restaurado; Team; Push; archive de teste.
- [ ] URL pública de privacidade.
- [ ] Maps keys **restritas**; Directions client sem key irrestrita.
- [ ] CI da branch **verde** (hoje: sim, 6/6).
- [ ] Review humana dos 10 itens da secção 2.
- [ ] Sem Function financeira HTTP aberta (já 410) e sem write de wallet no client (já false).
- [ ] Decisão da Raiany: merge em `main` **depois** do staging validado — não antes.

Referências: `CHECKLIST_FIREBASE_STAGING.md`, `CHECKLIST_GOOGLE_MAPS.md`, `PAGAMENTOS_STAGING.md`, `ANDROID_RELEASE_CHECKLIST.md`, `IOS_RELEASE_CHECKLIST.md`, `BLOCO_F.md`.
