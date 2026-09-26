# CARAJAS360 - Checklist iOS (prep para Mac / Xcode)

**STATUS F7:** **NOT TESTED** — requer **macOS + Xcode**  
**VERSION alvo:** 1.0.0+402 (alinhar FLUTTER_BUILD_NAME/NUMBER ao pubspec quando buildar)  
**Bundle ID (AppInfo):** `br.com.carajas360`  
**Firebase project:** `carajas360-a17c5`  
**PAYMENTS:** OFF — nao ativar no TestFlight como cobranca real  
**Publicacao App Store:** **NAO** nesta fase

Este documento e **preparacao**. Nao inventar Team ID, provisioning, APNs key ou secrets no Git.

## 1. Ambiente

- [ ] Mac com Xcode atualizado
- [ ] CocoaPods / `pod install` no `ios/`
- [ ] Conta Apple Developer (EXTERNAL — proprietaria/operacao)
- [ ] Confirmar se `ios/Runner.xcodeproj` / `.xcworkspace` existem no ambiente de build (podem estar ausentes no Git — restaurar com cuidado)

## 2. Identidade

- [ ] Display name Carajas 360
- [ ] `PRODUCT_BUNDLE_IDENTIFIER` = `br.com.carajas360`
- [ ] App iOS registrado no Firebase Console para o mesmo bundle (EXTERNAL)
- [ ] `GoogleService-Info.plist` **real** (nao placeholder) — baixar do Console; **nao** commit secrets desnecessarios

## 3. Assinatura / distribuicao

- [ ] Team ID / provisioning profiles (fora do Git)
- [ ] Archive no Xcode
- [ ] Upload TestFlight (internal) apenas apos privacy/terms live OK
- [ ] Export compliance / criptografia conforme pergunta Apple (definir com operacao)

## 4. Permissoes (Info.plist)

Validar textos de localizacao, camera, fotos, microfone antes do review. Adicionar keys extras so se o app usar o recurso.

## 5. Qualidade

- [ ] Smoke install em dispositivo iOS fisico
- [ ] Login / navegacao basica (espelhar roteiro Android **sem pagamento real**)
- [ ] Links privacy/terms HTTP 200
- [ ] Crashlytics: evento de teste apos install — hoje **NOT TESTED** no Android release; repetir no iOS quando houver build

## 6. Bloqueios conscientes F7

| Item | Status |
|------|--------|
| Build/Archive | NOT TESTED |
| TestFlight | NAO |
| App Store producao | NAO |
| Pagamentos | OFF |

## 7. Referencia adicional

Checklist legado de prep: `IOS_RELEASE_CHECKLIST.md` na raiz (alinhar numeros de versao ao 402 ao executar).

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
