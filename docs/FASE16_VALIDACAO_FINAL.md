# FASE 16 — Validação final, entrega técnica e contratação Workana

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**HEAD:** `a95b2e5` (*docs(orders): versiona log E2E emulator de fotos…*)  
**Baseline FASE 15:** `docs/FASE15_AUDITORIA_DEFINITIVA.md` (HEAD auditado então: `e07b633`)  
**Versão app:** `1.0.0+403`  
**Firebase:** `carajas360-a17c5`  
**Regra:** não recriar app; não inventar evidências; não expor segredos.

---

## Confirmação FASE 15

Relatório **existe** e foi usado como baseline: `docs/FASE15_AUDITORIA_DEFINITIVA.md`.  
FASE 16 **atualiza** o HEAD para `a95b2e5` (evidência E2E fotos versionada) sem alterar o veredito de publicação.

---

## 1. Conferência final do projeto

| Item | Status | Evidência |
|------|--------|-----------|
| Código no Git | OK | Branch `feat/modernizacao-visual` |
| Commit final pacote | `a95b2e5` | `git rev-parse HEAD` |
| Telas e rotas | Inventariadas (~40+) | `docs/AUDITORIA_TELAS_CARAJAS360.md` |
| Fluxo cliente/pro | Código IS; E2E auth N/E | FASE 15 |
| Painel admin | Código IS; E2E N/E | AdminGate + Disputas |
| Orçamento **fotos** | IT (unit + emulator) | `docs/evidence/orcamento_fotos/` |
| Orçamento **vídeo/áudio** | AU no pedido | FASE 15 §5 |
| Carajás IA | UI IS; LLM BX | Blaze off / CF 403 |
| Mercado Pago | Código+unit IT; sandbox N/E | Functions 163/163 |
| Firebase | Auth/Firestore OK; Storage prod BX | billing false |
| Web homolog | HTTP **200** | FASE 16 probe |
| Web live | HTTP **404** | FASE 16 probe |
| Android AAB/APK | Não gerados neste HEAD | Disco/keystore |
| iOS IPA/TestFlight | Não gerados (Windows) | — |

### Testes FASE 16 (executados)

| Suite | Resultado | Artefato |
|-------|-----------|----------|
| `flutter test` order_photos + placeholders | **14/14 PASS** | `docs/evidence/fase16_flutter_photos.txt` |
| `functions` `npm test` | **163/163 PASS** | `docs/evidence/fase16_functions_test.txt` |
| Homolog Web | **200** | probe 2026-11-17 |
| Live Web | **404** | probe 2026-11-17 |
| Billing | **false** | `gcloud billing projects describe` |
| E2E fotos (emuladores, sessão anterior) | **PASS** | `docs/evidence/orcamento_fotos/emulator_e2e.txt` |
| E2E cliente→pagamento autenticado | **NÃO EXECUTADO** | — |
| IA turno real LLM | **NÃO EXECUTADO** | — |
| MP sandbox | **NÃO EXECUTADO** | — |
| APK/AAB/IPA | **NÃO EXECUTADO** | — |

---

## 2. Pendências (P0 / P1 / P2)

### P0 — Impede publicação ou compromete segurança

| ID | Problema | Módulo | Arquivo / área | Causa | Solução | Dependências | Aceite |
|----|----------|--------|----------------|-------|---------|--------------|--------|
| P0-1 | Live hosting 404 | Web | Hosting Firebase | Sem release live | Deploy com GO (`scripts/live_web_deploy.ps1`) | GO contratante | `carajas360-a17c5.web.app` = 200 + rotas OK |
| P0-2 | Blaze / CF API 403 | Firebase / IA / pagamentos | Cloud Functions | Billing ausente | Upgrade Blaze + habilitar APIs | Conta Google owner | `functions:list` OK; deploy possível |
| P0-3 | Storage bucket prod ausente | Orçamento fotos | Storage | Billing / não iniciado | Get Started Storage + `deploy --only storage` | P0-2 | Upload real homolog + rules |
| P0-4 | IA sem runtime LLM | Carajás IA | `aiAssistant` | Function não deployável | Deploy + secret Anthropic opcional | P0-2 | Turno real com grounded providers |
| P0-5 | Pagamentos sandbox N/E | Pagamentos | Functions MP | Flags off / sem token TEST | Token TEST + `PAYMENTS_ENABLED` sandbox | P0-2 + MP | PIX/cartão/webhook sandbox comprovados |
| P0-6 | Sem AAB deste HEAD | Android | `android/` | Disco/keystore | `key.properties` + build release | Keystore local | AAB + SHA256 |
| P0-7 | Sem IPA/TestFlight | iOS | `ios/` | Sem macOS nesta entrega | Xcode + Apple Developer | Mac + conta Apple | IPA no TestFlight |

### P1 — Funcionalidades importantes

