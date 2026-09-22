# CARAJAS360 RC1 — Matriz de Testes

| ID | Area | Cenario | Esperado | Obtido | Status | Evidencia |
|----|------|---------|----------|--------|--------|-----------|
| E2E-01 | Auth | Cadastro cliente | Conta criada | — | NOT TESTED | device |
| E2E-02 | Auth | Cadastro profissional | Conta criada | — | NOT TESTED | device |
| E2E-03 | Servico | Criacao servico | Request aberto | — | NOT TESTED | device |
| E2E-04 | Match | Matching categoria | Match correto | Suite Flutter taxonomy | PASS | unit |
| E2E-05 | Creditos | Unlock lead | 1 debito idempotente | CF + homolog | PASS | unit/code |
| E2E-06 | Proposta | Envio proposta | Proposta salva | — | NOT TESTED | device |
| E2E-07 | Aceite | Aceite orcamento | Snapshot termos | — | NOT TESTED | device |
| E2E-08 | Pagamento | Sandbox MP | PENDING→CONFIRMED | PAYMENTS off | NOT TESTED | gateway |
| E2E-09 | Comissao | 8% e Admin 10% | 40/460 e 50/450 | orderPolicy | PASS | node |
| E2E-10 | Split | Payout interno | providerAmount | orderPolicy | PASS | node |
| E2E-11 | Ciclo | Conclusao | completed | — | NOT TESTED | device |
| E2E-12 | Avaliacao | Pos-conclusao | 1 review | — | NOT TESTED | device |
| E2E-13 | Cancel | Cancelamento | Estado valido | — | NOT TESTED | device |
| E2E-14 | Estorno | Refund sandbox | Compensatorio | — | NOT TESTED | gateway |
| E2E-15 | PRO | Assinatura | Ativa pos confirm | — | NOT TESTED | device |
| E2E-16 | Patrocinado | Destaque | Label PATROCINADO | — | NOT TESTED | device |
| E2E-17 | Webhook | Evento duplicado | 1 ledger | webhookApply | PASS | node |
| E2E-18 | Seguranca | IDOR perfil | Negado | rules F3 | PASS | rules |
| E2E-19 | Admin | Acesso indevido | Negado | — | NOT TESTED | device |
| E2E-20 | Admin | Altera comissao | Nova taxa | canPayout | PASS | node |
| F4-01 | Financeiro | direct_contact 0% | Sem comissao | orderPolicy | PASS | node |
| F4-02 | Saque | Mensagem manual | pending_manual | code review | PASS | code |
| F4-03 | LGPD | Emails carajas360 | Dominio novo | identity test | PASS | flutter |
| F4-04 | Auth | OAuth consent | Dialogo/checkbox | code | PASS | code |