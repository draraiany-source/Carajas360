# BLOCO E — pendências conscientes (não executadas no D)

Restrições: sem produção, sem pagamento real, sem inventar secrets.

## Directions via Cloud Function
O GPS ainda chama a Directions API no client (`RuntimeConfig.googleMapsApiKey`).  
Mover para uma callable exige **key de servidor restrita por IP da Function**, que só a Raiany pode criar. Sem essa key, não implementamos o proxy (evita inventar secret e deixar rota aberta).

## Firestore Rules no emulador
CI atual: auditoria estática (`functions/firestoreRules.audit.js`).  
Testes `@firebase/rules-unit-testing` pedem Emulator Suite + Java no runner. Configurar no GitHub quando a Raiany habilitar o workflow com `firebase emulators:exec`.

## Webhook Mercado Pago
`mercadoPagoWebhook` + `webhookSandbox.js` respondem **501** e **não** alteram pedido/carteira.  
Falta: secret de webhook (Secret Manager), verificação de assinatura, ambiente sandbox `TEST-`. Não ligar `PAYMENTS_ENABLED`.

## App Check enforce
Ainda `ENFORCE_APP_CHECK=false` até as keys reais (BLOCO C).

## Corpo de `FS`
Fachadas (`UserService`, `OrderService`, …) já existem. Próximo corte: mover o corpo de `firestore_facade.dart` para esses arquivos.
