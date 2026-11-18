# Matriz de pendências — FASE 17

**HEAD base:** `031ab29` · **Firebase:** `carajas360-a17c5`

## P0 — Impede publicação / segurança / runtime crítico

| ID | Problema | Módulo | Evidência | Solução | Dependência | Aceite |
|----|----------|--------|-----------|---------|-------------|--------|
| P0-1 | Live Web HTTP 404 | Hosting | Probe F17 | Deploy live **com GO** (`scripts/live_web_deploy.ps1`) | GO contratante | `carajas360-a17c5.web.app` = 200 |
| P0-2 | Billing Blaze = false | Firebase | gcloud + MCP | Upgrade Blaze (pago) | GO financeiro | Billing enabled |
| P0-3 | Cloud Functions API 403 | Functions/IA/Pay | MCP list 403 | Habilitar API + deploy | P0-2 | `functions:list` OK |
| P0-4 | Storage sem bucket | Fotos | 0 buckets | Console Get Started + `deploy --only storage` | P0-2 | Upload prod |
| P0-5 | IA sem turno LLM real | Carajás IA | CF 403 | Deploy `aiAssistant` + secret opcional | P0-2/3 | Resposta grounded real |
| P0-6 | MP sandbox N/E | Pagamentos | Flags/token | Token TEST + `PAYMENTS_ENABLED` sandbox | P0-2 + MP | PIX/cartão/webhook |
| P0-7 | Sem AAB deste HEAD | Android | Artefato ausente | key.properties + build | Keystore | AAB+SHA256 |
| P0-8 | Sem IPA/TestFlight | iOS | Windows | Mac + Xcode + Apple | Conta Apple | TestFlight |

## P1 — Funcionalidades importantes

| ID | Problema | Solução | Aceite |
|----|----------|---------|--------|
| P1-1 | Vídeo no orçamento ausente | Estender picker + rules | Upload+preview |
| P1-2 | Áudio no orçamento ausente | Reusar padrão chat | Áudio no order |
| P1-3 | E2E cliente autenticado N/E | Contas teste + roteiro | Fluxo completo |
| P1-4 | E2E profissional N/E | Conta pro + admin | Até recebimento |
| P1-5 | E2E admin N/E | Conta admin | Disputas/pagamentos |

## P2 — Melhorias

| ID | Problema | Nota |
|----|----------|------|
| P2-1 | Paridade visual premium 3D pixel | Só com aditivo |
| P2-2 | Widget tests históricos instáveis | CI |
| P2-3 | OAuth domains / domínio custom | Console |

## Já comprovado (não reabrir sem regressão)

- Functions unit **163/163** (F17)
- Flutter fotos/config **14/14** (F17)
- Fotos E2E **emuladores** (sessão anterior)
- Homolog Web **200**
- Firestore rules `photoUrls` deployadas (fase fotos)
- Pacote FASE 16 Workana no GitHub
