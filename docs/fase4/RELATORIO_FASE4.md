# Carajás 360 — Fase 4: Resolve, matching e contratação

> **Status:** concluída em **homologação local (emuladores)**.
> O pagamento do pedido contratado usa o **gateway simulado** da Fase 3; não houve chamada ao Mercado Pago real.
> Nada foi publicado e produção não foi tocada.

Escopo: seção 6 do pedido original (Orçamentos — Resolve Carajás).

## 1. Situação encontrada (antes de editar)

| Ponto | Encontrado | Correção |
|---|---|---|
| Questionários por serviço | Existiam no admin (Fase 2), mas **não eram usados** nas solicitações | O app mostra o questionário e o servidor valida as respostas |
| Criação da solicitação | Gravada direto pelo app (lote Firestore) | Feita só pela callable `createResolveRequest`, que é idempotente e valida tudo |
| Matching | Considerava serviço exato, aprovação, conta ativa e cidade | Agora considera também caminho do catálogo, conta bloqueada, **raio**, **modalidade** e **disponibilidade** |
| Aceite da proposta | Lote do app: marcava a proposta e a solicitação, sem criar pedido, chat, agenda ou financeiro | Feito só pela callable `acceptResolveProposal`, numa transação única |
| Notificações | Já eram por evento desde a Fase 1 (`notifySafe`; falha de push não derruba a operação) | Mantidas; o filtro passa a ser o matching novo. Também avisam os não escolhidos |
| Vínculo só via Resolve na notificação | Corrigido na Fase 1 (`canNotifyTarget` aceita vínculo por proposta) | Mantido (teste da Fase 1 continua passando) |
| Bug da Fase 2 | `serviceSnapshot` gravava `undefined` quando o item do catálogo não tinha `vertical` ou nome, e a função falhava | Campos ausentes viram `null` |

## 2. O que foi implementado

### Questionários condicionais e anexos

**Questionário aplicável:** o do item mais específico do caminho do catálogo que tiver um questionário publicado (serviço → grupo).

**Validação no servidor** (`resolveCore.validateAnswers`):
- regras de visibilidade: `equals`, `not_equals`, `in`, `answered`; a condição só olha perguntas anteriores **visíveis**;
- obrigatórias são exigidas apenas quando visíveis;
- tipos validados: texto, número, sim/não, data, escolha única/múltipla e anexo;
- respostas de perguntas ocultas são descartadas.

O app usa a mesma lógica em Dart (`lib/features/resolve/questionnaire.dart`) e um formulário dinâmico (`questionnaire_form.dart`).

**Anexos:**
- O cliente envia para `resolveUploads/{uid}/…`. O Storage aceita só a própria pasta, imagem ou PDF de até 10 MB, sem sobrescrever.
- O servidor confere se o caminho é da pasta do usuário (sem `..`), se o arquivo existe, o tipo e o tamanho, e guarda a lista em `resolveRequests/{id}/private/details`.
- Só o cliente, o **profissional escolhido** e o admin acessam o arquivo, e sempre por URL temporária (`getResolveAttachmentUrl`). Antes do aceite, nenhum prestador vê.

### Solicitação

**`createResolveRequest`** recebe:
- descrição e serviço;
- modalidade: presencial, no endereço do cliente ou online;
- data preferida (de hoje a 180 dias, no fuso `America/Belem`) e período;
- localização aproximada (arredondada para cerca de 1 km);
- endereço e telefone (privados);
- respostas do questionário.

**Idempotência:** o id é `rr_<hash(uid|requestId)>`; repetir devolve a mesma solicitação.

**Recusas:**
- serviço desativado;
- nível "categoria" (é preciso escolher grupo ou serviço);
- conta bloqueada.

**Visibilidade:** o documento principal guarda as respostas legíveis (`publicAnswers`) para o prestador orçar, mas nunca endereço, telefone ou anexos.

### Matching

Implementado em `resolveCore.providerMatch` e usado em todos os pontos: lista de oportunidades, notificação por evento, envio de proposta e aceite.

1. **Serviço:** declarar um serviço atende pedidos do serviço, do grupo e da categoria. Declarar só o grupo **não** cobre um serviço específico não declarado (mesma regra da busca da Fase 2).
2. **Aprovação:** `verified`.
3. **Conta ativa:** perfil `active` e usuário não bloqueado nem suspenso.
4. **Região:**
   - se o prestador e a solicitação têm localização, vale o **raio** do prestador (padrão 30 km, máximo 200 km), com distância calculada por Haversine;
   - senão, vale a cidade e as áreas atendidas;
   - pedidos online ignoram a região.
