# Carajás 360 — Fase 3: Checkout, pagamentos e financeiro (sandbox)

> **Status:** concluída em **homologação local (emuladores)**, com **gateway simulado**.
> **Nenhum teste chegou ao sandbox real do Mercado Pago.** A política de rede deste ambiente bloqueia `api.mercadopago.com` (HTTP 403 no proxy) e não há credenciais de teste.
> A integração com o Mercado Pago está implementada pelo SDK oficial, mas **não foi validada contra o gateway**. Nada foi publicado. Produção não foi tocada. Nenhum pagamento real foi feito.

## 1. Conferência das Fases 1 e 2 e dependências

- Os commits `d7e22c0` (Fase 1) e `e55892f` (Fase 2) estão na branch. As suítes dessas fases foram reexecutadas junto com as da Fase 3: emulador 73/73 e Flutter 82/82.
- Dependências que bloqueavam esta fase foram encontradas e corrigidas:
  - catálogo obrigatório nas regras de pedido;
  - o legado `orders` com `type: marketplace` deixava o cliente gravar o total.
- Achados da auditoria, conferidos no código recebido **antes** de editar:

| Achado | Situação encontrada | Correção |
|---|---|---|
| Cartão cobrava antes do pedido, com `orderId` = horário do aparelho | Confirmado (`CardPaymentScreen` + `_finalizeOrder` depois do pagamento) | O pedido é criado no servidor antes; a cobrança usa o id persistido |
| Pix com `order_${millis}` | Confirmado | Idem |
| `checkPayment` / `processPayout`: leitura depois de escrita na transação | Confirmado | Duas fases (todas as leituras antes das escritas) |
| Idempotência por minuto (`Math.floor(Date.now()/60000)`) | Confirmado em `generatePix` | Tentativa persistida com chave determinística |
| `walletOp` permitia débito arbitrário e saque que "cai em 1 dia útil" | Confirmado | Débito e saque desativados; o saque mostra explicação honesta |
| Comissão editada direto em `config/platform` pelo app | Confirmado | `config/finance` só por callable validada e versionada |
| Assinatura de planos abria Pix sem backend | Confirmado | Desativada, com aviso |
| Loja sem campos de frete | Confirmado | `deliveryFeeCents`, `deliveryEnabled`, `pickupEnabled` |
| Asaas / split externo | **Não existem** no código | Não foram presumidos; nada foi implementado como split |

## 2. Fluxo implementado

O fluxo vai do carrinho (persistente, por loja) até o acompanhamento do pedido:

1. **Carrinho por loja.** Fica salvo no aparelho e na conta.
2. **Endereço / entrega.** O cliente escolhe entrega ou retirada. `quoteMarketOrder` faz a cotação **no servidor**.
3. **`createMarketOrder`.** É idempotente pelo `requestId`. O servidor:
   - recalcula preço, promoção, cupom, frete e total em **centavos**;
   - valida produto ativo, loja e estoque;
   - **reserva o estoque** na mesma transação;
   - grava o snapshot dos itens e as condições financeiras (`financeTerms`);
   - grava `status = pending_payment` e `paymentStatus = unpaid`.
4. **`startPayment`** recebe o pedido real (`targetKind`, `targetId`, `method`, `requestId`):
   - cria a tentativa persistida `paymentAttempts/pa_<sha256(uid|tipo|alvo|requestId)>`;
   - usa a chave de idempotência do gateway = id da tentativa e `external_reference` = id da tentativa.
5. **Confirmação** por três caminhos:
   - webhook assinado → consulta ao gateway → `applyUpdate`;
   - `refreshPayment`, chamado periodicamente pela tela;
   - rotina agendada `paymentsMaintenance`, a cada 10 min.
6. **Acompanhamento.** A loja avança o pedido (`preparing → shipped|ready → delivered`). O cliente vê o pedido em tempo real.

- O status do **pedido** e o status do **pagamento** são campos separados.
- A interface **nunca** aprova localmente: todas as telas leem `marketOrders` e `paymentAttempts` do Firestore.

### Carrinho com várias lojas (decisão)

