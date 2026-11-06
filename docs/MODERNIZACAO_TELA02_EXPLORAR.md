# Modernização visual — Tela 02: Explorar Serviços

Branch: `feat/modernizacao-visual` (sem push, sem deploy). Referência: `02_Explorar_Servicos.png` (apenas referência visual).

## Implementado

- `UniversalSearchScreen` (aba "Explorar" e rota `universalSearch`) redesenhada na paleta Brand: banner, busca, seletor de categorias, filtros, ordenação, grade/lista, contador real e paginação.
- Profissionais carregados de `FS.providersStream(limit: 100)` (produção: `active=true`, `verified=true`). Antes a busca recebia lista vazia de profissionais em produção.
- Filtros sobre dados reais: categoria, avaliação mínima (exige avaliações), preço inicial (`minPrice`), atendimento (`presential`/`online`); ordenação por relevância, avaliação, nº de avaliações e menor preço; 12 por página, voltando ao topo dos resultados ao trocar de página.
- Preservado: histórico de buscas, sugestões, cards de serviços/categorias da taxonomia e `initialQuery`.
- Componentes extraídos da Home para reuso, sem duplicação: `BrandProviderCard`, `BrandFavoriteButton`, `brandCategories`, `BrandDragScrollBehavior`.
- Corrigido `UniversalSearch.fuzzyMatch`: palavras curtas ("e", "de", "ele") casavam como prefixo de qualquer busca ("eletric" retornava 30 de 32 profissionais e sugeria "Banho e tosa"). Teste de regressão adicionado.
- Removida a ação "Busca só profissionais" da AppBar: os profissionais agora aparecem na própria tela.

## Arquivos alterados

- `lib/features/search/universal_search_screen.dart`
- `lib/features/home/carajas_home_screen.dart` (passa a usar os componentes compartilhados)
- `lib/core/theme/brand.dart`
- `lib/shared/widgets/brand_provider_card.dart` (novo)
- `lib/shared/widgets/brand_categories.dart` (novo)
- `lib/core/search/universal_search.dart`, `test/universal_search_phase1_test.dart`
- `scripts/web_nav_smoke.mjs` (passos `setup`, `then`, `type`, `expectNone`; campos de texto)
- `scripts/smoke/tela02_explorar.json`, `scripts/smoke/tela02_paginacao.json` (novos)

## Testes

| Verificação | Resultado |
|---|---|
| `flutter analyze` | PASS — 0 erros, 150 issues (linha de base) |
| `flutter test` | PASS — 135 aprovados (1 novo), 1 ignorado |
| `flutter build web --release` | PASS |
| Smoke Tela 02 desktop / celular | PASS — 14/14 e 6/6 (`docs/evidence/tela02/report.json`) |
| Paginação | PASS — `report_paginacao.json` |
| Regressão Tela 01 desktop / celular | PASS — 38/38 e 13/13 |
| Dados reais do Firestore | NOT TESTED — homologação usa catálogo demo |

## Pendências

- Filtro "Distância": NOT APPLICABLE — sem geolocalização no app.
- "Ver perfil": ausente, sem perfil público do profissional (Tela 08).
- "Tipo de serviço": coberto pelo seletor de categorias.
- Contador "254" e preços da referência não usados; o contador é real.
- Setas de voltar do login/cadastro sem rótulo acessível (herdado da Tela 01).
- `SearchScreen` (`home_screen.dart`) ainda existe; consolidar na Tela 07.
