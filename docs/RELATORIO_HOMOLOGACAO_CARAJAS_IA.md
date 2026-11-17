# Relatório de homologação — Carajás IA

**Data:** 16/11/2026  
**Projeto Firebase:** `carajas360-a17c5` (ativo via `firebase use`)  
**Escopo:** preparar testes reais Web/Android/iOS · **sem** deploy Functions/Hosting nesta etapa  
**Identidade visual:** preservada (Brand verde-esmeralda / branco / dourado)

---

## 1. Arquivos alterados (IA + pré-requisito Auth)

| Área | Arquivos |
|------|----------|
| Backend IA | `functions/carajasAi.js`, `functions/index.js` (`aiAssistant`), `carajasAi.test.js`, `.env.example` |
| Rules | `firestore.rules` (já publicadas), `firestoreRules.audit.js` |
| App | `lib/features/ai_assistant/ai_screen.dart`, `ai_service.dart`, `brand_shell.dart`, `profile_screens.dart`, `main.dart` |
| SDK real (bloqueio Auth) | `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` |
| Docs | este relatório + `PLANO_DEPLOY_HOMOLOG_IA.md` |

---

## 2. Testes unitários

| Suite | Resultado | Evidência |
|-------|-----------|-----------|
| `carajasAi` (7 originais + 2 isolamento/chave) | **9/9 APROVADO** | `docs/evidence/homolog_ia/unit_carajasAi.txt` |
| Rules audit (incl. AI) | **17/17 APROVADO** | `docs/evidence/homolog_ia/security_rules.txt` |
| Security / auth callables | **APROVADO** (mesmo arquivo) | idem |
| Flutter `AiTurnResult` | ver evidência | `docs/evidence/homolog_ia/flutter_ai_turn.txt` |

Os **7 testes originais** do Prompt 9 continuam passando; foram adicionados:
- `scopedConversationId isola por uid`
- `sanitizeAnthropicKey rejeita placeholders`

---

## 3. Firestore rules — projeto/ambiente

| Item | Status |
|------|--------|
| Projeto alvo | `carajas360-a17c5` |
| Deploy rules (16/11) | **Confirmado** — `firestore: released rules` + `Deploy complete!` (evidência terminal 96853) |
| Coleções IA | `aiConversations` (+ `messages`) e `aiUsage`: client lê só o próprio `userId`; escrita `false` |
| `firestore:rules:get` CLI | **indisponível** nesta versão do Firebase CLI — validação via log de deploy + audit estático |

---

## 4. Preparação `aiAssistant` (staging)

| Controle | Estado no código |
|----------|------------------|
| Auth | `requireAuth` / `assertCallableAuth` |
| Autorização modo | admin → `isAdmin`; provider → role/`providers/{uid}` |
| Limites | `planAiQuota` + `enforceRateLimit(ai_${mode})` |
| Custo | `estimateCostUsd` + doc `aiUsage` (sem expor chave) |
| Grounding | só `providers` active+verified; sem inventar |
| Saúde | consentimento obrigatório; sem diagnóstico |
| Histórico | `retentionDays: 30`; ID **prefixado com uid** (`scopedConversationId`) |
| Isolamento | recusa overwrite se `userId` ≠ auth; rules impedem leitura cruzada no client |
| Anthropic | `sanitizeAnthropicKey`; LLM só com chave válida + `AI_ENABLED!=false` |
| Secrets | `BIND_ANTHROPIC_SECRET=true` ativa `runWith({ secrets })` — **exige Blaze** |

**Secret Manager:** tentativa de `functions:secrets:access` falhou — projeto precisa **Blaze** para API `secretmanager.googleapis.com`.  
**Decisão staging:** operar **grounded-only** (custo LLM = 0) até Blaze + secret autorizado.  
**ANTHROPIC_API_KEY:** não está no frontend; **não** foi definida nem impressa neste relatório.

---

## 5. Testes reais (auth / mensagens / histórico / isolamento)

| Caso | Resultado | Motivo |
|------|-----------|--------|
| Auth E2E com contas reais | **BLOQUEADO** | Callable `aiAssistant` nova **não deployada**; `functions:list` falhou; Auth export evitido (dados sensíveis) |
| Mensagem → resposta grounded live | **BLOQUEADO** | Depende do deploy Functions |
| Histórico persistido | **Lógica APROVADA** unitário; runtime pendente | Escrita backend em `aiConversations` |
| Isolamento entre usuários | **Lógica APROVADA** | `scopedConversationId` + rules + checagem de ownership |
| Rules IA no servidor | **Publicadas** | Deploy 16/11 |

---

## 6. Interface Web / Android / iOS

| Plataforma | Código UI | Build nesta máquina | Observação |
|------------|-----------|---------------------|------------|
| Web | `AiAssistantScreen` + nav “Carajás IA” | Device Chrome/Edge disponíveis; `build/web` existe (pode estar **desatualizado**) | Homolog: https://carajas360-a17c5--homolog-88u39zqx.web.app — **sem** rebuild pós-IA nesta etapa |
| Android | Mesmo código Flutter | Device físico/emulador **não** listado | SDK real aplicado; `oauth_client` vazio → Google Sign-In pode falhar |
| iOS | Mesmo código Flutter | **Sem** macOS/Pods neste ambiente (`ios/Pods` ausente) | SDK real aplicado; compilação iOS **não presumida** |

Apps Firebase Console (reais): Android / iOS / Web IDs `…815702597e79223a9eec39` / `…28b25a6c6d3c60279eec39` / `…cd3e505962fd07059eec39`.

---

## 7. Deploy de homologação

**Não executado** (aguarda GO explícito).

Plano completo: `docs/PLANO_DEPLOY_HOMOLOG_IA.md`  
Resumo de riscos: Blaze/secrets, Auth obrigatória após keys reais, não tocar canal `live`, custo Functions/Anthropic.

---

## 8. Pendências para ativação comercial

1. **GO** deploy `functions:aiAssistant` (staging grounded).  
2. **GO** rebuild + `hosting:channel:deploy homolog` (não `live`).  
3. Habilitar Auth Email/Password (e OAuth Google se desejado) + domínios autorizados.  
4. Upgrade **Blaze** se for usar Secret Manager / Anthropic.  
5. E2E autenticado: 2 usuários, histórico isolado, modos client/health/provider/admin.  
6. APK Android + build iOS em ambiente adequado.  
7. Job de purge > 30 dias; DPIA/LGPD; App Check em produção.  
8. Monitoramento `aiUsage` / custo.

---

## Veredito

**Carajás IA está pronta para testes reais após o deploy de homologação autorizado**, com fallback grounded e SDK Firebase real no repo.  

**Não operacional comercialmente.** Sem evidência de callable nova em runtime nem E2E Auth/chat.
