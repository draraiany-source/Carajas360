# Roteiro E2E — cliente e profissional (FASE 13)

Executar em **homolog** com contas de teste. Marcar resultado na matriz do relatório FASE13.

## Cliente

| # | Passo | Esperado | Resultado |
|---|-------|----------|-----------|
| C1 | Cadastro/login | Conta criada / sessão | N/E nesta sessão |
| C2 | Busca Explorar | Lista real de profissionais | Código + homolog UI OK |
| C3 | Perfil profissional | Dados + pedir orçamento | Código OK |
| C4 | Enviar orçamento | Pedido em Meus pedidos | Código OK |
| C5 | Aceitar proposta Resolve | `acceptResolveProposal` → pedido | Código OK; E2E N/E |
| C6 | Pagamento teste | PIX/cartão/carteira via CF | Bloqueado (PAYMENTS off / API 403) |
| C7 | Conclusão + avaliação | Status + ReviewScreen | Código OK; E2E N/E |

## Profissional

| # | Passo | Esperado | Resultado |
|---|-------|----------|-----------|
| P1 | Cadastro provider | Onboarding + docs | Código OK; E2E N/E |
| P2 | Aprovação admin | Status approved | Código OK; E2E N/E |
| P3 | Receber pedido | Lista Provider Home (sem demo) | Código OK |
| P4 | Aceitar com preço | Valor obrigatório | Código OK |
| P5 | Proposta Resolve | Envio proposta | Código OK |
| P6 | Execução / conclusão | Transições OrderPolicy | Código OK |
| P7 | Recebimento teste | Escrow / payout | Bloqueado sem pagamentos |

## Falhas de código corrigidas nesta fase

- Testes Flutter alinhados a `firebase_options` reais  
- HomologCatalog override só em testes  
