# Relatório técnico — Correção urgente Interface + Carajás 360 IA

**Data:** 2026-11-16 (UTC-3)  
**Projeto Firebase:** `carajas360-a17c5`  
**Branch:** `feat/modernizacao-visual` (`8b055e0` + working tree)  
**Regra:** nenhum app novo; apenas o repositório existente.

---

## 1. Diagnóstico (obrigatório)

| Item | Achado |
|------|--------|
| App em execução | Flutter Web + Android/iOS compartilhados; Firebase Hosting canal **homolog** |
| URL `/explorar` | **Não existe** como rota nomeada. Aba **Explorar** e rotas `/search` e `/universal-search` usam `UniversalSearchScreen` (`lib/features/search/universal_search_screen.dart`) |
| Por que a IA “não aparecia” | (1) Canal **live** `https://carajas360-a17c5.web.app` está **Site Not Found** (sem deploy live). (2) Homolog anterior ainda tinha só ícone sparkle discreto. (3) Cache/service worker do browser podia servir bundle antigo — o JS remoto já continha as strings novas antes do hard refresh. |
| Módulo de IA no código | **Existe:** UI (`ai_screen`, FAB, personagem), cliente callable (`ai_service.dart`), backend `functions/carajasAi.js` + `aiAssistant`. |
| IA “pronta” comercialmente? | **Não.** Chat UI e grounding no código; **Cloud Function `aiAssistant` ainda depende de GO de deploy**; chave Anthropic opcional (Blaze/Secret Manager). Sem Function publicada, o turno real falha de forma explícita — não há simulação fingindo LLM. |

---

## 2. O que foi implementado nesta correção

### Explorar Serviços (premium + IA visível)
- Banner **Carajás 360 IA** com avatar oficial + botão **Abrir IA**
- Placeholder **Descreva o serviço que você precisa**
- Atalho **Encontrar com IA** (abre conversa com o texto digitado)
- FAB flutuante rotulado **Carajás 360 IA** (web largo)
- Painel lateral / rota `/ai` com chat real (`AiAssistantScreen`), não tela ilustrativa

### Arquivos principais alterados
- `lib/features/search/universal_search_screen.dart`
- `lib/features/ai_assistant/carajas_ia_fab.dart`
- `lib/features/ai_assistant/ai_screen.dart`
- `lib/main.dart` (args `initialMessage` na rota `/ai`)
- `test/carajas_ia_screen_smoke_test.dart`

(Backend/rules/assets da Central IA já existiam no working tree: `functions/carajasAi.js`, `lib/features/ai_assistant/*`, `assets/carajas_ia/*`.)

---

## 3. URL e versão efetivamente atualizadas

| Canal | URL | Status |
|-------|-----|--------|
| **Homolog (atualizado)** | https://carajas360-a17c5--homolog-88u39zqx.web.app | Deploy channel OK; `main.dart.js` ~5 777 517 bytes contém `Encontrar com IA` |
| **Live** | https://carajas360-a17c5.web.app | **Site Not Found** — sem hosting live; **não** é a versão com IA |
| Expiração canal homolog | ~2026-11-23 | Renovar com `scripts/homolog_web_preview.ps1` |

**Como abrir a versão correta:**  
`https://carajas360-a17c5--homolog-88u39zqx.web.app/#/search`  
Se a UI antiga persistir: Ctrl+Shift+R / limpar cache do site.

**Evidências:**  
- `docs/evidence/homolog_ia/explorar_carajas360_ia.png` — Explorar com banner IA + Abrir IA + Encontrar com IA  
- `docs/evidence/homolog_ia/central_carajas360_ia_chat.png` — Central com personagem, atalhos e chat (sem cadeado)  
- `docs/evidence/homolog_ia/deploy_explorar_ia_v2.log` — redeploy homolog  

**URLs que funcionam (hash routing):**  
- Explorar: `https://carajas360-a17c5--homolog-88u39zqx.web.app/#/search`  
- Central IA: `https://carajas360-a17c5--homolog-88u39zqx.web.app/#/ai`  
(Hard refresh se o browser guardar bundle antigo.)

---

## 4. Testes

| Teste | Resultado |
|-------|-----------|
| `test/carajas_ia_screen_smoke_test.dart` | Passou (após ajuste label FAB) |
| `test/carajas_ia_character_test.dart` | Passou |
| `test/ai_turn_result_test.dart` | Passou |
| `flutter build web --release` | Passou |
| `firebase hosting:channel:deploy homolog` | Passou |
| E2E chat autenticado + Function `aiAssistant` | **Não executado** (Function não publicada / sem GO) |
| Lista de profissionais na sessão browser | Estado **erro** com retry (Listen Firestore lento/timeout) — **não** loading infinito |
| Build Android/iOS device | Não refeito neste turno |

---

## 5. Integração IA — pendências reais

1. **GO** para deploy Cloud Functions (`aiAssistant`) — ver `docs/PLANO_DEPLOY_HOMOLOG_IA.md`
2. **GO** para publicar rules/indexes se ainda não estiverem no projeto remoto
3. Auth Email/Google no domínio homolog (aviso Firebase Auth no deploy do channel)
4. Anthropic (opcional): plano **Blaze** + Secret Manager; sem isso o backend deve operar só em modo grounded (Firestore real)
5. **Não** publicar canal `live` sem GO explícito
6. Login necessário para rota `/ai` e para envio de turnos (callable autenticada)

---

## 6. Travamentos

- Timeout 15s + reset de cache em `FS.providersStream` já no código
- UI Explorar distingue loading / erro / vazio / sucesso
- Observado nesta sessão: falha de carga de profissionais com **Tentar novamente** (preferível a spinner eterno)

---

## 7. Conclusão

A Central e os CTAs da IA **estão no código e no canal homolog**. A ausência na interface “atual” vinha de **URL live inexistente / cache / build homolog antigo sem CTA destacado**.  

**IA operacional para usuários reais:** ainda **não** — falta deploy da Function e validação E2E autenticada.  
**IA visível na Explorar (homolog):** **sim**, comprovado por screenshot e strings no bundle remoto.
