# iOS — preparação TestFlight (FASE 13)

**Ambiente desta máquina:** Windows — **não** gera IPA aqui.  
**Bundle ID:** `br.com.carajas360`  
**Projeto:** `ios/Runner.xcworkspace`

## Requisitos externos

| Item | Obrigatório |
|------|-------------|
| macOS com Xcode 15+ | Sim |
| Conta Apple Developer (pago) | Sim para TestFlight |
| Certificado Distribution + Profile | Sim |
| CocoaPods (`pod install`) | Sim |

## Passos (no Mac)

```bash
cd /caminho/CARAJAS360
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release
# Ou: abrir ios/Runner.xcworkspace → Product → Archive → Distribute → TestFlight
```

## Checklist Info.plist (já no repo)

- `CFBundleIdentifier` = `br.com.carajas360`
- `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`
- Ícones em `ios/Runner/Assets.xcassets`

## Não afirmar

Sem arquivo `.ipa` gerado nesta sessão Windows, **IPA = não gerado**.
