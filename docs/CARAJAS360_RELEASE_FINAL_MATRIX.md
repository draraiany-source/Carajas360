# CARAJAS360 — Release Final Matrix

**Branch:** `fix/correcao-completa-final`  
**Commits:** `3700d05` restore, `1ac2045` fixes (+ docs commit atual)  
**Version:** `1.0.0+402`  
**Payments:** OFF  
**Status agregado:** 🟡 CÓDIGO CORRIGIDO — DEPENDÊNCIAS EXTERNAS PENDENTES

Legenda: **PASS** | **FAIL** | **NOT TESTED** | **EXTERNAL** | **NOT APPLICABLE**

---

## Matriz completa

| AREA | ITEM | RESULTADO | NOTA / EVIDENCIA |
|------|------|-----------|------------------|
| Qualidade | flutter analyze | PASS | 0 errors, 82 warnings, 68 infos |
| Qualidade | flutter test | PASS | 134 pass, 1 skip, 0 fail |
| Qualidade | functions npm test | PASS | 115 pass, 0 fail |
| Codigo | mounted / context.mounted guards | PASS | fixes em 1ac2045 |
| Codigo | chat bytes fallback | PASS | fixes em 1ac2045 |
| Codigo | firestore cast | PASS | fixes em 1ac2045 |
| Codigo | hosting pages locais | PASS | privacy, terms, account-deletion, support |
| Codigo | firebase rewrites | PASS | firebase.json |
| Build | APK release | PASS | size 81900337; SHA256 7BFF7E8FAA875F06FABF752224B2A95F75035697003CEDE7EEDF818500CEC069 |
| Build | AAB release | PASS | size 76951191; SHA256 C13110A65C8D0462F0CA924E93D6E917FC0DA1A517F8B5C43AD52AE88B45FDC1 |
| Build | evidence android | PASS | docs/evidence/correcao_final_android_build.md |
| Financeiro | Payments production | PASS | OFF (intencional) |
| Financeiro | Commission config/platform + order snapshot | PASS | default fallback 0.08; ja testado |
| Financeiro | Ativacao financeira producao | NOT APPLICABLE | fora deste gate; payments OFF |
| Legal / Hosting | Paginas hosting no repo | PASS | READY |
| Legal / Hosting | Privacy live URL | FAIL | 404 ate `firebase deploy --only hosting`; https://carajas360-a17c5.web.app/privacy |
| Legal / Hosting | Terms / account-deletion / support live | FAIL | mesmo deploy hosting pendente |
| E2E | Device E2E | NOT TESTED | dispositivo/adb |
| E2E | Sandbox MP E2E | EXTERNAL | secrets/token TEST/webhook |
| Mobile | iOS build / E2E | NOT TESTED | macOS + Xcode |
| Cloud | Firebase prod / App Check | EXTERNAL | config owner |
| Cloud | HomologCatalog | PASS | apenas com Firebase placeholders |
| Seguranca | Private keys no git | PASS | placeholders only |
| Ops | DNS MX | EXTERNAL | checklist DNS |
| Ops | Backup operacional | EXTERNAL | rotina operacional |
| Store | Play Console upload/listing | EXTERNAL | AAB pronto localmente |
| Store | Apple App Store | EXTERNAL | requer Apple/macOS |
| Release | Push remoto desta sessao | NOT APPLICABLE | Do NOT push |
| Release | Deploy desta sessao | NOT APPLICABLE | Do NOT deploy |

---

## Resumo por categoria

| Categoria | Verdict |
|-----------|---------|
| Suites automaticas | PASS |
| Artefatos Android | PASS |
| Codigo da correcao | PASS |
| Legal live (hosting) | FAIL |
| Device / iOS E2E | NOT TESTED |
| Sandbox / Firebase prod / DNS / Stores / Backup | EXTERNAL |
| Payments ON | NOT APPLICABLE (OFF) |

**Gate final:** 🟡 CÓDIGO CORRIGIDO — DEPENDÊNCIAS EXTERNAS PENDENTES