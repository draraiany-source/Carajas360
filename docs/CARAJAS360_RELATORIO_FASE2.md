# CARAJAS360_RELATORIO_FASE2.md

**Data:** 2026-09-22
**Ambiente:** Homologacao / Sandbox
**Producao:** NAO ativada · NAO publicada
**Checkpoint pre-fase2:** `30c6d97`
**Base Fase 1:** `7146541`

---

## 1. Resumo executivo

A Fase 2 liga o marketplace da Fase 1 ao fluxo de monetizacao **sobre o stack existente** (carteira, Mercado Pago Sandbox, comissao 8%, escrow, Resolve/propostas), sem recriar o projeto e sem pagamentos reais.

**STATUS DA FASE 2: amarelo — PRONTO PARA FASE 3 / AUDITORIA FINAL**

Motivo do amarelo (nao verde producao):
- Webhook que **aplica** credito/PRO/destaque em ambiente com token MP ainda depende de `PAYMENTS_ENABLED=true` + secrets do owner.
- Split nativo Asaas nao existe (comissao continua no payout interno — stack MP preservado).
- E2E nativo Android/iOS e deploy homolog pendentes de execucao manual.

---

## 2. Estado encontrado da Fase 1

Completo: taxonomia remota, busca universal, matching anti-bleed, marketplace questionario.
Pendente herdado: anexos ricos, unificar Categories const, E2E nativo.

## 3. Auditoria monetizacao pre-Fase 2

| Peca | Estado |
|------|--------|
| Carteira / ledger | Existia |
| MP PIX/cartao callables | Existia (off sem PAYMENTS_ENABLED) |
| Comissao 8% + escrow | Existia |
| Planos requestPlanChange | Existia (charged=false) |
| Unlock lead / pacotes credito | **Faltava** |
| Destaques pagos | **Faltava** |
| Asaas split | Nao existe (nao reinventado) |

## 4. Funcionalidades concluidas (codigo + UI + teste unitario)

- Oportunidades para voce (cards + filtros + seed homolog)
- Detalhe: Desbloquear contato vs Enviar proposta (explicado)
- Unlock idempotente (prefs homolog + CF `unlockLeadContact`)
- Proposta profissional (valor, prazo, materiais, validade)
- Comparacao de propostas (Fase 1/Resolve) mantida
- MoneyCents + CommissionSplit (centavos)
- MonetizationConfig (flags + precos Admin)
- Pacotes de credito (Sandbox)
- Carajas PRO (preco Admin, status ACTIVE/CANCELLED homolog)
- Destaques 24h/7d/30d + selo PATROCINADO
- Carteira: atalhos Creditos / PRO
- Admin: label comissao corrigido; validacao commissionRate 0–30%
- Disputas: Ajuda com este servico + ticket
- Cloud Functions: unlockLeadContact, purchaseCreditPackage, purchaseHighlight
- Seed oportunidades homolog (`hrq_opp_*`)
- Colecoes: leadUnlocks, disputes (+ creditPurchases/highlightPurchases no backend)

## 5. Parcialmente concluidas

- Pagamento Sandbox E2E com webhook aplicando credito: **PENDENTE DE CONFIGURACAO DO PROPRIETARIO** (`PAYMENTS_ENABLED`, token MP TEST-)
- Split gateway nativo: nao aplicavel no stack atual (payout interno)
- Notificacoes push para todos os eventos: parcialmente via fluxos existentes
- Dashboard financeiro Admin (cards extras receita PRO/creditos/destaques): parcial (base + comissao corrigida)
- Feature flags no Admin UI visual completa: modelo pronto via platformConfig; toggles UI parciais
- Avaliacoes criterios extras / antifraude avancado: base reviews existente
- Testes E2E A–F automatizados: cobertos em unitario + fluxos homolog manuais documentados

## 6. Arquivos alterados / criados

### Criados
- lib/core/monetization/money.dart
- lib/core/monetization/monetization_config.dart
- lib/core/monetization/lead_unlock_service.dart
- lib/features/monetization/opportunities_screen.dart
- lib/features/monetization/monetization_screens.dart
- test/monetization_phase2_test.dart
- docs/CARAJAS360_RELATORIO_FASE2.md (este)

