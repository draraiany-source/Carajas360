# CARAJAS360 - Firebase Producao (prep EXTERNAL)

**STATUS:** **EXTERNAL CONFIG REQUIRED**  
**Project ID (AppInfo):** `carajas360-a17c5`  
**F7:** sem deploy de producao nesta sessao; pagamentos **OFF**; Fase 8 **nao** iniciada  
**Regra:** **nenhum secret** (API keys privadas, service accounts, tokens MP) neste arquivo ou commit.

## 1. Objetivo

Checklist operacional para endurecer/alinhar Firebase antes de tracks fechados/piloto — **prep only**.

## 2. Projetos e apps

- [ ] Confirmar projeto Firebase ativo e billing/quotas sob conta da proprietaria
- [ ] Apps registrados: Android `br.com.carajas360`, iOS `br.com.carajas360` (iOS EXTERNAL/Mac)
- [ ] `google-services.json` / `GoogleService-Info.plist` corretos no ambiente de build (nao colar secrets aqui)

## 3. Authentication

- [ ] Providers habilitados apenas os usados (e-mail, Google, etc.)
- [ ] Dominios autorizados alinhados
- [ ] Revisar usuarios teste vs producao (sem misturar dados reais cedo demais)

## 4. Firestore / Storage / Rules

- [ ] Rules de seguranca revisadas (auditoria separada)
- [ ] Indexes necessarios deployados
- [ ] Storage rules para uploads de perfil/chat

## 5. Hosting (bloqueador F7 live)

- [x] Codigo: `firebase.json` `public=hosting` + privacy/terms reais (fix F7)
- [ ] **EXTERNAL:** `firebase deploy --only hosting`
- [ ] Verificar HTTPS 200 em `/privacy` e `/terms`
- [ ] (Opcional) Custom domain carajas360.com.br — ver DNS checklist

## 6. App Check

- [ ] Decidir provedor (Play Integrity / DeviceCheck / debug tokens so em dev)
- [ ] Registrar apps e ativar enforcement gradualmente
- [ ] **NOT DONE** na F7 — EXTERNAL

## 7. Crashlytics / Monitoring

- [ ] Crashlytics SDK presente no app
- [ ] **NOT TESTED** em install do artefato release F7
- [ ] Apos install RC: forcar/nao-fatal de teste em build interno e confirmar no Console

## 8. Cloud Functions

- [ ] Ambiente / secrets via Secret Manager ou config **fora do Git**
- [ ] Webhooks MP: URL e token **TEST** vs PROD claramente separados
- [ ] SANDBOX E2E: **EXTERNAL CONFIG REQUIRED** (token TEST / webhook nao confirmados)
- [ ] Manter flags de pagamento **OFF** ate plano financeiro

## 9. Backup

- [ ] Politica de export/backup Firestore (DOC ONLY / PARTIAL na F7)
- [ ] Quem executa, frequencia, retencao — definir com proprietaria

## 10. Rollback

Ver `CARAJAS360_INCIDENT_RESPONSE.md` (kill switch financeiro, tracks Play, nao apagar historico).

## 11. O que NAO fazer nesta prep

- Nao habilitar PRODUCTION_PAYMENTS / pagamentos reais
- Nao iniciar piloto
- Nao comitar `.env`, JSON de service account, tokens
- Nao declarar PASS de App Check / DNS / E2E sem evidencia

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