| ID | Problema | Módulo | Solução | Aceite |
|----|----------|--------|---------|--------|
| P1-1 | Vídeo curto ausente no orçamento | Solicitação | Estender picker + Storage rules | Upload ≤ limite + preview |
| P1-2 | Áudio ausente no orçamento (existe no chat) | Solicitação | Mesmo padrão do chat no pedido | Áudio associado ao order |
| P1-3 | E2E cliente autenticado N/E | Fluxos | Contas teste + roteiro | Cadastro→avaliação sem falha |
| P1-4 | E2E profissional N/E | Fluxos | Conta pro + admin | Cadastro→recebimento |
| P1-5 | E2E admin N/E | Admin | Conta admin | Aprovação/disputas/relatórios |

### P2 — Melhorias não bloqueantes

| ID | Problema | Solução |
|----|----------|---------|
| P2-1 | Paridade visual “premium 3D” N/E | Comparação pixel a pixel se contratado |
| P2-2 | Widget tests Explorar instáveis (histórico F12) | Estabilizar suite completa |
| P2-3 | Domínios OAuth homolog/prod | Config Auth Console |
| P2-4 | Domínio custom Web | DNS + Hosting |

---

## 3. Plano de testes de fluxo (execução)

### Cliente
`Cadastro → Explorar → Orçamento(+fotos) → Proposta → Aceite → Pagamento → Conclusão → Avaliação`  
**Código:** IS · **E2E auth:** N/E · **Fotos emulator:** IT

### Profissional
`Cadastro → Aprovação admin → Solicitação → Proposta → Atendimento → Recebimento`  
**Código:** IS · **E2E:** N/E

### Admin
`Aprovação → Monitoramento → Pagamentos → Disputas → Relatórios`  
**Código:** IS · **E2E:** N/E

Roteiro detalhado: `PLANO_TESTES_FINAL` neste pacote.

---

## 4. Inteligência Artificial

| Aspecto | Status |
|---------|--------|
| UI Central / FAB / modos | Implementado |
| Callable `aiAssistant` | Código presente; **não listável/deployável** (403) |
| Modelo real nesta fase | **NÃO** |
| Análise fotos (sugestão descrição) | Código seguro (sem preço/diagnóstico); runtime CF pendente |
| Config necessária | Blaze + APIs + deploy Function + Secret `ANTHROPIC_API_KEY` (opcional; fallback grounded) |

**Não expor** tokens Anthropic / MP / keystores neste pacote.

---

## 5. Artefatos Android / iOS / Web

| Artefato | Existe? |
|----------|---------|
| Projeto Flutter Android/iOS/Web | SIM |
| Homolog Web | SIM (200) |
| Live Web | NÃO (404) |
| APK debug/release HEAD | NÃO comprovado |
| AAB + assinatura | NÃO |
| IPA / TestFlight | NÃO |
| Keystore no Git | NÃO (correto) |

---

## 6. Marcos Workana (pagamento)

| Marco | Escopo | Entregáveis verificáveis |
|-------|--------|--------------------------|
| **1** | Críticos, Firebase, IA | Blaze/APIs; Storage rules; deploy `aiAssistant`; prova turno IA; lista P0 parcial fechada |
| **2** | Fluxos + multimídia + MP sandbox | E2E cliente/pro; vídeo/áudio se no escopo; PIX/cartão/webhook sandbox |
| **3** | Android/iOS dispositivos | APK; AAB+SHA256; IPA TestFlight; evidências device |
| **4** | Homologação + docs + prep publicação | Checklist completo; live só com GO; termo de entrega |

Aceite de marco **não** é só screenshot: logs, URLs, builds e testes objetivos.

---

## 7. Veredito FASE 16

| Pergunta | Resposta | Evidência |
|----------|----------|-----------|
| **PRONTO PARA CONTRATAR PROGRAMADOR** | **SIM** | Pacote F14–F16 + FASE 15 + escopo/pendências claros |
| **PRONTO PARA PUBLICAR WEB** | **NÃO** | Live 404; GO + deploy |
| **PRONTO PARA PUBLICAR ANDROID** | **NÃO** | Sem AAB deste HEAD |
| **PRONTO PARA PUBLICAR IOS** | **NÃO** | Sem IPA/TestFlight |
| **INTELIGÊNCIA ARTIFICIAL FUNCIONAL** | **NÃO** | Sem turno LLM real (Blaze/CF) |
| **PAGAMENTOS HOMOLOGADOS** | **NÃO** | Sandbox E2E N/E |
| **ORÇAMENTOS MULTIMÍDIA FUNCIONAIS** | **PARCIAL** | Fotos IT (emulator); vídeo/áudio AU; Storage prod BX |

**NÃO APTO PARA PUBLICAÇÃO** sem fechar P0 e E2E autenticados.

---

## 8. Pacote gerado

Pasta: `ENTREGA_PROGRAMADOR_CARAJAS360/` + `docs/FASE16_*`  
ZIP: `ENTREGA_PROGRAMADOR_CARAJAS360/ZIP_DOCUMENTACAO_FINAL.zip`