5. **Modalidade:** a do pedido precisa estar entre as do prestador.
6. **Disponibilidade:**
   - dias da semana e períodos declarados;
   - pausa (`acceptingRequests`) e ausência até uma data (`unavailableUntil`);
   - perfis antigos sem disponibilidade declarada não são restringidos.

O prestador configura tudo isso na nova tela **"Meu atendimento"**, a partir do painel do prestador. As regras validam o formato de raio, localização, dias, períodos e datas.

### Aceite transacional

`acceptResolveProposal` executa tudo numa única transação Firestore:

1. Valida a solicitação **aberta** e confirma que quem aceita é o **cliente** dono.
2. Valida que a proposta pertence à solicitação e não foi retirada.
3. Revalida o prestador: aprovação, conta, serviço, modalidade e região. A disponibilidade já foi avaliada quando ele enviou a proposta.
4. **Seleciona uma única proposta:** a proposta vira `accepted`; a solicitação vira `matched`, com `matchedProposalId` e `orderId`.
5. Registra o preço e as condições aceitas (`acceptedTerms`: valor em centavos, prazo e mensagem).
6. Cria o **pedido operacional** `orders/rs_<requestId>`:
   - `status: accepted` e `paymentStatus: unpaid`;
   - `financeTerms` com a comissão vigente em `config/finance`, preservada no pedido;
   - modalidade e data agendada.
7. **Vincula:**
   - **chat:** sala canônica entre cliente e prestador; os vínculos só são gravados se ainda não existirem;
   - **agenda:** `scheduleEntries/{orderId}` com data, período, fuso e status `to_confirm`;
   - **financeiro:** o pedido é pago pelo fluxo da Fase 3 (`startPayment` com `targetKind: 'service'`). A conclusão continua exigindo pagamento confirmado e o repasse usa a comissão gravada no pedido.

**Concorrência e repetição:**
- aceitar de novo a mesma proposta devolve o mesmo pedido (`already: true`);
- aceitar outra proposta depois é recusado;
- dois aceites simultâneos de propostas diferentes: a transação garante que **exatamente um** vence (testado).

**Depois do aceite** (gatilho `onResolveRequestMatched`): as demais propostas viram `not_selected`, e o escolhido e os não escolhidos são avisados.

**Regras:** o app não cria solicitação, não marca `matched` e não aceita proposta diretamente. O cliente ainda pode cancelar a própria solicitação aberta (regra ou callable `cancelResolveRequest`).

### Telas

- **Pedir orçamento:**
  - serviço (com pré-seleção por rota) e descrição;
  - questionário dinâmico com anexos;
  - modalidade, data e período;
  - cidade, endereço privado, localização aproximada e telefone;
  - envio idempotente.
- **Propostas recebidas:**
  - respostas, data e modalidade;
  - aceite com confirmação, feito pelo servidor;
  - cartão "Pedido contratado" com valor aceito, situação do pagamento, agenda, chat, pagamento (Pix/cartão pela tela da Fase 3) e anexos;
  - cancelar solicitação.
- **Oportunidades (prestador):** modalidade, distância, data/período, respostas e quantidade de anexos (liberados só após o aceite).
- **Meu atendimento (prestador):** pausa, modalidades, raio, base aproximada, dias, períodos e ausência.
- **Meus pedidos:** botão **Pagar** nos pedidos de serviço aceitos ou em andamento ainda não pagos, e etiqueta "Pago". Isso fecha a pendência da Fase 3, em que o pagamento de serviço não tinha tela.

## 3. Arquivos

**Backend:**
- `functions/resolveCore.js` (novo)
- `functions/resolveCore.test.js` (novo)
- `functions/resolve.js` (novo; substitui as funções de Resolve que estavam em `index.js`)
- `functions/index.js`
- `functions/catalogCore.js` (correção do `serviceSnapshot`)
- `functions/package.json`

**Regras:**
- `firestore.rules`: criação e aceite do Resolve só pelo servidor; atendimento do prestador; `scheduleEntries`; dados privados sem anexos vindos do cliente.
- `storage.rules`: `resolveUploads`.

**App:**
- `lib/features/resolve/questionnaire.dart` (novo)
- `lib/features/resolve/questionnaire_form.dart` (novo)
- `lib/features/resolve/resolve_screen.dart`
- `lib/features/provider/provider_attendance_screen.dart` (novo)
- `lib/features/provider/provider_home_screen.dart`
- `lib/features/orders/orders_screen.dart`
- `lib/shared/models/models.dart`
- `lib/shared/services/firebase_service.dart`
- `lib/main.dart`

**Testes:**
- `firebase-tests/functions/resolve.test.js` (novo)
- `firebase-tests/rules/resolve.rules.test.js` (novo)
- `firebase-tests/e2e/resolve.e2e.js` (novo)
- `test/resolve_questionnaire_test.dart` (novo)
- `test_driver/e2e_resolve_main.dart` (novo)
- Testes de regras das Fases 1 e 2 atualizados (abaixo).

