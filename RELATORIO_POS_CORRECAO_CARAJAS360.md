# Relatório pós-correção — Carajás 360

**Branch:** `cursor/bloco-a-security-staging-c199`  
**PR:** https://github.com/draraiany-source/Carajas360/pull/1  
**HEAD na entrega F:** `2d70e80` (+ commits deste bloco)  
**Base:** `main` (`5013dcd`)  
**Blocos cobertos:** A (1–10) · B (11–13) · C (14–19) · D (20–24) · E (25–30) · F (31)  
**Data:** 2026-09-18  

**Não é publicação.** Sem Play Store, App Store, pagamento real, keystore no Git ou merge em `main`.

> **Atualização pós-F (IDs):** a Raiany autorizou a migração de IDs no código. Valores atuais: Dart `carajas_360`, Android/iOS `br.com.carajas360`, Firebase `carajas360-a17c5`. Placeholders `COLE_SUA_…` permanecem. E-mails `@servicoconecta.com.br` são residual A. Ver `IDENTIDADE_TECNICA.md`.

---

## CLASSIFICAÇÃO FINAL

# STAGING READY

Pode testar com segurança em **staging** depois que a Raiany colar os arquivos Firebase de staging (veja o checklist no fim). **Não publicar** lojas nem ligar `PAYMENTS_ENABLED`.

**Por que não BLOCKED**  
Pedidos, carteira, pagamentos, rules e Functions financeiras públicas foram endurecidos. Fraude clássica (preço, providerId, double charge, payout duplo, Function sem auth) está coberta por policy + rules + testes. O app **release** recusa placeholder Firebase de propósito.

**Por que não RELEASE CANDIDATE**  
Ainda faltam credenciais essenciais (Firebase/Maps reais), App Check sem enforce, keystore, projeto Xcode, URL de privacidade e emulador de rules. Directions ainda no client. Flutter não foi analisado neste agente (CI GitHub sim). RC exigiria isso resolvido **e** ausência de vuln crítica/alta conhecida — não é o caso.

---

## 1. Resumo executivo

O Carajás 360 (IDs técnicos atuais `carajas_360` / `br.com.carajas360` / Firebase `carajas360-a17c5`; e-mails ainda `@servicoconecta.com.br`) saiu de um estado em que o client escrevia dinheiro e as Functions HTTP de pagamento existiam, para um núcleo **staging-safe**:

- Máquina de estados de pedido + payout idempotente no backend.
- Client **não** grava wallet, payment, XP, plan, verified.
- HTTP financeiro público = **410**.
- Exclusão LGPD = anonimizar + retenção 5 anos (não apagar fiscal).
- Pagamentos **desligados** (`PAYMENTS_ENABLED=false`).
- DemoData **só debug**.
- CI: Functions + analyze Flutter + audit estático de rules.

O produto **não** está pronto para loja. Está pronto para a Raiany ligar um projeto Firebase de **staging**, instalar o app em debug e exercitar fluxos **sem cobrança**.

---

## 2. Problemas encontrados (antes / durante A–E)

| Área | Problema |
|---|---|
| Pedidos / dinheiro | Client podia escrever preço, status, payout; payout sem idempotência |
| Functions | Endpoints HTTP de PIX/cartão/IA públicos |
| Rules | Superfície larga; wallets/payments graváveis ou catch-all fraco |
| Admin | Rotas sem gate real; `adminRole` sozinho |
| LGPD | “Delete” incompleto ou hard-delete inseguro |
| CPF / XP | Validação fraca; XP no client |
| Identidade | Nome Carajás 360 vs IDs `servicoconecta` misturados |
| Assets | SVG/imagens quebrando UI |
| Firebase / Maps | Keys no client ou inventáveis |
| Pagamentos | Sem abstração; risco de ligar produção |
| Node Functions | Runtime 18 (Gen1) |
| UX | Perfil/chat/pedidos vazios sem login; DemoData no lugar do backend |
| Serviço único | `firebase_service.dart` monolítico |
| CI | Sem pipeline |
| Release | Sem checklist; iOS sem Xcode project; sem keystore |
| Observabilidade | Snacks com `$e`; auditoria furada (aprovação prestador, login admin) |
| Webhook MP | Inexistente ou perigoso se aplicado cego |

