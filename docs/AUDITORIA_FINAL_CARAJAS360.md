# AUDITORIA FINAL — Carajás 360 (FASE 12)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Commit auditado:** `9880c6f`  
**Versão app (`pubspec`):** `1.0.0+402`  
**Projeto Firebase:** `carajas360-a17c5`  
**Escopo:** auditoria das fases 1–11 com testes reais onde possível; **sem** republicar nas lojas e **sem** deploy live.

---

## VEREDITO DE PUBLICAÇÃO

# **NÃO APTO para publicação**

O produto **não** deve ser publicado nas lojas nem em hosting live neste estado.

### Bloqueadores P0 (impedem “APTO”)

| # | Bloqueador | Evidência |
|---|------------|-----------|
| 1 | Hosting **live** indisponível (404) | `Invoke-WebRequest` → 404 em `carajas360-a17c5.web.app` e `.firebaseapp.com` |
| 2 | Cloud Functions API **desabilitada** / 403 | MCP `functions_list_functions` → HTTP 403 *Cloud Functions API has not been used…* |
| 3 | Carajás IA **sem turno LLM real** | UI OK no homolog; Function `aiAssistant` não listável/deployável sem API; docs prévios confirmam não deploy |
| 4 | Pagamentos produção / sandbox E2E **não comprovados** | `PAYMENTS_ENABLED` / GO ausentes; sem cobrança real testada nesta fase |
| 5 | AAB **desta branch/commit** não gerado | Build release iniciado e sem artefato; pasta `build/.../app-release.aab` ausente |
| 6 | iOS / TestFlight **não testados** | Ambiente Windows; sem IPA |

Homolog Web e vários testes de código **passam**, mas isso **não** autoriza publicação comercial.

---

## 1. Resumo das 11 fases (auditoria)

| Fase | Tema | Status auditoria FASE 12 | Nota |
|------|------|--------------------------|------|
| 1 | Auditoria de telas | **APROVADO** | `docs/AUDITORIA_TELAS_CARAJAS360.md` |
| 2 | Organizar rotas / demo / disputas | **APROVADO (código)** | `e3ca8b4` + relatório FASE 2 |
| 3 | Tela a tela (cliente P0) | **APROVADO (código)** | `acf93b6` |
| 4 | Fluxo E2E cliente | **NÃO TESTADO** (E2E) / código parcial | Sem login+pedido+pagamento ponta a ponta nesta sessão |
| 5 | Fluxo profissional | **NÃO TESTADO** (E2E) / código parcial | Demo removido; E2E cadastro→recebimento N/E |
| 6 | Pagamentos / comissões / webhook | **REPROVADO** p/ publicação | Código + unitários OK; runtime MP N/E; API CF 403 |
| 7 | Carajás IA | **REPROVADO** p/ publicação | UI APROVADA; runtime LLM REPROVADO |
| 8 | Erro profissionais | **APROVADO** (homolog) | Explorar com 3 profissionais (2026-11-17 + PNG prévio) |
| 9 | Android / iOS | **REPROVADO** / **NÃO TESTADO** | Projeto existe; AAB atual N/E; iOS N/E |
| 10 | Matriz homologação | **APROVADO** (documento) | Atualizado por esta auditoria |
| 11 | Entrega programador | **APROVADO** (documento) | `ENTREGA_PROGRAMADOR_CARAJAS360.md` |

---

## 2. Matriz de verificação (item a item)

Legenda: **APROVADO** | **REPROVADO** | **NÃO TESTADO**

### 2.1 Telas, botões, formulários e navegação

| Item | Resultado | Evidência | Erros | Correções necessárias |
|------|-----------|-----------|-------|------------------------|
| Inventário rotas/telas | **APROVADO** | FASE 1 + commits 2–3 | — | Manter auditoria atualizada |
| Home Web homolog | **APROVADO** | Screenshot browser 2026-11-17 (home carregou) | — | — |
| Explorar Web homolog | **APROVADO** | 3 profissionais; IA CTA visível | — | — |
| Todas as telas E2E autenticadas | **NÃO TESTADO** | Sem sessão login completa nesta auditoria | — | Roteiro E2E com contas teste |
| `flutter test` widgets Explorar | **REPROVADO** | `+190 ~1 -12` em `docs/evidence/fase12_flutter_test.txt` | 8 falhas `universal_search_screen_test`; 3 `firebase_placeholders_test`; 1 identity | Ajustar testes ao `firebase_options` real; estabilizar widget tests |

### 2.2 Fluxo cliente (cadastro → avaliação)

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Código do fluxo (orçamento, aceitar proposta, pagar via CF) | **APROVADO (código)** | Fases 3–4 + `OrderPolicy` / `acceptResolveProposal` | — | — |
| E2E real cadastro→avaliação | **NÃO TESTADO** | Não executado com usuários reais | — | Homolog autenticado + checklist FASE 4 |

### 2.3 Fluxo profissional (cadastro → recebimento)

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Provider Home sem pedidos fictícios | **APROVADO (código)** | `9880c6f` removeu `DemoData` | — | — |
| E2E cadastro→aprovação→proposta→recebimento | **NÃO TESTADO** | — | — | Conta prestador + admin aprovação |

