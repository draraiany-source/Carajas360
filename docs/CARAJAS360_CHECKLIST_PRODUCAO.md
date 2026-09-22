# CARAJAS360_CHECKLIST_PRODUCAO.md

## BLOQUEADORES

- [ ] Firebase real (sem COLE_SUA_*)
- [ ] PAYMENTS_ENABLED revisado (default false ate autorizacao)
- [ ] Secrets em Secret Manager (nao no Git)
- [ ] firestore.rules + storage.rules deployados
- [ ] Cloud Functions deployadas (incl. unlockLeadContact)
- [ ] Admin claim configurado
- [ ] App Check plano definido
- [ ] Zero P0 de IDOR/financeiro aberto
- [ ] Build release Android assinado (sem publicar)
- [ ] Build iOS signing (sem publicar)

## OBRIGATORIOS

- [ ] Politica de Privacidade / Termos atualizados no dominio final
- [ ] deleteMyAccount testado
- [ ] Webhook HMAC + idempotencia
- [ ] Comissao Admin = payout
- [ ] Saque: regra de negocio definida
- [ ] Rate limit login/compra/unlock
- [ ] Logs sem secrets/PII excessiva
- [ ] E2E-01..20 PASS ou justificativa
- [ ] Target SDK / politicas lojas

## RECOMENDADOS

- [ ] Crashlytics/Analytics em release
- [ ] Paginação listas grandes
- [ ] Feature flags Admin UI completa
- [ ] Expurgo LGPD job
- [ ] Consentimento OAuth reforcado

## OPCIONAIS

- [ ] Split gateway nativo (Asaas) — so se decisao comercial
- [ ] Deep links avancados
- [ ] Acessibilidade audit completa WCAG

## Nao fazer nesta checklist

- Publicar Play Store / App Store sem autorizacao explicita
- Ligar pagamentos reais sem sandbox validado
- Commitar senhas de teste