---

## 3. Problemas corrigidos

| Bloco | Correção |
|---|---|
| A | `transitionOrder` / `processPayout` / `payOrderWithWallet` autenticados; payout único; rules wallets/payments write false; AdminGate; testes de fraude |
| A | HTTP `generatePixHttp` etc. → 410 |
| B | `deleteMyAccount` anonimiza; retenção 5 anos; CPF com dígitos; XP só `xpEvents` |
| C | Checklists Firebase/Maps/pagamentos; `PaymentGateway`; `requestPlanChange` sandbox (`charged/applied` false); Node **20**; SafeSvg; display Carajás 360 **sem** mudar IDs; App Check **opt-in** |
| D | Barrel + fachadas; CTA login; endereço dedicado; DemoData debug-only; GitHub Actions; testes AUTH/USERS/PROVIDERS/ORDERS/PAYMENTS/WALLET/ADMIN/REVIEWS/NOTIFICATIONS; stub webhook |
| D/E | CI Flutter: export `CloudCallException`; analyze não falha em warning antigo |
| E | Checklists Android/iOS; backlog P0–P3; OCR só doc; `auditLog.js`; `AppError`/`ErrorWidget`; webhook HMAC sem aplicar; `getDirections` sem chamar Google |

Functions locais ao fechar E: **82/82**.

---

## 4. Problemas pendentes (código / processo)

| Item | Severidade | Por que ficou |
|---|---|---|
| Placeholders Firebase / Maps / MP public | Alta p/ **rodar** staging real | Não inventar secrets |
| App Check enforce off | Alta p/ **produção** | Sem keys Play Integrity / DeviceCheck |
| Directions HTTP no client | Alta se key real irrestrita | Callable pronta; GPS ainda não migrou (key servidor ausente + cobrança Maps) |
| Rules só audit estático | Média | Emulador + Java não no CI |
| `firestore_facade.dart` ~1694 linhas | Média | Split progressivo; corpo não movido |
| PIX QR demo se gateway off | Média (UX) | Não credita; pode confundir tester |
| `Runner.xcodeproj` ausente | Alta p/ **iOS** | Não recriar no agente (risco de sobrescrever) |
| Keystore / `key.properties` | Alta p/ **Play** | Propositalmente fora do Git |
| URL pública de privacidade | Alta p/ **loja** | Não inventar domínio |
| Job de expurgo LGPD após 5 anos | Baixa | Só documentado |
| Refund MP de verdade | Média | Staging marca `refunded` sem API MP |
| Flutter analyze local | — | SDK ausente no agente; CI GitHub |

Nenhum destes autoriza ligar pagamento real ou publicar.

---

## 5. Problemas que dependem da proprietária (Raiany)

1. Projeto Firebase **staging** `carajas360-a17c5` + cadastrar apps `br.com.carajas360` + baixar `google-services.json`, `GoogleService-Info.plist`, `flutterfire configure --project=carajas360-a17c5` (`IDENTIDADE_TECNICA.md`).
2. SHA-1/256 debug (e depois upload) no Firebase.
3. Ativar Auth: e-mail, Google, Apple, telefone.
4. Deploy **staging** de rules + Functions (`PAYMENTS_ENABLED=false`).
5. Maps: keys **restritas** (Android/iOS SDK + Directions). Key de **servidor** só se for ligar o proxy (hoje o proxy **não** chama Google).
6. Mercado Pago **TEST-** no Secret Manager **somente** se ela quiser exercitar PIX sandbox — **não** ligar `PAYMENTS_ENABLED` sem alinhamento.
7. `MERCADOPAGO_WEBHOOK_SECRET` se for testar HMAC (continuar sem aplicar crédito).
8. Keystore de upload **na máquina dela** — nunca no Git.
9. Restaurar `ios/Runner.xcodeproj` + Team + APNs.
10. URL pública da política de privacidade.
11. App Check (Play Integrity / DeviceCheck / reCAPTCHA) **depois** dos apps reais; só então `ENFORCE_APP_CHECK=true`.
12. **Não** merge em `main` até revisar este PR.

