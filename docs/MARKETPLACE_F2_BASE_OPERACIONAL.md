# Carajás 360 — Expansão Marketplace de Serviços
## Fase 2: Base operacional e segurança (P0)

Branch: `feat/modernizacao-visual`. Nada publicado: regras, Functions e app alterados apenas no repositório. Nenhuma cobrança real; pagamentos continuam desligados (`PAYMENTS_ENABLED=false`).

---

## 1. Funcionalidades implementadas

| Item | O que mudou |
|---|---|
| P0-1 Pedido direto fecha | O profissional informa o valor ao aceitar (obrigatório). O cliente vê **Pagar** em Meus pedidos (carteira, PIX ou cartão) com o `orderId` real. Pagamento só é aceito com profissional, valor e etapa válida (aceito, em andamento ou aguardando pagamento). |
| Custódia | Pagamento confirmado deixa o valor **retido** (`escrowStatus: held`). Conclusão pelo profissional **não** faz repasse: abre o prazo de custódia (`config/platform.escrowHoldDays`, 1 a 30 dias; padrão já existente de 3). O repasse sai quando o cliente **confirma o serviço** ou quando o prazo vence sem contestação (rotina `releaseDueEscrows`, a cada 6 h). |
| Contestação | Cliente ou profissional podem contestar após a conclusão enquanto o repasse não saiu; o valor fica bloqueado. |
| P0-2 Proposta do Resolve vira pedido | Nova Function `acceptResolveProposal` (transação, idempotente): cria `orders/resolve_{requestId}` com o valor e o profissional da proposta, marca a proposta como aceita e fecha a solicitação. O app leva o cliente para Meus pedidos, pronto para pagar. |
| P0-3 Privacidade | Novos pedidos abertos gravam nome e endereço em `resolveRequests/{id}/private/contact`, legível só pelo cliente, pelo profissional escolhido e pelo admin. Pedidos abertos passam a ser listados só para quem tem cadastro de profissional. Desbloqueio de lead lê o contato do documento privado. Script de migração para os documentos antigos (não executado). |
| P0-5 Transições | Removidas: concluído → cancelado, pago → cancelado, cancelado → aceito/pendente por ação comum (reabrir continua só pelo admin e não vale para pedido pago). Pedido sem profissional só é aceito por profissional **aprovado** e nunca pelo próprio cliente. Pedido pago não é cancelado pelas partes. `processPayout` respeita a custódia. |
| P0-6 Regras faltantes | `serviceTaxonomy`, `leadUnlocks`, `creditPurchases`, `highlightPurchases`. |
| P0-7 Validações | Prestador não cria perfil com nota. Proposta exige profissional cadastrado, pedido aberto de outra pessoa, valor entre 0 e 100.000 e nota/total iguais ao perfil. Cliente não marca proposta como aceita direto nem muda status para `matched`. Cliente da reserva só cancela enquanto pendente; reserva nasce pendente. Pedido de serviço nasce sem preço e sem campos de custódia. |
| P0-8 Kill switch | `financialKillSwitch` agora bloqueia também carteira (pagamento, saque, cashback), PIX, cartão, repasse manual, confirmação e a rotina de liberação. |

### Defeitos encontrados e corrigidos nesta fase

- `createOrder` e `createCartOrder` gravavam `payoutStatus`, campo proibido pela regra de criação: **criar pedido falharia no Firebase real**. O campo saiu da criação.
- A tela de PIX, sem gateway, exibia um QR Code falso com "Aguardando pagamento". Agora mostra "PIX indisponível neste ambiente. Nenhuma cobrança foi feita."
- O cartão, quando o gateway não responde, dizia "Pagamento recusado"; agora diz que nenhuma cobrança foi feita.
- `canReleaseEscrow` liberava pelo prazo fixo de 3 dias mesmo quando o pedido tinha `releaseAt` maior; agora respeita `releaseAt`.
- Taxa informativa gravada em `payments` (PIX/cartão) usava 8% fixo; passou a ler `config/platform`.

## 2. Arquivos criados ou modificados

**Backend**
- `functions/index.js` — `transitionOrder` (preço no aceite, aceite só por profissional aprovado, `confirm`, contestação, custódia, cancelamento de pago bloqueado), `processPayout`, `payOrderWithWallet`, `generatePix`, `checkPayment`, `processCardPayment`, `walletOp`, `unlockLeadContact`, `publishAssistedRequest`, `deleteMyAccount`; novas `acceptResolveProposal` e `releaseDueEscrows`.
- `functions/orderPolicy.js` — tabela de transições, `acceptPriceDecision`, `cancelBlockReason`, `paymentBlockReason`, `escrowHoldDays`, `disputeBlockReason`, ação `confirm`.
- `functions/testing/fakeFirestore.js` (novo), `functions/marketplaceF2.test.js` (novo), `functions/marketplaceF2.flow.test.js` (novo), `functions/orderPolicy.test.js`, `functions/firestoreRules.audit.js`, `functions/package.json` (script de teste).

**Regras**
- `firestore.rules` — orders, bookings, providers, resolveRequests (+ `private`), resolveProposals e quatro coleções novas.

**App**
- `lib/shared/models/models.dart` — `OrderModel` com pagamento e custódia (`canPay`, `awaitingClientConfirmation`).
- `lib/shared/services/firestore_facade.dart` — `confirmOrder`, `disputeOrder`, `payOrderWithWalletOrThrow`, `acceptResolveProposal` via Function, contato privado no pedido aberto, criação de pedido sem preço.
- `lib/features/orders/orders_screen.dart` — Pagar, Confirmar serviço, Contestar e situação do pagamento.
- `lib/features/provider/provider_home_screen.dart` — valor obrigatório ao aceitar; aviso de pagamento e de custódia.
- `lib/features/resolve/resolve_screen.dart` — aceite pela Function e ida para Meus pedidos.
- `lib/features/wallet/wallet_screen.dart` — PIX e cartão com `orderId`; sem QR falso.
- `lib/core/security/order_policy.dart` — espelho da política do backend.
- `test/order_policy_test.dart`, `test/marketplace_f2_order_test.dart` (novo).