O código não tinha pedido multi-loja nem split. A decisão foi **um pedido e um pagamento por loja**:

- o carrinho agrupa os itens por loja;
- "Finalizar pedido desta loja" cobra só aquela loja;
- os itens das outras lojas continuam no carrinho.

Assim, nunca é cobrado um total combinado sem regra de distribuição. Um checkout combinado exigiria split no gateway, que não está integrado.

### Carrinho e login

- **Persistência:** `SharedPreferences` no aparelho + `carts/{uid}` na conta.
- **Ao entrar:** o carrinho de visitante é unido ao da conta. Para o mesmo produto fica a maior quantidade (sincronizar de novo não duplica).
- **Ao sair:** o carrinho local é limpo; ele continua salvo na conta.
- **Ação pendente:** quem toca em "Finalizar" sem login é levado ao login e volta direto ao checkout daquela loja.
- **Limpeza:** abrir a tela de pagamento **não** limpa o carrinho. Os itens saem só quando o pedido aparece **pago** no servidor.

### Estoque

- A baixa acontece na criação do pedido, dentro de uma transação. Isso impede vender acima do estoque: no teste, 5 pedidos simultâneos com estoque 3 resultaram em exatamente 3 pedidos.
- A reserva vale `reservationMinutes` (padrão 30). Com Pix, ela é estendida até o vencimento do código, com teto de 2 h.
- O estoque é devolvido **uma única vez** (`stockReleased`) em três casos:
  - cancelamento;
  - expiração pela rotina;
  - reembolso total antes do envio.

## 3. Gateway (adapter)

Arquivo: `functions/payments/gateway.js`.

- **`mercadoPagoGateway`** usa o SDK oficial `mercadopago@3.6.1` (`Payment`, `PaymentRefund`):
  - Pix com `date_of_expiration`;
  - cartão por **token**, com `three_d_secure_mode: 'optional'`;
  - consulta, busca por `external_reference`, cancelamento e reembolso parcial/total com `idempotencyKey`.
- **Classificação de erros:** timeout, 5xx, 409 e 429 viram `GatewayUncertain` (concilia antes de nova cobrança); 4xx vira `GatewayRejected`.
- **`fakeGateway`** é o simulador, aceito **só** com `FUNCTIONS_EMULATOR=true`. Ele reproduz:
  - idempotência por chave;
  - timeout antes e depois de criar;
  - recusa;
  - 3DS;
  - reembolso assíncrono.

### Guarda de homologação (`financeCore.gatewayMode`)

`PAYMENTS_GATEWAY=mercadopago` só liga se **todas** estas condições valerem:

- `PAYMENTS_ENV=sandbox`;
- o projeto **não** está em `PROD_PROJECT_IDS` (padrão `servicoconecta`);
- o token começa com `TEST-` (ou `APP_USR-` com `MP_TEST_USER_CREDENTIALS=true`, para usuário de teste);
- `MP_WEBHOOK_SECRET` está definido.

Em qualquer outro caso, os pagamentos ficam **desligados** e a mensagem explica o motivo. O valor `fake` fora do emulador também desliga.

- Os secrets ficam só no backend (Secret Manager / env).
- `redact()` remove tokens de mensagens e logs.
- Nenhum token aparece em respostas.

### Documentação oficial consultada

- O acesso direto a `mercadopago.com.br/developers` foi bloqueado pela rede deste ambiente. Os endpoints e o algoritmo foram confirmados por duas vias: a busca na documentação oficial e o **código-fonte do SDK oficial** (`node_modules/mercadopago`).
- **Algoritmo do webhook:** manifest `id:{data.id};request-id:{x-request-id};ts:{ts};`, HMAC-SHA256 em hex, `ts` em segundos. A validação usa o próprio `WebhookSignatureValidator` do SDK, com `data.id` em minúsculas e tolerância de 900 s.

## 4. Pix e cartão

