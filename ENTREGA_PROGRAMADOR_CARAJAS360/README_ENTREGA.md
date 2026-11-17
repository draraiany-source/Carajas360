# Carajás 360 — Pacote de entrega ao programador (FASE 14)

| Campo | Valor |
|--------|--------|
| Versão app | **1.0.0+403** |
| Commit | **686d16c** (`686d16c5f0b9e9eae24a661c5506f290b5fd8046`) |
| Branch | `feat/modernizacao-visual` |
| Firebase | `carajas360-a17c5` |
| Homolog Web | https://carajas360-a17c5--homolog-88u39zqx.web.app |
| Estado publicação | **NÃO APTO** (Fases 12 e 13) |

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
| `MAPA_FLUXOS.md` | Fluxogramas Mermaid (fonte) |
| `SEGURANCA_CREDENCIAIS.md` | Como tratar secrets |

## Código-fonte

**Não** recriar o app. Trabalhar no repositório existente:

```bash
git fetch
git checkout 686d16c
# ou branch feat/modernizacao-visual a partir deste commit
flutter pub get
cd functions && npm test && cd ..
```

O ZIP deste pacote contém **documentação**. O código completo fica no Git no commit acima (respeitando tamanho e segurança — sem keystores/tokens).

### Relatórios de origem no repo

- `docs/AUDITORIA_FINAL_CARAJAS360.md` (Fase 12)
- `docs/FASE13_CARAJAS360.md` (Fase 13)
- `docs/AUDITORIA_TELAS_CARAJAS360.md`
- `docs/FASE13_GO_EXTERNOS.md`
- `docs/IOS_BUILD_TESTFLIGHT.md`
- `scripts/homolog_web_preview.ps1`
- `scripts/live_web_deploy.ps1` (exige `-IAuthorizeLiveDeploy`)

## Resumo rápido

| Pronto | Programador corrige/homologa | Proprietária (GO) | Contas externas |
|--------|------------------------------|-------------------|-----------------|
| App Flutter multiplataforma | Builds APK/AAB após disco+keystore | Blaze Firebase | Apple Developer |
| Homolog Web + Explorar | Deploy Functions após API | Secrets Anthropic/MP | Play Console |
| Código pedidos/chat/admin | E2E cliente/profissional | GO live hosting | Mercado Pago |
| UI IA + erro honesto | Evidências IA/pagamentos | GO publicação | Anthropic (opcional) |

**Builds ainda necessários:** APK debug, AAB+SHA256, IPA/TestFlight.  
**Não declarar pronto para publicação** sem checklist 10 + critérios 12.
