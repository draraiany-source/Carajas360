# Carajás 360 — Relatório técnico da Fase 1

**Escopo:** segurança, ambientes, dados fictícios, filtros e índices.
**Ambiente:** apenas desenvolvimento local (emuladores Firebase). Nada foi publicado, nenhum projeto em nuvem foi alterado e nenhum pagamento foi feito.
**Base:** commit `5013dcd` (`main`).

---

## 1. Achados da auditoria conferidos no código recebido

| # | Achado | Situação no código | Onde |
|---|--------|--------------------|------|
| 1 | Hub Serviços: Casa/Veículos/Jurídico mudavam os atalhos, mas "Em destaque" seguia sem filtro | **Confirmado.** Chamava `FS.providersStream(limit: 5)` sem categoria | `home_screen.dart` |
| 2 | Índice de `providersStream` (active + verified + categories + rating) | **Confirmado: faltava.** O índice existente não tinha `categories` | `firestore.indexes.json` |
| 3 | Erro de consulta gerava skeleton/carregamento infinito ou lista fictícia | **Confirmado.** `DemoData.orEmpty` trocava erro por demo (debug) ou por lista vazia (release) | várias telas |
| 4 | Perfil público de prestador com documentos e selfie | **Confirmado.** `documentUrl`, `selfieUrl` e `certificates` em `providers/*` (leitura pública), com download URLs que ignoram as regras do Storage | `firebase_service.dart`, `provider_home_screen.dart` |
| 5 | Chat: participantes alteráveis, terceiros podiam ser incluídos | **Confirmado.** Qualquer participante podia regravar `participants`; a criação aceitava qualquer lista que contivesse o autor | `firestore.rules` |
| 6 | Resolve: qualquer autenticado lia solicitações | **Confirmado.** `allow read: if isAuth()` | `firestore.rules` |
| 7 | Propostas sem checagem de elegibilidade | **Confirmado.** Qualquer usuário criava proposta e incrementava `proposalCount` | `firestore.rules` |
| 8 | Notificação de vínculo só via Resolve recusada | **Confirmado.** `canNotifyTarget` não conhecia propostas; o app avisava prestadores pelo cliente, com falha silenciosa | `functions/index.js` |
| 9 | Avaliação sem validar o prestador do pedido | **Confirmado.** A regra não comparava `providerId` com o do pedido; o gatilho somava todas as avaliações | `firestore.rules`, `functions/index.js` |
| 10 | Cadastro podia gravar `verified`, `xp` e `status` | **Confirmado** na criação de `users/*` | `firestore.rules` |
| 11 | Catálogo fictício no Mercado e falha de backend escondida | **Confirmado.** 24 produtos e lojas inventados sempre visíveis; o erro do stream era ignorado | `marketplace_screen.dart` |
| 12 | PIX sem gateway exibia código "copia e cola" falso | **Confirmado** | `wallet_screen.dart` |
| 13 | Apple Pay/Google Pay apresentados como disponíveis | **Confirmado** em `availableMethods` (nenhuma tela o usa hoje) | `payment_gateway.dart` |
| 14 | Sem separação de ambientes; falha de config virava "modo demonstração" | **Confirmado** | `main.dart`, `firebase_bootstrap.dart` |
| 15 | Projeto iOS incompleto | **Confirmado:** não há `Runner.xcodeproj` | `ios/` |
| 16 | Painel admin "Ver documentos" | **Não funcionava:** lia um campo `documents` que nunca é gravado | `admin_screen.dart` |
| 17 | `admin.firestore.FieldValue` indefinido no emulador de Functions | **Encontrado nesta fase.** Todas as functions que gravam timestamp falhavam no emulador | `functions/index.js` |

---

## 2. Alterações implementadas

