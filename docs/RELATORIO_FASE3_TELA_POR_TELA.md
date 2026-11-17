# FASE 3 — Funcionamento tela a tela (fluxo cliente P0)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Base:** `docs/AUDITORIA_TELAS_CARAJAS360.md` + FASE 2  
**Escopo:** corrigir loading/erro/vazio, validação, navegação e dados reais nas telas do **fluxo cliente** — sem criar app novo, sem deploy live/Functions.

---

## Telas percorridas (ordem do fluxo)

| # | Tela | Rota / entrada | Status FASE 3 |
|---|------|----------------|---------------|
| 1 | Home | MainNav / Início | OK (loading/erro/retry já existiam) |
| 2 | Explorar | `/search` | OK (erro/vazio/retry já existiam) |
| 3 | Perfil profissional | `/provider-profile` | Corrigido: args vazios + erro de rede vs 404 |
| 4 | Solicitar orçamento | `/request-service` | Corrigido: bloqueio sem `providerId` |
| 5 | Marketplace → matching | `ServiceRequestFlowScreen` | Corrigido: matching com Firestore real |
| 6 | Meus pedidos | `/my-orders` | Corrigido: retry em falha de carga |
| 7 | Mensagens / Chat | inbox + `/chat` | Corrigido: retry inbox; loading/erro na sala |
| 8 | Avaliações | `/reviews` | Corrigido: validação + try/catch |
| 9 | Notificações | `/notifications` | Corrigido: removido fallback demo |
| 10 | Cupons | `/coupons` | Corrigido: só validação real via Firestore |

---

## Alterações realizadas

### Navegação / args
- `/request-service` e `/provider-profile` sem ID → `_MissingArgsScreen` (sem pedido fantasma).
- Matching do marketplace deixa de cair no seed Homolog quando o Firebase real está ativo; usa `FS.providersStream`.

### Dados reais (sem inventar)
- Notificações: lista só do stream (`snap.data ?? []`).
- Cupons: removidos códigos fictícios e “válido” em debug; valida só `FS.validateCoupon`.

### Estados UX
- Meus pedidos / inbox: botão **Tentar novamente**.
- Chat: loading e erro ao carregar mensagens.
- Avaliação: auth, `orderId` inválido, nota, erro de rede.
- Perfil: distingue falha de rede de perfil inexistente.

---

## O que NÃO foi feito (GO / fases seguintes)

- Deploy `aiAssistant` / Blaze  
- Hosting live  
- Pagamentos MP produção / webhooks  
- FASE 4 (fluxo E2E cliente ponta a ponta com status no banco)  
- FASE 5+ profissional / pagamentos / IA runtime  

---

## Testes manuais sugeridos

1. Explorar → perfil → Solicitar orçamento (com login).  
2. Abrir `/request-service` sem args → mensagem clara.  
3. Meus pedidos offline/com erro → Tentar novamente.  
4. Avaliar sem `orderId` → orientação para Pedidos.  
5. Cupons: código inexistente → inválido (sem PROMO30 fake).  
6. Marketplace serviço → Ver compatíveis → lista real ou vazio honesto.

---

## Próxima fase

**FASE 4** — fluxo completo do cliente (busca → orçamento → proposta → aceite → pagamento → conclusão → avaliação) com atualização de status no Firestore.
