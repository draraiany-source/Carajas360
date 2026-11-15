# Mapa das 10 telas premium → rotas

Referências em `docs/ref_telas_premium/Carajas360_10_Telas/`.

| # | Arquivo | Rota / entrada | Implementação |
|---|---------|----------------|---------------|
| 01 | `01_Inicio_Servicos.png` | `Routes.main` aba 0 · `HomeScreen` | Hero, categorias, destaques; nav superior desktop |
| 02 | `02_Explorar_Servicos.png` | `Routes.search` / aba Explorar · `UniversalSearchScreen` | Filtros em sidebar (≥1000), grade/lista, contagem real |
| 03 | `03_Perfil_Profissional.png` | `Routes.providerProfile` | Breadcrumb, modalidades, demo bloqueado, avaliações reais |
| 04 | `04_Solicitar_Servico.png` | `Routes.requestService` passo 1 · `QuoteRequestFlowScreen` | Campos de limpeza só quando categoria de limpeza |
| 05 | `05_Revisao_Solicitacao.png` | mesmo fluxo passo 2 | Revisão + confirmação; envio só no passo 3 |
| 06 | `06_Meus_Pedidos.png` | aba Pedidos / `Routes.myOrders` | Indicadores e lista a partir de pedidos reais |
| 07 | `07_Mensagens_Orcamento.png` | aba Mensagens + `Routes.chat` | Hero inbox; painel de proposta/pedido em telas largas |
| 08 | `08_Saude_Agendamentos.png` | `Routes.health` | Solicitar agendamento (preferência, sem slots inventados) |
| 09 | `09_Favoritos.png` | `Routes.favorites` (nav superior) | Busca/filtros sobre favoritos reais |
| 10 | `10_Perfil_Configuracoes.png` | aba Perfil · `ProfileScreen` | Seções Dados / Endereços / Notificações / Segurança / Privacidade / Ajuda |

Chrome compartilhado: `lib/shared/widgets/brand_shell.dart` (`BrandTopNav`, `BrandPageHero`, `BrandDemoNotice`, …).
