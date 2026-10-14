# Carajás 360 — Fase 6: chat, painéis, navegação e acabamento

> **Status:** concluída em **homologação local (emuladores)**.
> Nada foi publicado e produção não foi tocada. Sem pagamentos reais.

Escopo: seção 10 do pedido original (chat, navegação, estados de tela, textos públicos, responsividade, painéis).

## 1. Situação encontrada (conferida na versão recebida antes de editar)

| Ponto | Encontrado |
|---|---|
| Caixa de entrada | Lia `users/{outra pessoa}` (perfil **privado**). As regras negam essa leitura, então a lista caía no texto genérico **"Contato"** sem foto. Liberar a leitura exporia telefone, CPF e e-mail |
| Voltar | Telas abertas por link ou rota única ficavam sem destino ao voltar (pop em pilha vazia) |
| Login | Depois do login o app ia sempre para o início: a ação que pediu o login (contratar, conversar, abrir um pedido) se perdia |
| Sessão expirada | Sem tratamento: callables respondiam `unauthenticated` e a tela mostrava erro genérico |
| Notificações | Tocar não abria nada; não havia "marcar todas como lidas"; o servidor não gravava o destino |
| Perfil do prestador | Não havia tela pública: o card ia direto para o pedido |
| Contratar novamente | Não existia |
| Favoritos | Sem estado de erro (consulta com falha = lista vazia) |
| Painel admin | Os KPIs e o relatório financeiro **devolviam zeros quando a consulta falhava**. A comissão era sempre 15%, sem usar a taxa gravada no pedido. As recargas eram somadas pelo campo errado |
| Painel do prestador | Ganhos com 15% fixo, contados pela **data de criação** e não pela de conclusão. Sem estado de carregando/erro (carregando aparecia como "Sem pedidos") |
| Offline | Nenhum aviso |
| Marca | "Serviço Conecta" em textos visíveis: canal de notificação, relatórios, boas-vindas, Mercado, Saúde, termos, indicação, assistente, `Info.plist`, `web/index.html`, `manifest.json` |
| Layout | Margens fixas de 16 px em todas as larguras e barra inferior também no desktop. No desktop o conteúdo esticava até 1440 px |

## 2. O que foi implementado

### Chat — perfil público mínimo
- Nova coleção **`publicProfiles/{uid}`** com apenas `name`, `photoUrl`, `kind`, `verified` e `updatedAt`, mantida **só pelo servidor** (`functions/profiles.js`):
  - **cliente:** primeiro nome + inicial do sobrenome ("Maria Silva Souza" → "Maria S.");
  - **prestador aprovado e ativo:** o nome do perfil profissional, que já é público;
  - os triggers `onUserPublicProfile` e `onProviderPublicProfile` atualizam a coleção quando `users/` ou `providers/` muda; deixar de ser verificado volta ao nome mínimo.
- Callable **`migratePublicProfiles`** (somente admin, com `dryRun`) para preencher os perfis já existentes.
- A caixa de entrada lê `publicProfiles` (com cache). Na falta do perfil mostra "Usuário", nunca dados privados. Também ganhou estado de erro.

### Navegação, sessão e retomada (`lib/core/navigation/app_navigation.dart`)
- **`safeBack`:** volta se houver para onde; senão vai ao início. Aplicado nos cabeçalhos de Saúde, Mercado, Locação e Perfil do prestador, com rótulo de acessibilidade.
- **`AuthResume`:** guarda a rota e os argumentos que pediram login e os retoma depois de entrar. Usado em `RequireAuth`, `AdminGate`, notificações, caixa de entrada e perfil do prestador. O checkout pendente da Fase 3 continua com prioridade.
- **`SessionGuard`:** se a sessão cai sem o usuário ter saído (token revogado, conta desativada ou callable `unauthenticated`), guarda a tela atual, avisa "Sua sessão expirou…" e abre o login. O "Sair" voluntário não dispara o aviso.
  - Corrigido durante os testes: a primeira versão aguardava a navegação até o login ser fechado e ficava travada (`_handling` preso).