Checklist operacional no **final deste arquivo**.

---

## 6. Arquivos alterados (A–F vs `main`)

15 commits, ~96 arquivos, +9800 / −2700 linhas (ordem de grandeza).

**Functions / rules:** `functions/index.js`, `orderPolicy.js`, `security.js`, `accountDeletion.js`, `planChange.js`, `auditLog.js`, `webhookSandbox.js`, `directionsProxy.js`, `*.test.js`, `firestore.rules`, `storage.rules`.

**App:** `lib/shared/services/*` (barrel + fachadas + `firestore_facade.dart`), `access_control.dart`, `demo_data.dart`, `app_error.dart`, `app_telemetry.dart`, `runtime_config.dart`, `firebase_bootstrap.dart`, telas perfil/chat/pedidos/wallet/admin/resolve, `main.dart`.

**CI / docs:** `.github/workflows/ci.yml`, `ANDROID_RELEASE_CHECKLIST.md`, `IOS_RELEASE_CHECKLIST.md`, `BACKLOG_FASE_2.md`, `OCR_DOCUMENTOS.md`, `CHECKLIST_FIREBASE_STAGING.md`, `CHECKLIST_GOOGLE_MAPS.md`, `PAGAMENTOS_STAGING.md`, `IDENTIDADE_TECNICA.md`, `LGPD_DATA_RETENTION.md`, `BLOCO_E.md`, `BLOCO_F.md`, este relatório.

IDs **migrados de propósito** (pós-F, autorização da Raiany): `carajas_360`, `br.com.carajas360`, `carajas360-a17c5`. E-mails `@servicoconecta.com.br` e npm `servicoconecta-functions` ficaram como residual A.

---

## 7. Firestore Rules

Deny-by-default (`match /{document=**}` → `read, write: if false`).

| Recurso | Client |
|---|---|
| `wallets` | write **false** |
| `payments` / `transactions` | write **false** |
| `users` delete | **false** |
| `plan` / `xp` / `type` / `verified` | bloqueados no update do dono |
| `xpEvents` / `rateLimits` | read/write **false** |
| `planChangeRequests` | write **false** |
| `financialAudits` / `legalRetention` | write **false** |
| `auditLogs` | create só admin |

CI: `functions/firestoreRules.audit.js` (estático). **Sem** `@firebase/rules-unit-testing` no runner.

---

## 8. Functions

Runtime **Node 20** (Gen1). Auth + App Check **opcional** (`ENFORCE_APP_CHECK=false`).

**Callables:** `transitionOrder`, `processPayout`, `payOrderWithWallet`, `generatePix`, `checkPayment`, `processCardPayment`, `aiAssistant`, `walletOp`, `createNotification`, `processRefund`, `requestPlanChange`, `deleteMyAccount`, `switchProfileType`, `getDirections`.

**HTTP:** PIX/cartão/IA → **410**. `mercadoPagoWebhook` → 501/401/202, **`charged:false` `applied:false`**.

**Triggers:** FCM, rating, XP signup, sanitize PII, notifies Resolve/booking. **Schedule:** `cleanupOldOrders` (cancela expirados — não apaga financeiro).

`getDirections` **não** chama Maps (evita cobrança). Sem `GOOGLE_MAPS_SERVER_KEY` recusa.

---

## 9. Autenticação

E-mail/senha, Google, Apple (plataforma Apple), telefone OTP.  
`RequireAuth` / EmptyState nas rotas de dinheiro, chat, pedidos, reviews, Resolve autenticado, prestador, etc.  
`AdminGate`: claim `admin` **ou** `users.type==admin`. `adminRole` sozinho **não** passa.  
Login admin gera `auditLogs.admin_login` (uma vez por sessão).  
GPS, home, marketplace, Resolve **criar** pedido ainda são visitáveis; submit exige uid.

