# CARAJAS360 — Homologacao RC1 Matrix (Fase 5)

**Atualizado:** 2026-09-23
**Branch:** release/carajas360-rc1
**Commit base Fase 4:** 4155283
**Versao alvo:** 1.0.0-rc1 (+401)
**FEATURE FREEZE:** ativo

## Heranca Fase 4 (evidencias)

| ID | Perfil | Fluxo | Teste | Esperado | Obtido | Status | Evidencia | Observacao |
|----|--------|-------|-------|----------|--------|--------|-----------|------------|
| F4-G01 | Sistema | Build APK | Artefato release | APK gerado | Daemon JVM crash F4 | FAIL (F4) | build_rc1_apk.log | Retry F5 em andamento |
| F4-G02 | Sistema | Node | 99 PASS | 99/0 | PASS | build_rc1_node.log + npm F5 | Reconfirmado |
| F4-G03 | Sistema | Flutter test | Suite PASS | 131 PASS 1 skip | PASS | build_rc1_test.log | |
| F4-G04 | Sistema | Analyze errors | 0 error | 0 error | PASS | build_rc1_analyze2.log | wallet const fix |
| F4-E04 | Match | Matching | Correto | Unit | PASS | taxonomy tests | |
| F4-E05 | Creditos | Unlock idempotente | 1 debito | Unit/code | PASS | monetization + CF | |
| F4-E09 | Fin | Comissao | Calculo | Node | PASS | orderPolicy | |
| F4-E10 | Fin | Split | providerAmount | Node | PASS | orderPolicy | |
| F4-E17 | Fin | Webhook dup | 1 ledger | Node | PASS | webhookApply | |
| F4-E18 | Seg | IDOR | Negado | Rules | PASS | firestore.rules | |
| F4-F01 | Fin | direct_contact | 0% | Node | PASS | orderPolicy | |
| E2E-01 | Cliente | Cadastro | Conta | — | NOT TESTED | — | DEVICE + Firebase real |
| E2E-02 | Pro | Cadastro | Conta | — | NOT TESTED | — | DEVICE + Firebase real |
| E2E-03 | Cliente | Solicitacao | Publicada | — | NOT TESTED | — | DEVICE REQUIRED |
| E2E-06 | Pro | Proposta | Enviada | — | NOT TESTED | — | DEVICE REQUIRED |
| E2E-08 | Fin | Pagamento Sandbox | Confirmado | — | NOT TESTED | — | MP secrets ABSENT |
| E2E-11 | Mix | Conclusao | Completed | — | NOT TESTED | — | DEVICE REQUIRED |
| E2E-12 | Cliente | Avaliacao | 1 review | — | NOT TESTED | — | DEVICE REQUIRED |
| PAY-SBX | Fin | Gateway integrado | Sandbox | — | NOT TESTED | — | CONFIG EXTERNA |
| WH-INT | Fin | Webhook integrado | Apply | — | NOT TESTED | — | CONFIG EXTERNA |
| ANDROID-DEV | Android | Install APK | Abrir app | — | NOT TESTED | — | DEVICE REQUIRED |
| IOS | iOS | Build/test | — | — | NOT TESTED | — | REQUIRES macOS/Xcode |

## Contas homologacao

| Conta | Status |
|-------|--------|
| CLIENTE_TESTE | NOT CREATED — Firebase Auth real necessario |
| PROFISSIONAL_TESTE | NOT CREATED |
| PROFISSIONAL_PRO_TESTE | NOT CREATED |
| ADMIN_TESTE | NOT CREATED — custom claim |

Senhas: nao documentadas / nao no Git.

## Ambiente verificado nesta sessao

| Variavel | Estado |
|----------|--------|
| PAYMENTS_ENABLED | ABSENT (codigo default false) |
| MERCADOPAGO_ACCESS_TOKEN | ABSENT |
| MERCADOPAGO_WEBHOOK_SECRET | ABSENT |
| firebase_options | COLE_SUA_* |
| Devices Flutter | windows, chrome, edge — sem Android |