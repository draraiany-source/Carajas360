# CARAJAS360 — Relatorio Fase 6 (Preparacao de Producao)

**Data:** 2026-09-23
**Branch:** release/carajas360-rc1
**Commit base F4:** 4155283
**Versao app:** 1.0.0-rc1 (+401)
**FEATURE FREEZE:** ativo
**PAGAMENTOS REAIS:** OFF
**PUBLICACAO:** NAO

## 1. Entrada a partir da Fase 5

Fase 5 ficou **parcial**:
- Sem CARAJAS360_RELATORIO_FASE5 completo ate esta sessao (agora preenchido com estado real)
- Build APK RC1: FAIL (Gradle daemon JVM)
- Device/Sandbox E2E: NOT TESTED
- P0 codigo = 0; P1 build artefato aberto

Gate F6 **nao** pode ser verde tecnico completo.

## 2. Gateway real

**Mercado Pago** (nao Asaas). Split = payout interno server-side.
Checklist: docs/CARAJAS360_ASAAS_PRODUCAO_CHECKLIST.md (titulo historico; conteudo MP).

## 3. Mudancas tecnicas desta fase (sem ativar cobranca)

- productionPaymentsEnabled default false (Flutter MonetizationConfig)
- financialKillSwitch (config/platform + assert nas callables financeiras)
- PRODUCTION_PAYMENTS_ENABLED env (functions) + fail-safe:
  - token APP_USR- bloqueado se producao off
  - token TEST- bloqueado se producao on
- functions/.env.example atualizado
- Docs operacionais: incident, acoes proprietaria/programador, readiness matrix

## 4. Ambientes

| Env | Firebase | Gateway | Payments |
|-----|----------|---------|----------|
| Dev/Homolog placeholders | COLE_SUA_* + HomologCatalog | off | off |
| Staging | projeto staging (CONFIG) | MP TEST- | PAYMENTS_ENABLED sob controle |
| Production | projeto prod (CONFIG) | APP_USR- | PRODUCTION_PAYMENTS_ENABLED=false ate autorizacao |

## 5. Seguranca varredura rapida

- Secrets no Git: nao encontrados (placeholders)
- ROTATION_REQUIRED=false
- IDOR chat: corrigido F3
- Admin escalation: rules
- Fail-safe token prod: adicionado F6

## 6. Android / iOS / Lojas

- AAB production-like: ver evidencia de build nesta sessao
- iOS: NOT TESTED (Windows)
- Play/App Store: preparacao documental apenas — NAO enviar

## 7. Gate Fase 6

Ver secao final da entrega.

**PAGAMENTOS REAIS = OFF**
**PUBLICACAO AUTOMATICA = NAO**