---

## 10. Pagamentos

`PAYMENTS_ENABLED=false`. Sem token MP no Git.  
PIX/cartão recusam no backend. Carteira interna (`payOrderWithWallet`) é saldo Firestore, não MP.  
Plano: `requestPlanChange` grava pedido, **não cobra**, **não** muda `users.plan`.  
Google/Apple Pay: mensagem de “não ativado”.  
Webhook: no máximo aceita assinatura sandbox; **nunca** credita.  
QR demo na UI se o callable falha: **não é PIX válido**.

---

## 11. Carteira

Client: só stream. `credit`/`debit` no client retornam false.  
`walletOp` allowlist: `withdraw` | `cashback`.  
Payout: uma vez, comissão 15%, `financialAudits`.  
Saque mínimo R$ 10. Audit `wallet_change`.

---

## 12. LGPD

`deleteMyAccount`: anonimiza, retém pedidos/pagamentos/contratos/auditoria, congela wallet, apaga Auth por último.  
Retenção legal **5 anos** (`legalRetention`).  
Exportação pelo perfil. CPF validado no backend.  
**Não** há job automático de expurgo pós-5 anos.

---

## 13. Android

`applicationId` `br.com.carajas360`. `1.0.0+1`. R8/ProGuard no release.  
Release **não** assina debug se faltar `key.properties` (falha de propósito).  
Permissões: localização, câmera, microfone, fotos, notificações.  
`google-services.json` placeholder. Sem adaptive icon. Ver `ANDROID_RELEASE_CHECKLIST.md`.

---

## 14. iOS

Display **Carajás 360**, bundle `br.com.carajas360`.  
Privacy strings no plist. Push/Maps sem entitlements no Git.  
**`Runner.xcodeproj` ausente** — archive impossível até a Raiany restaurar.  
Plist Firebase / `GMSApiKey` / `REVERSED_CLIENT_ID` placeholders. Ver `IOS_RELEASE_CHECKLIST.md`.

---

## 15. Assets

`SafeSvg` com fallback. Splash/ícones presentes.  
Alguns SVGs do kit premium ainda são opcionais. Não bloqueia staging debug.

---

## 16. CI

`.github/workflows/ci.yml` (PR + `main` + `cursor/**`):

| Job | Comando | Papel |
|---|---|---|
| Functions | `npm ci` / lint / test | Crítico |
| Flutter | `pub get` / `analyze --no-fatal-infos --no-fatal-warnings` / `test` | Erros bloqueiam; warnings antigos não |
| Rules | `node --test firestoreRules.audit.js` | Estático |

No agente: Flutter SDK ausente. No GitHub, um job Flutter do ciclo `2d70e80` já passou; Functions/rules verdes.

---

## 17. Testes

**Functions (local): 82/82.**  
Suites: orderPolicy, security/fraude, BLOCO B (CPF/XP/LGPD), C (plan sandbox), D (AUTH…NOTIFICATIONS + webhook 501), E (audit, HMAC, Directions), rules audit.

**Flutter:** `test/financial_fraud_test.dart`, `bloco_b_lgpd_test.dart`, `bloco_c_identity_test.dart`, `bloco_d_access_test.dart`, `bloco_e_observability_test.dart`, `order_policy_test.dart`, `auth_*`, `models_test`, `widget_test`. Rodados no CI, não neste VM.

Não há teste de emulador Firestore no CI.

---

## 18. Vulnerabilidades restantes

| Sev | Item | Mitigação atual |
|---|---|---|
| Alta (prod) | Sem App Check | Flag false; não publicar |
| Alta (ops) | Placeholders Firebase | Release crash se placeholder; staging precisa arquivos reais |
| Alta (se key irrestrita) | Directions no APK | Placeholder pula HTTP; restringir key; migrar ao callable depois |
| Média | Rules sem emulador | Audit estático + policy JS |
| Média | Callables sem attestation | Auth obrigatória; rate limit em PIX |
| Média | QR PIX fake | Snack; sem crédito |
| Média | iOS/Android store | Sem xcodeproj / keystore |
| Baixa | FS monolito | Fachadas estáveis |

