# Carajás 360 — Relatório Fases 4–11 (Prompt Mestre)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Projeto:** `carajas360-a17c5`  
**Regra:** evidência de código; sem declarar comercialização; live/Functions/MP só com GO explícito.

Fases 1–3: ver `AUDITORIA_TELAS_CARAJAS360.md`, `RELATORIO_FASE2_ORGANIZAR_TELAS.md`, `RELATORIO_FASE3_TELA_POR_TELA.md`.

---

## FASE 4 — Fluxo completo do cliente

| Etapa | Evidência | Status |
|-------|-----------|--------|
| Home → Explorar → perfil | Rotas + CTAs reais | **Aprovado (código)** |
| Orçamento (`/request-service`) | `createOrder` + args guard | **Aprovado (código)** |
| Proposta Resolve → pedido | `acceptResolveProposal` CF + nav Meus pedidos | **Aprovado (código)** |
| Pagamento | `canPay` + callables; sem marcar pago só no UI | **Parcial** (gateway off) |
| Execução / GPS / conclusão / avaliação | Pedidos + reviews + GPS | **Parcial** |
| Anti-duplicata / status | `OrderPolicy` + CF transações | **Aprovado (código)** |

**Correções nesta leva:** aceite Resolve → `pushNamedAndRemoveUntil` Meus pedidos; perfil na proposta → `/provider-profile`; recusa sem fingir persistência.

---

## FASE 5 — Fluxo do profissional

| Etapa | Status |
|-------|--------|
| Cadastro / onboarding / aprovação admin | **Aprovado (código)** |
| Perfil público + online/offline | **Aprovado (código)** |
| Receber pedidos / aceitar com preço | **Aprovado (código)** |
| Enviar proposta Resolve | **Aprovado (código)** |
| Lista sem pedidos fictícios | **Corrigido** (removido `DemoData` em Provider Home) |
| Só dados autorizados | Regras + streams provider | **Aprovado (código)** |

---

## FASE 6 — Pagamentos e comissões

| Item | Status |
|------|--------|
| Kill switch / `PAYMENTS_ENABLED` | **Aprovado (código)** |
| Comissão via `config/platform` | **Aprovado (código)** |
| Webhook sem confiar em `userId`/`credits` do body | **Corrigido** — exige `payments/{id}` + MP `approved` |
| Marcar pago só pelo frontend | **Não** — só CF/`checkPayment`/webhook |
| MP produção / live | **Bloqueado** até GO |

---

## FASE 7 — Carajás 360 IA

| Item | Status |
|------|--------|
| UI Central / FAB / Explorar CTA | **Aprovado** |
| Callable `aiAssistant` | **Não deployada** (sem GO Blaze/API) |
| Erro honesto + retry | **Melhorado** (`unavailable` + mensagem CF) |
| Profissionais só reais na resposta | Backend grounded (código); runtime **N/E** |

---

## FASE 8 — Erros e travamentos

| Item | Status |
|------|--------|
| “Não foi possível carregar os profissionais” | **Corrigido** (REST + cache; evidência homolog) |
| Sem mascarar com seed em produção | HomologCatalog só com placeholders |
| Retry Home/Explorar/Pedidos | **Aprovado (código)** |

---

## FASE 9 — Android e iOS

| Item | Evidência | Status |
|------|-----------|--------|
| Tecnologia | Flutter multiplataforma existente | **Reutilizar** |
| Android `applicationId` | `br.com.carajas360` | OK |
| iOS Bundle | `br.com.carajas360` | OK |
| Permissões | Internet, GPS, câmera, mic, notif | OK no manifesto/plist |
| AAB / IPA / TestFlight | Não gerados nesta sessão | **N/E** (iOS exige macOS + Apple Developer) |
| Assinatura release | Config externa | **Pendente publicação** |

---

## FASE 10 — Homologação final

Ver `docs/MATRIZ_HOMOLOGACAO_FASE10.md` (aprovado / reprovado / não executado).

Resumo unitários (2026-11-17): **~190 ok**, falhas em testes de widget de busca sem Firebase app — **não** bloqueiam o app; ambiente de teste incompleto.

---

## FASE 11 — Entrega ao programador

Ver `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md`.

---

## Pendências explícitas (GO)

1. Blaze + deploy `aiAssistant` (+ assist)  
2. Hosting **live**  
3. `PAYMENTS_ENABLED` + token MP + webhook secret em produção  
4. Builds AAB/IPA assinados e testes em dispositivo  
5. Suite E2E autenticada em homolog  
