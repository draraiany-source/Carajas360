# Modernização visual — Tela 03: Detalhes do Serviço (perfil do profissional)

Branch: `feat/modernizacao-visual` (sem push, sem deploy). Referência: `03_Detalhes_Servico.png` (apenas referência visual).

Decisão aprovada: as referências 03 e 08 mostram a mesma página. Foi criada uma única tela de detalhes do profissional; a Tela 08 será refinamento desta mesma tela, sem duplicar.

## Implementado

- Nova rota pública `Routes.providerProfile` (`/provider-profile`) → `ProviderProfileScreen`.
- Abre ao tocar no card do profissional (Home, Explorar em grade e em lista). O botão "Solicitar serviço" do card continua igual.
- Dados lidos de `providers/{id}` (`FS.providerStream`) e `reviews` filtradas por `providerId` (`FS.providerReviewsStream`, ordenação no cliente, sem índice novo). Só leitura; nenhuma mudança de estrutura ou de regras.
- Conteúdo: voltar + trilha, foto, nome, verificado, categorias, nota/nº de avaliações (ou "Novo"), cidade, destaques reais (verificado, atendimento presencial/online, certificados enviados), ações Solicitar serviço / Conversar no chat / Favoritar.
- Abas: Sobre (bio, desde quando está no Carajás 360), Serviços (categorias, preço inicial ou "Valor sob consulta"), Avaliações (comentários publicados), Área de atendimento (cidade e áreas informadas).
- Orçamento rápido: abre o fluxo existente de Solicitar Serviço com a descrição preenchida (`RequestServiceScreen.initialDescription`). Campo vazio mostra aviso e foca o campo.
- Favoritar reaproveita `toggleProviderFavorite`, extraído do card.
- Acessibilidade: seções com fronteiras semânticas próprias (sem elas o Flutter web juntava todo o texto da página no rótulo do campo de texto).

## Itens da referência não implementados (sem dado real)

- Galeria/portfólio de fotos e vídeo, "Profissional Destaque", distância, telefone/WhatsApp e horário: não existem no modelo.
- "Garantia do Serviço" e "Nota Fiscal": não exibidos — não há comprovação.
- "+380 serviços realizados": não existe contador real de serviços concluídos por profissional.

## Arquivos alterados

- `lib/features/provider/provider_profile_screen.dart` (novo)
- `lib/core/constants/app_constants.dart` (rota)
- `lib/main.dart` (rota e argumento `description` em `requestService`)
- `lib/shared/services/firestore_facade.dart` (`providerStream`, `providerReviewsStream`)
- `lib/features/orders/orders_screen.dart` (`initialDescription`)
- `lib/shared/widgets/brand_provider_card.dart` (`openProviderProfile`, `toggleProviderFavorite`, descrição opcional)
- `lib/features/search/universal_search_screen.dart` (linha da lista abre o perfil)
- `scripts/web_nav_smoke.mjs` (lê texto de nós folha e `textarea`), `scripts/smoke/tela03_perfil.json`

## Testes

| Verificação | Resultado |
|---|---|
| `flutter analyze` | PASS — 0 erros, 150 issues (linha de base) |
| `flutter test` | PASS — 135 aprovados, 1 ignorado |
| `flutter build web --release` | PASS |
| Smoke Tela 03 desktop / celular | PASS — 9/9 e 2/2 (`docs/evidence/tela03/report.json`) |
| Regressão Tela 02 desktop / celular | PASS — 14/14 e 6/6 |
| Regressão Tela 01 desktop / celular | PASS — 38/38 e 13/13 |

## Pendências

- Pré-preenchimento da descrição com usuário logado: NOT TESTED no navegador (visitante cai no login antes do formulário).
- Comentários de avaliações: o catálogo de homologação não tem avaliações; com Firestore real: NOT TESTED.
- A tela abre por cima do menu lateral (como as demais telas internas); manter o menu visível exige navegação aninhada — avaliar na Fase 5.
- Snackbars e foco de alguns campos ainda no azul do tema antigo (Fase 2).
