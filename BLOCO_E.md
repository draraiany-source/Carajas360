# BLOCO E — Fases 25–30 (entregue)

Restrições: sem produção, sem pagamento real, sem inventar secrets, sem merge em `main`.

## Feito
- Fases 25–26: `ANDROID_RELEASE_CHECKLIST.md`, `IOS_RELEASE_CHECKLIST.md` (prep only; sem keystore).
- Fase 27: `BACKLOG_FASE_2.md` (P0–P3). Voz/vídeo, Pay, OCR pago, SMS/WhatsApp **não** implementados.
- Fase 28: `OCR_DOCUMENTOS.md` (arquitetura; sem serviço pago).
- Fase 29: `functions/auditLog.js` — login admin, permissão, aprovação prestador, pagamento, cancelamento, reembolso, payout, carteira, exclusão. Sem secrets.
- Fase 30: Crashlytics/Analytics já no `main`; `AppError` / `AppTelemetry`; `ErrorWidget` sem stack; `functions.logger` estruturado.

## Pendências D (tratadas sem bloquear)
- Directions: `getDirections` + `directionsProxy.js` — recusa sem key; **não** chama Google (cobrança Maps).
- Rules emulador: não viável neste CI sem `emulators:exec` — audit estático permanece.
- Webhook MP: HMAC se `MERCADOPAGO_WEBHOOK_SECRET` existir; senão 501; **nunca** aplica crédito.
- Split `FS`: não movido o corpo (risco). Fachadas mantidas.

Próximo: **BLOCO F** (`BLOCO_F.md`).
