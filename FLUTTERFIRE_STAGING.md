# FlutterFire — staging (`carajas360-a17c5`)

Passos para a **Raiany**. Este agente **não** executa `flutterfire configure` (login Google + Console).

## Comando

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=carajas360-a17c5
```

Substituir placeholders em:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

## C1 — bloqueio Console

**C1 não pode ser auto-corrigido sem acesso ao Firebase Console.** Cadastrar apps `br.com.carajas360` e ativar Auth/Firestore/Storage/Functions.

## Pós-configure

- iOS: `REVERSED_CLIENT_ID` → `Info.plist` URL schemes
- Web: OAuth client → `web/index.html`
- SHA-1/256 no Console (debug + upload keystore)

`PAYMENTS_ENABLED` permanece **false**. Ver `CHECKLIST_FIREBASE_STAGING.md`.