- **Pix:** QR Code (`qr_flutter`), copia-e-cola e vencimento gravado (`pixExpiresAt`, mínimo de 30 min exigido pelo gateway). A confirmação chega por webhook, consulta periódica e rotina agendada. Expiração, cancelamento e nova tentativa usam um novo `requestId`.
- **Cartão:**
  - tokenização direto no endpoint oficial de `card_tokens`, com a chave pública;
  - número e CVV **nunca** passam pelo backend nem são gravados (teste 1 confere isso);
  - parcelas validadas no servidor: 1 a `maxInstallments`, parcela mínima `minInstallmentCents`;
  - estados tratados: aprovado, recusado, pendente/em análise e desafio 3DS (abre o link do banco e aguarda a confirmação do servidor).

## 5. Idempotência

| Situação | Tratamento | Teste |
|---|---|---|
| Clique duplo | Mesma tentativa (id determinístico); uma cobrança no gateway | 5 |
| Duas abas (requestId diferentes) | Retoma a tentativa ativa; trocar de método é bloqueado | 5 |
| Timeout / resposta perdida | Tentativa fica `uncertain`; repetir usa a mesma chave e o gateway devolve a mesma cobrança | 6 |
| Incerto + nova cobrança | Bloqueada até conciliar; sem cobrança após 10 min = falha | 6 |
| Eventos repetidos | `webhookEvents` deduplica; `shouldApply` ignora repetidos e fora de ordem | 7 |
| Confirmação após cancelamento | Reembolso automático (`rf_late_*`) + divergência registrada | 13c |
| Pagar pedido já pago | Retorna `already: true`, sem cobrar | 5 |

## 6. Webhooks e conciliação

Endpoint: `paymentsWebhook` (onRequest).

- **Autenticidade:** assinatura inválida recebe 401.
- **Deduplicação** em `webhookEvents`.
- **Confirmação no gateway:** sempre consulta `GET payment` em vez de confiar no corpo.
- **Validações:** referência externa = tentativa, valor, moeda, conta recebedora (`MP_COLLECTOR_ID`) e id do pagamento. Qualquer diferença gera `financialIssues/payment_divergence` e o pagamento **não** é aprovado.
- **Erros recuperáveis:** resposta 500 para o gateway reenviar.
- **Rotina `paymentsMaintenance`** (agendada; `runPaymentsMaintenance` para o admin):
  - expira reservas;
  - concilia tentativas paradas;
  - reenvia e confirma reembolsos;
  - registra cada execução em `reconciliationRuns`.

## 7. Carteira

Arquivo: `functions/payments/wallet.js`.

- O saldo é guardado em **centavos** (`balanceCents`); `balance` em reais é só espelho.
- O razão auditável fica em `transactions/{chave}`, e a chave torna cada lançamento idempotente. Exemplos:
  - `recharge_{id}`, `pay_{tentativa}`, `refund_{id}`;
  - `sale_{pedido}`, `cashback_{pedido}`, `sale_reversal_{id}`.
- Todo uso é em duas fases (`readWallet` antes, `postLedger` depois). Débito que deixaria saldo negativo é recusado.
- `checkPayment` (legado) foi corrigido: leituras antes das escritas e crédito único `recharge_legacy_{id}`. O pagamento com carteira dos pedidos de serviço também foi corrigido.
- `walletReconcile` (admin) compara saldo × soma do razão e registra divergência.
- O cliente não altera saldo (regras + testes). Débito livre e saque estão **desativados**.

## 8. Comissão, cashback e repasses

- **Fonte única:** `config/finance`, alterável só por `updateFinanceConfig`. A callable valida limites, versiona em `config/finance/history/{v}` e grava auditoria. Limites:
  - comissão de 0 a 30%;
  - cashback de 0 a 10%;
  - parcelas de 1 a 12;
  - reserva de 30 a 120 min.
- **Quando a comissão incide:** sobre mercadorias menos desconto; o frete é integral da loja.
  - É **calculada e gravada no pedido na criação** (`financeTerms`, com versão).
  - É **reconhecida na entrega** (`delivered`).
  - Pedidos anteriores mantêm as condições originais (teste 12).
