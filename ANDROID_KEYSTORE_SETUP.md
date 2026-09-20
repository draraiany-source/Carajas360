# Android — keystore de upload (setup seguro)

**Nunca commitar** `.jks`, senhas ou `android/key.properties` (já no `.gitignore`: `*.jks`, `key.properties`).

## Modelo

Copie `android/key.properties.example` → `android/key.properties`:

```properties
storePassword=SUA_SENHA_FORTE
keyPassword=SUA_SENHA_FORTE
keyAlias=upload
storeFile=upload-keystore.jks
```

## Gerar keystore (Play Store)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## Staging interno (opcional, só dev)

```bash
keytool -genkey -v -keystore android/upload-keystore-staging.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload -storepass stagingOnlyChangeMe -keypass stagingOnlyChangeMe -dname "CN=Carajas360 Staging, OU=Dev, O=Carajas360, L=SP, ST=SP, C=BR"
```

## Build

```bash
flutter build appbundle --release
```

Sem `key.properties`, release **falha de propósito**. Ver `ANDROID_RELEASE_CHECKLIST.md`.