### 2.1 Segurança e privacidade (`firestore.rules`, `storage.rules`)
- **Prestadores:** o perfil público aceita só uma lista fechada de campos. Documento, selfie e certificados vão para `providers/{id}/private/verification`, que só o dono e o admin leem, e lá ficam apenas **caminhos do Storage**, nunca URLs públicas. Perfis pendentes (não verificados) deixam de ser públicos. Nota, total de avaliações, `verified` e `active` não podem ser definidos pelo próprio prestador; `active` só muda depois da aprovação.
- **Usuários:** o cadastro não pode nascer verificado, com XP, admin, permissões ou saldo. A edição continua bloqueando os campos protegidos (agora também `balance`, `rating`, `totalReviews` e `commissionRate`).
- **Chat:** sala 1:1 com id canônico `{uidMenor}_{uidMaior}` e o próprio usuário obrigatoriamente entre os 2 participantes. `participants`, `orderId` e `requestId` são imutáveis. Na sala, só se atualizam `lastMsg`, `lastMsgTime` e o próprio `typing_{uid}`. Mensagem com remetente forjado é recusada; o destinatário só marca como lida; o remetente só apaga para todos (não edita o texto).
- **Resolve:** a solicitação só é lida pelo cliente, pelo admin e pelo prestador escolhido. Endereço e contato ficam em `resolveRequests/{id}/private/details`. Propostas só são criadas pela callable. O aceite é um lote atômico: proposta aceita + solicitação `matched`, com checagem cruzada via `getAfter`. Um segundo aceite é recusado.
- **Avaliações:** a regra exige cliente do pedido, pedido concluído, prestador igual ao do pedido, nota inteira de 1 a 5, campos fechados e id `{orderId}_{clientId}` (somente criação, ou seja, uma por contratação).
- **Financeiro:** `orders` não nasce com `paidAt`, `reviewed`, `refunded` etc. Atualizações em `deliveries` e `appointments` não trocam participantes nem preço. Carteira, transações, pagamentos e notificações continuam somente no servidor.
- **Storage:** documentos de verificação só são lidos pelo dono e pelo admin (custom claim ou `users.type`). O upload aceita só os tipos `document`, `selfie` e `certificate`. Arquivos de `users/{uid}` fora de `/photo` deixam de ser públicos. Qualquer caminho não previsto é negado.
- O admin por claim agora é verificado de forma segura contra token sem claim (`token.get('admin', false)`).

### 2.2 Backend (`functions/index.js`, `functions/security.js`)
- `listResolveOpportunities` (callable): devolve só para prestador aprovado e ativo, dos serviços dele e da região (cidade ou áreas atendidas), **sem endereço, contato ou clientId**.
- `submitResolveProposal` (callable, transação): valida a solicitação aberta e a elegibilidade, impede duplicidade (id `{requestId}_{uid}`), pega nome, foto e nota **do servidor** (ignora o que o app enviar), incrementa `proposalCount` e notifica o cliente. Falha de push não desfaz a proposta.
- `onResolveRequestCreated` / `onResolveRequestMatched`: notificações por evento (até 50 prestadores elegíveis) e aviso ao prestador escolhido.
- `onReviewCreated` (substitui `updateProviderRating`): revalida no servidor. Avaliação inválida é removida e auditada; a válida recalcula a nota só com notas válidas, marca o pedido como avaliado e dá XP uma única vez (`processedAt`).
- `canNotifyTarget`: passa a reconhecer o vínculo por proposta Resolve.
- `sendPushNotification`: falha de FCM só é registrada em log; não gera erro depois de a notificação estar salva.
- `migratePhase1Privacy` (admin, idempotente, com `dryRun`): move a documentação legada para `private/verification`, **invalida as download URLs antigas** (troca o token do Storage), move `address` de `resolveRequests` para `private/details`, preenche `clientId` nas propostas e grava o relatório em `migrations/phase1_privacy`.
- `getVerificationFileUrl` (admin): URL assinada de 15 minutos para documento privado, com registro em auditoria.
- `FieldValue` passa a vir de `firebase-admin/firestore` (corrige o achado 17).

