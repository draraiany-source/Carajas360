# CARAJAS360 — Relatorio Fase 5 (Homologacao) — ESTADO REAL

**Data:** 2026-09-23
**Branch:** release/carajas360-rc1
**Commit base:** 4155283 (Fase 4)
**STATUS:** Homologacao INCOMPLETA / PARCIAL

## Gate Fase 5 (honesto)

**YELLOW HOMOLOGACAO PARCIAL**

Codigo financeiro/seguranca unitario OK. Artefato Android RC1 e E2E device/gateway NAO concluidos.

## Evidencias

| Item | Status |
|------|--------|
| Node tests | PASS 99 (reconfirmado) |
| Flutter tests | PASS 131 / 1 skip |
| Analyze errors | PASS 0 (apos fix wallet) |
| Build APK release | FAIL / NOT COMPLETE (Gradle JVM crash F4; retry F5 interrompido) |
| Device Android | NOT TESTED — DEVICE REQUIRED |
| Pagamento Sandbox integrado | NOT TESTED — secrets ABSENT |
| iOS | NOT TESTED — macOS/Xcode |
| Contas teste Auth | NOT CREATED — Firebase real |

## P0/P1

- P0 codigo: 0
- P1: BUG-F5-001 build Android (bloqueador de artefato)
- Demais P1 seg/fin codigo: 0

Ver CARAJAS360_HOMOLOGACAO_RC1_MATRIX.md e CARAJAS360_HOMOLOGACAO_BUGS.md.