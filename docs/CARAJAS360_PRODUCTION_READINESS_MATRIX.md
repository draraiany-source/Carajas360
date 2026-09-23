# Matriz de Prontidao — Producao

| ITEM | RESPONSAVEL | STATUS | EVIDENCIA | BLOQUEADOR | ACAO |
|------|-------------|--------|-----------|------------|------|
| P0 codigo | Prog | PASS | F3/F4 | — | — |
| P1 fin/seg codigo | Prog | PASS | F4 | — | — |
| Build APK/AAB | Prog | FAIL/NOT TESTED | build_rc1_apk.log | JVM crash | Gerar AAB |
| E2E device | Ambos | NOT TESTED | F5 matrix | DEVICE | Emulador/device |
| Sandbox MP integrado | Ambos | NOT TESTED | env ABSENT | Secrets MP TEST | Config externa |
| Firebase prod files | Proprietaria | EXTERNAL CONFIG REQUIRED | COLE_SUA_* | Placeholders | flutterfire |
| PRODUCTION_PAYMENTS | Prog | PASS (off) | .env.example | — | Manter false |
| Kill switch | Prog | PASS (codigo) | financialKillSwitch | Deploy config | Admin UI precisa setar |
| Gateway = Mercado Pago | — | PASS | functions/index.js | — | Nao Asaas |
| Split interno | Prog | PASS (unit) | orderPolicy | E2E gateway | — |
| Webhook idempotente | Prog | PASS (unit) | webhookApply | Integrado | URL HTTPS |
| App Check | Proprietaria | EXTERNAL CONFIG REQUIRED | ENFORCE false | Keys | Registrar |
| Dominio/e-mail | Proprietaria | EXTERNAL CONFIG REQUIRED | AppInfo | DNS | Configurar |
| LGPD textos | Ambos | NOT TESTED device | hosting URLs staging | Dominio final | Revisar |
| Play Store prep | Ambos | NOT TESTED | — | AAB+conta | Checklist |
| App Store prep | Ambos | NOT TESTED | — | macOS | Checklist |
| Observabilidade | Prog | PARTIAL | Crashlytics no app | Firebase real | Ativar release |
| Backup/rollback | Prog | DOC ONLY | incident doc | Processo | Validar |
| Pagamentos reais | — | OFF | PRODUCTION_PAYMENTS_ENABLED | Autorizacao | Nao ligar |
| Publicacao | — | NAO | — | Gate | Fase futura |