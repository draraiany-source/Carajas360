# Gateway Producao — Checklist

## IMPORTANTE: arquitetura real = Mercado Pago (NAO Asaas)

O Carajas 360 usa **Mercado Pago** (PIX/cartao callables + webhook).
Asaas / split gateway nativo **nao existe** no codigo atual.
Split = payout interno (comission snapshot + wallet profissional).

## O que a proprietaria precisa no painel Mercado Pago

1. Conta Mercado Pago empresarial aprovada (producao).
2. Separar claramente aplicacao **TEST/Sandbox** vs **Producao**.
3. Em Secret Manager (NUNCA no Git/chat):
   - MERCADOPAGO_ACCESS_TOKEN (somente quando autorizado)
   - MERCADOPAGO_WEBHOOK_SECRET
4. Configurar webhook HTTPS apontando para Cloud Function mercadoPagoWebhook do projeto Firebase de producao.
5. Confirmar metodos: PIX, cartao (boleto se for usar).
6. Nao reutilizar paymentId/customerId/walletId do Sandbox em producao.
7. Manter PRODUCTION_PAYMENTS_ENABLED=false ate autorizacao explicita pos-piloto.

## Confirmacao

- [ ] Conta MP producao distinta do sandbox
- [ ] Secrets no Secret Manager
- [ ] Webhook URL HTTPS producao
- [ ] Teste Sandbox ja passou antes de qualquer token APP_USR-