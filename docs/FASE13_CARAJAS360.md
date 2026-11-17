# FASE 13 — Correção dos bloqueadores e preparação Android/iOS

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Versão:** `1.0.0+403` (base auditoria FASE 12: `1.0.0+402`)  
**Projeto Firebase:** `carajas360-a17c5`  
**Referência:** `docs/AUDITORIA_FINAL_CARAJAS360.md`

## Veredito

# **NÃO APTO para publicação**

Correções de código/testes e preparação de scripts foram feitas.  
**Não** há evidência de turno IA real, pagamento sandbox E2E, AAB assinado nem IPA.  
**Não** foi alterado faturamento Blaze. **Não** houve deploy live.

---

## 1. Bloqueadores resolvidos (código / preparação)

| Item | Ação |
|------|------|
| Testes Flutter (placeholders / identity / Explorar) | Atualizados para `firebase_options` reais; `HomologCatalog.debugOverrideEnabled` só em testes |
| Suite focada | **19/19** passed (`firebase_placeholders`, `bloco_c_identity`, `universal_search_screen`) |
| Functions unitários | **163/163** pass (`docs/evidence/fase13/functions_test.txt`) |
| `flutter analyze` lib/test | Sem **errors**; warnings/infos pré-existentes (~134) |
| Hosting live 404 — diagnóstico | Sem release live; só canal homolog. Script `scripts/live_web_deploy.ps1` exige `-IAuthorizeLiveDeploy` |
| Script homolog | `--no-wasm-dry-run` (já aplicado) |
| Docs iOS / GO externos | `docs/IOS_BUILD_TESTFLIGHT.md`, `docs/FASE13_GO_EXTERNOS.md`, `docs/FASE13_ROTEIRO_E2E.md` |
| Webhook MP (código prévio) | Continua exigindo `payments/{id}` + status aprovado |

---

## 2. Bloqueadores pendentes (externos / GO)

| # | Bloqueador | Evidência FASE 13 |
|---|------------|-------------------|
| 1 | **Billing Blaze = No** | MCP `firebase_get_environment`: `Billing enabled: No` |
| 2 | Cloud Functions API **403** | `functions_list_functions` → API not used/disabled |
| 3 | `aiAssistant` não deployável sem Blaze/API | Código OK; runtime N/E |
| 4 | Turno IA real | Sem Function → sem conversa LLM evidenciada |
| 5 | Pagamentos sandbox E2E | Sem token/`PAYMENTS_ENABLED` GO |
| 6 | Hosting live 404 | Sem GO para `live_web_deploy` |
| 7 | AAB assinado | Sem `android/key.properties` |
| 8 | IPA / TestFlight | Windows sem Xcode |
| 9 | Disco C: quase cheio | Build APK/AAB pode falhar por ENOSPC |

---

## 3. Firebase e IA

### 403 — causa raiz
Cloud Functions API desabilitada / nunca usada no projeto **e** billing **não** habilitado.  
Link de enable (owner):  
https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=carajas360-a17c5  

**Não alteramos faturamento.**

### `aiAssistant`
- Callable autenticada, grounded em providers reais, chave só no backend/Secret Manager.  
- Deploy **não executado** (403 / sem Blaze).  
- **Evidência IA real:** **não gerada** nesta fase.

---

## 4. Fluxos cliente / profissional

| Fluxo | Código | E2E autenticado |
|-------|--------|-----------------|
| Cliente cadastro→avaliação | OK (fases 3–4) | **N/E** (sem contas teste nesta sessão) |
| Profissional cadastro→recebimento | OK (sem demo) | **N/E** |

Roteiro: `docs/FASE13_ROTEIRO_E2E.md`.

---

## 5. Pagamentos

| Item | Status |
|------|--------|
| Unitários policy/webhook | **163 pass** |
| PIX/cartão/webhook sandbox runtime | **N/E** — sem GO |
| Cobrança real | **Não ativada** |

---

## 6. Flutter / Android

| Item | Resultado |
|------|-----------|
| Testes críticos corrigidos | **Pass** |
| `flutter analyze` | Sem errors (warnings restantes) |
| APK debug interno | **Não gerado** — Gradle daemon crash (disco C: / heap); log em evidências |
| AAB release assinado | **Não gerado** (sem keystore + disco) |

---

## 7. iOS

Preparação documentada em `docs/IOS_BUILD_TESTFLIGHT.md`.  
**IPA não gerado** (ambiente Windows).

---

## 8. Hosting / Web

| URL | Status |
|-----|--------|
| Homolog `…--homolog-88u39zqx.web.app` | **200** (canal preview) |
| Live `carajas360-a17c5.web.app` | **404** — sem versão live |
| `firebaseapp.com` | **404** |

Causa: nunca houve `firebase deploy --only hosting` live; homolog usa canal.  
`firebase.json` do repo aponta `hosting/` (páginas legais), não o Flutter — o script live monta `build/web` temporário.

---

## 9. Artefatos / evidências

| Artefato | Caminho |
|----------|---------|
| Este relatório | `docs/FASE13_CARAJAS360.md` |
| GO externos | `docs/FASE13_GO_EXTERNOS.md` |
| Roteiro E2E | `docs/FASE13_ROTEIRO_E2E.md` |
| iOS | `docs/IOS_BUILD_TESTFLIGHT.md` |
| Functions test | `docs/evidence/fase13/functions_test.txt` |
| Analyze | `docs/evidence/fase13/flutter_analyze.txt` |
| APK / AAB / SHA256 | **ausente** — liberar disco + keystore antes de novo build |
| Evidência IA real | **ausente** |
| Evidência MP sandbox | **ausente** |

---

## 10. Próximas ações externas (owner)

1. Liberar **espaço em disco** no Windows (C:).  
2. **GO Blaze** + habilitar Cloud Functions API.  
3. Deploy `aiAssistant` (+ secret Anthropic opcional).  
4. Conversa IA real + screenshot/log.  
5. Contas teste → executar roteiro E2E.  
6. Token MP sandbox + `PAYMENTS_ENABLED` (não produção).  
7. `android/key.properties` → AAB + SHA256.  
8. Mac + Apple Developer → IPA/TestFlight.  
9. **GO** explícito → `scripts/live_web_deploy.ps1 -IAuthorizeLiveDeploy`.

---

*FASE 13 não declara APTO. Homolog continua adequado à demonstração parcial (UI + profissionais), sem IA/pagamentos comerciais.*