### 2.4 Busca e carregamento de profissionais

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Homolog Explorar carrega lista | **APROVADO** | Browser `#/search` — “3 profissionais encontrados”; `docs/evidence/homolog_ia/explorar_profissionais_ok.png` | Nenhum erro de carga nesta execução | Continuar monitoramento índices/rules |
| Sem mascarar falha com seed em prod keys | **APROVADO (código)** | `HomologCatalog` só com placeholders; `firebase_options` com keys reais `AIza…` | Testes antigos de placeholder falharam | Atualizar `firebase_placeholders_test` |

### 2.5 Carajás IA

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| UI Central / modos / atalhos | **APROVADO** | `docs/evidence/fase12/homolog_ia_ui.png` — greeting + chips | — | — |
| Turno real (LLM + profissionais grounded) | **REPROVADO** | Cloud Functions API 403; list functions falha; docs FASE 7 | Function indisponível | Habilitar API + Blaze + deploy `aiAssistant` + secret (GO) |
| Tratamento de erro honesto | **APROVADO (código)** | `AiSvc` source `unavailable` | — | Validar após deploy |

### 2.6 Pagamentos, taxas, comissões, webhooks

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Unitários Functions (policy/webhook apply) | **APROVADO** | `npm test` **163/163** → `docs/evidence/fase12_functions_test.txt` | — | — |
| Webhook não confia em body | **APROVADO (código)** | `functions/index.js` exige `payments/{id}` + MP `approved` | — | Deploy Functions (GO) |
| Cobrança PIX/cartão sandbox E2E | **NÃO TESTADO** | Pagamentos desligados / sem GO | — | Token MP + `PAYMENTS_ENABLED` em sandbox |
| Produção MP | **REPROVADO** | Sem GO; live 404 | — | Não ligar até checklist |

### 2.7 Admin e permissões

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| AdminGate + aba Disputas (código) | **APROVADO (código)** | FASE 2 | — | Testar com usuário admin real |
| E2E permissões admin | **NÃO TESTADO** | — | — | Conta admin homolog |

### 2.8 Segurança, autenticação, LGPD

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Regras/policy em testes Functions | **APROVADO** | 163 testes | — | Emulador rules full N/E nesta sessão |
| Auth E2E (Google/Apple/email) | **NÃO TESTADO** | — | — | Contas + domínios OAuth |
| Export/delete LGPD (código) | **APROVADO (código)** | Perfil / callables documentados | — | Executar delete em homolog |

### 2.9 Web

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Homolog channel | **APROVADO** | HTTP **200** `…--homolog-88u39zqx.web.app` | — | Cache-bust em deploys |
| Live hosting | **REPROVADO** | HTTP **404** | Site Not Found | Deploy live **somente com GO** |

### 2.10 Android

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Projeto / `applicationId` | **APROVADO** | `br.com.carajas360` em `android/app/build.gradle` | — | — |
| Build AAB **HEAD atual** | **NÃO TESTADO** | Sem `app-release.aab` no workspace; build FASE 12 sem artefato | Build sem log útil / interrompido | `flutter build appbundle --release` com disco/JAVA estáveis; arquivar AAB+SHA256 |
| AAB histórico (outra branch) | **NÃO TESTADO** p/ este veredito | `docs/evidence/correcao_final_android_build.md` (commit antigo) | Não prova `9880c6f` | Regenerar AAB nesta branch |

### 2.11 iOS

| Item | Resultado | Evidência | Erros | Correções |
|------|-----------|-----------|-------|-----------|
| Bundle ID / projeto | **APROVADO (existência)** | `br.com.carajas360` em Info.plist | — | — |
| Compilação / TestFlight | **NÃO TESTADO** | Windows sem Xcode | — | macOS + Apple Developer + archive |

---

## 3. Arquivos e versões gerados nesta FASE 12

| Artefato | Caminho |
|----------|---------|
| Este relatório | `docs/AUDITORIA_FINAL_CARAJAS360.md` |
| Functions test log | `docs/evidence/fase12_functions_test.txt` |
| Flutter test log | `docs/evidence/fase12_flutter_test.txt` |
| Screenshot IA UI | `docs/evidence/fase12/homolog_ia_ui.png` |
| Índice evidências | `docs/evidence/fase12/INDEX.txt` |
| AAB desta sessão | **não gerado** |
| IPA / TestFlight | **não gerado** |

---

## 4. Critérios para voltar a avaliar como APTO

1. Cloud Functions API + Blaze ativos; `aiAssistant` deployada; turno IA real evidenciado.  
2. Hosting live 200 **após GO**.  
3. Sandbox MP: PIX/cartão/webhook com pagamento de teste aprovado (não só UI).  
4. E2E cliente e profissional documentados (cadastro→avaliação / cadastro→recebimento).  
5. AAB gerado do commit candidato + SHA256; smoke em dispositivo.  
6. iOS archive ou justificativa formal de adiamento de loja Apple.  
7. `flutter test` estável (ou exclusões justificadas) no CI.  
8. Autorização explícita de publicação (não automática).

---

## 5. Declaração final

**Estado:** **NÃO APTO para publicação** nas lojas e **não apto** para go-live do hosting principal.  
**Estado homolog:** **parcialmente apto** para demonstração Web (Home + Explorar + UI IA), com profissionais carregando e sem declarar IA/pagamentos comerciais prontos.

*Auditoria FASE 12 — evidências em `docs/evidence/fase12/` e `docs/evidence/homolog_ia/`. Nenhuma publicação automática foi executada.*
