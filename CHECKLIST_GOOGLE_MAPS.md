# Checklist — Google Maps (Carajás 360)

A key do Maps SDK **é de cliente**: ela aparece no APK/IPA. Isso é o modelo do Google. O que não pode vazar é uma key **sem restrição** ou uma key de **servidor** (Directions/Geocoding irrestrita).

**Não inventamos API key neste bloco.** Placeholders `COLE_SUA_GOOGLE_MAPS_API_KEY_AQUI` permanecem até a Raiany colar a key **restrita** de staging.

---

## Onde a key entra hoje

| Plataforma | Arquivo | Mecanismo | Key no Git? |
|---|---|---|---|
| Android (SDK nativo) | `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY` = `${MAPS_API_KEY}` | `android/app/build.gradle` lê `MAPS_API_KEY` de `android/local.properties` | `local.properties` está no `.gitignore`. Fallback no Gradle é o placeholder |
| iOS (SDK nativo) | `ios/Runner/Info.plist` chave `GMSApiKey` + `AppDelegate.swift` lê do bundle | Placeholder no plist. `provideAPIKey` **só** se o valor não for placeholder | Placeholder pode ir ao Git. Key real: preferir xcconfig local / CI e **restringir** no Cloud Console (a key ainda entra no IPA) |
| Flutter Directions (rota GPS) | `lib/features/gps/gps_screen.dart` | `--dart-define=GOOGLE_MAPS_API_KEY=...` via `RuntimeConfig` | Default placeholder. Chamada HTTP **é pulada** se ainda for placeholder (rota em linha reta) |
| Exemplo local | `android/local.properties.example` | Modelo sem valor real | Sim (só o exemplo) |

**Não** cole a key privada no Dart, no `AppDelegate` hardcoded, nem no Manifest em texto puro se puder usar placeholder + `local.properties` / dart-define / CI.

`COMO_COMPILAR.md` antigo pedia colar a key no Manifest e no `gps_screen.dart` — isso está **obsoleto**. Use os mecanismos acima.

---

## O que a Raiany precisa criar

1. [Google Cloud Console](https://console.cloud.google.com/) no mesmo projeto do Firebase staging (ou um projeto GCP ligado).
2. Ativar APIs:
   - **Maps SDK for Android**
   - **Maps SDK for iOS**
   - **Directions API** (usada no GPS para polyline/ETA)
   - (opcional) Places, Geocoding — **não ligar** se o app não usa
3. Criar **duas** keys (recomendado), ambas de staging:

### Key A — Apps móveis (SDK)

Restrições de aplicativo:

- Android: nome do pacote `br.com.servicoconecta` + SHA-1 do keystore **debug** e do **upload/release**.
- iOS: bundle `br.com.servicoconecta`.

Restrições de API: **somente** Maps SDK for Android e Maps SDK for iOS.

Uso: `MAPS_API_KEY` (Android) e `GMSApiKey` (iOS).

### Key B — Directions (HTTP do app)

O app chama `https://maps.googleapis.com/maps/api/directions/json?key=...` do dispositivo. Essa key **será visível**. Mitigação:

- Restrição de API: **somente Directions API**.
- Restrição de app: Android package+SHA-1 e iOS bundle (o Google aplica no SDK; para HTTP puro a restrição de app às vezes não pega — nesse caso use **cota baixa** + monitoramento de billing).
- Callable `getDirections` existe (BLOCO E) e recusa se `GOOGLE_MAPS_SERVER_KEY` estiver vazia. **Não chama** a API Google mesmo com key (evita cobrança). GPS no client permanece até a Raiany criar a key de servidor e autorizar o proxy.

Uso: `--dart-define=GOOGLE_MAPS_API_KEY=<key B>`.

**Não** use a mesma key irrestrita para Maps + Directions + Places + billing aberto.

---

## Onde colar (sem commit de secret)

```bash
# android/local.properties  (gitignored)
MAPS_API_KEY=AIza...   # Key A

# iOS: substituir o placeholder em Info.plist GMSApiKey, ou injetar via CI
# Flutter (Directions)
flutter run \
  --dart-define=GOOGLE_MAPS_API_KEY=AIza...   # Key B
```

Billing: ativar faturamento no GCP (obrigatório para Maps). Definir **quota alerts** e teto diário. Staging: cotas baixas.

---

## Como testar

1. Sem key: mapa pode ficar cinza; GPS **não quebra** — usa linha reta e log `Directions: GOOGLE_MAPS_API_KEY placeholder`.
2. Com Key A: mapa carrega em dispositivo/emulador com Play Services (Android) / simulador iOS.
3. Com Key B: polyline e ETA reais na tela GPS (`lib/features/gps/gps_screen.dart`).
4. Key errada / API não ativada: fallback de linha reta (já tratado).
5. Verificar no Cloud Console → Credentials que as restrições de pacote/bundle batem com `br.com.servicoconecta`.

---

## Não fazer

- Não commitar key real em `AppDelegate.swift`, Manifest ou Dart.
- Não usar key de produção no staging.
- Não deixar key **sem restrição**.
- Não ativar billing irrestrito sem alerta.
- Não mudar `applicationId`/`bundleId` sem atualizar as restrições da key (ver `IDENTIDADE_TECNICA.md`).