### 2.3 Categorias e filtros
- `ServiceFilter` (novo, puro e testável): Categoria → Grupo → Serviço → Profissionais. Trocar de grupo limpa o serviço incompatível; a especialidade levada para a contratação é o serviço escolhido (ou a especialidade do prestador dentro do grupo).
- Hub e Busca: a consulta e a lista mudam juntas a cada troca de filtro (stream guardado em estado, não recriado a cada `build`). Erro aparece como erro com "Tentar novamente"; o skeleton só aparece enquanto carrega; lista vazia mostra um aviso específico do filtro. Os chips de serviço do grupo filtram no próprio hub, e "Ver todos" leva o grupo ou serviço para a Busca.
- `providersStream`: serviço único usa `array-contains`. Grupo usa `array-contains-any` em blocos de 30 (o grupo Agro tem 31 serviços), mesclados sem duplicar e ordenados por nota. Há também um filtro de defesa no app para nunca exibir prestador de outro serviço.
- Revisão do catálogo: IDs únicos (preservados), nenhum grupo vazio, atalhos do hub apontando para grupos existentes (coberto por testes). A mistura de "Lojas", "Máquinas" e itens "aluguel_*" no catálogo de serviços fica para a **Fase 2** (taxonomia administrável).

### 2.4 Índices (`firestore.indexes.json`)
- **Novo:** `providers (active ASC, verified ASC, categories CONTAINS, rating DESC)`, que atende `providersStream` com `array-contains` e com `array-contains-any`.
- **Novos:** `providers (verified, active, categories CONTAINS)` para o gatilho do Resolve; `orders (status, createdAt)` para `cleanupOldOrders`; `orders (providerId, status, createdAt DESC)` para a agenda do prestador; `resolveProposals (providerId, clientId)`.
- **Removidos:** 5 "índices" de campo único (`stores.ownerId`, `rentals.ownerId`, `bookings.*`). O `firebase deploy` recusa esse tipo de entrada, que já é coberto pelos índices automáticos.

### 2.5 Ambientes
- `APP_ENV` = `dev` | `hml` | `prod` (`lib/core/config/app_env.dart`), via `--dart-define` ou `--dart-define-from-file=config/env/<env>.json`.
  - **dev:** emuladores, projeto `demo-carajas360` (sem nuvem).
  - **hml:** projeto `carajas360-hml` (placeholder, ver pendências) e Android `br.com.servicoconecta.hml`.
  - **prod:** projeto `servicoconecta` e `br.com.servicoconecta` (**IDs preservados**).
- `firebase_options.dart` escolhe entre `firebase_options_{dev,hml,prod}.dart`. `.firebaserc` tem os aliases `dev`, `hml` e `prod`, com padrão `demo-carajas360`: um `firebase deploy` sem alias não atinge projeto real.
- Android: flavors `dev`, `hml` e `prod` (sufixo de applicationId só em dev/hml), nome do app por flavor e `google-services.json` por flavor. A assinatura vem de `key.properties` ou das variáveis `CARAJAS_KEYSTORE_*` (nenhuma credencial no repositório). `key.properties.example` foi convertido de UTF-16 para UTF-8. O cache `android/.gradle/` saiu do Git.
- **Release com configuração inválida** (sem ambiente, ambiente dev, emulador, placeholders, ou `APP_ENV` diferente do flavor) abre a tela **"Serviço temporariamente indisponível"**, sem login, pedidos ou pagamentos. O antigo "modo demonstração" deixou de existir. Fora de produção aparece uma faixa DEV/HML.

