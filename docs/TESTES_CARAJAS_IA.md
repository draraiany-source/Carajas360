# Testes — Central Carajás IA

**Data:** 16/11/2026

| ID | Caso | Resultado | Evidência |
|----|------|-----------|-----------|
| T1 | `carajasAi` unitários (mode, intent, fallback, custo) | **7/7 APROVADO** | `docs/evidence/divulgacao/prompt9_carajas_ai_node.txt` |
| T2 | Parse `AiTurnResult` / consent | **APROVADO** | `docs/evidence/divulgacao/prompt9_ai_turn_flutter.txt` |
| T3 | Rules audit `aiConversations`/`aiUsage` | **APROVADO** | `docs/evidence/divulgacao/prompt9_rules_audit.txt` |
| T4 | Rules deploy Firestore | **APROVADO** | deploy 16/11 |
| T5 | UI Carajás IA (modos, chips, Brand) | **Código pronto** | `ai_screen.dart` |
| T6 | E2E callable autenticada + cartões Firestore | **BLOQUEADO** | Deploy Functions + Auth |
| T7 | LLM Anthropic real | **NÃO TESTADO** | Sem `ANTHROPIC_API_KEY` nesta sessão |
| T8 | Fallback grounded com seeds `[TESTE]` Saúde | **Lógica APROVADA** unitário; runtime CF pendente | — |

**Conclusão:** base testada em unitário; **não** declarar IA operacional sem E2E da Function deployada.
