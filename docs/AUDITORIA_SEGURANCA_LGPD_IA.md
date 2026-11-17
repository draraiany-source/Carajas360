# Auditoria de segurança e LGPD — Carajás IA

## Controles

| Controle | Implementação |
|----------|----------------|
| Sem chave no client | Só Cloud Function + `AiSvc` |
| Auth obrigatória | `RequireAuth` + `requireAuth` na callable |
| Rate limit | Por uid+modo (`ai_${mode}`) alinhado ao plano |
| Perfis | Admin/provider checados no servidor |
| Grounding | Providers só `active+verified` do Firestore |
| Anti-alucinação | Prompt + fallback grounded; urgência sem lista inventada |
| Prompt injection | Instrução explícita de ignorar override de regras |
| Histórico | `aiConversations` retenção 30 dias (campo); escrita backend |
| Uso/custo | `aiUsage` com `costUsd` estimado |
| Saúde | Consentimento explícito; sem diagnóstico/prescrição |
| Rules | Client read own; write false |

## Dados sensíveis

- Chat Saúde: usuário orientado a **não** enviar dados clínicos.  
- Sem execução de pagamento/contratação pela IA.  
- Admin: apenas agregados.

## Pendências de compliance

- DPIA formal / DPO review.  
- Job de purge após `retentionDays`.  
- App Check enforce quando produção.  
- Revisar logs para não persistir PII além do necessário.
