# Carajás 360 — Pacote de entrega ao programador (FASES 14–15)

| Campo | Valor |
|--------|--------|
| Versão app | **1.0.0+403** |
| HEAD auditoria F15 (código) | **e07b633** |
| Commit pacote docs F15 | **87c5f37** |
| Pacote docs F14 | **82dc012** |
| Branch | `feat/modernizacao-visual` |
| Firebase | `carajas360-a17c5` |
| Homolog Web | https://carajas360-a17c5--homolog-88u39zqx.web.app |
| ZIP | `ENTREGA_PROGRAMADOR_CARAJAS360_F15_e07b633.zip` |
| SHA256 ZIP | `3CC0CA0DFA04AAF3C9D58A9A5975137AFD799BCCDDCE07D925193F7468A75B5C` |
| Estado publicação | **NÃO APTO** (Fases 12–15) |
| Entrega ao programador (veredito A) | **SIM** |

## Conteúdo desta pasta

| Arquivo | Assunto |
|---------|---------|
| `01_RELATORIO_EXECUTIVO.pdf` | Visão geral e responsabilidades |
| `02_INVENTARIO_TELAS.pdf` | Telas/rotas/módulos classificados |
| `03_MAPA_FLUXOS.pdf` | Cliente, pro, admin, pagamento, IA |
| `04_PENDENCIAS_TECNICAS.pdf` | P0/P1 e o que não fazer sem GO |
| `05_GUIA_FIREBASE_IA.pdf` | Blaze, APIs, deploy `aiAssistant` |
| `06_GUIA_PAGAMENTOS.pdf` | Mercado Pago sandbox (sem cobrança real) |
| `07_GUIA_ANDROID.pdf` | Gradle, APK, keystore, AAB |
| `08_GUIA_IOS.pdf` | Xcode, TestFlight, loja |
| `09_GUIA_WEB.pdf` | Homolog, live, Auth domains |
| `10_CHECKLIST_PUBLICACAO.pdf` | Gate de publicação |
| `11_ROTEIRO_TESTES.pdf` | Testes obrigatórios |
| `12_CRITERIOS_ACEITE.pdf` | Aceite do serviço contratado |
| `13_AUDITORIA_MULTIMIDIA.pdf` | Fotos IT; vídeo/áudio ausentes no orçamento |
| `14_TESTES_EVIDENCIAS.pdf` | Matriz APROVADO/REPROVADO/N-E FASE 15 |
| `15_PLANO_FINALIZACAO_PROGRAMADOR.pdf` | Ordem de trabalho sugerida |
| `EDITAL_CONTRATACAO_PROGRAMADOR.pdf` | Texto para Workana |
| `MAPA_FLUXOS.md` | Fluxogramas Mermaid (fonte) |
| `SEGURANCA_CREDENCIAIS.md` | Como tratar secrets |
| `docs/FASE15_AUDITORIA_DEFINITIVA.md` | Auditoria completa no repo |

## Código-fonte

**Não** recriar o app. Trabalhar no repositório existente:

```bash
git fetch
git checkout feat/modernizacao-visual
# baseline de código auditado na F15: e07b633
# pacote de documentação F15: 87c5f37 (ou tip da branch)
flutter pub get
cd functions && npm test && cd ..
```

O ZIP `ENTREGA_PROGRAMADOR_CARAJAS360_F15_e07b633.zip` contém **documentação**. O código completo fica no Git (respeitando tamanho e segurança — sem keystores/tokens).

### Relatórios de origem no repo

- `docs/AUDITORIA_FINAL_CARAJAS360.md` (Fase 12)
- `docs/FASE13_CARAJAS360.md` (Fase 13)
- `docs/AUDITORIA_TELAS_CARAJAS360.md`
- `docs/RELATORIO_ORCAMENTO_FOTOS_IA.md` (**fotos no orçamento** — E2E emuladores OK; bucket live pendente billing)
- `docs/FASE13_GO_EXTERNOS.md`
- `docs/IOS_BUILD_TESTFLIGHT.md`
- `scripts/homolog_web_preview.ps1`
- `scripts/live_web_deploy.ps1` (exige `-IAuthorizeLiveDeploy`)

### Orçamento com fotos — aceite técnico

1. Código: `OrderPhotoPicker` / `uploadOrderPhoto` / galerias / visita / proposta.  
2. Unitários: `order_photos_test` + `order_photos_flow_test` (8 pass).  
3. E2E emuladores: `order_photos_emulator_e2e_test` — upload, ACL cliente/pro/deny estranho, attach `photoUrls`, delete (**PASS**, ver `docs/evidence/orcamento_fotos/`).  
4. Firestore rules `photoUrls` **já deployadas**.  
5. Storage rules: delete ACL corrigido (sem `request.resource` no delete).  
6. **P0 produção:** vincular billing → criar bucket → `firebase deploy --only storage` → smoke no app homolog.

## Resumo rápido

| Pronto | Programador corrige/homologa | Proprietária (GO) | Contas externas |
|--------|------------------------------|-------------------|-----------------|
| App Flutter multiplataforma | Builds APK/AAB após disco+keystore | Blaze Firebase | Apple Developer |
| Homolog Web + Explorar | Deploy Functions após API | Secrets Anthropic/MP | Play Console |
| Código pedidos/chat/admin | E2E cliente/profissional | GO live hosting | Mercado Pago |
| UI IA + erro honesto | Evidências IA/pagamentos | GO publicação | Anthropic (opcional) |

**Builds ainda necessários:** APK debug, AAB+SHA256, IPA/TestFlight.  
**Não declarar pronto para publicação** sem checklist 10 + critérios 12.
