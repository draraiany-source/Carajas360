# E2E staging — smoke manual

Checklist cliente / prestador / admin com Firebase staging real.

> **Aviso:** E2E automatizado contra staging **live** **não foi executado por completo** — faltam keys reais e App Check.

## Pré-condições

- [ ] `firebase_options.dart` sem `COLE_SUA_*`
- [ ] Functions: `PAYMENTS_ENABLED=false`, `ENFORCE_APP_CHECK=false`

## Cliente

- [ ] C1 Login/cadastro
- [ ] C4 Criar pedido
- [ ] C6 PIX → esperado falha ou QR demo (sem cobrança real)
- [ ] C8 Links /privacy e /terms

## Prestador

- [ ] P2 Aceitar pedido
- [ ] P4 Concluir (bloqueia se unpaid)
- [ ] P5 Net 92% (`AppConst.commission = 0.08`)

## Admin

- [ ] A3 Reabrir cancelado
- [ ] A4 Cancelamento definitivo
- [ ] A5 Liberar escrow
- [ ] A6 Payout 8%

## Automatizado

| Suite | Staging live |
|---|---|
| `test/firebase_placeholders_test.dart` | OK local |
| `test/admin_order_actions_test.dart` | OK local |
| `integration_test/*` | Requer emulador |

| Data | Resultado |
|---|---|
| _pendente_ | Aguardando flutterfire configure |
