# Ambientes

O app não mistura homologação com produção. Não há chave real neste repositório.

| Ambiente | Como ligar | Firebase |
| --- | --- | --- |
| Local com demonstração rotulada | `flutter run -d chrome --dart-define=DEV_BYPASS_LOGIN=true` | Firebase desligado. A faixa amarela diz que os cartões são demonstração. Ignorado em release. |
| Emulador | `flutter run --dart-define=USE_FIREBASE_EMULATOR=true` ou chaves placeholder em debug | Auth 9099, Firestore 8080, Storage 9199, Functions 5001. Semente: `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 node functions/seed/homologacao.js` (recusa rodar sem o emulador). |
| Homologação | `--dart-define=APP_ENV=homolog` depois de gerar `lib/firebase_options.dart` do projeto de homologação | Projeto Firebase separado do de produção. Ainda não há arquivo de opções reais. |
| Produção | `--dart-define=APP_ENV=prod` e `flutterfire configure --project=carajas360-a17c5` | `firebase_options.dart` e `google-services.json` hoje ainda apontam para o placeholder `servicoconecta`. Não publicar assim. |

## Credenciais que continuam de fora

- Firebase do projeto `carajas360-a17c5` (`flutterfire configure`)
- `MERCADOPAGO_ACCESS_TOKEN` e `PAYMENTS_ENABLED=true` para cobrança real
- Opcional: `ASAAS_API_KEY` ou `PAGARME_API_KEY` (`PAYMENT_PROVIDER`)
- `GEMINI_API_KEY`, `OPENAI_API_KEY` ou `ANTHROPIC_API_KEY` no Secret Manager
- `WHATSAPP_TOKEN` e `WHATSAPP_PHONE_ID` (Cloud API)
- Google Maps, Sign-In e Apple

Nenhuma delas deve ir para o app. O gateway, sem credencial, responde `aguardando_credenciais` e não marca pagamento como aprovado.

## Build web

```bash
flutter build web --release --dart-define=APP_ENV=homolog
```

A saída fica em `build/web`. O deploy de homologação é feito fora desta máquina.
