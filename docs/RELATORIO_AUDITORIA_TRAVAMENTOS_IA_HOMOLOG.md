# Relatório — Travamentos, IA e Homologação (Carajás 360)

**Data:** 16/11/2026  
**Projeto:** `carajas360-a17c5` · app existente (sem app novo)  
**Produção/live:** não alterada nesta etapa

---

## 1. Problemas encontrados

| # | Problema | Evidência |
|---|----------|-----------|
| P1 | Profissionais em “carregando…” sem fim | Stream Firestore sem timeout; UI só mostrava shim |
| P2 | Falha vs lista vazia confusas | Mesmo banner genérico |
| P3 | Filtro por categoria pode exigir índice composto ausente | Query `active+verified+categories+rating` |
| P4 | Cache de stream quebrado após erro | Retry reutilizava stream morto |
| P5 | Listeners monetização sem cancel (já corrigido) | setState pós-dispose |
| P6 | IA Function não deployada | E2E chat real bloqueado |
| P7 | Homolog Web pode estar sem personagem oficial | Rebuild pendente pós-assets |

---

## 2. Causas identificadas

1. **Loading infinito:** `providersStream` via `snapshots()` sem timeout; se rede/índice/Firebase não responde, `StreamBuilder` fica em `waiting` para sempre.  
2. **Categoria:** índice composto com `arrayContains` faltava em `firestore.indexes.json`.  
3. **Erro mascarado:** home não distinguia `hasError` de lista vazia com CTA de retry.  
4. **IA:** módulo existe; callable `aiAssistant` no código local, staging/rules OK, **runtime Functions pendente**.

---

## 3. Arquivos modificados (esta rodada + recentes)

- `lib/shared/services/firestore_facade.dart` — timeout 15s + purge cache no erro  
- `lib/features/home/carajas_home_screen.dart` — empty ≠ erro + retry  
- `lib/features/health/health_screen.dart` — stream estável + retry  
- `lib/shared/services/cloud_fn.dart` — timeout callables  
- `lib/features/monetization/*` — cancel subscriptions  
- `lib/features/ai_assistant/*` — personagem oficial, FAB, retry  
- `firestore.indexes.json` — índice providers+categories  
- Assets `assets/carajas_ia/*`

---

## 4. Correções implementadas

| Correção | Status |
|----------|--------|
| Timeout 15s no stream de profissionais | Feito |
| Remover cache ao erro/timeout | Feito |
| UI: falha ≠ vazio + “Tentar novamente” (Home) | Feito |
| Índice composto categoria | Declarado no JSON (**deploy indexes aguarda GO**) |
| Central Carajás 360 IA no menu/FAB | Feito |
| Grounding / sem inventar preços | Feito no backend |
| Voltar (`AppNav.safeBack` / BrandBackLink) | Já existente; mantido |

---

## 5. Testes executados e resultados

| Teste | Resultado |
|-------|-----------|
| `carajasAi` unit 9/9 | **PASS** (evidência homolog) |
| Rules audit AI collections | **PASS** |
| Smoke personagem/FAB (sessão anterior) | **PASS** |
| Loading profissionais E2E com dados reais | **NÃO EXECUTADO** (precisa rede + dados verified) |
| Login/cadastro E2E | **NÃO EXECUTADO** |
| Contratação/pagamento E2E | **NÃO** (pagamentos desligados) |
| IA mensagem live | **BLOQUEADO** (Function não deployada) |
| Build Android/iOS | **NÃO** neste host (sem device/Pods) |

---

## 6. Situação real da IA

| Item | Status |
|------|--------|
| UI Web/Mobile compartilhada | Pronta |
| Personagem oficial | Assets aplicados |
| Backend seguro (callable) | Código pronto |
| Rules histórico | Publicadas |
| Function `aiAssistant` em staging | **Pendente GO** |
| LLM Anthropic | Opcional; Blaze + secret; **chave não no frontend** |
| Declarar operacional comercial | **NÃO** |

Homolog UI atual: https://carajas360-a17c5--homolog-88u39zqx.web.app  

---

## 7. Pendências Web

- [ ] Deploy `firestore:indexes` (novo índice categoria)  
- [ ] Deploy `functions:aiAssistant`  
- [ ] Rebuild canal `homolog` com personagem oficial  
- [ ] Authorized domain + Auth Email/Google  
- [ ] Validar lista profissionais com docs `active+verified`  

## 8. Pendências Android/iOS

- [ ] Compilar em device/emulador  
- [ ] SHA / OAuth Google (oauth_client ainda vazio no Android)  
- [ ] Testar FAB + teclado + voltar  

## 9. Checklist para publicação (não “pronto” ainda)

- [ ] Zero loading infinito em Home/Explorar/Saúde (evidência)  
- [ ] Empty vs erro comprovados  
- [ ] IA E2E autenticada  
- [ ] Indexes deployed  
- [ ] Pagamentos: só com GO explícito  
- [ ] Canal `live` só com autorização  

**Veredito:** correções de estabilidade aplicadas no código; **aplicativo não declarado pronto** sem E2E funcional e deploy staging da Function/indexes.