- **`OfflineBanner`:** aviso discreto quando o Firestore passa a responder só do cache (debounce de 4 s), sem bloquear o uso.

### Notificações
- O servidor grava `link: {route, id}` com uma lista fechada de destinos: `resolveDetail`, `resolveOpportunities`, `appointments`, `bookings`, `marketOrder`, `myOrders`, `storeOrders`.
- Resolve, Saúde, Locação e pedidos passam o link.
- Ao tocar, a notificação é marcada como lida e abre o destino. As notificações antigas, sem link, usam o tipo.
- "Marcar todas como lidas", carregando e estado sem login com "Entrar".

### Perfil do prestador e contratar novamente
- **`ProviderProfileScreen`:** mostra só dados públicos de `providers/` e as avaliações. Tem favorito, "Agendar consulta" (Saúde), "Solicitar serviço" (mantém a especialidade escolhida na busca) e "Conversar".
- Os cards de prestador (início, busca e favoritos) abrem o perfil.
- "Contratar novamente" em pedidos concluídos ou cancelados abre o perfil com a mesma especialidade.
- Favoritos com estado de erro.

### Painéis
- **Admin:**
  - os KPIs e o relatório financeiro mostram **erro** em vez de zeros;
  - a comissão vem de cada pedido: `commission` gravada → `financeTerms.commissionBps` → 15% só para pedidos legados;
  - as recargas são somadas pelas confirmadas (`amountCents`);
  - rótulos esclarecidos.
- **Prestador:**
  - os ganhos usam a comissão de cada pedido e a **data de conclusão** (`completedAt`; pedidos antigos sem o campo usam a criação);
  - o rótulo diz "estimativa";
  - carregando e erro no resumo do dia, na semana e nas listas.
  - Os dados de demonstração continuam restritos a dev (regra da Fase 1).

### Textos públicos
- "Serviço Conecta" foi trocado por **Carajás 360** em todos os textos visíveis listados acima. `manifest.json` ganhou a descrição "Serviços, compras, saúde e locação na região de Carajás.".
- **Mantidos de propósito** (identificadores internos e IDs de aplicação):
  - pacote Dart `servico_conecta`, classe `ServicoConectaApp`;
  - `applicationId br.com.servicoconecta` e bundle id iOS;
  - id do canal de notificação `sc_main`.

### Responsividade e acessibilidade
- **`AdaptiveNavScaffold`:** barra inferior abaixo de 900 px; `NavigationRail` a partir de 900 px, expandida a partir de 1200 px.
- **`pagePadding` e `MaxWidth`:** 16 px no celular e conteúdo centralizado em até 920 px nas telas largas. Aplicado em 12 telas.
- Grade do Mercado com largura máxima por card e altura que acompanha o tamanho de texto (até 1,6×).
- Rótulos de acessibilidade nos botões de ícone dos cabeçalhos e na nota do prestador.

## 3. Arquivos

**Novos**
- `functions/profiles.js`, `functions/profiles.test.js`
- `lib/core/navigation/app_navigation.dart`
- `lib/shared/widgets/adaptive_nav.dart`
- `lib/features/provider/provider_profile_screen.dart`
- `test/phase6_navigation_test.dart`
- `firebase-tests/functions/profiles.test.js`, `firebase-tests/rules/profiles.rules.test.js`
- `firebase-tests/e2e/phase6.e2e.js`, `test_driver/e2e_phase6_main.dart`
- `docs/fase6/RELATORIO_FASE6.md`, `docs/fase6/evidencias/*.png`