- **Pedidos de serviço (legado):** passam a receber `financeTerms` no `onCreate`. `canPayout` usa a taxa do snapshot (15% para pedidos antigos sem snapshot).
- **Cashback:** % sobre mercadorias, creditado **uma vez** na entrega e estornado proporcionalmente em reembolso.

### Distinção de valores

| Termo | Onde aparece | Situação |
|---|---|---|
| **Pagamento recebido** | `paymentAttempts.status=approved` / `marketOrders.paymentStatus=approved` | Integrado (sandbox, não validado no gateway real) |
| **Saldo interno** | `earnings` (`pending_release` → `released`) + lançamento `sale_release` na carteira da loja | Integrado |
| **Repasse solicitado** | Não existe | **Desativado** |
| **Transferência externa confirmada** | Não existe | **Não integrada** |

O crédito na carteira da loja é **saldo interno**, não split bancário. Saque e split ficam desativados e estão listados nas pendências.

## 9. Cancelamento e reembolso

- **Pedido aguardando pagamento:** a cobrança pendente é cancelada no gateway e o estoque volta.
  - Se o gateway disser que o pagamento acabou de ser aprovado, o cancelamento é recusado com a mensagem "solicite cancelamento com reembolso" (teste 13c).
- **Pedido pago ou em preparo:** vai para `cancellation_requested` e gera um reembolso total.
- **Reembolso parcial:** solicitado pelo admin financeiro.
- **Confirmação:** o status só vira `refunded` / `partially_refunded` quando o pagamento **consultado no gateway** mostra o valor reembolsado. Até lá fica `refund_requested` (teste 13a).
- **Pagamento com carteira:** o estorno é interno e confirmado na mesma transação (teste 13d).
- **Efeitos de um reembolso confirmado:**
  - estoque devolvido (se total e antes do envio);
  - comissão e repasse ajustados proporcionalmente;
  - se o valor já tinha sido liberado à loja, lançamento `sale_reversal`; se o saldo não cobrir, abre a divergência `seller_negative_balance` para ajuste manual;
  - cashback estornado.
- **Aprovação tardia** (pagamento confirmado depois de cancelamento ou expiração):
  - `paymentStatus=approved_late`;
  - reembolso automático;
  - divergência `late_approval`;
  - o pedido mantém o status (expirado/cancelado).

## 10. Telas

**Cliente** (`lib/features/checkout/`):
- `CartScreen`: carrinho por loja, com aviso de várias lojas.
- `CheckoutScreen`: entrega/retirada, endereço, cupom, cotação do servidor e criação do pedido com `requestId` salvo por loja.
- `MarketOrderScreen`:
  - resumo, itens, frete e total;
  - status do pedido e do pagamento;
  - reserva, Pix/cartão/carteira e tentativa em andamento;
  - cancelar / pedir reembolso e histórico de eventos.
- `MyMarketOrdersScreen`: histórico de pedidos.
- `PaymentScreen`: Pix e cartão; estados de carregamento, incerto, pendente, 3DS, recusado e sucesso, todos vindos do Firestore.
- **Carteira:** saldo em centavos, recarga por Pix/cartão (crédito só após confirmação), saque desativado com explicação, aba explicando como funciona.

**Loja:**
- frete e modos de entrega;
- `StoreOrdersScreen`, onde a loja avança o pedido; a entrega libera o saldo interno.

**Admin**, aba "Pagamentos" (`finance_admin_tab.dart`):
- configuração versionada;
- pedidos, com reembolso parcial/total;
- tentativas;
- reembolsos;
- divergências;
- conciliação: executar a rotina, conciliar carteira e ver execuções recentes.

A leitura é restrita por `isFinanceAdmin` (admin `master` / `financial` ou claim). O campo de comissão foi removido de "Configurações".

## 11. Modelo de dados

