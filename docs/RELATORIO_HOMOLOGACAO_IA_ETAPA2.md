# Relatório de homologação — Carajás IA (Etapa 2)

**Data:** 16/11/2026  
**Projeto Firebase:** `carajas360-a17c5`  
**Escopo:** deixar IA pronta para testes reais · **sem** deploy Functions/live nesta etapa  
**Personagem:** referência oficial anexada e aplicada em `assets/carajas_ia/`

---

## 1. Testes unitários (7 originais + extras)

| Suite | Resultado | Evidência |
|-------|-----------|-----------|
| `carajasAi` — 7 testes Prompt 9 | **APROVADO** | Incluídos em 9/9 |
| Isolamento `scopedConversationId` | **APROVADO** | idem |
| `sanitizeAnthropicKey` | **APROVADO** | idem |
| Rules audit `aiConversations`/`aiUsage` | **APROVADO** | `firestoreRules.audit.js` |
| Deploy rules (16/11) | **APROVADO** | terminal 96853 → `released rules` em `carajas360-a17c5` |

**Conclusão unitária:** base OK. **Não** substitui E2E autenticado.

---

## 2. Firestore rules — projeto/ambiente

| Item | Status |
|------|--------|
| Projeto | `carajas360-a17c5` (ativo) |
| Coleções IA | `aiConversations` (+messages), `aiUsage` — client lê próprio; write false |
| Publicação | Confirmada no deploy rules 16/11 |

---

## 3. Preparação `aiAssistant` (staging)

| Controle | Estado no código |
|----------|------------------|
| Auth | `requireAuth` |
| Perfis | admin / provider checados |
| Limites | `planAiQuota` + rate limit `ai_${mode}` |
| Custo | `estimateCostUsd` + `aiUsage` |
| Histórico | `scopedConversationId` + retentionDays 30 |
| Grounding | providers active+verified |
| Saúde | consentimento; sem diagnóstico |
| Anthropic | só `process.env` / Secret Manager; **nunca** no app |
| Binding secret | `BIND_ANTHROPIC_SECRET=true` (exige **Blaze**) |

**Staging recomendado:** grounded-only (`AI_ENABLED=false` ou sem chave) até Blaze + secret autorizado.  
**Chave:** não lida/exibida neste relatório.

---

## 4. Testes reais (auth / mensagens / histórico / isolamento)

| Caso | Resultado |
|------|-----------|
| Auth E2E 2 usuários | **BLOQUEADO** — Function nova não deployada |
| Mensagem → cartões reais | **BLOQUEADO** — idem |
| Histórico isolado | **Lógica APROVADA** unitário |
| Isolamento cross-user | **Lógica APROVADA** (`u_{uid}_…`) |

---

## 5. Interface Web / Android / iOS

| Plataforma | Código | Build/runtime |
|------------|--------|---------------|
| Web | Personagem oficial + FAB/painel + 5 atalhos da referência | Homolog: https://carajas360-a17c5--homolog-88u39zqx.web.app (pode estar sem rebuild pós-referência oficial) |
| Android | Mesmo código Flutter | Device/emulador **não presumido** |
| iOS | Mesmo código Flutter | Sem macOS/Pods **não presumido** |

UI alinhada à referência: boas-vindas oficial, status “Online · 24 horas”, atalhos Encontrar / Agendar / Saúde / Comprar·Alugar / Dúvidas (+ orçamento).

**Mockups avançados** (agendamento confirmado, voz, painel admin com métricas inventadas) **não** foram implementados como “dados reais” — evitam inventar disponibilidade/números. Usam rotas reais existentes.

---

## 6. Plano de deploy homologação (**NÃO EXECUTADO**)

### Comandos (após GO explícito)

```bash
# A) Function staging grounded (sem LLM / sem Blaze secret)
firebase deploy --only functions:aiAssistant --project carajas360-a17c5

# B) (Opcional LLM — só com Blaze + secret já criado, SEM colar chave no chat)
# firebase functions:secrets:set ANTHROPIC_API_KEY --project carajas360-a17c5
# BIND_ANTHROPIC_SECRET=true firebase deploy --only functions:aiAssistant --project carajas360-a17c5

# C) Rebuild Web + canal homolog (NÃO live)
flutter build web --release
powershell -ExecutionPolicy Bypass -File scripts\homolog_web_preview.ps1 -Channel homolog -Expires 30d
```

### Recursos afetados
- Cloud Function `aiAssistant` (us-central1)
- Hosting channel `homolog`
- Firestore: sem wipe; só leitura/escrita via Function

### Riscos
1. Blaze obrigatório para Secret Manager  
2. Auth Email/Google + domínio homolog  
3. Rebuild Web necessário para personagem oficial no canal  
4. Custo Anthropic se chave ligada  
5. **Não** tocar canal `live`

---

## 7. Pendências para ativação comercial

1. **GO** deploy `functions:aiAssistant`  
2. **GO** rebuild homolog com assets oficiais  
3. Auth E2E + histórico isolado com 2 contas  
4. Blaze + secret Anthropic (opcional LLM)  
5. PNG transparente master (polimento)  
6. Domínio homolog em Authorized domains  
7. App Check / purge 30 dias / DPIA  

**Veredito:** código e rules prontos para testes reais **após** deploy autorizado.  
**IA NÃO operacional comercialmente** sem E2E da Function.