**Alterados**
- **Backend:** `functions/index.js` (notify com link, módulos), `functions/resolve.js`, `functions/schedule.js` (links), `functions/package.json` (testes)
- **Regras:** `firestore.rules` (`publicProfiles`)
- **App:**
  - `lib/main.dart`, `lib/core/auth/access_control.dart`, `lib/core/constants/app_constants.dart`
  - `lib/shared/services/firebase_service.dart`, `lib/shared/models/models.dart`, `lib/shared/widgets/widgets.dart`, `lib/shared/widgets/micro_interactions.dart`, `lib/shared/services/local_notifications_io.dart`
  - telas: `auth`, `admin`, `ai_assistant`, `chat_inbox`, `checkout` (3), `health` (3), `home` (2), `marketplace`, `orders`, `profile_screens`, `provider` (2), `rental`, `resolve`, `support`, `wallet`
- **Plataforma:** `ios/Runner/Info.plist` (nome exibido), `web/index.html`, `web/manifest.json`

## 4. Regras, índices e migrações
- **Regras:** `match /publicProfiles/{userId} { allow read: if isAuth(); allow write: if false; }`. `users/{outro}` continua **negado** (testado).
- **Índices:** nenhum novo. A caixa de entrada e as notificações usam consultas que já existiam.
- **Migração:** depois do deploy em homologação, chamar `migratePublicProfiles` como admin, primeiro com `{dryRun: true}` e depois sem ele. Os triggers mantêm a coleção daí em diante.

## 5. Testes executados

| Suíte | Resultado |
|---|---|
| Functions, unitários (`npm test`) | **65/65** |
| Emulador: regras + functions (todas as fases) | **102/102** |
| Flutter (`flutter test`) | **97 passaram, 1 pulado** (o mesmo pulado das fases anteriores) |
| `flutter analyze lib test` | **0 erros** (só avisos de APIs depreciadas que já existiam) |
| E2E Fase 6 (Playwright + emuladores) | **16/16** |
| Build web hml (`--release --dart-define=APP_ENV=hml`) | **OK** (título "Carajás 360") |

O E2E da Fase 6 cobre:
- perfil público só com campos mínimos;
- caixa de entrada do cliente com o nome do prestador verificado;
- caixa de entrada do prestador com "Maria S.", sem "Contato", sobrenome ou telefone;
- notificação com link abrindo `/resolve-detail {id}` e ficando lida;
- notificação antiga abrindo pelo tipo;
- "Marcar todas como lidas";
- perfil do prestador em 360, 800 e 1440 px sem rolagem horizontal e centralizado no desktop;
- sem login, "Solicitar serviço" abre o login e guarda a retomada.

Evidências em `docs/fase6/evidencias/`.

Novos testes Dart:
- destino de notificação;
- navegação adaptativa (celular, desktop e tablet com texto 1,5×);
- `pagePadding`;
- `AuthResume`;
- sessão expirada → login, preservando a tela;
- ganho do prestador com a comissão do pedido e a data de conclusão.

## 6. Limitações e pendências
- **E-mails de suporte** continuam `@servicoconecta.com.br`: não inventei contato novo. É preciso definir o domínio e as caixas do Carajás 360.
- **Ganhos do prestador** no painel são uma **estimativa** calculada no app a partir dos pedidos. O valor oficial é o saldo e o extrato da carteira (razão no servidor, Fase 3).
- **Offline** é detectado pelos metadados de cache do Firestore, sem pacote de conectividade. Pode levar alguns segundos para aparecer ou sumir.
- **Sessão expirada** foi testada em widget test e pelo caminho da callable. A revogação real de token em homologação não foi exercitada.
- No E2E a especialidade aparece pelo id ("eletricista") porque o catálogo não foi semeado nesse teste. No app real o nome vem do catálogo.
- **Android e iOS:** builds não executados nesta fase (previstos na Fase 7). **Nenhum APK foi gerado.**
- O Mercado Pago sandbox continua não validado com credenciais reais (pendência da Fase 3).

## 7. Commit
Branch `fase1-seguranca-ambientes-filtros`, commit "Fase 6: chat com perfil público, navegação, painéis e acabamento".
