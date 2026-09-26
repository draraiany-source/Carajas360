# CARAJAS360 - GO / NO-GO (Fase 7)

**Decisao:** **YELLOW — CONFIG EXTERNAS** (apto parcial)  
**Status line:** 🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES  
**Data:** 2026-09-24  
**Branch:** `release/carajas360-rc1` @ `1c47a74` (working tree com mudancas F7)  
**VERSION:** 1.0.0+402  
**RELEASE FREEZE:** ACTIVE  
**PAYMENTS:** OFF  
**Piloto:** PILOTO BLOQUEADO — nao iniciar

## Resumo da decisao

AAB/APK **PASS** e pagamentos **OFF** no codigo. **Nao** ha GO verde para teste fechado enquanto:

- privacy/terms **live** permanecerem **404** (fix codigo READY; deploy externo pendente);
- DEVICE E2E / MAIN E2E **NOT TESTED** (DEVICE REQUIRED);
- configs Firebase prod / App Check / DNS / sandbox MP / iOS permanecerem EXTERNAL.

## Tabela GO / NO-GO

| ITEM | STATUS | EVIDENCIA | BLOQUEADOR | RESPONSAVEL |
|------|--------|-----------|------------|-------------|
| VERSION 1.0.0+402 | PASS | pubspec / build | — | Programador |
| COMMIT HEAD 1c47a74 | PASS | git HEAD (+ working tree F7) | — | Programador |
| RELEASE FREEZE ACTIVE | PASS | `CARAJAS360_RELEASE_FREEZE.md` | — | Programador / Produto |
| PAYMENTS OFF | PASS | flags codigo OFF | Nao ativar | Programador |
| flutter analyze (prior) | PASS (0 errors; 83 warn; 78 info) | prior + fixes mounted monetization/opportunities | Warnings residuais nao bloqueiam F7 | Programador |
| flutter test (prior) | PASS 134 / SKIP 1 / FAIL 0 | prior | — | Programador |
| npm test Functions (prior) | PASS 115 / FAIL 0 | prior | — | Programador |
| APK release | PASS | path + size 81900337 + SHA256 C27C2994…EC7CDB3F; `docs/evidence/fase7_android_build.md` | — | Programador |
| AAB release | PASS | path + size 76950847 + SHA256 F3A9D135…0AE74C2; `docs/evidence/fase7_android_build.md` | — | Programador |
| Privacy/Terms codigo+config | FIXED / READY | `firebase.json` public=hosting; `docs/evidence/fase7_hosting_privacy_fix.md` | Deploy pendente | Programador (fix) / Proprietaria (deploy) |
| Privacy/Terms URL live | FAIL (404) | live URL ate deploy | `firebase deploy --only hosting` | Proprietaria |
| DEVICE E2E | NOT TESTED | flutter devices: Windows/Chrome/Edge; adb nao PATH | DEVICE REQUIRED | Proprietaria + Programador |
| MAIN E2E client→pro | NOT TESTED | — | DEVICE REQUIRED | Proprietaria + Programador |
| SANDBOX E2E (MP TEST) | EXTERNAL CONFIG REQUIRED | token/webhook nao confirmados no env | Config MP TEST | Proprietaria + Programador |
| FIREBASE PROD / App Check | EXTERNAL CONFIG REQUIRED | `CARAJAS360_FIREBASE_PROD_PREP.md` | Config externa | Proprietaria |
| DNS MX carajas360.com.br | EXTERNAL CONFIG REQUIRED | `CARAJAS360_DNS_CHECKLIST.md`; AppInfo emails | MX suporte@ / privacidade@ | Proprietaria |
| iOS | NOT TESTED | `CARAJAS360_IOS_CHECKLIST.md` | macOS + Xcode | Programador (Mac) |
| BACKUP | DOC ONLY / PARTIAL | docs | Backup operacional incompleto | Proprietaria + Programador |
| ROLLBACK | DOCUMENTED | `CARAJAS360_INCIDENT_RESPONSE.md` | — | Programador / Operacoes |
| MONITORING Crashlytics release | NOT TESTED | Crashlytics no app; sem install release validado | Install + evento teste | Programador |
| Teste fechado GO | FAIL / NAO INICIADO | planos preparados | Privacy live 404 + device E2E | Ambos |
| Piloto | BLOQUEADO | `CARAJAS360_PLANO_PILOTO.md` | Exige GO teste fechado | Produto |

## Decisao consolidada

**F7 GO_NO_GO = YELLOW CONFIG EXTERNAS**

Apto parcial para preparacao (artefato existe, pagamentos OFF). **Nao** autorizar ainda:

- Teste fechado como **GO** formal (falta hosting live + E2E device).
- Distribuicao piloto / usuarios reais de piloto.
- Upload Play Store como release publica.
- Ativacao de pagamentos reais / PRODUCTION_PAYMENTS.

## Acoes minimas antes de reavaliar GREEN (teste fechado)

1. `firebase deploy --only hosting` e verificar privacy/terms HTTP 200.
2. Device Android + install APK/AAB RC e E2E conforme roteiro (sem pagamento real).
3. Registrar evidencias; nova rodada GO/NO-GO — nao presumir GREEN automatico.

## Assinaturas

| Papel | Nome | Data | Decisao |
|-------|------|------|---------|
| Produto | _pendente_ | | YELLOW |
| Engenharia | _pendente_ | | YELLOW |
| Operacoes | _pendente_ | | YELLOW |

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
