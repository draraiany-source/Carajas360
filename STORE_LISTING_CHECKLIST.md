# Store listing — Google Play + App Store

**Sem auto-upload.** Publicação manual.

## URLs legais

| Documento | URL |
|---|---|
| Privacidade | https://carajas360-a17c5.web.app/privacy |
| Termos | https://carajas360-a17c5.web.app/terms |

Fonte: `AppInfo.privacyUrl` / `AppInfo.termsUrl` em `app_constants.dart`.

## Google Play

- [ ] Package `br.com.carajas360`
- [ ] Política: URL acima
- [ ] AAB assinado → track Internal testing
- [ ] Data safety alinhada a `web/privacy.html`

## App Store

- [ ] Bundle `br.com.carajas360`
- [ ] Privacy Policy URL acima
- [ ] TestFlight internal antes de review
- [ ] `Runner.xcodeproj` presente

Antes do review: Firebase real, sem placeholders, `PAYMENTS_ENABLED=false`.