### Modificados
- lib/shared/models/models.dart (Wallet credits; ResolveRequest campos oportunidade)
- lib/shared/services/firestore_facade.dart (oportunidades seed, dispute, config validation)
- lib/core/constants/app_constants.dart (rotas/colecoes)
- lib/main.dart (rotas monetizacao)
- lib/features/wallet/wallet_screen.dart (atalhos)
- lib/features/admin/admin_screen.dart (label comissao)
- functions/index.js (unlockLeadContact, purchase*)

## 7. Migrations / banco

Sem migration destrutiva. Novas colecoes (criadas sob demanda):
- `leadUnlocks` (docId = `{uid}_{requestId}`)
- `disputes`
- `creditPurchases` / `highlightPurchases` (backend)
- Campos opcionais em `wallets`: credits, creditsUsed, creditsPurchased, creditsPromotional
- Campos opcionais em `resolveRequests`: neighborhood, budgetMin/Max, slotsRemaining, photoUrls
- `config/platform`: flags monetizacao + proPriceCents + defaultLeadCreditCost

## 8. Endpoints criados

- `unlockLeadContact` (callable) — custo server-side, idempotente
- `purchaseCreditPackage` (callable) — pending_sandbox sem aplicar credito
- `purchaseHighlight` (callable) — pending_sandbox

## 9. Fluxos

### Creditos
Carteira → Comprar pacote → Sandbox → (homolog) adiciona creditos apos confirmacao simulada / (prod-ready) so apos webhook.

### Unlock
Oportunidade → confirmar custo Admin → debitar creditos → leadUnlocks → contato aproximado.
Re-unlock: 0 cobranca.

### Proposta protegida
Enviar proposta → cliente compara → aceita → pagamento Sandbox existente → comissao OrderPolicy 8% (ou Admin) → payout.

### Comissao / split interno
MoneyCents + CommissionSplit; server orderPolicy.js permanece fonte de verdade do payout.

### PRO / Destaque
Telas + requestPlanChange / purchaseHighlight; ativacao plena apos confirmacao backend.

## 10. Testes executados

```
flutter test test/monetization_phase2_test.dart test/universal_search_phase1_test.dart
```

**Resultado: PASSED** (monetizacao + regressao Fase 1 busca/taxonomia).

Evidencias: saida do test runner local 2026-09-22.

## 11. Problemas / vulnerabilidades

Corrigidos / mitigados:
- Custo de lead nao aceito do client (CF ignora amount do app)
- Unlock idempotente
- Credito client-side ja bloqueado (mantido)
- commissionRate validado 0–30% no updatePlatformConfig
- Label Admin 15% → config real

Pendentes (owner):
- Ativar Sandbox MP com secrets
- Deploy Functions + regras Firestore para leadUnlocks/disputes
- PDF do relatorio (markdown entregue; PDF se ferramenta disponivel)

## 12. Variaveis de ambiente necessarias (owner)

- `PAYMENTS_ENABLED=true` (somente homolog)
- `MERCADOPAGO_ACCESS_TOKEN` (TEST-)
- `MERCADOPAGO_WEBHOOK_SECRET` (se HMAC)
- Nunca versionar secrets

## 13. Checklist homologacao

- [ ] Deploy Functions unlockLeadContact
- [ ] Regras Firestore leadUnlocks (somente dono ler/escrever via CF)
- [ ] Token MP TEST + PAYMENTS_ENABLED em staging
- [ ] Testar unlock com saldo insuficiente
- [ ] Testar double-tap unlock (idempotencia)
- [ ] Testar proposta → aceite → payOrder Sandbox
- [ ] Testar compra creditos + webhook
- [ ] Android / iOS / web responsivo
- [ ] Voltar em todas as telas novas

## 14. Checklist publicacao

- [ ] Auditoria final Fase 3
- [ ] PAYMENTS_ENABLED revisado
- [ ] Sem placeholders Firebase
- [ ] Secrets producao separados
- [ ] NAO publicar ate aprovacao explicita

## 15. Contas de teste

**PENDENTE DE CONFIGURACAO DO PROPRIETARIO** — nao versionar senhas.
Sugerido criar no Auth homolog: cliente, pro free, pro PRO, admin (sem commits de secrets).

---

## STATUS DA FASE 2

**PRONTO PARA FASE 3 / AUDITORIA FINAL**

Nao pronto para producao.
