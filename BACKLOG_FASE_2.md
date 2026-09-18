# Backlog — Fase 2 (não implementar agora)

Itens abaixo estão **classificados**, não executados.  
BLOCO E **não** implementa voz/vídeo, split/refund completo, Google/Apple Pay, OCR pago, SMS/WhatsApp.

Prioridade: **P0** bloqueia staging confiável · **P1** falta para release candidato · **P2** valor de produto · **P3** futuro.

## P0 — segurança / dinheiro / identidade

| Item | Estado hoje | Nota |
|---|---|---|
| Keystore Android + `key.properties` | Só example no Git | Raiany gera **fora** do repo |
| `google-services.json` / `GoogleService-Info.plist` reais | Placeholders | Sem inventar keys |
| App Check enforce | `ENFORCE_APP_CHECK=false` | Depois de Play Integrity / DeviceCheck |
| `PAYMENTS_ENABLED` | `false` | Continua desligado |
| Webhook MP assinado + sandbox `TEST-` | Stub + HMAC se secret existir; **não cobra** | Secret Manager (Raiany) |
| Directions via Function | Callable recusa se `GOOGLE_MAPS_SERVER_KEY` ausente | Não inventar key |
| URL pública de privacidade | Só e-mail in-app | Play/App Store exigem link |
| `Runner.xcodeproj` | Ausente no Git | Bloqueia iOS archive |

## P1 — release candidato (depois do staging)

| Item | Estado hoje |
|---|---|
| Adaptive icon Android | Só `mipmap-*dpi` |
| Push iOS (APNs + background modes) | Código FCM; sem entitlements |
| Google Sign-In iOS (`REVERSED_CLIENT_ID`) | Placeholder |
| SHA-1/256 Play App Signing no Firebase | Depois do 1º AAB interno |
| Rules no emulador (`@firebase/rules-unit-testing`) | CI = audit estático |
| Mover corpo de `FS` para services de domínio | Fachadas finas |
| Refund **completo** (API MP + estorno de carteira) | Só marca `refunded` + audit |
| Split marketplace MP (15% já é interno no payout) | Sem split de gateway |

## P2 — produto (Fase 2 explícita — NÃO agora)

| Item | Por que esperar |
|---|---|
| Voz / vídeo (WebRTC) | UI só envia mensagem de “solicitou ligação” |
| Google Pay / Apple Pay | Enum + mensagem; sem merchant ID |
| OCR pago (Vision / Textract) | Ver `OCR_DOCUMENTOS.md` — arquitetura só |
| SMS / WhatsApp transacional (Twilio, Zenvia) | Auth hoje = Firebase Phone / e-mail |
| Streaming (Bunny.net etc.) | Fora do núcleo |
| Módulos comingSoon (Vagas, Fretes, Imóveis, Obras, Auto, Kids) | `platform_modules.dart` |

## P3 — evolução

| Item | Nota |
|---|---|
| ATT / tracking iOS | Não usamos tracking hoje |
| Multi-idioma | App em PT-BR |
| Dark mode extra / tablets | Tema já existe; não é bloqueio |
| Relatórios fiscais automáticos | Retenção LGPD 5 anos já documentada |

## Explicitamente fora deste PR

- Publicar Play / App Store.
- Criar keystore, certificados, secrets.
- Ligar pagamento real.
- Merge em `main`.
