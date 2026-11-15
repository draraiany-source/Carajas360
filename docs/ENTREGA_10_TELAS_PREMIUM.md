# Entrega — 10 telas premium (referências)

Data: 15/11/2026 · Branch: `feat/modernizacao-visual`  
Referências: `docs/ref_telas_premium/Carajas360_10_Telas/`

## Associação referência → rota

| # | Arquivo | Rota / entrada | Status |
|---|---------|----------------|--------|
| 01 | `01_Inicio_Servicos.png` | `MainNav` aba 0 · `HomeScreen` | Chrome BrandTopNav (desktop); hero, módulos, destaques reais |
| 02 | `02_Explorar_Servicos.png` | `Routes.search` / aba Explorar | Hero + filtros em painel (≥1000) / bottom sheet (mobile); contagem real |
| 03 | `03_Perfil_Profissional.png` | `Routes.providerProfile` | Breadcrumb, hero, modalidades, demo bloqueado, avaliações reais |
| 04 | `04_Solicitar_Servico.png` | `Routes.requestService` passo 1 | `QuoteRequestFlowScreen` — campos de imóvel só em limpeza |
| 05 | `05_Revisao_Solicitacao.png` | mesmo fluxo passo 2 | Revisão + confirmação; grava só no envio |
| 06 | `06_Meus_Pedidos.png` | aba Pedidos | Stats/lista/detalhe a partir do stream real (sem pedidos fictícios) |
| 07 | `07_Mensagens_Orcamento.png` | aba Mensagens + `Routes.chat` | Hero na inbox; painel de pedido em telas largas |
| 08 | `08_Saude_Agendamentos.png` | `Routes.health` | Solicitar agendamento (preferência; sem slots inventados como livres) |
| 09 | `09_Favoritos.png` | `Routes.favorites` | Busca/filtros sobre favoritos reais |
| 10 | `10_Perfil_Configuracoes.png` | aba Perfil | Seções Dados / Endereços / Notificações / Segurança / Privacidade / Ajuda |

Chrome compartilhado: `lib/shared/widgets/brand_shell.dart`.

## Integrações ausentes / bloqueios

- Login no canal de preview: domínio precisa estar em Authorized domains (Auth).
- Build com chaves provisórias: catálogo de demonstração ativo; pedidos a perfis demo bloqueados no cliente e nas regras de produto.
- Agenda de saúde: sem integração de disponibilidade real — apenas solicitação de preferência.
- Aceite de proposta no chat: painel mostra pedido real; ações de aceite/ajuste só quando a API/transições existentes permitirem (sem simular mensagens).
- 2FA: não implementado — UI informa indisponível.

## Como testar

1. `flutter run -d chrome` (ou servir `build/web`).
2. Desktop ≥900px: barra superior Início / Explorar / Pedidos / Favoritos.
3. Explorar → filtrar categoria → abrir perfil → Voltar (filtros preservados).
4. Pedir orçamento em profissional real (não demo): Detalhes → Revisão → Enviar.
5. Favoritos, Pedidos e Saúde com conta autenticada.