**Migração:** nenhuma migração de dados.
- Solicitações antigas continuam legíveis.
- Os campos novos são opcionais.
- Prestadores sem raio, base ou disponibilidade seguem com a regra de cidade e sem restrição de agenda.

**Índices:** os existentes cobrem as consultas (`resolveRequests` por `status + category + createdAt`; `providers` por `verified + active + categories`). Nenhum índice novo.

## 4. Testes

| Suíte | Resultado | Observação |
|---|---|---|
| Functions unitários (`npm test`) | **55/55** | +8 do `resolveCore` |
| Emulador (regras + integração, Fases 1–4) | **88/88** | Inclui 12 de integração do Resolve e 4 de regras/Storage |
| Flutter (`flutter test`) | **87 aprovados, 1 ignorado** | O ignorado é o teste de login que só roda com emulador, já existente |
| E2E navegador (`resolve.e2e.js`) | **13/13** | Questionário → matching → proposta → aceite → contratado → pagamento simulado |
| `flutter analyze` | **0 erros** | Só avisos antigos de estilo e deprecação |
| Build web hml (release, `APP_ENV=hml`) | **OK** (não publicado) | — |

**Coberto na integração:**
- questionário obrigatório e condicional, resposta oculta descartada e idempotência;
- serviço desativado, nível categoria e data passada recusados;
- anexo de outra pessoa, inexistente ou de tipo proibido recusado; anexo inacessível antes do aceite;
- oportunidades e notificações só para compatíveis: raio, grupo × serviço, modalidade, pausa e conta bloqueada;
- sábado fora da disponibilidade; pedido em nível de grupo;
- propostas de incompatíveis recusadas;
- aceite cria pedido, chat e agenda com valor em centavos e comissão;
- repetição devolve o mesmo pedido; segunda proposta recusada; demais propostas encerradas e avisadas;
- **aceites concorrentes: exatamente um vence**;
- proposta retirada, prestador desativado ou solicitação cancelada bloqueiam o aceite;
- pagamento simulado → início → conclusão → repasse com a comissão do pedido.

**Testes antigos alterados porque o comportamento mudou de propósito:**
- `firestore.rules.test.js` e `catalog.rules.test.js`: criar a solicitação ou aceitar a proposta direto pelo app agora **falha** (antes passava).
- O Phase 1 (`phase1.test.js`, propostas e notificações) continua passando sem mudanças.

**Evidências:** `docs/fase4/evidencias/` traz as capturas do E2E: questionário, aguardando propostas, oportunidade no celular, confirmação do aceite, contratado e pago.

**Não reexecutado nesta fase:** o E2E de checkout da Fase 3 (17/17 na fase anterior). Os arquivos dele não mudaram; os testes de integração de pagamentos (16/16) foram reexecutados dentro dos 88.

## 5. Aplicar em homologação

1. `firebase deploy --project hml --only firestore:rules,storage,functions`.
2. Publique o app hml **junto**. Versões antigas do app não conseguem mais criar solicitação nem aceitar proposta, porque as regras passam a exigir as callables.
3. Os prestadores podem configurar "Meu atendimento". Sem configuração, continuam valendo cidade e áreas, sem restrição de agenda.

## 6. Limitações e pendências

- **Agenda:** a entrada é criada no aceite como "a confirmar", com data e período, mas **ainda não há horário exato nem confirmação ou reagendamento pelo prestador**. Isso, junto com conflito de agenda e horários reais, entra na Fase 5 (Saúde/agenda).
- **Disponibilidade:** é por dia da semana e período, não por horário. Não há bloqueio por pedidos já agendados.
- **Localização:** é aproximada (cerca de 1 km) e opcional. Sem ela, o matching usa cidade e áreas por texto normalizado. Não há geocodificação de endereço (falta a chave de Maps configurada).
- **Notificações:** por evento, limitadas a 50 prestadores por solicitação. Não há fila de reenvio para push que falhou (o registro em `notifications` permanece).
- **Anexos:**
  - a lista de quem pode ver é conferida a cada pedido de URL;
  - em produção a URL é assinada e expira em 10 min; no emulador é a URL direta do emulador;
  - arquivos enviados e não usados não são apagados automaticamente.
- **Proposta:** o prestador ajusta valor e prazo ou retira a proposta pelas regras (`available: false`), mas ainda não há botão "retirar" na tela do prestador.
- **Pagamento:** continua no **gateway simulado / sandbox não validado** (ver Fase 3).
- **Builds Android/iOS:** não executados (sem SDKs neste ambiente).