**Não** há Function financeira pública aberta. **Não** há write de wallet/payment no client. Isso é o que separa STAGING READY de BLOCKED.

---

## 19. Recomendações antes da publicação (loja)

1. **Não publicar agora.**
2. Staging: checklist da Raiany abaixo → smoke (login, pedido, chat, perfil, admin) **com pagamentos off**.
3. Só então: keystore, AAB interno, Xcode+TestFlight, privacidade com URL, App Check, SHA do **App signing** Play.
4. Pagamento: token `TEST-` + webhook assinado + **ainda** sem `APP_USR-`. Ligar `PAYMENTS_ENABLED` só com decisão explícita.
5. Mover Directions para Function **depois** da key de servidor + cota.
6. Emulador de rules no CI.
7. Revisar este PR; **não** merge automático em `main`.

---

## Checklist — o que a Raiany faz para deploy **staging**

Ordem sugerida. Nada disso foi executado neste agente (evita inventar secret / deploy prod).

### A. Firebase staging (obrigatório para o app falar com backend real)

- [ ] Console Firebase → projeto `carajas360-a17c5`.
- [ ] Cadastrar apps Android/iOS `br.com.carajas360` (este agente **não** registrou).
- [ ] Ativar Auth, Firestore, Storage, Functions, FCM, Crashlytics, Analytics.
- [ ] Baixar `google-services.json` → `android/app/google-services.json`.
- [ ] Baixar `GoogleService-Info.plist` → `ios/Runner/`.
- [ ] `flutterfire configure --project=carajas360-a17c5` → `lib/firebase_options.dart`.
- [ ] Colar `REVERSED_CLIENT_ID` no `Info.plist`.
- [ ] SHA-1/256 do **debug** no app Android.
- [ ] Auth: e-mail, Google, Apple, telefone.
- [ ] `firebase deploy --only firestore:rules,storage,functions` no projeto de **staging** (nunca produção por engano).
- [ ] Confirmar no Console: `PAYMENTS_ENABLED` **não** está true; `ENFORCE_APP_CHECK` false.

### B. Maps (opcional para GPS real)

- [ ] Key Android/iOS restrita por package/bundle + SHA.
- [ ] `--dart-define=GOOGLE_MAPS_API_KEY=` só em máquina local / CI secreto.
- [ ] **Não** commitar key irrestrita.

### C. Rodar o app (debug)

```bash
flutter pub get
flutter run --debug
# Sem arquivos Firebase reais: emulador
# firebase emulators:start
# flutter run --debug --dart-define=USE_FIREBASE_EMULATOR=true
```

- [ ] Login / logout.
- [ ] Perfil sem login = CTA (não vazio).
- [ ] Pedido sem pagamento real.
- [ ] Admin só com user `type=admin` ou claim.
- [ ] Release local **deve falhar** se ainda houver `COLE_SUA` no Firebase (comportamento certo).

### D. Explicitamente NÃO fazer agora

- [ ] Não `PAYMENTS_ENABLED=true`.
- [ ] Não token `APP_USR-`.
- [ ] Não criar keystore no Git.
- [ ] Não publicar Play / TestFlight produção.
- [ ] Não merge em `main` sem review.
- [ ] Não trocar IDs de volta para `br.com.servicoconecta` / `servico_conecta` / `servicoconecta` — a migração já foi autorizada (`IDENTIDADE_TECNICA.md`).

### E. Depois do staging estável (fora deste PR)

Ver `ANDROID_RELEASE_CHECKLIST.md`, `IOS_RELEASE_CHECKLIST.md`, `BACKLOG_FASE_2.md`.

---

## Veredito em uma frase

**STAGING READY:** o código deste PR é o núcleo certo para testar Carajás 360 em staging, sem cobrança e sem loja; a Raiany ainda precisa das chaves e do deploy Firebase para o binário conversar com o projeto real.
