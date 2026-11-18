# Relatório IA — FASE 17

## Estado

| Item | Status |
|------|--------|
| UI Central / FAB `/ai` | Implementado |
| Cliente → callable `aiAssistant` | Código (`AiSvc`) — **sem chave no app** |
| Assist service request / proposal | Callables no `functions/index.js` |
| Sugestão descrição c/ fotos | `suggestOrderDescriptionFromPhotos` — sem preço/diagnóstico |
| Turno LLM real nesta fase | **NÃO** (Functions API 403 / Blaze off) |
| Inventar prestadores/preços | **Proibido** — grounded + prompts seguros |

## Pré-requisitos (antes de ativar — AGUARDAR GO)

### Custos potenciais (ordem de grandeza)

| Item | Observação |
|------|------------|
| Firebase Blaze | Pay-as-you-go; Functions/Hosting/Storage faturáveis após free tier |
| Anthropic (opcional) | Por token; sem chave a Function pode operar **grounded** (lista providers reais) |
| Cold start / invocações | Monitorar quotas e custo mensal no Console |

**Esta fase NÃO ativa Blaze nem secrets pagos.**

### Instruções (owner)

1. Upgrade Blaze em `carajas360-a17c5`  
2. Habilitar Cloud Functions API (+ Build/Artifact Registry se pedido)  
3. `firebase deploy --only functions:aiAssistant --project carajas360-a17c5`  
4. Opcional: Secret Manager `ANTHROPIC_API_KEY`  
5. Prova: turno real + label “gerado por IA” + confirmação humana antes de pagar/contratar  

Ver também: `docs/FASE13_GO_EXTERNOS.md`.

## Controles desejados (já parcialmente no código)

- Limites/quotas (serviceAssist)  
- Consentimento saúde (`consentRequired`)  
- Erro honesto se Function indisponível  
- Confirmação humana para ações irreversíveis (produto — validar E2E após deploy)