### 2.6 Dados fictícios
- `DemoData.allow` só vale em dev + debug + `--dart-define=DEMO_DATA=true`. **Nunca** em hml, prod ou release.
- Mercado: o catálogo fictício fica restrito a dev com `DEMO_DATA`. A falha do catálogo real mostra "Catálogo indisponível / Tentar novamente". A promessa fixa "Entrega 30-60 min / Grátis acima de R$ 50" foi removida.
- PIX sem gateway mostra **"PIX indisponível — Nenhuma cobrança foi gerada"**, sem QR nem código falso.
- Apple Pay e Google Pay saíram de `availableMethods` (o enum foi mantido por compatibilidade).
- Telas com demo (pedidos, agenda do prestador, notificações, extrato, chat, saúde) passam a mostrar o erro explicitamente (`QueryErrorView`).
- Maps e Mercado Pago com placeholder não disparam chamadas inúteis.

### 2.7 Outras correções feitas no caminho
- Painel admin "Ver documentos": agora lê `private/verification` e abre cada arquivo por URL temporária.
- Onboarding do prestador: falha de upload ou de gravação mostra erro (antes falhava em silêncio).
- Resolve: o detalhe sem acesso ou inexistente não fica girando para sempre; o aceite mostra erro se a solicitação já foi fechada.

---

## 3. Arquivos modificados