| Coleção | Conteúdo | Escrita |
|---|---|---|
| `marketOrders/{mo_*}` (+ `events`) | Cliente, loja, itens (snapshot), centavos, `financeTerms`, status, `paymentStatus`, `activeAttemptId`, `paidAttemptId`, `reservedUntil`, reembolsado/pendente | Só servidor |
| `paymentAttempts/{pa_*}` (+ `events`) | Alvo, método, valor, status, id no gateway, Pix, desafio 3DS, `gatewayUpdatedAt` | Só servidor |
| `walletRecharges/{rc_*}` | Recarga e seu status | Só servidor |
| `refunds/{rf_*}` | Valor, motivo, status (`requested → pending_confirmation → approved / failed`) | Só servidor |
| `earnings/{orderId}` | Bruto, comissão, líquido, status (`pending_release / released / cancelled`), estornos | Só servidor |
| `transactions/{chave}` | Razão da carteira (`signedCents`, `balanceAfterCents`, referência) | Só servidor |
| `financialIssues`, `webhookEvents`, `reconciliationRuns` | Auditoria e conciliação | Só servidor |
| `config/finance` (+ `history`) | Comissão, cashback, parcelas, reserva, limites de recarga | Só pela callable |
| `carts/{uid}` | `items` + `updatedAt` (preço só para exibição) | Dono |

**Regras** (`firestore.rules`):
- todas as coleções acima com escrita `false` para o app;
- `orders` não aceita mais `type: marketplace` nem `financeTerms` vindos do cliente;
- `config/finance` não pode ser escrito nem por admin;
- `_fakeGateway*` é negado.

**Índices novos** (`firestore.indexes.json`, 12 no total):
- `marketOrders`: cliente / loja / dono por data; `status + reservedUntil`;
- `paymentAttempts`: `status + updatedAt`; `targetId + createdAt`;
- `refunds`: `attemptId + status`; `status + data`;
- `earnings`, `financialIssues`, `transactions`, `walletRecharges` por usuário/status + data.

**Configuração sem segredos:**
- `functions/.env.example` documenta as variáveis de sandbox;
- `functions/.env.demo-carajas360` só vale no emulador e tem segredo de teste falso.

## 12. Testes e resultados

| Suíte | Resultado | Mock ou sandbox real |
|---|---|---|
| Functions unitários (`cd functions && npm test`): financeCore, gateway (normalização, guarda), orderPolicy, security, catalogCore | **47/47** | Puro / mocks |
| Emulador (`firebase-tests`, regras + integração das Fases 1–3) | **73/73** | Emulador + **gateway simulado** |
| — dos quais `payments.test.js` (obrigatórios 1–13 e 15) | 16/16 | Gateway simulado |
| — dos quais `payments.rules.test.js` | 8/8 | Emulador de regras |
| Flutter (`flutter test`), inclui `checkout_test.dart` (obrigatório 14) | **82/82** | Puro + `SharedPreferences` mock |
| E2E navegador (`firebase-tests/e2e/checkout.e2e.js`) | **17/17** | Emulador + gateway simulado |
| `flutter analyze` | **0 erros** (só avisos antigos de estilo/deprecação) | — |
| Build web hml (release, `APP_ENV=hml`) | **OK** (não publicado) | — |

**Nenhum teste atingiu o sandbox real do Mercado Pago.**

### Testes obrigatórios

| # | Teste | Como foi verificado |
|---|---|---|
| 1 | Pedido antes da cobrança | Integração (pedido existe, zero tentativas e zero cobranças no gateway) + E2E |
| 2 | ID persistido chega a Pix/cartão | `external_reference` = tentativa → `targetId` = pedido; E2E Pix |
| 3 | Total adulterado ignorado | Integração (preço/total/frete/desconto falsos ignorados; gateway cobra o valor do servidor) |
| 4 | Pedido de outro usuário bloqueado | Integração (pagar, consultar, cancelar, reembolsar) + regras |
| 5 | Clique duplo | Integração (duas chamadas simultâneas + outra aba = 1 cobrança) |
| 6 | Timeout / retry | Integração (timeout depois e antes de criar, recusa, 3DS) |
| 7 | Webhook duplicado / fora de ordem | Integração (assinatura inválida, duplicado, estado antigo, valor divergente) |
| 8 | Confirmação com o app fechado | Integração (só a rotina agendada) + E2E (Pix confirmado pelo webhook, sem ação no app) |
| 9 | Recarga creditada uma vez | Integração (webhooks concorrentes + consulta + rotina = 1 lançamento) |
| 10 | Débitos concorrentes sem saldo negativo | Integração (5 × R$ 30 com R$ 100 → 3 aprovados, saldo R$ 10, razão confere) |
| 11 | Concorrência de estoque e liberação | Integração (5 pedidos / estoque 3; cancelamento e expiração devolvem uma vez) |
| 12 | Comissão preservada em pedidos anteriores | Integração (15% → 10%; pedido antigo libera o líquido a 15%) |
| 13 | Cancelamento / reembolso | 13a total, 13b parcial, 13c aprovação tardia, 13d carteira |
| 14 | Carrinho preservado após login | `checkout_test.dart` (merge, restauração, ação pendente) + E2E (recarregar a página) |
| 15 | Homologação bloqueia operação real | Unitário `gatewayMode` (produção, sem sandbox, token não-teste, sem segredo, `fake` fora do emulador) + integração (endpoints legados desativados) |

