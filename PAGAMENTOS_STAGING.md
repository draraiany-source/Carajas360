# Pagamentos — staging / sandbox (não remover Mercado Pago)

**Pagamento real está desligado.** `PAYMENTS_ENABLED` default `false`. Este bloco **não** liga cobrança, webhook de produção nem saque automático.

## Integração atual (Mercado Pago) — documentada, mantida

Não está “morta”: é o gateway único, atrás de `PaymentGateway` / `PaymentService`. **Não removemos.**

| Peça | Onde | Staging |
|---|---|---|
| Access token (privado) | Functions `process.env.MERCADOPAGO_ACCESS_TOKEN` | Vazio. Sem token + flag false → callables de PIX/cartão recusam com `failed-precondition` |
| Public key (cliente, tokenizar cartão) | `--dart-define=MERCADOPAGO_PUBLIC_KEY` → `RuntimeConfig` → `PaySvc.tokenizeCard` | Placeholder; tokenização contra `api.mercadopago.com` só com key TEST real da Raiany |
| PIX | callable `generatePix` | Recusa se `PAYMENTS_ENABLED` não for true |
| Consulta | callable `checkPayment` | Idem; UI de PIX cai no QR **demo** (não credita carteira) |
| Cartão | callable `processCardPayment` (token PCI no client) | Idem |
| Carteira interna | callable `payOrderWithWallet` | Não é Mercado Pago; usa saldo Firestore (regras: client não escreve wallet) |
| Estorno | callable `processRefund` (admin) | Marca pedido `refunded` + audit; **não** chama MP se gateway real off |
| Repasse | callable `processPayout` | Idempotente; só após pagamento confirmado (BLOCO A) |
| Google Pay / Apple Pay | `PaymentMethod` na abstração | Retornam erro claro — **não** simulam sucesso |
| Assinatura / plano | callable `requestPlanChange` (BLOCO C) | Grava `planChangeRequests` **pending**. **Não cobra. Não altera `users.plan`.** |

HTTP abertos (`generatePixHttp` etc.) continuam `410 Gone` (BLOCO A).

### O que está incompleto no MP (não é lixo a apagar)

- Sem webhook MP no repo (confirmação via polling `checkPayment`).
- Sem split / marketplace MP nativo — comissão é calculada no payout interno.
- Public key e access token não estão no Git (correto).
- QR demo na `PixScreen` quando o callable falha: payload EMV fake, merchant display `Carajas 360`, e-mail ainda `@servicoconecta.com.br`. **Não é PIX válido e não credita.**
- `PAYMENTS_ENABLED=true` exigiria token **TEST-** (sandbox MP), nunca `APP_USR-` de produção, e decisão explícita da Raiany. **Não ligar agora.**

## Abstração (para trocar de gateway no futuro)

- `PaymentGateway` — contrato: `createPayment` / `checkPayment` / `refundPayment` / `processPayout`.
- `MercadoPagoGateway` — implementação atual (PIX/cartão/MP + carteira via Functions).
- `PaymentService` — fachada do app. Telas novas devem usar isso, não o SDK do MP direto.

Trocar de provedor = nova classe `implements PaymentGateway` + Functions equivalentes. O app não deve importar axios/MP.

## Plano / assinatura (sandbox)

`requestPlanChange({ plan })`:

- Auth obrigatória + rate limit.
- Planos: `free` | `professional` | `premium` | `corporate`.
- Escreve `planChangeRequests/{id}` com `status: pending_sandbox` (ou `pending_review` se a flag de pagamentos estiver on — **ainda sem charge**).
- `charged: false`, `applied: false`.
- Client **não** pode setar `users.plan` (rules BLOCO A).

Tela Carteira → Assinar chama essa callable e mostra o aviso de staging. Não abre PIX/cartão para “comprar plano”.

## Como testar sem cobrar

```bash
cd functions && npm test   # inclui planChange
# Emulador: chamar requestPlanChange autenticado → doc pending, users.plan inalterado
```

Com `PAYMENTS_ENABLED=false`, `generatePix` / `processCardPayment` devem falhar de forma explícita — isso é o comportamento certo.
