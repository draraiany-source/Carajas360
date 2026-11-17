# Estimativa de custo operacional — Carajás IA

## Modelo de referência
Claude Sonnet 4.5 via Anthropic (quando `ANTHROPIC_API_KEY` + `AI_ENABLED`).

Hipótese usada no código (`estimateCostUsd`):
- Input ≈ US$ 3 / 1M tokens  
- Output ≈ US$ 15 / 1M tokens  
- Tokens ≈ caracteres / 4  

## Cenários (ordem de grandeza)

| Cenário | Uso LLM | Custo/turno (USD) | Observação |
|---------|---------|-------------------|------------|
| Fallback grounded (sem chave) | Não | **0** | Só Firestore + Functions |
| Turno típico cliente (~1,5k tokens) | Sim | **~0.005–0.02** | Depende do histórico |
| 1.000 turnos LLM/dia | Sim | **~5–20 / dia** | + custo Functions/Firestore |

## Controles de custo
- Rate limit por plano (`planAiQuota`).  
- `max_tokens: 500`.  
- Histórico limitado a 8 mensagens.  
- Urgência médica: sem chamada LLM.  
- Flag `AI_ENABLED=false` força só grounded.

Valores são **estimativas**; validar na fatura Anthropic após piloto.