**Regras, índices e configuração:** `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `.firebaserc`, `.gitignore`, `config/env/*`, `android/app/build.gradle`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/{dev,hml}/google-services.json`, `android/key.properties.example`.

**Functions:** `functions/index.js`, `functions/security.js` (novo), `functions/security.test.js` (novo), `functions/package.json`, `functions/package-lock.json`.

**App:** `lib/main.dart`, `lib/firebase_options*.dart`, `lib/core/config/app_env.dart`, `lib/core/utils/{firebase_bootstrap,demo_data,query_errors}.dart`, `lib/core/widgets/config_unavailable.dart`, `lib/features/home/{home_screen,service_filter}.dart`, `lib/features/{admin,auth,chat,gps,health,marketplace,orders,profile,provider,resolve,wallet}/*`, `lib/shared/{models/models,services/firebase_service,services/payment_gateway,widgets/widgets}.dart`.

**Testes:** `test/{service_filter,provider_merge,app_env}_test.dart`, `test/auth_flow_emulator_test.dart`, `tool/auth_smoke.dart`, `firebase-tests/**`.

---

## 4. Testes executados

| Suíte | Comando | Resultado |
|-------|---------|-----------|
| Análise estática | `flutter analyze` (Flutter 3.47.7) | **0 erros.** 162 avisos/infos, o mesmo total de antes das mudanças (deprecações e estilo já existentes) |
| Testes Flutter | `flutter test` | **62 aprovados**, 1 ignorado (`auth_flow_emulator_test`, que exige emulador) |
| Auth flow no emulador | `firebase emulators:exec ... flutter test test/auth_flow_emulator_test.dart` | **1/1 aprovado** |
| Unitários das Functions | `cd functions && npm test` | **22/22** |
| Regras Firestore + Storage | `cd firebase-tests && npm run emu` | **26/26** |
| Integração das Functions (Auth + Firestore + Storage + Functions) | idem | **6/6** (matching, propostas, duplicidade, notificação por evento, avaliações, migração, URL privada) |
| E2E visual do hub (Chromium + emulador com dados) | script Playwright (harness temporário, não versionado) | Todos → 4 aprovados (pendente oculto). Casa → Eletricista + Encanador. Casa→Eletricista → só Eletricista. Jurídico → só Advogada, com o serviço limpo. Veículos → só Mecânico. Imagens em `docs/fase1/evidencias/` |
| Build web hml (release) | `flutter build web --release --dart-define=APP_ENV=hml` | **OK.** Ao abrir, mostra a tela de indisponibilidade (evidência `hml_sem_config_indisponivel.png`) |

**Não executados nesta fase (informado com clareza):**
- **Build Android:** não há Android SDK neste container. **Nenhum APK foi gerado.** Os flavors não foram validados pelo Gradle (previsto para a Fase 7).
- **Build iOS:** sem macOS/Xcode, e o projeto Xcode não existe no repositório (Fase 7).
- **Validação dos índices em homologação real:** não existe projeto hml nem credencial neste ambiente, e o emulador não exige índices. Os índices estão declarados e precisam ser implantados no hml (passo abaixo).

---

## 5. Como aplicar em homologação (sem tocar em produção)

1. Crie o projeto Firebase de homologação. Se o id não for `carajas360-hml`, ajuste `.firebaserc` e `lib/firebase_options_hml.dart`.
2. `flutterfire configure --project=<hml> --out=lib/firebase_options_hml.dart --android-package-name=br.com.servicoconecta.hml`. Copie o `google-services.json` gerado para `android/app/src/hml/`.
3. `firebase deploy --project hml --only firestore:rules,firestore:indexes,storage,functions`
   - O deploy vai perguntar se pode **remover `updateProviderRating`**: responda sim (foi substituída por `onReviewCreated`).
   - Na primeira publicação das regras do Storage, aceite a permissão cross-service (Storage → Firestore) que o console solicitar.
4. Espere os índices ficarem "Ativos" no console.
5. Com um usuário admin: chame `migratePhase1Privacy` com `{dryRun: true}`, confira os números e depois rode sem `dryRun`. O relatório fica em `migrations/phase1_privacy`.
6. Gere o app de homologação: `flutter build web --dart-define-from-file=config/env/hml.json` (ou `--flavor hml` no Android).

Desenvolvimento local: `firebase emulators:start --project demo-carajas360` e `flutter run --dart-define-from-file=config/env/dev.json`.

---

## 6. Compatibilidade e riscos de transição

- **Versões antigas do app ficam incompatíveis com as novas regras** nestes fluxos: cadastro de prestador (gravava documentos no perfil público), lista de oportunidades e envio de proposta (agora por callable) e reabertura de sala de chat existente (o `set(merge)` com `createdAt` passa a ser negado). Publique regras e app de homologação **juntos**.
- Perfis de prestador **pendentes** deixam de ser públicos (era o comportamento esperado; antes vazavam).
- URLs de documentos copiadas antes da migração **param de funcionar** depois dela (intencional).
- Dados existentes foram preservados: IDs de categorias, de pedidos e de aplicação continuam os mesmos.

---

## 7. Limitações e pendências (para as próximas fases)

- **Fase 2:** taxonomia administrável. O catálogo ainda é constante no app e mistura serviços, lojas e locação; o admin ainda edita uma lista estática.
- **Fase 3:** o checkout do Mercado continua cobrando antes de criar o pedido e com ID inventado. Hoje ele fica bloqueado com segurança (PIX indisponível / pedido inexistente no servidor), mas **não está corrigido**. Também falta corrigir a ordem leitura/escrita em `checkPayment` e a comissão vinda de `config/platform`.
- **Fase 4:** o aceite de proposta ainda não cria pedido, agenda nem financeiro (hoje é um lote atômico com regras, mas não cobre os passos 5 a 7); falta raio de atendimento, modalidade e disponibilidade no matching; questionários por serviço.
- **Fase 5:** "Todos" em Saúde ainda não consulta nada; a reserva de Locação ainda tenta gravar `notifications` pelo app.
- **Fase 6:** a caixa de entrada do chat ainda mostra "Contato" (falta perfil público mínimo). Encontrado no E2E: o timer da splash substitui uma rota aberta por deep link. Padronização de textos públicos (ex.: `web/index.html` ainda diz "ServiçoConecta").
- **Fase 7:** Android SDK/APK, projeto Xcode completo, build iOS, CI.
- Functions usam `firebase-functions` v4 (1ª geração) e `engines.node = 18`, runtime em descontinuação no Cloud Functions. Recomendo atualizar numa fase própria (os testes rodaram em Node 22).
