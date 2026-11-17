# Relatório de implementação — Central Carajás IA (Prompt 9)

**Data:** 16/11/2026  
**Projeto:** Carajás 360 · Firebase `carajas360-a17c5`  
**Escopo:** reutilizar módulo `/ai` + callable `aiAssistant` (sem app novo)

---

## O que foi entregue

| Camada | Entrega |
|--------|---------|
| Backend | `functions/carajasAi.js` + rewrite de `exports.aiAssistant` (modos, grounding, consentimento Saúde, histórico, custo) |
| Rules | `aiConversations` / `aiUsage` — client só lê o próprio; escrita backend |
| App | UI premium `AiAssistantScreen` (Brand verde/dourado), modos, chips, cartões, suporte humano |
| Nav | Atalho “Carajás IA” no `BrandTopNav` + item no Perfil |
| Cliente API | `AiSvc.askTurn` com resposta estruturada |
| Testes | `carajasAi.test.js` (7) · `ai_turn_result_test.dart` (1) · audit rules |

## Removido / corrigido

- Fallback local da tela antiga que **inventava** preços e profissionais (eletricista R$…, Ana Oliveira, etc.).
- Resposta agora: Cloud Function fundamentada em `providers` ativos/verificados **ou** mensagem honesta de “não encontrado” / falha de rede.

## Arquivos principais

- `functions/carajasAi.js`, `functions/carajasAi.test.js`, `functions/index.js`
- `firestore.rules` (deployado)
- `lib/features/ai_assistant/ai_screen.dart`
- `lib/shared/services/ai_service.dart`
- `lib/shared/widgets/brand_shell.dart`, `lib/features/profile/profile_screens.dart`, `lib/main.dart`

## Estado operacional

| Item | Status |
|------|--------|
| Código staging no repo | **Pronto** |
| Rules IA no Firestore | **Publicadas** |
| Cloud Function `aiAssistant` nova | **Código local — deploy Functions pendente** |
| `ANTHROPIC_API_KEY` | **Externo** — sem chave, Function usa fallback grounded |
| Declaração “IA operacional comercial” | **NÃO** — falta deploy Functions + Auth E2E + evidência live |

## Como ativar (staging)

1. Definir secret/env `ANTHROPIC_API_KEY` (opcional; sem ela o fallback grounded responde).  
2. `AI_ENABLED=true` (default se não for `false`).  
3. Autorizar: `firebase deploy --only functions:aiAssistant` (ou functions).  
4. Redeploy homolog web com a nova UI.  
5. Testar com usuário autenticado nos 4 modos.

---

## Pacote de entrega Prompt 9

| Documento | Caminho |
|-----------|---------|
| Relatório de implementação | `docs/RELATORIO_IMPLEMENTACAO_CARAJAS_IA.md` |
| Fluxos por perfil | `docs/FLUXOS_IA_POR_PERFIL.md` |
| Auditoria segurança / LGPD | `docs/AUDITORIA_SEGURANCA_LGPD_IA.md` |
| Testes funcionais / integração | `docs/TESTES_CARAJAS_IA.md` |
| Custo operacional | `docs/CUSTO_OPERACIONAL_IA.md` |
| Pendências ativação comercial | `docs/PENDENCIAS_ATIVACAO_IA.md` |

### Evidências unitárias (16/11/2026)

- `docs/evidence/divulgacao/prompt9_carajas_ai_node.txt` — 7/7  
- `docs/evidence/divulgacao/prompt9_rules_audit.txt` — inclui `aiConversations`/`aiUsage`  
- `docs/evidence/divulgacao/prompt9_ai_turn_flutter.txt` — parse `AiTurnResult`

**Veredito:** código e regras prontos para staging; **IA não operacional** até deploy Functions + Auth E2E.
