# BLOCO F — relatório final (próximo)

Restrições iguais: sem produção, sem pagamento real, sem inventar secrets, sem merge em `main`.

## Entregar no F

1. Relatório consolidado A–E.
2. Classificação única: **BLOCKED** / **STAGING READY** / **RELEASE CANDIDATE**.
3. Lista do que a Raiany precisa fazer com as **mãos** (keystore, plists reais, secrets, URL de privacidade, Xcode project).

## Pendências conscientes do E (não bloqueiam o F documental)

| Item | Por que parou |
|---|---|
| HTTP Directions de verdade | Key de servidor ausente **e** chamada Google = cobrança Maps. Callable `getDirections` existe e recusa. |
| Rules no emulador CI | Precisa `firebase emulators:exec` + Java no workflow. Mantido audit estático. |
| Webhook aplicar pagamento | Mesmo com HMAC válido: `applied:false`. Ligar só com `TEST-` + `PAYMENTS_ENABLED` pela Raiany. |
| Corpo de `FS` → services | Fachadas ok; mover 1600+ linhas agora é risco de regressão. |
| App Check enforce | Sem keys reais. |
| iOS archive | `Runner.xcodeproj` ausente. |
| AAB Play | Sem keystore no Git (proposital). |
