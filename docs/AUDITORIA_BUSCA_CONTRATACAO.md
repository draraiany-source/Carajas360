# Auditoria — busca, cartões e contratação (Carajás 360)

Data: 14/11/2026 · Branch: `feat/modernizacao-visual`

## Problemas confirmados e causa

| # | Problema | Causa |
|---|----------|-------|
| 1 | Duas buscas (verde/dourada e azul com botões largos) | `Routes.search` abria a `SearchScreen` antiga de `home_screen.dart`; `Routes.universalSearch` abria a nova. Categorias da home, chips e hub iam para a antiga. |
| 2 | Azul na tela antiga e em telas legadas | `AppColors.primary` ainda era azul (`0xFF0B3D91`) e fundos `0xFFE3F0FF`. |
| 3 | Categoria escolhida sem destaque / "Todas" não restaurava | Tela antiga mantinha estado próprio e consultava Firestore com `categories arrayContains` + `orderBy rating` (índice inexistente). |
| 4 | Números "32" e "5" | 32 = tamanho do catálogo de demonstração (ativo porque o build usa chaves provisórias); 5 = profissionais do grupo "Casa" nesse catálogo. Não eram contagens reais. |
| 5 | "Online" no cartão | Derivado de `modalities.contains('online')` (modalidade), não de presença. |
| 6 | Selo de verificado em perfis fictícios | Seed de homologação com `verified: true`. |
| 7 | Login perdia o contexto | Tela de login substituía a pilha; após entrar o usuário não voltava para a tela de origem. |
| 8 | Solicitação de orçamento | Sem proteção contra toque duplo, sem tratamento de erro (sucesso exibido mesmo se a gravação falhasse), `senderName: 'Você'`, endereço obrigatório mesmo para atendimento a distância, sem bloqueio de pedido para o próprio perfil ou para perfil de demonstração. |
| 9 | Perfil do usuário com dados falsos | Subtítulos fixos "3 não lidas", "PROMO30 disponível", "1 consulta agendada", "8 medalhas". |
| 10 | Hit de empresa na busca | Abria o painel da empresa do próprio usuário (`companyProfile`) com dados fictícios. |
| 11 | "Tentar novamente" sem efeito | Stream de profissionais em cache não era recriado. |

## Correções

- Busca única: `Routes.search` e `Routes.universalSearch` abrem `UniversalSearchScreen` com `q`, `category` e `group`. `SearchScreen` antiga removida.
- Lógica pura em `lib/core/search/provider_search.dart` (texto sem acento/maiúsculas, escopo por ids estáveis, especialidades múltiplas, cidade + áreas de atendimento, nota mínima só com avaliações reais, modalidade, preço máximo, ordenações, paginação).
- Cartão e grade compartilhados (`BrandProviderCard`/`BrandProviderGrid`) na busca, home, hub de serviços e favoritos; botões com 44 px e tooltip; favoritar/conversar não abrem o perfil; "Preço sob consulta" quando não há preço; selo só para verificação real; tag "Demonstração" no catálogo fictício.
- `ensureSignedIn` + `popOnSuccess` no login: visitante entra e volta para a mesma tela.
- `ServiceRequest` + `SubmitGuard` (`lib/core/orders/service_request.dart`): bloqueios antes de gravar, validação por tipo de atendimento, envio único, sucesso só após `createOrder`; conversa é best-effort e, se falhar, o usuário vai para Pedidos.
- Paleta legada passou para verde; "Online" do `ProvCard` virou "Atende online".
- Perfil: subtítulos falsos removidos; adicionados "Planos e assinaturas", "Divulgue seu serviço" e "Ajuda e suporte" (também para visitante).

## Pendências externas

- Fluxo real de pedido/chat contra Firestore: NOT TESTED (build usa chaves provisórias; emulador local indisponível para este projeto).
- Domínio do canal de preview não autorizado no Firebase Auth: EXTERNAL CONFIG REQUIRED.
- Filtro por categoria no servidor exige índice composto; hoje a busca filtra os profissionais carregados (lotes de 100 com "Carregar mais").
- Módulo Saúde usa preço padrão (150/200) quando o profissional não informa preço — fora do escopo desta auditoria, registrado para revisão.
