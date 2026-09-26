# CARAJAS360 — Pendencias Externas

**Branch:** `fix/correcao-completa-final`  
**Version:** `1.0.0+402`  
**Escopo:** somente dependencias externas (fora do codigo ja corrigido)  
**Status codigo:** 🟡 CÓDIGO CORRIGIDO — DEPENDÊNCIAS EXTERNAS PENDENTES

Este documento lista **apenas** itens externos. Correcoes de codigo ja aplicadas nao entram aqui.

---

## 1. Hosting deploy

| Item | Detalhe |
|------|---------|
| Acao | `firebase deploy --only hosting` (autenticacao owner) |
| Paginas prontas | privacy, terms, account-deletion, support |
| Live atual | privacy ainda **404** |
| URL AppInfo | https://carajas360-a17c5.web.app/privacy |
| Bloqueio | URLs legais publicas obrigatorias para store / AppInfo |

---

## 2. Device E2E

| Item | Detalhe |
|------|---------|
| Status | **NOT TESTED** |
| Motivo | Requer dispositivo fisico / emulador com adb; ambiente atual insuficiente |
| Escopo tipico | fluxo cliente → profissional, chat, navegacao critica |

---

## 3. Mercado Pago sandbox secrets

| Item | Detalhe |
|------|---------|
| Status | **EXTERNAL** |
| Necessario | token TEST, webhook, secrets de sandbox fora do git |
| Nota | Payments de producao permanecem **OFF**; sandbox E2E nao substitui ativacao financeira |

---

## 4. Firebase producao / App Check

| Item | Detalhe |
|------|---------|
| Status | **EXTERNAL** |
| Itens | projeto/prod keys reais, App Check, HomologCatalog so com placeholders |
| Secrets | nenhuma private key no git — apenas placeholders |

---

## 5. DNS MX

| Item | Detalhe |
|------|---------|
| Status | **EXTERNAL** |
| Acao | configurar/validar registros MX do dominio operacional |
| Ref | checklist DNS do projeto |

---

## 6. Play Console

| Item | Detalhe |
|------|---------|
| Status | **EXTERNAL** |
| Artefato | AAB `build/app/outputs/bundle/release/app-release.aab` (SHA256 C13110A6…45FDC1) |
| Pendente | upload, listing, politicas, teste fechado na Console |

---

## 7. Apple / macOS

| Item | Detalhe |
|------|---------|
| Status | **NOT TESTED** / **EXTERNAL** |
| Motivo | requer macOS + Xcode + conta Apple Developer |
| iOS build/E2E | nao executados |

---

## 8. Backup operacional

| Item | Detalhe |
|------|---------|
| Status | **EXTERNAL** (operacional) |
| Nota | documentacao de incidente pode existir; execucao/rotina de backup e restore operacional ainda pendente |

---

## Ordem sugerida (externa)

1. `firebase deploy --only hosting` → validar privacy/terms/account-deletion/support live  
2. Device E2E no artefato APK `1.0.0+402`  
3. Configurar secrets sandbox MP (se for validar pagamentos em teste)  
4. Firebase prod + App Check  
5. DNS MX  
6. Play Console (AAB)  
7. Apple/macOS quando houver ambiente  
8. Backup operacional periodico  

**Nao fazer automaticamente:** push remoto, deploy sem owner, ativar payments em producao.