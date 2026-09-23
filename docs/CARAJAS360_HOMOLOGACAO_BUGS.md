# CARAJAS360 — Homologacao Bugs (Fase 5)

## BUG-F5-001
- Severidade: P1 (bloqueia artefato RC1)
- Tela/Area: Build Android release
- Passos: flutter build apk --release
- Esperado: APK gerado
- Obtido (F4): Gradle daemon disappeared / JVM hs_err
- Evidencia: build_rc1_apk.log
- Correcao: gradle.properties heap/workers; minifyEnabled false em release homolog (app/build.gradle)
- Reteste: em andamento nesta sessao
- Status: EM CORRECAO

## BUG-F5-002
- Severidade: P2
- Tela: wallet_screen.dart:78
- Passos: flutter analyze
- Esperado: sem error
- Obtido: const bal com valor nao-constante
- Correcao: final bal = ...
- Reteste: analyze2 HAS_ERRORS=0
- Status: CORRIGIDO (working tree, pendente commit)

## Sem bugs de fluxo device
Device E2E nao executado — DEVICE REQUIRED. Nao inventar FAIL/PASS de UI.