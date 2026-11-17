# Checklist Android / iOS / Web — Carajás 360 (FASE 16)

**HEAD baseline:** `a95b2e5` · **Versão:** `1.0.0+403`  
Marcar: [x] existe/comprovado · [ ] pendente · [N/A] não aplicável

---

## WEB

| Item | Status FASE 16 | Nota |
|------|----------------|------|
| Projeto Flutter Web | [x] | `flutter` web |
| Hosting homolog | [x] | HTTP 200 `…--homolog-88u39zqx.web.app` |
| Hosting live | [ ] | HTTP 404 |
| Rotas principais homolog | [x] parcial | Home/Explorar evidenciados em fases anteriores |
| Auth OAuth domains | [ ] | Config Console |
| Privacy/Terms hosting paths | [x] código | `firebase.json` rewrites |
| Deploy live script | [x] | `scripts/live_web_deploy.ps1` (exige GO) |

**Artefatos a produzir:** release live (GO), smoke autenticado homolog completo.

---

## ANDROID

| Item | Status | Nota |
|------|--------|------|
| Projeto `android/` | [x] | package `br.com.carajas360` |
| `key.properties.example` | [x] | sem keystore no Git |
| `key.properties` local | [ ] | programador |
| APK debug HEAD | [ ] | gerar |
| AAB release HEAD | [ ] | gerar + SHA256 |
| Play App Signing | [ ] | conta Play |
| Teste device real | [ ] | login + orçamento + foto |
| Permissões câmera/galeria | [x] código | validar device |

**Artefatos a produzir:** APK, AAB, SHA256, screenshots device (complemento, não único aceite).

---

## iOS

| Item | Status | Nota |
|------|--------|------|
| Projeto `ios/` / Xcode | [x] existência | |
| Bundle id alinhado | [x] esperado | validar no Mac |
| Certificados / provisioning | [ ] | Apple Developer |
| IPA | [ ] | |
| TestFlight | [ ] | |
| Teste device real | [ ] | |
| Permissões Info.plist câmera/mic | [ ] | validar no Mac |

**Artefatos a produzir:** archive, IPA, TestFlight build, smoke device.

---

## Cross-plataforma (comum)

| Item | Status |
|------|--------|
| `pubspec` version | [x] 1.0.0+403 |
| Firebase options (cliente) | [x] projeto real |
| Storage prod | [ ] bucket |
| Functions deploy | [ ] Blaze |
| Crashlytics | [x] dependência; validar runtime |

---

## Resumo honesto

| Plataforma | Publicável agora? |
|------------|-------------------|
| Web homolog | Uso interno/homologação — **SIM parcial** |
| Web live | **NÃO** |
| Android loja | **NÃO** |
| iOS loja | **NÃO** |
