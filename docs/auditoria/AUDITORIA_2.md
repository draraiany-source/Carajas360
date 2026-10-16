# Carajás 360 — Auditoria 2 (16/10/2026)

**Escopo:** tudo o que mudou depois da auditoria anterior (`d4b646e`): 21 commits, cerca de 2.900 linhas em backend, regras, app, CI e configuração.
**Método:** 4 frentes em paralelo:
- reservas e pagamentos;
- demais funções do servidor e regras do Firestore/Storage;
- app Flutter;
- CI, implantação e configuração.

Cada achado foi conferido no código antes da correção. As regressões ganharam testes. Nada foi publicado: só emulador e CI, sem produção.

**Legenda:**
- ✅ corrigido e testado;
- ✅ᴸ corrigido, conferido só por leitura (o caminho não é reproduzível no emulador);
- 📝 registrado como pendência (exige recurso externo).

## Achados e correções

### Reservas e pagamentos (Saúde e Locação)

| # | Gravidade | Problema | Correção | |
|---|---|---|---|---|
| P0 | **Alta** (achado durante os testes, existia desde a Fase 3) | Reembolso recusado pelo gateway: a transação de `processRefund` lia depois de escrever. A transação falhava, o reembolso ficava `requested` para sempre e o valor travado em `refundPendingCents`, sem a pendência `refund_failed` aparecer. | Leituras antes das escritas (`payments/index.js`). Uma varredura das demais transações não achou outro caso. | ✅ |
| P1 | Alta | Depois da correção acima: o reembolso recusado devolve `paymentStatus` a `approved`, e o gatilho da reserva tratava isso como pagamento novo e pedia o reembolso de novo, em laço. | `refundRestored`: a volta de `refund_requested` para `approved` com o mesmo `paidAttemptId` não é tratada como pagamento (`schedule.js`). | ✅ |
| P2 | Alta | Se a confirmação de uma reserva paga falhasse uma vez (gatilhos v1 não repetem), cliente e horário ficavam presos: pago, `pending_payment` e bloqueando a agenda. | A tarefa `expireBookingHolds` confirma ou devolve reservas pagas cujo prazo já passou. | ✅ᴸ |
| P3 | Média | Quem pagava depois do prazo podia tirar o horário de quem estava dentro da própria retenção. | `holdBlocks`: pagamento depois do prazo (`paidAtMs > holdUntilMs`) não bloqueia; a confirmação do atrasado confere conflito. | ✅ |
| P4 | Média | O Pix (mínimo de 30 min) vencia depois da retenção (15 min), o que gerava pagamentos "tardios" corriqueiros. | Ao gerar o Pix, a retenção acompanha o vencimento, com teto no prazo original + 30 min (cancelar e gerar outro não segura o horário). O limite por cliente (`bookingHolds`) acompanha. | ✅ |
| P5 | Baixa | Uma segunda aprovação depois de um reembolso era tratada como a primeira, e o valor ficava retido. | Qualquer aprovação com `paidAttemptId` diferente já registrado é tratada como duplicada e devolvida. | ✅ᴸ |
| P6 | Baixa | Cupom apagado travava a expiração de pedidos e o resto da manutenção. | As regras proíbem apagar cupom (desativar com `active:false`); `expireOrders` isola falhas por pedido. | ✅ |
| P7 | Baixa | Clique duplo na reserva de Saúde respondia `scheduled` para reserva `pending_payment`. | Devolve o estado real (como na Locação). | ✅ᴸ |
| P8 | Baixa | A cotação de locação ignorava o relógio de teste. | Usa `clock.nowMs`. | ✅ᴸ |

### Servidor e regras

