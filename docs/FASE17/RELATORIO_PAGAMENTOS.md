# Relatório pagamentos — FASE 17

## Modelo comercial (preservar)

Duas modalidades no produto existente (documentação/fases anteriores):

1. **Pagamento dentro do app** (custódia/escrow + comissão Admin — default ~8%).  
2. **Contato/pagamento direto ao prestador** (`direct_contact` / isenção de comissão quando aplicável).

**Não presumir split MP nativo** — validação e ledger no backend (Functions).

## O que está implementado (código + unit)

| Item | Status |
|------|--------|
| PIX / cartão / wallet callables | Código |
| Webhook não confia só no body | Código + testes |
| `PAYMENTS_ENABLED` / `PRODUCTION_PAYMENTS_ENABLED` fail-safe | Testes FASE6 |
| Comissão / payout / escrow / disputa | Testes F2 |
| Kill switch financeiro | Testes |

## O que NÃO está comprovado

| Item | Status F17 |
|------|------------|
| Sandbox MP E2E | **NÃO EXECUTADO** |
| Produção | **BLOQUEADA** (flag + GO) |
| Deploy Functions pagamentos | **403 / Blaze** |

## Sandbox (após GO Blaze + token TEST)

```
PAYMENTS_ENABLED=true
PRODUCTION_PAYMENTS_ENABLED=false
MERCADOPAGO_ACCESS_TOKEN=<TEST-...>  # Secret Manager
```

Aceite: PIX + cartão + webhook idempotente com logs (sem cobrança produção).
