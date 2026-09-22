# Relatorio de Polimento UI/UX — Carajas 360

**Data:** 2026-09-21  
**Escopo:** homologacao (Firebase placeholders). Pagamentos e seguranca nao alterados.

## 1. Telas corrigidas

| Area | Mudanca |
|------|---------|
| Home (Carajas) | Cards densos, icones Material, grid responsivo, homolog providers |
| Servicos (hub) | CarajasAppBar + icones Material nos modulos + HomologCatalog |
| Busca | CarajasAppBar + HomologCatalog quando Firebase placeholder |
| Pedidos / Favoritos / Solicitar | CarajasAppBar |
| Mensagens / Conversa | CarajasAppBar (safeBack) |
| Perfil / Notificacoes / Avaliar / Tema | CarajasAppBar |
| Saude / Mercado / Aluguel / Entregas / IA / Resolve | CarajasAppBar ou leading safeBack |
| Empresa (equipe/filiais/contratos) | CarajasAppBar |
| Ajuda / Cupons / Legal / Indicacao | CarajasAppBar |

## 2. Rotas e botao voltar

- Widget padrao: `CarajasAppBar` (`lib/shared/widgets/carajas_app_bar.dart`)
- Navegacao: `AppNav.safeBack` — `Navigator.pop` se `canPop`, senao `Routes.main`
- SliverAppBar (detalhe aluguel / loja): leading explicito com `AppNav.safeBack`
- Tabs MainNav: voltar so aparece quando a tela foi empurrada (`canPop`)
- Android/iOS/Web: pop do Navigator + historico web do Flutter

## 3. Navegacao desktop

- Largura >= 900: NavigationRail lateral
- Largura >= 1100: rail extended com marca
- Mobile: bottom bar prioritaria

## 4. Icones

- Linguagem unica: Material Icons rounded (`CategoryIcons`)
- Removidos emojis dos cards de modulo Home/Servicos e chips de categoria
- ProvCard: botoes sem emoji; chat com Icons.chat_bubble_outline

## 5. Cards e responsividade

- Home modulos: altura ~92px; colunas 2/3/4/6 conforme largura
- Servicos hub: grid 4/5/7 colunas
- ProvCard padding 12
- Breakpoints: mobile 375-430, tablet, 1024, 1366, 1440, 1920

## 6. Busca / dados homolog

- Causa do vazio: DemoData bloqueado em release + Firestore sem providers
- Solucao: HomologCatalog ativo somente com FirebaseBootstrap.hasPlaceholderKeys
- Seed: eletricista, encanador, pintor, medico, diarista, TI, pedreiro, cabeleireiro

## 7. Estados

- Loading (skeleton), vazio (EmptyState), sucesso (lista), fallback homolog

## 8. Problemas encontrados

1. AppBar inconsistente / telas sem saida
2. Emojis misturados com Material/SVG
3. Cards altos com muito espaco vazio
4. Web = celular esticado (sem sidebar)
5. Busca vazia em release homolog
6. Arquivos UTF-16 gerados por Write tool (corrigidos)

## 9. Pendencias

- Migrar emojis residuais em marketplace produtos / admin / resolve textos
- Tags Online/Presencial no ProvCard ainda textuais
- Validacao nativa Android/iOS em device
- Nao ativar producao; nao alterar pagamentos

## 10. Arquivos principais

- lib/shared/widgets/carajas_app_bar.dart
- lib/core/utils/app_nav.dart
- lib/core/catalog/homolog_catalog.dart
- lib/core/constants/category_icons.dart
- lib/core/modules/platform_modules.dart
- lib/main.dart (MainNav desktop)
- lib/features/home/carajas_home_screen.dart
- lib/features/home/home_screen.dart
- Telas em lib/features/** com CarajasAppBar

## 11. Deploy homolog

- URL: https://carajas360-a17c5--homolog-qukn7syp.web.app
- Canal: homolog (expira ~30 dias)
- Prints DEPOIS: docs/prints_polimento/

## 12. Criterio de aprovacao (status)

| Criterio | Status |
|----------|--------|
| Voltar em telas internas | OK (CarajasAppBar + safeBack) |
| Nenhuma rota prende usuario | OK (fallback Home) |
| Web desktop (sidebar) | OK (>=900px NavigationRail) |
| Cards proporcionais | Parcial (densificados; lista busca max 880px) |
| Icones padronizados | OK Material rounded (modulos/chips) |
| Sem areas vazias criticas | Melhorado; Em breve so em modulos futuros |
| Sem placeholders visiveis | HomologCatalog preenche busca |
| Aparencia de produto | Melhorada vs wireframe |