| # | Gravidade | Problema | Correção | |
|---|---|---|---|---|
| B1 | **Alta** | Qualquer usuário podia mandar notificação com texto próprio (phishing) a qualquer outro: o pedido de serviço não conferia o `providerId` e o aviso usava o título do cliente. | Regras: pedido só para prestador verificado e ativo, nunca para si mesmo, com título e descrição limitados. Aviso com texto fixo e limite de 20 por hora por cliente. | ✅ |
| B2 | Média | O modo manutenção não cobria: repasse, cashback, reagendar/confirmar Saúde, transições de Locação, status de pedido do Mercado, confirmar recebimento (libera dinheiro), nem a criação de anúncios, lojas e produtos. | Guarda em todas essas operações, com cancelar e recusar liberados para o usuário poder sair; `notInMaintenance()` nas criações de anúncio, loja e produto. | ✅ |
| B3 | Média | `migrateReviewAuthors` trocava nomes reais por "Cliente" ou "Usuário" quando não havia perfil público, e de forma permanente. | Pula e lista essas avaliações; paginada, com tempo de 540 s. A causa do "Usuário" também foi corrigida: o XP da avaliação criava usuário "fantasma" com `set+merge`. | ✅ |
| B4 | Média | Aprovar prestador reativava conta suspensa ou apagada. | Recusa a aprovação se a conta está suspensa ou tem `deletedAt`. | ✅ |
| B5 | Baixa-média | `adminRunMaintenance` aceitava qualquer admin (inclusive suporte), nomes como `hasOwnProperty` e repetições; uma tarefa com erro parava as demais. | Exige perfil financeiro (master ou financial), `Object.hasOwn`, sem repetição, até 10 tarefas, erro isolado por tarefa. | ✅ |
| B6 | Baixa | O aviso de "nova resposta" do chamado nunca era limpo. | Callable `markTicketRead` (só o dono), usada pelo app ao abrir o chamado. | ✅ |
| B7 | Baixa | Um `orderId` qualquer silenciava o push de mensagens do chat. | Regras: `orderId` só do próprio pedido do cliente. O gatilho também confere o vínculo. | ✅ |
| B8 | Baixa | A foto do autor ia para a avaliação, que é pública até sem login. | A avaliação não guarda mais a foto. | ✅ |
| B9 | Baixa | A reanálise podia ser pedida em qualquer estado, sem registro. | Só a partir de "recusado", com registro em auditoria. | ✅ |
| B10 | Baixa | Aprovar duas vezes notificava duas vezes, e a auditoria gravava "Admin" fixo. | Decisão repetida não notifica; grava o nome real do admin. | ✅ |

### App Flutter

| # | Gravidade | Problema | Correção | |
|---|---|---|---|---|
| A1 | **Alta** | O modo manutenção só cobria a tela inicial: depois do login, ao tocar numa notificação ou numa tela já aberta, o usuário continuava usando o app. | O bloqueio vai no `MaterialApp.builder` e cobre todas as rotas, exceto abertura, login e cadastro. Sem piscar, e o estado das telas é preservado. | ✅ |
| A2 | Média | A retomada pós-login podia levar à tela errada (entrada antiga não era limpa). | Limpa ao explorar sem entrar e quando a rota não tem nome; tolera argumentos não serializáveis. | ✅ |
| A3 | Média | O aviso de chamado não lido não sumia, e a conversa se re-inscrevia nos fluxos a cada envio. | `markTicketRead`; fluxos criados uma vez; rolagem até a mensagem nova; "Chamado não encontrado." | ✅ |
| A4 | Média | O botão Pagar ficava visível depois do prazo, e a tela de pagamento permitia gerar Pix vencido. | Atualização periódica dos cartões pendentes; a tela de pagamento bloqueia depois do prazo. | ✅ |
| A5 | Média | Erros que não vinham da callable passavam sem aviso, e o pagamento com carteira aceitava toque duplo. | Aviso genérico de falha; bloqueio de toque duplo. | ✅ |
| A6 | Média | A folha de cupom chamava `setState` depois de fechada e vazava controladores. | Componente próprio com `dispose` e checagem de `mounted`. | ✅ |
| A7 | Baixa | Faltava confirmação ao cancelar reserva ou consulta, e "Enviar chamado" duplicava. | Diálogo de confirmação; bloqueio durante o envio. | ✅ |
| A8 | Baixa | Mensagem errada para reserva repetida já expirada, cupom pedido sem login, acessibilidade. | Mensagem pelo `status`; pedido de login; rótulos semânticos. | ✅ |

