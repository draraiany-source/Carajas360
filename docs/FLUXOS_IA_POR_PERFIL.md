# Fluxos de IA por perfil — Carajás 360

## Cliente (`mode=client`)
1. Abre Carajás IA (nav / perfil) → RequireAuth.  
2. Descreve necessidade em linguagem natural.  
3. Backend identifica intent/categoria e carrega profissionais elegíveis do Firestore.  
4. Resposta + cartões → “abrir perfil” / orientar solicitação.  
5. Não contrata nem cobra; usuário confirma no fluxo de pedido.

## Saúde (`mode=health`)
1. Usuário marca consentimento educativo (obrigatório).  
2. Explicações de especialidade/modalidade; urgência → SAMU 192.  
3. Proibido diagnóstico/prescrição/confirmação de consulta.  
4. Encaminha à tela Saúde / solicitação de preferência de horário.

## Profissional (`mode=provider`)
1. Exige perfil prestador (role ou doc `providers/{uid}`).  
2. Sugestões de organização/resposta/orçamento **sem inventar preço** (prestador informa).  
3. Integra com fluxos já existentes `assistProposalDraft`.

## Admin (`mode=admin`)
1. Exige admin (token/doc).  
2. Indicadores agregados (amostra): ativos, categorias, cidades, suporte.  
3. Sem PII de clientes na resposta.

## Humano
Botão “Humano” → `Routes.support`.
