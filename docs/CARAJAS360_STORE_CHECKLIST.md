# CARAJAS360 - Checklist Loja (Play / preparacao)

**VERSION:** 1.0.0+402  
**Branch:** `release/carajas360-rc1` @ `1c47a74`  
**Publicacao:** NAO — F7 YELLOW  
**PAYMENTS:** OFF  

## Android (Google Play)

| Item | Status F7 | Notas |
|------|-----------|-------|
| AAB release assinado | **PASS** | `app-release.aab` 76950847 bytes; SHA256 F3A9D135…0AE74C2 |
| APK release | **PASS** | opcional sideload; SHA256 C27C2994…EC7CDB3F |
| versionCode 402 alinhado | Planejado / build feito | Sem binario entregue a store ainda |
| Politica de privacidade URL | **FAIL live (404)** | Fix codigo READY; deploy hosting pendente |
| Termos / delete account flow | Revisar no app + URL | URL termos 404 ate deploy |
| Data safety form | Rascunho — ver matriz | `CARAJAS360_PRIVACY_DATA_MATRIX.md` |
| Content rating questionario | Pendente | |
| Target API / 64-bit | Verificar no Gradle ao buildar | Build F7 gerado |
| Internal testing track | **Nao usar** ate privacy live + GO | |
| Production track | **NAO** | |

## iOS (App Store)

| Item | Status F7 |
|------|-----------|
| Build IPA | NOT TESTED (ambiente Windows) |
| App Privacy | Pendente |
| Publicacao | **NAO** |

Ver `CARAJAS360_IOS_CHECKLIST.md`.

## Conteudo listing

Ver `CARAJAS360_PLAY_STORE_CONTENT.md` — texto honesto, sem prometer pagamentos ou piloto ativo.

## Financeiro na loja

- Declarar que compras in-app / pagamentos reais **nao** estao ativos na versao RC atual.
- Nao marcar app como com "compras" ate ativacao aprovada.

## Gate

Loja **bloqueada** ate: URLs legais live OK + decisao GO documentada + (recomendado) teste fechado executado.

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
