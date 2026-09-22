# CARAJAS360_RELATORIO_FASE4_RC1.md

**Data:** 2026-09-22
**Versao auditada:** 1.0.0-rc1 (build +401)
**Branch:** release/carajas360-rc1
**Backup pre-fase4:** 43dae2c
**Base Fase 3:** a2ad7ef
**ROTATION_REQUIRED:** false

---

## 1. Resumo executivo

Fase 4 corrigiu achados P1 de codigo (webhook apply idempotente, saque honesto, comissao sem cobranca dupla, emails, consentimento OAuth, rules) e preparou artefatos RC1.

### GATE RC1

**ORANGE RC1 BLOQUEADO** para criterio estrito de homologacao completa porque:
- Pagamento Sandbox gateway E2E-08: NOT TESTED (PAYMENTS_ENABLED=false)
- Fluxo principal E2E device: majoritariamente NOT TESTED
- Build Android release assinado: NOT TESTED nesta sessao (placeholders Firebase)

Codigo financeiro/seguranca unitario: PASS. Nao ha P0 de codigo aberto.
RC1 = candidato parcial; **nao e producao**.

---

## 2. Correcoes

| ID | Sev | Problema | Correcao | Teste | Status |
|----|-----|----------|----------|-------|--------|
| P0-01 | P0 | IDOR chat | Fase 3 | rules | CORRIGIDO |
| P0-02 | P0 | Firebase placeholders | Homolog mode + CONFIG EXTERNA | placeholders test | CONFIG EXTERNA (nao bloqueia codigo RC1) |
| P1-01 | P1 | Comissao Admin | Fase 3 + snapshot F4 | node | CORRIGIDO |
| P1-02 | P1 | Unlock profissional | Fase 3 + rate limit | code | CORRIGIDO |
| P1-03 | P1 | Webhook apply | webhookApply + index | node idempotencia | CORRIGIDO (gate PAYMENTS_ENABLED) |
| P1-04 | P1 | App Check | Mantido off | — | DECISÃO OWNER |
| P1-05 | P1 | Saque sem PIX | pending_manual_payout | code + UI | CORRIGIDO |
| P1-06 | P1 | Emails servicoconecta | @carajas360.com.br | flutter identity | CORRIGIDO (DNS CONFIG) |
| P2 | P2 | OAuth consent | Dialogo login | code | CORRIGIDO |
| F4 | P1 | Cobranca dupla lead | billingMode direct_contact | node | CORRIGIDO |

---

## 3. Seguranca / LGPD / Financeiro

- Rules: users get sem sharesChat; disputes; withdrawalRequests; webhookEvents
- Ledger: CREDIT_PURCHASE via eventId unico quando PAYMENTS_ENABLED
- Comissao: Admin + snapshot; direct_contact = 0%
- Split: payout interno server-side
- LGPD: deleteMyAccount existente; emails atualizados; consentimento OAuth reforcado
- Secrets: nenhum secret prod no Git; ROTATION_REQUIRED=false

---

## 4. Android / iOS

- applicationId / bundle: br.com.carajas360
- versionName 1.0.0-rc1 / versionCode 401
- Build release APK: NOT TESTED
- iOS build: NOT TESTED

---

## 5. Contagens E2E (matriz)

TOTAL PASS: 9 (unit/code)
TOTAL FAIL: 0
TOTAL NOT TESTED: 11+
P0 ABERTOS (codigo): 0
P1 ABERTOS (seg/fin codigo): 0 (App Check / secrets / DNS = CONFIG/DECISÃO)
P2/P3: ver pendencias

---

## 6. Artefatos

- docs/CARAJAS360_RELATORIO_FASE4_RC1.md
- docs/CARAJAS360_RC1_RELEASE_NOTES.md
- docs/CARAJAS360_RC1_TEST_MATRIX.md
- docs/CARAJAS360_RC1_PENDENCIAS.md

## 7. Impedimentos para gate verde

1. E2E device + pagamento Sandbox real (TOKEN TEST)
2. Build release Android homolog
3. Firebase real (CONFIG EXTERNA)
4. Deploy functions/rules

**Nao publicar. Nao ativar pagamentos reais.**