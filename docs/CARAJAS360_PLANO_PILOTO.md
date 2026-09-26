# CARAJAS360 - Plano de Piloto

**Status:** **PILOTO BLOQUEADO** — piloto **NAO DEVE** iniciar  
**Data do documento:** 2026-09-24  
**VERSION:** 1.0.0+402  
**Branch:** `release/carajas360-rc1` @ `1c47a74`  
**Decisao:** ver `CARAJAS360_GO_NO_GO.md` (YELLOW CONFIG EXTERNAS)  
**Bloqueio explicito:** piloto permanece bloqueado **ate GO de teste fechado** (nao basta AAB existir)

## 1. Proposito (quando autorizado no futuro)

Validar uso real limitado com cohort controlado, telemetria e suporte, **sem** promover disponibilidade publica e **sem** pagamentos reais ate plano financeiro aprovado.

## 2. Estado atual — bloqueio

| Bloqueador | F7 |
|------------|-----|
| GO F7 teste fechado | YELLOW / nao GREEN |
| AAB/APK | PASS (artefato existe) |
| Privacidade/termos live | FAIL 404 (fix READY) |
| Teste fechado executado | NAO INICIADO / DEVICE REQUIRED |
| Pagamentos | OFF |
| iOS | NOT TESTED |

**Instrucao operacional:** **NAO** convidar usuarios piloto, **NAO** publicar link de download amplo, **NAO** contabilizar metricas de piloto — piloto nao iniciado.

## 3. Pre-requisitos para desbloqueio (futuro)

1. GO F7 reavaliado = GREEN para teste fechado (documentado).
2. `CARAJAS360_GO_NO_GO.md` atualizado para GO pelo comite.
3. Artefato RC distribuido (track interno Play ou sideload controlado).
4. URLs legais publicadas e verificadas (HTTP 200).
5. Teste fechado concluido com criterios do plano.
6. Pagamentos permanecem OFF salvo plano `CARAJAS360_PLANO_ATIVACAO_FINANCEIRA.md` aprovado separadamente.

## 4. Cohort e etica (placeholder — sem numeros inventados)

- Tamanho e perfil do cohort: **a definir** apos GO; **nao** registrar contagens ficticias nesta fase.
- Consentimento informado e canal de suporte: definir antes do start.
- Criterio de parada: kill switch operacional + rollback (ver incident response).

## 5. Entregaveis do piloto (quando existir)

- `CARAJAS360_RELATORIO_PILOTO.md`
- `CARAJAS360_PILOT_BUGS.md`
- Revisao GO pos-piloto

## 6. Estado F7/F8

**Piloto nao iniciado.** Qualquer atividade de usuario real alem de homolog interna exige novo GO explicito. Fase 8 **nao** iniciada neste fechamento.

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
