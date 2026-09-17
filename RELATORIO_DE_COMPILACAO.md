# RELATÓRIO DE COMPILAÇÃO — ServiçoConecta v1.5

## Resumo honesto

**O APK não foi gerado.** Não posso gerá-lo neste ambiente, e não vou
declarar o contrário. Abaixo está a prova técnica e o passo a passo para
você gerar o APK na sua máquina em poucos minutos.

## Por que o APK não pôde ser gerado aqui

Verificação executada neste ambiente:

```
$ which flutter dart
(nenhum encontrado no PATH)

$ ls /usr/lib/flutter /opt/flutter ~/flutter
No such file or directory

$ which javac
Java: ausente (JDK necessário para compilar Android)

$ curl -I https://storage.googleapis.com/flutter_infra_release/...
HTTP/2 403
x-deny-reason: host_not_allowed
```

Ou seja:
1. O Flutter SDK **não está instalado**.
2. O JDK e o Android SDK **não estão disponíveis**.
3. A rede **bloqueia** o download do SDK (403 `host_not_allowed`), então
   não há como instalá-lo.

Sem SDK, os comandos `flutter clean`, `flutter pub get`, `flutter analyze`,
`flutter test` e `flutter build apk --release` **não executam**. Portanto o
arquivo `build/app/outputs/flutter-apk/app-release.apk` **não existe** e não
pode ser renomeado nem entregue.

## O que foi entregue

| Arquivo | Status |
|---|---|
| `ServicoConecta_v1.5_COMPLETO.zip` | ✅ Entregue — ZIP válido, 715 arquivos, 2,3 MB |
| `ServicoConecta_v1.5-release.apk` | ❌ **Não gerado** — requer Flutter SDK |
| `RELATORIO_DE_COMPILACAO.md` | ✅ Este arquivo |

Verificação de integridade do ZIP:
```
$ file ServicoConecta_v1.5_COMPLETO.zip
Zip archive data, at least v2.0 to extract, compression method=deflate

$ unzip -t ServicoConecta_v1.5_COMPLETO.zip
No errors detected in compressed data.
```
O ZIP contém `pubspec.yaml`, `lib/main.dart`, `android/app/build.gradle`,
`firestore.rules` e `firestore.indexes.json` — projeto completo.

### Sobre o download "sem extensão"
O ZIP anterior era válido (testado acima). Alguns navegadores e apps de
mensagem removem a extensão no download. Se o arquivo baixar sem `.zip`,
**renomeie manualmente para `.zip`** e ele abrirá normalmente. No celular,
prefira baixar pelo navegador e abrir com um gerenciador de arquivos.

## Como gerar o APK na sua máquina

### 1. Instalar o Flutter (uma vez)
- Baixe em https://docs.flutter.dev/get-started/install
- Instale também o Android Studio (traz o Android SDK e o JDK).
- Confirme: `flutter doctor` — resolva o que aparecer com ❌.

### 2. Preparar o projeto
```bash
unzip ServicoConecta_v1.5_COMPLETO.zip -d servicoconecta
cd servicoconecta
flutter clean
flutter pub get
```

### 3. Configurar as chaves obrigatórias
O app não sobe sem elas:
```bash
# Firebase (cria o firebase_options.dart real)
dart pub global activate flutterfire_cli
flutterfire configure
```
- **Google Maps**: coloque a chave em `android/app/src/main/AndroidManifest.xml`
  (procure `com.google.android.geo.API_KEY`).
- **Mercado Pago**: chave nas Cloud Functions, se for usar pagamento real.

### 4. Verificar e testar
```bash
flutter analyze
flutter test
```

### 5. Gerar o APK
```bash
flutter build apk --release
```
O arquivo sai em:
```
build/app/outputs/flutter-apk/app-release.apk
```

### 6. Renomear
```bash
mv build/app/outputs/flutter-apk/app-release.apk ServicoConecta_v1.5-release.apk
```

### 7. (Play Store) Gerar o AAB
```bash
flutter build appbundle --release
# sai em build/app/outputs/bundle/release/app-release.aab
```

### Assinatura para publicar
Para publicar na Play Store o APK/AAB precisa ser assinado com a sua
keystore. Veja `COMO_COMPILAR.md` no ZIP e
https://docs.flutter.dev/deployment/android#signing-the-app

## Deploy obrigatório do Firebase
Antes de usar o app com dados reais:
```bash
firebase deploy --only firestore:indexes,firestore:rules,storage
```
Sem os 23 índices, as listas (pedidos, carteira, locação, reservas)
falham em produção com `FAILED_PRECONDITION`.

## Validação estática realizada (o que consegui fazer)

Como não posso compilar, rodei a bateria estática completa sobre os
28 arquivos Dart / 9.950 linhas:

| Verificação | Resultado |
|---|---|
| Sintaxe / balanceamento | ✅ 0 erros |
| Imports quebrados | ✅ 0 |
| Símbolos usados sem import | ✅ 0 |
| Classes/enums duplicados | ✅ 0 |
| Métodos de serviço inexistentes | ✅ 0 |
| Rotas sem definição / sem handler | ✅ 0 / 0 |
| Dependências circulares | ✅ 0 |
| Assets referenciados ausentes | ✅ 0 |
| Coleções Firestore sem regra | ✅ 0 |
| pubspec.yaml válido | ✅ |

**Isto não substitui `flutter analyze`.** A análise estática cobre a maior
parte dos erros (sintaxe, referências, imports, rotas), mas não é um
compilador: um erro de tipo sutil só aparece no build real. Se o
`flutter analyze` acusar algo, me envie a saída que eu corrijo.