### CI, implantação e configuração

| # | Gravidade | Problema | Correção | |
|---|---|---|---|---|
| C1 | Alta | `workflow_dispatch` roda de qualquer branch; quem protege os secrets é o environment. | Documentado como obrigatório: environment `homologacao` restrito à branch protegida, com revisor. | 📝 configuração no GitHub (você) |
| C2 | Alta | Com a seção `hosting`, um `firebase deploy -P prod` sem `--only` publicaria um build hml/dev em produção. | `predeploy` do Hosting (`tool/hosting_guard.js`) recusa produção sem confirmação explícita. | ✅ |
| C3 | Média | O checador aceitava `config/env/hml.json` com `APP_ENV=prod`. | Exige `APP_ENV=hml`, sem emulador, e `PROD_PROJECT_IDS` com os dois projetos de produção. | ✅ |
| C4 | Média | O checador procurava o plist iOS num caminho que o Xcode não usa (e que não era ignorado pelo Git). | Corrigido para `ios/config/` (o caminho ignorado), também na documentação. | ✅ |
| C5 | Média | O iOS usa um *bundle id* só para todos os ambientes. | Plano em `BUILD_MOBILE.md`: configurações e *scheme* hml. | 📝 exige macOS/Xcode e conta Apple |
| C6 | Média | Dependências eram instaladas com a credencial já carregada; firebase-tools sem versão fixa. | Instalação e build antes da autenticação; `firebase-tools@14.27.0`. | ✅ |
| C7 | Média | Actions fixadas por *tag*; bundletool sem checksum. | — | 📝 recomendação |
| C8 | Média | `npm audit`: 8 moderados (`uuid@9` via firebase-admin 13). | Sem exposição (só `uuid.v4()`); a correção exige firebase-admin 14 (quebra de API). | 📝 já registrado |
| C9 | Baixa | `github.ref_name` interpolado no script; `find \| head` com `pipefail`. | Variável de ambiente; `find -print -quit`. | ✅ |
| C10 | Baixa | O checador marcava como modelo o `firebase_options` real do flutterfire (comentário "Example:"). | Regex sem "example". | ✅ |
| C11 | Baixa | O script de contas trocava (em vez de somar) a lista de produção pela variável. | A variável só acrescenta. | ✅ |

## Resultados dos testes (16/10/2026)

| Suíte | Resultado | Onde |
|---|---|---|
| Regras + functions (emulador) | **164/164** (eram 152; +12 de regressão: `rules/homologacao.rules.test.js` e `functions/homologacao_auditoria2.test.js`) | EMU |
| Unitários das functions | 65/65 | local |
| Flutter (`flutter test`) | **140/140** (eram 124 + 1 pulado; +15 em `test/audit_round2_test.dart`; o teste que depende do emulador de Auth também rodou, porque o emulador estava ativo); `flutter analyze` sem erros (147 avisos informativos, eram 150) | local |
| E2E web (7 fluxos, app real incluído) | **91/91**: catalog 16, checkout 17, resolve 13, schedule 16, phase6 16, hml 10, app 3 | EMU |
| Índices × consultas | 46 consultas compostas, 0 faltando | estático |

**Mudanças de comportamento intencionais, com testes antigos ajustados:**
- pedido de serviço exige prestador verificado (as fixtures dos testes de regras ganharam o prestador);
- o Pix estende a retenção (os testes adiantam 31 min em vez de 16);
- `adminRunMaintenance` exige perfil financeiro (os testes usam o admin master).
