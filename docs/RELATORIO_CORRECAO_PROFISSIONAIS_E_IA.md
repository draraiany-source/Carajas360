# Relatório — Correção profissionais + validação IA

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Projeto:** `carajas360-a17c5`  
**Ambiente atualizado:** canal Hosting **homolog** (não live)

---

## 1. Causa do erro “Não foi possível carregar os profissionais”

### Evidências no banco (dados reais)
Existem documentos em `providers` com `active: true` e `verified: true` (ex.: Dra. Helena Saúde, Fis. Juliana Costa, Dr. Carlos Matos — seeds de homologação marcados `isTestSeed`).

### Causa técnica
1. A UI usava só `Query.snapshots()` (Listen). No Web o canal Firestore Listen frequentemente **não entrega payload** (`transferSize: 0`) → timeout/erro, **mesmo com dados no banco**.
2. Cache do browser mantinha `main.dart.js` antigo após deploys (decoded 5 777 863 vs bundle novo 5 782 344).
3. Stream **broadcast** descartava o resultado do `get()` se o Future terminasse antes do `StreamBuilder` escutar.
4. Índices remotos incompletos (JSON tinha índices single-field inválidos bloqueando deploy).
5. **Não** era ausência de cadastros nem regra (`providers` allow read: true). REST com a API key Web lista 4 docs reais.

### Correção aplicada
- `FS.providersStream`: Future em cache + na Web **REST Firestore** (docs reais) antes do SDK; fallback SDK/`get`.
- Índices deployados; single-field inválidos removidos do JSON.
- Homolog: **cache-bust** `?v=stamp` em `flutter_bootstrap.js` / `main.dart.js` + headers `Cache-Control`.
- Evidência: `docs/evidence/homolog_ia/explorar_profissionais_ok.png` — **3 profissionais encontrados**.

---

## 2. Validação Carajás IA

| Item | Status |
|------|--------|
| UI Central / FAB / CTAs Home+Explorar | **Operacional na interface** |
| Callable `aiAssistant` no projeto | **NÃO deployada** |
| Cloud Functions API | **Desabilitada / nunca usada** no projeto (`403`) |
| Billing (Blaze) | **Não** (`Billing Enabled: No`) |
| Chave Anthropic no frontend | **Não** (correto — só backend) |
| Modo grounded no código | Existe em `functions/carajasAi.js` — **só roda após deploy da Function** |

**Conclusão:** a IA **não está conectada a um provedor em runtime**. O chat responde falha explícita / pedido de login; **não** inventa profissionais. Turnos reais (busca, orçamento, etc.) **não** estão comprovados até GO: habilitar Cloud Functions API + Blaze + `firebase deploy --only functions:aiAssistant` (+ secret opcional).

---

## 3. Integração IA nas telas
- Home: CTA **Carajás 360 IA** no hero.
- Explorar: banner + **Encontrar com IA** + FAB (já existentes, mantidos).
- Rota `/#/ai`: Central com personagem e chat.

---

## 4. Visual premium
- Cards de profissionais: elevação + gradiente discreto esmeralda/branco.
- Identidade verde / branco / dourado preservada.
- Sem troca de fluxos de navegação.

---

## 5. Testes

| Teste | Resultado |
|-------|-----------|
| Unit/smoke IA | Passou |
| Analyze (arquivos tocados) | Só infos; sem errors |
| Deploy `firestore:indexes` | Passou (após limpeza) |
| Build web + channel homolog | Ver log `deploy_fix_providers.log` |
| E2E turno IA + Function | **Reprovado / bloqueado** (Function inexistente) |
| Live hosting | Site Not Found |

---

## 6. Arquivos modificados
- `lib/shared/services/firestore_facade.dart`
- `lib/features/home/carajas_home_screen.dart`
- `lib/features/search/universal_search_screen.dart`
- `lib/shared/widgets/brand_provider_card.dart`
- `firestore.indexes.json`
- Docs em `docs/`

---

## 7. URL / versão
- Homolog: https://carajas360-a17c5--homolog-88u39zqx.web.app  
- Explorar: `…/#/search`  
- Central IA: `…/#/ai`  
- Live: **não** atualizado (Site Not Found; sem GO)

---

## 8. Pendências para GO
1. Habilitar **Cloud Functions API** + plano **Blaze**.
2. Deploy `functions:aiAssistant` (e rules já preparadas).
3. Autorizar domínio homolog no Auth.
4. E2E autenticado: busca profissional real, orçamento, agendamento.
5. Anthropic opcional via Secret Manager (`BIND_ANTHROPIC_SECRET=true`).

**App não declarado pronto para IA comercial** — UI sim; backend IA não.
