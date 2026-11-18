# Relatório Web / Android / iOS — FASE 17

## Web

| Item | Status |
|------|--------|
| Flutter Web | SIM |
| Homolog channel | **https://carajas360-a17c5--homolog-88u39zqx.web.app** — HTTP **200** |
| Live `carajas360-a17c5.web.app` | HTTP **404** — sem release (GO para publicar) |
| SPA rewrites | Presentes |
| Deploy script live | `scripts/live_web_deploy.ps1` (exige autorização) |

## Android

| Item | Status |
|------|--------|
| Projeto `android/` | SIM |
| applicationId esperado | `br.com.carajas360` |
| `key.properties.example` | SIM |
| `key.properties` / JKS | Locais (gitignore) — **não** no commit |
| APK/AAB deste HEAD | **Não gerados nesta fase** |
| Motivo | Assinatura + tempo/disco; não declarar AAB sem arquivo |

## iOS

| Item | Status |
|------|--------|
| Projeto `ios/` | SIM |
| Bundle ID | `br.com.carajas360` (MCP/options) |
| IPA / TestFlight | **Não gerados** |
| Bloqueio | Ambiente Windows — requer **macOS + Xcode + Apple Developer** |

### Passos iOS (programador Mac)

1. Abrir `ios/Runner.xcworkspace`  
2. Signing Team + bundle  
3. Archive → IPA / TestFlight  
4. Smoke device (login, orçamento, foto)
