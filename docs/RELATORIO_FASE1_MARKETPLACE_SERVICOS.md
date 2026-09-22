# Relatorio FASE 1 — Marketplace Servicos Carajas 360

**Data:** 2026-09-22
**Ambiente:** Homologacao apenas
**Producao:** NAO publicada
**Escopo desta execucao:** Auditoria + FASE 1 somente

---

## 1. Auditoria (estado antes da FASE 1)

### A) Ja existia e funcionava
- ServiceTaxonomy (vertical/grupo/servico/questionario) + marketplace UI
- ServiceMatching com match exato de categoria
- HomologCatalog anti-bleed (Casa nao invade Veiculos/Juridico) + testes
- Resolve/propostas e Orders/chat
- Saude e Locacao como verticais independentes

### B) Parcial
- Admin categorias (arvore visual, sync incompleto)
- Overlay remoto (`applyRemoteOverlay`) sem boot
- Resolve classico sem questionario dinamico

### C) Duplicado
- Categories const vs ServiceTaxonomy seed
- ResolveScreen vs ServiceRequestFlowScreen
- Seeds demo no hub + HomologCatalog

### D) Mock / homolog only
- Providers/rentals/health seeds com placeholders
- Pedidos `hrq_*` sem Firestore

### E) Faltava (FASE 1)
- Busca universal multi-entidade
- Taxonomia editavel sem release (wire remoto + admin ativar/desativar)
- Historico/sugestoes de busca

### Identidade legada
- Busca por "Servico Conecta / SaudeConecta / MercadoConecta / EntregaConecta": **0 ocorrencias** em `lib/`
- Residual: e-mails `servicoconecta.com.br` em AppInfo (nao alterado nesta fase)

---

## 2. FASE 1 — o que foi implementado

### Taxonomia administravel
- Colecao `Col.serviceTaxonomy`
- `FS.serviceTaxonomyStream` / `saveTaxonomyVertical` / `publishFullTaxonomy`
- `TaxonomyRepository` (parse, overlay, patch active)
- Boot: MainNav escuta stream e aplica overlay (exceto homolog placeholders → seed)
- Admin: switches ativar/desativar vertical/grupo/servico + botao Publicar

### Correcao de filtros
- Mantida/regression-tested: match exato + testes anti-bleed
- Verticais novas: Design, Mudancas, Entregas, Servicos empresariais

### Busca universal
- Motor `UniversalSearch` (servicos, categorias, subcategorias, profissionais, empresas)
- Sugestoes ao digitar + fuzzy/ortografia leve (Levenshtein)
- Historico recente (SharedPreferences)
- UI `UniversalSearchScreen` ("O que voce precisa?")
- Hub/Home e tab Explorar apontam para busca universal
- SearchScreen de profissionais preservada via rota/atalho

---

## 3. Arquivos alterados / criados

### Criados
- lib/core/search/universal_search.dart
- lib/core/catalog/taxonomy_repository.dart
- lib/features/search/universal_search_screen.dart
- test/universal_search_phase1_test.dart
- docs/RELATORIO_FASE1_MARKETPLACE_SERVICOS.md

### Modificados
- lib/core/constants/app_constants.dart (Col.serviceTaxonomy, Routes.universalSearch)
- lib/core/catalog/service_taxonomy.dart (verticais extras)
- lib/shared/services/firestore_facade.dart (APIs taxonomia)
- lib/features/admin/admin_screen.dart (CRUD ativacao + publicar)
- lib/features/home/home_screen.dart / carajas_home_screen.dart (busca)
- lib/main.dart (rota, tab Explorar, boot taxonomia)

---

## 4. Migrations / endpoints

- **Migration:** nenhuma destrutiva. Nova colecao Firestore `serviceTaxonomy` (docs = verticais).
- **Endpoints/API client:**
  - `FS.serviceTaxonomyStream`
  - `FS.saveTaxonomyVertical`
  - `FS.deleteTaxonomyVertical`
  - `FS.publishFullTaxonomy`
- Em HomologCatalog.enabled, writes de taxonomia sao no-op (protege producao/mistura).

---

## 5. Testes

```
flutter test test/universal_search_phase1_test.dart \
  test/homolog_catalog_filter_test.dart \
  test/service_marketplace_taxonomy_test.dart
```

**Resultado: 24/24 passed**

---

## 6. Bugs encontrados / corrigidos nesta fase

- Busca do hub ia so para lista de profissionais → agora busca universal
- Overlay remoto nao carregava no boot → wired no MainNav
- Admin sem ativar/desativar servicos → switches + publish
- Encoding UTF-16 em arquivos novos (padrao Windows) → convertidos UTF-8

---

## 7. Pendencias (FORA da FASE 1 — proximas fases)

- FASE 2+: questionarios condicionais por servico, anexos, matching Firestore real
- Unificar Categories const gerado a partir da taxonomia
- Editor visual completo de perguntas no admin
- E2E nativo Android/iOS
- Deploy canal homolog (quando autorizado)

---

## 8. Checkpoint

Commit de checkpoint da FASE 1 solicitado apos revisao deste relatorio.
**NAO avancar automaticamente para FASE 2 nem producao.**

## Pronto para revisao?

SIM — FASE 1 concluida para revisao humana antes de prosseguir.
