# FASE 2 — Organizar telas (Carajás 360)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Base:** `docs/AUDITORIA_TELAS_CARAJAS360.md`  
**Escopo:** reutilizar módulos existentes; **não** criar app novo nem 30 telas novas.

---

## Objetivo desta fase

Organizar navegação e lacunas P1 da auditoria:
- rotas órfãs;
- deep links sem IDs inventados (`demo`);
- agenda como rota;
- disputas no admin.

---

## Alterações realizadas

| Item | Antes | Depois |
|------|-------|--------|
| `/service-request-flow` | Constante sem `case` | Resolve `TaxonomyService` por `serviceId`/`categoryId` → `ServiceRequestFlowScreen` |
| `/opportunity-detail` | Constante sem `case` | `OpportunityDetailLoader` carrega pedido real + config |
| `/appointments` | Só push MaterialPageRoute | Rota nomeada + RequireAuth → `AppointmentsScreen` |
| Chat `/chat` | Fallback `roomId: demo` | Tela de orientação se args inválidos |
| Reviews `/reviews` | Fallback `orderId: demo` | Idem → Meus pedidos |
| GPS → Avaliar | `orderId ?? 'demo'` | Exige pedido real |
| Admin | Só denúncias (`reports`) | Nova aba **Disputas** (`Col.disputes`) |
| Hub oportunidades | MaterialPageRoute | `pushNamed(Routes.opportunityDetail)` |

### Arquivos principais
- `lib/main.dart`
- `lib/core/constants/app_constants.dart`
- `lib/features/monetization/opportunities_screen.dart`
- `lib/features/admin/admin_screen.dart`
- `lib/shared/services/firestore_facade.dart` (`disputesStream`, `updateDisputeStatus`)
- `lib/features/gps/gps_screen.dart`
- `lib/features/health/health_screen.dart`

---

## O que NÃO foi feito nesta fase (depende de GO / fases seguintes)

- Deploy Cloud Function `aiAssistant` / Blaze
- Hosting live
- Integração Mercado Pago produção / fila de saques
- Redesign visual completo de todas as telas
- Builds AAB/IPA

---

## Testes sugeridos (manual / próxima fase)

1. Deep link `/#/service-request-flow?` com args via `pushNamed` + `serviceId`
2. `/#/opportunity-detail` com `{id}` de Resolve aberto
3. `/#/appointments` autenticado
4. `/#/chat` e `/#/reviews` sem args → mensagem clara (sem `demo`)
5. Admin → aba Disputas (lista vazia ou tickets reais)

`flutter analyze` nos arquivos tocados: apenas infos/warnings pré-existentes; sem errors novos de compilação detectados.

---

## Próxima fase

**FASE 3** — funcionamento tela a tela (layout, formulários, estados loading/erro, permissões), começando pelas telas do fluxo cliente P0.