**Evidências:** `docs/fase3/evidencias/` (capturas do E2E: vitrine, carrinho multi-loja, cotação, cartão, Pix com QR, pedido pago, histórico no celular).

**Como rodar:**
- `cd functions && npm test`
- `cd firebase-tests && npm run emu`
- `flutter test`
- E2E: veja o cabeçalho de `firebase-tests/e2e/checkout.e2e.js`. O harness `test_driver/e2e_checkout_main.dart` é só de dev e é compilado com `PAYMENTS_FAKE_TOKENS=true`.
- Observação: o harness desliga a persistência do login, porque o emulador de Auth não renova sessão restaurada. O carrinho continua salvo localmente e é isso que o teste de recarga verifica.

## 13. Como validar no sandbox real (pendente)

1. Crie credenciais de **teste** no Mercado Pago (usuário vendedor de teste) e configure o webhook com a assinatura secreta.
2. No projeto **hml**, defina:
   - `PAYMENTS_GATEWAY=mercadopago`;
   - `PAYMENTS_ENV=sandbox`;
   - `PAYMENTS_WEBHOOK_URL` (URL da function `paymentsWebhook`);
   - `MP_COLLECTOR_ID`;
   - os secrets `MERCADOPAGO_ACCESS_TOKEN` (TEST-…) e `MP_WEBHOOK_SECRET`.
3. No app hml, defina `MERCADOPAGO_PUBLIC_KEY` (chave pública de teste).
4. `firebase deploy --project hml --only firestore:rules,firestore:indexes,functions` e aguarde os índices ficarem ativos.
5. Valide com os cartões de teste oficiais: aprovado, recusado e 3DS. Valide também:
   - Pix de teste;
   - webhook recebido e assinatura conferida;
   - reembolso parcial e total;
   - expiração do Pix.

## 14. Limitações e pendências

- **Sandbox real não validado.** Endpoints, formato real do webhook (inclusive `x-signature` em produção de teste), 3DS real, retorno de `refunds` e `collector_id` foram conferidos só no SDK/documentação, não no gateway.
- **Tokenização de cartão:** usa o endpoint REST `card_tokens` com a chave pública, já existente no app. Os componentes oficiais (Bricks / SDK mobile) não foram adotados.
- **Sem split bancário, saque ou transferência externa.** Ficam desativados. O líquido da loja é saldo interno.
- **Assinaturas de planos:** sem cobrança (desativadas).
- **Pagamento de pedidos de serviço** pelo novo fluxo: o backend aceita `targetKind: 'service'`, mas as telas de serviço não foram migradas (fica para a Fase 4, com o aceite de proposta).
- **Estoque editado pela loja:** se a loja grava um valor absoluto enquanto há reservas, essas reservas não são consideradas. Recomenda-se ajuste por incremento numa fase futura.
- **Saldo negativo de vendedor em estorno após liberação:** gera divergência para ajuste manual, sem cobrança automática.
- **Índices** validados só no emulador (não há projeto hml acessível).
- **Builds Android/iOS** não executados (sem SDKs neste ambiente).