**Migração**
- `scripts/migrations/001_resolve_private_contact.js` (novo) — simulação por padrão; `--apply` copia; `--remove-public` remove do documento público depois de copiar.

## 3. Migrações de banco

| Migração | Situação |
|---|---|
| 001 contato de pedidos abertos para `private/contact` | Script pronto, **não executado**. Ordem: export do Firestore → simulação → `--apply` → conferir → `--remove-public`. Até rodar, pedidos abertos antigos continuam com nome/endereço no documento público (agora visível só para profissionais, não para qualquer usuário). |
| Campos novos em `orders` (`escrowStatus`, `heldAmount`, `releaseAt`, `completedBy`, `clientConfirmedAt`, `paymentMethod`, `origin`, `disputedAt`…) | Aditivos, gravados só pelo backend. Pedidos antigos funcionam sem eles. |
| Índices | A rotina de liberação usa filtro de um campo (`releaseAt`), coberto pelo índice automático. Nenhum índice composto novo. |

## 4. APIs e rotas

| Callable / rotina | Uso |
|---|---|
| `transitionOrder` | ações `accept` (exige `price` se o pedido não tem valor), `start`, `complete`, `confirm` (novo, cliente), `dispute` (`reason`), `cancel`, `decline`; admin: `reopen`, `cancelDefinitive`, `releaseEscrow` (agora faz o repasse) |
| `acceptResolveProposal` (novo) | `{requestId, proposalId}` → `{orderId}` |
| `payOrderWithWallet`, `generatePix`, `processCardPayment` | exigem pedido pagável; retêm o valor |
| `processPayout` | só com confirmação do cliente ou prazo vencido |
| `releaseDueEscrows` (novo, agendada) | a cada 6 h |

Rotas do app: nenhuma nova; PIX e cartão abertos a partir de Meus pedidos com o `orderId`.

## 5. Testes executados

| Verificação | Resultado |
|---|---|
| `flutter analyze` | PASS — 0 erros, 149 avisos (linha de base 150) |
| `flutter test` | PASS — 141 aprovados, 1 ignorado (6 novos) |
| `npm test` (Functions) | PASS — 153 aprovados (37 novos) |
| Fluxo ponta a ponta com as Functions reais sobre Firestore em memória (`marketplaceF2.flow.test.js`) | PASS — 15 cenários: aceite com valor, pagamento e retenção, cancelamento de pago bloqueado, conclusão sem repasse, repasse só com confirmação (10% do Admin → R$ 180 de R$ 200), idempotência, aceite só por profissional aprovado, contestação, liberação por prazo, kill switch, proposta do Resolve vira pedido pagável |
| Compilação das regras alteradas (validador do Firebase, sem publicar) | PASS — sem erros |
| Regras e Functions no emulador do Firebase | NOT TESTED — Java não instalado nesta máquina |
| Telas no navegador (Pagar, Confirmar, Contestar, aceite com valor) | NOT TESTED — dependem de login e Firestore reais; no modo homologação as telas pedem login |
| PIX/cartão reais | EXTERNAL CONFIG REQUIRED — gateway desligado por decisão |
| Deploy | NOT APPLICABLE — não autorizado |

## 6. Evidências

- Saída dos testes acima (rodados nesta máquina).
- Nenhuma captura de tela nesta fase: as telas alteradas só funcionam com usuário logado e Firestore real ou emulador.

## 7. Pendências e bloqueios

- **Ordem de publicação** (quando autorizado): Functions e regras juntas, depois o app. Com regras novas e app antigo, o aceite de proposta pelo app antigo deixa de funcionar (passa a exigir a Function).
- Migração 001 não executada (exige export do Firestore e autorização).
- Emulador: instalar Java 11+ para testar as regras com `@firebase/rules-unit-testing`.
- **Decisão do admin em contestação**: hoje o admin pode estornar (`processRefund`) ou cancelar; falta a ação "liberar ao profissional" depois de analisar a contestação e a tela de disputas no painel (P1).
- Estorno só marca o pedido; devolução do saldo/gateway continua manual (Fase 4).
- Webhook do Mercado Pago (P0-4) segue para a Fase 4; não ligar pagamentos antes.
- Cashback de 2% fixo e carrinho do Mercado 360 com total definido no app: decisões e módulo fora desta fase.
- Telas que ainda abrem PIX/cartão sem pedido real (plano da empresa, locação, Mercado 360): mostram aviso honesto, mas precisam de fluxo próprio.
- Oferta de entrega simulada em `support_screens.dart` cria pedido de demonstração; revisar.
- Decisões comerciais da Fase 1 continuam pendentes (comissão, prazo de custódia, cancelamento/reembolso, pagamento presencial, planos, Mercado Pago Marketplace, WhatsApp). O prazo de custódia usa o padrão já existente de 3 dias até o Admin definir `escrowHoldDays`.

## 8. Próxima fase recomendada

Concluir a Fase 2 com os itens P1: taxonomia única no Firestore com CRUD no admin, estados do profissional (pendente/aprovado/suspenso/rejeitado) com documentos visíveis ao admin, localização por CEP com área de cobertura, matching em produção e a ação do admin para resolver contestações.
