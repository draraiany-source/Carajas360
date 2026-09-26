# CARAJAS360 - Plano de Ativacao Financeira (somente preparacao)

**Status:** PREPARACAO - **NAO ATIVAR**  
**Pagamentos reais F7/F8:** **OFF**  
**Data:** 2026-09-24

## Principio

Este documento descreve **como** a ativacao **poderia** ocorrer no futuro. **Nenhum passo abaixo foi executado como ativacao** na Fase 7 ou entrada Fase 8.

## Estado atual (factual)

- Flutter: `productionPaymentsEnabled` default **false**
- Functions: `PAYMENTS_ENABLED` / `PRODUCTION_PAYMENTS_ENABLED` devem permanecer unset/false
- `financialKillSwitch` em `config/platform` para parada de emergencia
- F7 GO_NO_GO = NO-GO - loja e piloto bloqueados

## Pre-requisitos antes de qualquer flip para ON

1. GO financeiro separado do GO piloto/loja (documento assinado).
2. URLs legais e politica de reembolso publicadas.
3. Webhooks MP em ambiente staging validados com reconciliacao.
4. Runbook incidentes (`CARAJAS360_INCIDENT_RESPONSE.md`) revisado.
5. Backup Firestore / plano rollback testado em staging.
6. Checklist MP producao (`CARAJAS360_ASAAS_PRODUCAO_CHECKLIST.md` - titulo historico).

## Sequencia sugerida (nao executar agora)

| Ordem | Acao | Ambiente | Ativo? |
|-------|------|----------|--------|
| 1 | Validar tokens TEST- apenas | Staging | OFF prod |
| 2 | PAYMENTS_ENABLED=true staging | Staging | Somente se autorizado |
| 3 | Testes E2E pagamento sandbox | Staging | |
| 4 | PRODUCTION_PAYMENTS_ENABLED | Producao | **NAO** ate linha GO |
| 5 | productionPaymentsEnabled true app | Producao | **NAO** |
| 6 | Monitoramento 24h pos-flip | Producao | |

## Kill switch

Ante qualquer duvida ou incidente: `financialKillSwitch=true` - ver secao rollback em incident response.

## Proibicao explicita F7/F8

**Nao** definir env vars de pagamento producao. **Nao** habilitar checkout real para usuarios piloto ou publico.
