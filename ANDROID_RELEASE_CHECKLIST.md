# Android — checklist de release (prep only)

**Não é um release final.** Não gera AAB/APK assinado neste bloco.  
**Não criar keystore neste repositório.** A Raiany gera o upload keystore **fora do Git**.

Restrições: sem Play Store, sem pagamento real, sem inventar secrets.

| Campo | Valor atual no repo |
|---|---|
| Display name | Carajás 360 (`android/app/src/main/res/values/strings.xml`) |
| `applicationId` / `namespace` | `br.com.servicoconecta` |
| Pacote Dart | `servico_conecta` |
| Firebase `project_id` | `servicoconecta` |
| `versionName` / `versionCode` | `1.0.0` / `1` (`pubspec.yaml` `1.0.0+1`) |
| `minSdk` / `targetSdk` / `compileSdk` | via Flutter SDK (CI: Flutter stable) |
| `minifyEnabled` / `shrinkResources` | `true` no `release` |
| ProGuard | `android/app/proguard-rules.pro` |
| Ícone | `@mipmap/ic_launcher` (sem adaptive icon `anydpi-v26`) |
| Splash | `drawable/launch_background.xml` + `splash_logo.png` |
| Cleartext | `usesCleartextTraffic=false` |

## 1. Identidade (não mudar sem migração Firebase)

- [ ] Confirmar `applicationId` = `br.com.servicoconecta` (já está).
- [ ] **Não** trocar para `br.com.carajas360` sem projeto Firebase novo + SHA.
- [ ] `google-services.json` no repo ainda é **placeholder** (`project_number` `000000000000`, key `COLE_SUA_…`). A Raiany baixa o arquivo real do Console e **não** commita se a política for secretar.

## 2. Keystore / signing (Raiany, local)

- [ ] Gerar **uma vez**, na máquina da Raiany (não no CI, não no Git):
  `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Copiar `android/key.properties.example` → `android/key.properties` (já no `.gitignore`).
- [ ] Preencher `storeFile`, `storePassword`, `keyPassword`, `keyAlias`.
- [ ] Guardar backup offline do `.jks`. Perda = app não atualiza na Play.
- [ ] `signingConfigs.release` só existe se `key.properties` estiver presente. Sem arquivo, `assembleRelease`/`bundleRelease` **falha de propósito** (não assina com debug).
- [ ] **Este agente não cria keystore nem senhas.**

## 3. ProGuard / R8

- [ ] Release já tem minify + shrink.
- [ ] Revisar `proguard-rules.pro` após o primeiro AAB (Firebase, Maps, Sign-In).
- [ ] Testar um build release **interno** antes de qualquer Play.

## 4. Ícones e splash

- [ ] Conferir `ic_launcher` em todos os densidades.
- [ ] (Opcional) adaptive icon `mipmap-anydpi-v26`.
- [ ] Splash azul/verde + logo — validar em aparelho real.

## 5. Versão

- [ ] Antes do primeiro AAB interno: bump `pubspec.yaml` (`1.0.0+N`).
- [ ] `versionCode` deve **só aumentar**.
- [ ] `AppInfo.version` em `lib/core/constants/app_constants.dart` deve acompanhar o nome.

## 6. Permissões (`AndroidManifest.xml`)

Já declaradas: `INTERNET`, `ACCESS_FINE/COARSE_LOCATION`, `CAMERA`, `RECORD_AUDIO`, `READ_MEDIA_IMAGES`, `VIBRATE`, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`.

- [ ] Justificar cada uma na ficha de privacidade da Play.
- [ ] Microfone hoje só para stub de voz/vídeo (não implementar chamada neste bloco).

## 7. Privacidade

- [ ] Texto in-app: `LegalScreen` + `privacidade@servicoconecta.com.br`.
- [ ] **Falta URL pública** da política (Play exige link). A Raiany publica (site/Notion) — **não inventar domínio**.
- [ ] Data safety: localização, fotos, notificações, dados de conta.

## 8. Target SDK / Play

- [ ] Usar Flutter stable do CI; conferir `targetSdk` ≥ exigência Play do ano.
- [ ] AGP `8.11.1`, Gradle `8.14.3`, Java 17 — já no repo.

## 9. AAB (quando a Raiany for gerar, não agora)

```bash
# Só com key.properties real, local:
flutter build appbundle --release \
  --dart-define=GOOGLE_MAPS_API_KEY=CHAVE_RESTRITA
```

- [ ] **Não** rodar no agente / CI deste PR.
- [ ] Upload em **testes internos** da Play, não produção.

## 10. Play Integrity / App Check

- [ ] `APP_CHECK_ENABLED=false` e `ENFORCE_APP_CHECK=false` até keys reais.
- [ ] Sem `firebase_app_check` no `pubspec` ainda.
- [ ] Play Integrity + SHA-1/256 do **upload** e do **App signing** (Play Console) — depois do primeiro AAB interno.
- [ ] **Não** ligar enforce neste bloco.

## 11. Maps / Firebase

- [ ] `MAPS_API_KEY` em `android/local.properties` (exemplo no repo; arquivo real no `.gitignore`).
- [ ] Restringir key Android por `applicationId` + SHA.
- [ ] Directions HTTP no client ainda usa `--dart-define`. Callable servidor: ver `BLOCO_F.md` (key de servidor ausente).

## 12. Testes internos (gate)

- [ ] Login / logout / unauth.
- [ ] Pedido + estados (sem pagamento real).
- [ ] Perfil, endereço, chat com CTA.
- [ ] Release: `DemoData.allow == false`.
- [ ] Crashlytics recebe um crash de teste **só em build interno**.

## Parado de propósito

- Publicar na produção da Play.
- Criar ou versionar keystore / `key.properties`.
- Ligar `PAYMENTS_ENABLED`.
