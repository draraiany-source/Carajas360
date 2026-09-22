# Relatorio - Marketplace de Servicos Carajas 360

**Data:** 2026-09-21
**Escopo:** expansao completa do modulo Servicos sobre arquitetura existente.
**Producao:** NAO publicado.

## Arquitetura criada

Categoria (vertical) -> Grupo/Subcategoria -> Servico -> Questionario dinamico -> Matching tecnico -> Propostas (Resolve) / Contratacao direta (Order)

Fonte unica: `ServiceTaxonomy` (seed embarcado + overlay remoto via `applyRemoteOverlay`).
Telas nao devem hardcodar listas de servicos.

Compatibilidade preservada:
- `Categories` / `ServiceCategory` (legado + Automoveis)
- `ResolveRequest` / `ResolveProposal` (campos extras opcionais)
- `OrderModel` + ProviderHome + Chat
- Verticais independentes: Saude -> Routes.health, Maquinas -> Routes.rental

## Banco / migrations

Sem migration destrutiva. Campos novos em `resolveRequests` (opcionais):
serviceId, groupId, pricingMode, urgency, modality, answers, suggestedPrice

Admin: `FS.saveCategory` sincroniza grupos da taxonomia para colecao `categories`.

## APIs

- `ServiceTaxonomy.*` — consulta taxonomia
- `ServiceMatching.rank` — matching/ranking puro
- `FS.createResolveRequest` — extras + short-circuit homolog (`hrq_*`)
- `FS.resolveRequestStream` / `resolveProposalsStream` — seed homolog
- Rotas: `Routes.serviceMarketplace`

## Telas

- Marketplace completo (verticais grid responsivo)
- Grupos -> lista de servicos
- Fluxo questionario + preco fixo/orcamento + matching
- Hub Servicos: chip de categoria abre questionario; botao marketplace
- Propostas comparativas (ordenar preco/avaliacao/prazo, aceitar/recusar/perfil/chat)
- Admin Categorias: arvore Vertical/Grupo/Servico + sync backend
- Meus Pedidos / Resolve / ProviderHome / Chat (existentes, integrados)

## Arquivos modificados / criados

### Criados
- lib/core/catalog/service_taxonomy.dart
- lib/core/services/service_matching.dart
- lib/features/services/service_marketplace_screen.dart
- test/service_marketplace_taxonomy_test.dart
- docs/RELATORIO_MARKETPLACE_SERVICOS_CARAJAS360.md

### Modificados
- lib/core/constants/app_constants.dart (Automoveis + rotas)
- lib/core/catalog/homolog_catalog.dart (seed auto ha1-ha5)
- lib/shared/models/models.dart (ResolveRequest extras)
- lib/shared/services/firestore_facade.dart (resolve homolog + extras)
- lib/features/home/home_screen.dart (fluxo + marketplace)
- lib/features/resolve/resolve_screen.dart (comparativo)
- lib/features/admin/admin_screen.dart (taxonomia)
- lib/main.dart (rota serviceMarketplace)

## Seed Automoveis (homolog)

Grupos: Auto Eletrica, Funilaria/Pintura, Mecanica, Emergencia, Outros.
Profissionais homolog: Auto Eletrica Carajas, Funilaria Norte, Mecanica Diesel, Guincho 24h, Insulfilm PA.

## Testes executados

flutter test test/service_marketplace_taxonomy_test.dart -> 9/9 passed
- taxonomia Automoveis
- questionario
- matching cross-domain bloqueado (eletricista != juridico)
- inativos filtrados
- ranking por avaliacao
- pricing mode

## Bugs corrigidos

- Categoria ia direto para lista generica (agora questionario)
- Matching cruzado entre dominios
- Admin categorias era stub visual
- Propostas sem ordenacao comparativa
- Seed Automoveis ausente em homolog
- Encoding UTF-16 em arquivos novos (convertidos UTF-8)

## Riscos

- Overlay Firestore remoto ainda nao carrega automaticamente no boot (API pronta: applyRemoteOverlay)
- Fotos/anexos do questionario ainda nao sobem ao Storage neste passo
- E2E nativo Android/iOS pendente de validacao manual
- Aceite homolog de proposta e local (nao grava Firestore)

## Pendencias

- Upload fotos/videos no questionario
- Painel profissional: UI dedicada de "servicos oferecidos" ligada a taxonomia
- Moderacao/denuncia/disputa: hooks existentes, UX admin a aprofundar
- Geolocalizacao lat/lng real (hoje cidade + serviceAreas)
- Deploy canal homolog (nao producao)
- Suite E2E ampliada (widget/integration)

## Pronto para homologacao?

SIM para testar fluxo vertical->servico->questionario->matching->propostas em ambiente com placeholders Firebase.
NAO publicar producao.
