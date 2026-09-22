# CARAJAS360_RELATORIO_FASE3.md

**Data:** 2026-09-22
**Ambiente auditado:** Homologacao / staging (branch `cursor/bloco-a-security-staging-c199`)
**Producao:** NAO ativada · NAO publicada (Play/App Store)
**Backup pre-fase3:** `eafbf5b`
**Base Fase 2:** `4aa8dc1`

---

## 1. Resumo executivo

Auditoria pre-producao focada em seguranca, financeiro, LGPD e preparacao — **sem** novas features comerciais e **sem** pagamentos reais.

### GATE DE APROVACAO

**🟡 APTO PARA HOMOLOGAÇÃO FINAL**

Nenhum bloqueador P0 de codigo aberto apos correcoes desta fase. Producao **nao** autorizada.

Motivos para nao ir a producao ainda:
- Firebase `COLE_SUA_*` / placeholders
- `PAYMENTS_ENABLED=false` (correto) — webhook ainda nao aplica credito
- App Check off
- E2E nativo Android/iOS majoritariamente NOT TESTED
- Secrets reais / claims admin: CONFIGURACAO EXTERNA

---

## 2. Arquitetura encontrada (mapa real)

```
APP FLUTTER (carajas_360 / br.com.carajas360)
    ↓
Firebase Auth + Firestore + Storage + Cloud Functions (us-central1)
    ↓
Hosting (build/web + /privacy + /terms)
    ↓
Mercado Pago API (callables + webhook sandbox)
    ↓
FCM + Analytics + Crashlytics
    ↓
Painel Admin (AdminGate + config/platform)
```

**Nao existe:** Asaas, split gateway nativo, SQL/Postgres.

**Projeto:** `carajas360-a17c5`  
**URLs legais:** `https://carajas360-a17c5.web.app/privacy|terms`  
**Functions:** `https://us-central1-carajas360-a17c5.cloudfunctions.net`

---

## 3. Pendencias Fase 2 (status)

| Pendencia F2 | Status F3 |
|--------------|-----------|
| PAYMENTS_ENABLED + token MP | CONFIGURACAO EXTERNA |
| Webhook aplica credito | Ainda stub (by design ate owner ligar) |
| Deploy Functions unlock | CONFIGURACAO EXTERNA |
| E2E nativo | NOT TESTED |
| Contas teste | DECISÃO DO PROPRIETARIO |

---

## 4. Seguranca — achados e correcoes

### P0 encontrados

| ID | Descricao | Evidencia | Correcao | Status |
|----|-----------|-----------|----------|--------|
| P0-01 | IDOR perfil via criar chatRoom + sharesChat | firestore.rules users get | Removido `sharesChat` do allow get | **CORRIGIDO** |
| P0-02 | Firebase placeholders | firebase_options / google-services | — | **ABERTO** (CONFIG EXTERNA) |

### P1 encontrados

| ID | Descricao | Correcao | Status |
|----|-----------|----------|--------|
| P1-01 | Comissao Admin != payout server | canPayout + applyOfficialPayout leem config/platform; snapshot commissionRate no pedido | **CORRIGIDO** |
| P1-02 | unlockLead sem papel profissional | Exige providers/{uid} ativo + request open + slots atomicos | **CORRIGIDO** |
| P1-03 | Webhook nao aplica credito | — | **ABERTO** (by design ate PAYMENTS_ENABLED) |
| P1-04 | App Check off | — | **ABERTO** (DECISÃO OWNER) |
| P1-05 | Saque walletOp sem PIX out | — | **ABERTO** (DECISÃO OWNER) |
| P1-06 | Emails @servicoconecta | — | **ABERTO** (DECISÃO OWNER) |

### P2 / P3 (resumo)

- Resolve open legivel: P2 aceito (marketplace) — DECISÃO OWNER se restringir
- disputes sem rules → **CORRIGIDO** (rules adicionadas)
- Relatorio financeiro usava AppConst fixo → **CORRIGIDO** (usa config + snapshot)
- Consentimento OAuth fraco: P2
- Expurgo LGPD 5 anos nao automatizado: P3

---

## 5. Autenticacao / Autorizacao

- Papéis: client / provider / deliverer / company; admin via claim OU type
- Escalacao self-service para admin: bloqueada nas rules
- DEV_BYPASS: so debug/profile
- AdminGate UI + isAdmin server nas callables criticas
- IDOR chat→perfil: corrigido
- Testes manuais completos de sessao/refresh: **NOT TESTED** em device

---

