# Plano de testes final — Carajás 360 (FASE 16)

**Ambiente preferencial:** Homolog Web + emuladores Firebase + devices (Marco 3).  
**Proibido:** marcar PASS sem evidência (log, HTTP, build, ID de pedido).

---

## A. Automatizados (já executáveis)

| ID | Comando | Resultado F16 | Critério |
|----|---------|---------------|----------|
| A1 | `cd functions && npm test` | **163/163 PASS** | fail=0 |
| A2 | `flutter test test/order_photos_test.dart test/order_photos_flow_test.dart test/firebase_placeholders_test.dart` | **14/14 PASS** | fail=0 |
| A3 | Emulators: `order_photos_emulator_e2e_test.dart` | **PASS** (sessão fotos) | upload/ACL/delete |
| A4 | `flutter analyze` (opcional regressão) | N/E nesta rodada | 0 errors |

---

## B. Infra / smoke HTTP

| ID | Teste | Resultado F16 |
|----|-------|---------------|
| B1 | Homolog GET `/` | **200** |
| B2 | Live GET `/` | **404** FAIL publicação |
| B3 | Billing Blaze | **false** |
| B4 | Storage bucket list | **0 buckets** |

---

## C. Fluxo cliente (manual autenticado)

Pré-req: contas teste; Storage prod ou emulator documentado.

| Passo | Ação | Esperado | Status |
|-------|------|----------|--------|
| C1 | Cadastro/login cliente | Sessão Auth | N/E |
| C2 | Explorar profissionais | Lista real | Parcial (homolog sem auth) |
| C3 | Abrir perfil → solicitar orçamento | Form | N/E |
| C4 | Anexar até 10 fotos; visita técnica | Preview/upload | Código IT; prod N/E |
| C5 | Enviar solicitação | Order + photoUrls | N/E auth |
| C6 | Ver proposta (valor/prazo/texto) | Chat/UI | N/E |
| C7 | Aceitar | Order priced | N/E |
| C8 | Pagar sandbox | paid + escrow | N/E |
| C9 | Confirmar conclusão | Repasse elegível | N/E |
| C10 | Avaliar | Review 1x | N/E |

---

## D. Fluxo profissional

| Passo | Ação | Status |
|-------|------|--------|
| D1 | Cadastro prestador | N/E |
| D2 | Aprovação admin | N/E |
| D3 | Receber solicitação + ver fotos | N/E |
| D4 | Enviar proposta | N/E |
| D5 | Atender / concluir | N/E |
| D6 | Recebimento (sandbox) | N/E |

---

## E. Admin

| Passo | Ação | Status |
|-------|------|--------|
| E1 | Login AdminGate | N/E |
| E2 | Aprovar profissional | N/E |
| E3 | Monitorar pedidos/pagamentos | N/E |
| E4 | Disputa | N/E |
| E5 | Relatórios / auditoria | N/E |

---

## F. IA

| ID | Teste | Status |
|----|-------|--------|
| F1 | Abrir Central IA (UI) | Código/UI IS |
| F2 | Turno LLM real | **FAIL/N-E** (CF 403) |
| F3 | Busca grounded providers | Após deploy |
| F4 | Sugestão descrição c/ fotos (sem preço) | Código; runtime pendente |

---

## G. Multimídia orçamento

| ID | Teste | Status |
|----|-------|--------|
| G1 | Fotos ≤10 validação | **PASS** unit |
| G2 | Upload+ACL emulator | **PASS** |
| G3 | Upload prod | **BLOCKED** Storage |
| G4 | Vídeo | **AUSENTE** |
| G5 | Áudio no pedido | **AUSENTE** |

---

## H. Permissões e erros

| ID | Teste | Nota |
|----|-------|------|
| H1 | Estranho não lê order/fotos | Emulator PASS |
| H2 | Cliente não define preço na criação | Rules + functions tests |
| H3 | Erro IA honesto se Function off | Código `unavailable` |
| H4 | Pagamento bloqueado se flag off | Functions tests |

---

## Registro de execução FASE 16

| Suite | Pass | Fail | Skip/N-E |
|-------|------|------|----------|
| Functions | 163 | 0 | — |
| Flutter photos/config | 14 | 0 | — |
| E2E auth fluxos | 0 | — | todos |
| IA real | 0 | — | 1 |
| MP sandbox | 0 | — | todos |
| Mobile builds | 0 | — | todos |

**Conclusão do plano nesta data:** automação backend/fotos OK; fluxos autenticados e publicação **não** comprovados.
