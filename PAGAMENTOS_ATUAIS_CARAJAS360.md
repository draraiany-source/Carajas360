# Pagamentos atuais — Carajás 360

Mapa da arquitetura de pagamentos **como está no repositório hoje**. Não inventamos API keys nem ligamos cobrança real.

---

## Resumo executivo

| Item | Estado atual |
|---|---|
| **Gateway** | **Mercado Pago** (PIX + cartão via callables). **Asaas não está implementado.** |
| **Pagamentos reais** | **`PAYMENTS_ENABLED=false`** (default em Functions). Callables recusam com `failed-precondition`. |
| **Comissão** | **8% plataforma / 92% prestador** (`AppConst.commission = 0.08`, `OrderPolicy.commissionRate = 0.08`, `orderPolicy.js` `COMMISSION_RATE = 0.08`). |
| **Split no gateway** | **Não implementado.** Comissão calculada no repasse interno (`processPayout`), não via marketplace/split nativo do MP. |
| **Escrow (staging)** | `held` → `releaseAt` = `paidAt + 3 dias`; liberação via `canReleaseEscrow` (admin/backend). |
| **Decisão pendente (owner)** | Manter Mercado Pago vs implementar Asaas (ou outro gateway). |

---

## Arquivos-chave

| Camada | Arquivo | Função |
|---|---|---|
| Flutter | `lib/shared/services/pay_svc.dart` | `generatePix`, `checkPayment`, tokenização cartão, `fee()` |
| Flutter | `lib/shared/services/payment_gateway.dart` | `PaymentGateway`, `MercadoPagoGateway`, `PaymentService` |
| Flutter | `lib/core/constants/app_constants.dart` | `AppConst.commission = 0.08` |
| Flutter | `lib/core/security/order_policy.dart` | Escrow, payout, comissão (espelho client) |
| Functions | `functions/index.js` | `generatePix`, `processCardPayment`, `checkPayment`, `processPayout`, `processRefund`, `mercadoPagoWebhook` |
| Functions | `functions/orderPolicy.js` | `escrowHoldOnPaid`, `canReleaseEscrow`, comissão 8% |
| Functions | `functions/webhookSandbox.js` | Stub webhook MP (`charged=false`, `applied=false`) |

---

## Coleções Firestore

- **`payments`** — cobranças Mercado Pago
- **`wallets`** — saldo interno por usuário
- **`transactions`** — ledger (crédito, débito, payout)
- **`orders`** — `paymentStatus`, `escrowStatus`, `heldAmount`, `releaseAt`, `commission`, `payoutProcessed`

---

## Escrow (staging)

1. Pagamento confirmado → `escrowStatus: held`, `releaseAt = paidAt + 3 dias`
2. Liberação via `canReleaseEscrow` (confirmação cliente, prazo, ou admin)
3. Split gateway **não** implementado — repasse interno 8%/92% em `processPayout`

---

## Mercado Pago vs Asaas

- **Mercado Pago:** único gateway implementado; staging com `PAYMENTS_ENABLED=false`
- **Asaas:** **não implementado** — decisão do owner se substituir ou manter MP

Ver `PAGAMENTOS_STAGING.md` para comportamento sandbox detalhado.

---

## O que NÃO fazer

- Não ligar `PAYMENTS_ENABLED=true` sem token TEST e decisão explícita
- Não commitar secrets MP
- Não inventar Asaas neste ambiente