## 6. Financeiro / Creditos / Lead / Webhook

- Ledger: wallets + transactions (write client false)
- Unlock: idempotente + custo server-side + slots
- Homolog: SharedPreferences (nao mistura producao se placeholders)
- Comissao: default 0.08; Admin 0–30%; payout usa Admin
- Split: interno (payout), nao Asaas
- Webhook MP: HMAC + charged/applied false
- PAYMENTS_ENABLED=false

---

## 7. LGPD

- deleteMyAccount + exportacao no perfil: implementados
- privacy/terms hosting: existem
- Checkbox termos no cadastro email: sim
- OAuth: aviso textual apenas
- Emails legais residuais servicoconecta

---

## 8. Secrets

- Nenhum secret de producao encontrado no Git
- Placeholders Firebase presentes
- functions/.env.example so nomes
- Se secret real for encontrado no futuro: **ROTACIONAR**, nao so apagar

---

## 9. Android / iOS

- applicationId / bundle: `br.com.carajas360`
- Build release Homolog: **NOT TESTED** nesta sessao (auditoria codigo)
- Nao publicar

---

## 10. Testes E2E (matriz honesta)

| ID | Cenario | Resultado |
|----|---------|-----------|
| E2E-01 cadastro cliente | NOT TESTED | |
| E2E-02 cadastro profissional | NOT TESTED | |
| E2E-03 criacao servico | NOT TESTED | |
| E2E-04 matching | PASS (unit Fase1/2) | |
| E2E-05 desbloqueio creditos | PASS (unit homolog + CF review) | |
| E2E-06 proposta | NOT TESTED (device) | |
| E2E-07 aceite | NOT TESTED | |
| E2E-08 pagamento Sandbox | NOT TESTED (PAYMENTS off) | |
| E2E-09 comissao | PASS (orderPolicy node) | |
| E2E-10 split | PASS (payout interno / unit) | |
| E2E-11 conclusao | NOT TESTED | |
| E2E-12 avaliacao | NOT TESTED | |
| E2E-13 cancelamento | NOT TESTED | |
| E2E-14 reembolso | NOT TESTED | |
| E2E-15 PRO | NOT TESTED (homolog UI) | |
| E2E-16 patrocinado | NOT TESTED | |
| E2E-17 webhook duplicado | PASS (codigo idempotente / sandbox stub) | |
| E2E-18 IDOR | PASS (rules fix + review) | |
| E2E-19 acesso Admin | NOT TESTED (device) | |
| E2E-20 alteracao comissao Admin | PASS (validacao + payout le config) | |

**Regressao unitaria (Fase1/2) — executada nesta fase:**

| Suite | Resultado |
|-------|-----------|
| Flutter `monetization` + `universal_search` + `homolog_catalog` + `service_marketplace` | **32 PASS** |
| Node `functions` (orderPolicy, security, webhook, escrow, blocoE, …) | **93 PASS / 0 FAIL** |
| Commission override verify (Node) | 10% → 50/450; default 8% → 40/460 |

---

## 11. Contagens

**TOTAL PASS (E2E matriz):** 7  
**TOTAL FAIL (E2E matriz):** 0  
**TOTAL NOT TESTED (E2E matriz):** 13  
**Unitarios Flutter:** 32 PASS  
**Unitarios Node:** 93 PASS  
**P0 ABERTOS:** 1 (P0-02 Firebase placeholders — CONFIG EXTERNA; nao e falha de codigo desta fase)  
**P1 ABERTOS:** 4 (webhook apply, App Check, saque PIX, emails)  
**P2 ABERTOS:** varios menores (ver pendencias)  
**P3 ABERTOS:** varios

---

## 12. Arquivos alterados nesta Fase 3

- firestore.rules (IDOR chat + disputes)
- functions/orderPolicy.js (commissionRate)
- functions/index.js (payout config + unlock hardening)
- lib/shared/services/firestore_facade.dart (relatorio financeiro)
- docs/CARAJAS360_RELATORIO_FASE3.md
- docs/CARAJAS360_PENDENCIAS_FASE3.md
- docs/CARAJAS360_CHECKLIST_PRODUCAO.md

---

## 13. O que impede a proxima fase / producao

1. Configurar Firebase real (remover placeholders)
2. Decidir e configurar PAYMENTS_ENABLED + secrets MP TEST
3. Deploy rules + functions
4. App Check enforcement (decisao)
5. Executar E2E device Android/iOS
6. Contas de teste homolog documentadas fora do Git

**Nao usar “pronto para producao”.**
