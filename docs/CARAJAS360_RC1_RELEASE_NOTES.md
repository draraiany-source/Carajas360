# CARAJAS360 RC1 — Release Notes

**Versao:** 1.0.0-rc1 (build 401)
**Data:** 2026-09-22
**Branch:** release/carajas360-rc1
**Base Fase 3:** a2ad7ef / backup pre-fase4 43dae2c

## Principais correcoes
- Webhook MP: caminho de aplicacao idempotente por eventId (PAYMENTS_ENABLED gate)
- Saque: pending_manual_payout (sem PIX automatico)
- Comissao: isencao direct_contact / commissionExempt; snapshot commissionRate/Base/Amount
- Emails de contato: @carajas360.com.br
- Consentimento OAuth no login (dialogo)
- Rules: withdrawalRequests + webhookEvents
- Rate limit unlock lead

## Funcionalidades incluidas (homolog)
- Marketplace / Servicos / Locacao / Creditos / PRO / Admin financeiro (Fases 1–2)
- Modo HomologCatalog com placeholders Firebase

## Limitacoes RC1
- PAYMENTS_ENABLED=false por padrao (sem dinheiro real)
- Firebase client ainda com COLE_SUA_* ate CONFIG EXTERNA
- App Check off ate decisao do owner
- E2E device Android/iOS majoritariamente NOT TESTED nesta sessao
- ROTATION_REQUIRED=false (nenhum secret de producao encontrado no Git)

## Pendencias conhecidas
Ver CARAJAS360_RC1_PENDENCIAS.md