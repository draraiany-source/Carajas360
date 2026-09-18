# LGPD — retenção, anonimização e exclusão de conta

Documento do **BLOCO B (Fase 11)** do CARAJÁS 360. Ambiente alvo: **staging**. Não descreve chave, token ou credencial.

## Princípio

O titular pode pedir exclusão da conta. Isso **não** é apagar só o Firebase Auth e **não** é apagar o histórico financeiro/fiscal.

Fluxo oficial: Cloud Function autenticada `deleteMyAccount` (ownership = `request.auth.uid`).

1. Grava `legalRetention/{uid}` com hashes irreversíveis (SHA-256) de CPF/telefone, data e prazo.
2. Anonimiza `users/{uid}` (nome padrão, sem e-mail/foto/endereço/CPF/telefone/FCM).
3. Apaga `users/{uid}/private/*` (PII em claro).
4. Desativa e anonimiza `providers/{uid}` e empresas cujo `ownerId` é o titular.
5. Anonimiza nome/foto em avaliações, chamados e pedidos Resolve do titular.
6. Apaga **favoritos** e **notificações** (sem obrigação legal de guarda).
7. **Não apaga** pedidos, pagamentos, transações, auditoria financeira, contratos, carteira (fica `status: closed`) nem `xpEvents`.
8. Remove arquivos pessoais em Storage (`users/{uid}/`, `providers/{uid}/`). Anexos de pedido/contrato **permanecem** (prova do serviço).
9. Remove o usuário no Firebase Auth **depois** da anonimização (e-mail pode ser reutilizado).
10. Escreve `auditLogs` (`lgpd_account_anonymized`).

O app cliente **não** chama `User.delete()` nem apaga o documento `users/{uid}`. Rules: `allow delete: if false` em `users`.

## O que é anonimizado vs. retido

| Dado | Ação | Motivo |
|---|---|---|
| Nome, e-mail, foto, endereço, CPF, telefone, FCM | Anonimizar / apagar PII | Art. 18, VI LGPD (eliminação) |
| Documentos de identificação no Storage | Apagar pasta do usuário | PII sensível; KYC não vira obrigação fiscal da plataforma sozinha |
| Favoritos, notificações | Apagar | Sem guarda legal |
| Pedidos, pagamentos, transações, `financialAudits` | **Reter** (IDs internos, valores, status) | Obrigação fiscal/contratual; CTN ~5 anos |
| Contratos | **Reter** | Prova contratual |
| Mensagens de chat | Reter sala; o nome do remetente passa a resolver para “Usuário removido” no perfil. Texto histórico **não** é reescrito em massa (custo/risco). | Outra parte ainda precisa do histórico do atendimento |
| Carteira / saldo | Congelar (`closed`). **Não zera e não transfere sozinho** | Evitar perda silenciosa de saldo; operação manual se houver valor |
| XP / gamificação | Eventos `xpEvents` retidos; XP no perfil anonimizado deixa de ser usado | Auditoria de concessão |

Prazo de guarda dos registros retidos: **5 anos** a partir da exclusão (`legalRetention.retentionUntil`), alinhado à prescrição fiscal comum. Depois disso, um job futuro (BLOCO C/D) pode expurgar — **não implementado aqui** para não causar exclusão irreversível automática.

## Bases legais (resumo operacional)

- Execução de contrato e dever legal (pagamentos, notas, disputas): retenção minimizada, sem PII em claro.
- Consentimento / direito de eliminação: PII de perfil e documentos de cadastro.
- Hashes de CPF/telefone servem só para correlacionar um eventual ofício, não para reidentificar na interface.

## Como o titular exerce o direito

No app: **Perfil → Excluir minha conta** (confirmação). Portabilidade: **Exportar meus dados**.

Encarregado (texto atual do app): `privacidade@servicoconecta.com.br` — confirmar com a Raiany se o e-mail definitivo muda.

## O que a Function **não** faz (de propósito)

- Não estorna pagamento no gateway.
- Não debita/credita carteira de terceiros.
- Não apaga a conta de outro `userId`.
- Não exclui conta `type == admin` por este fluxo (evita lockout).
- Não liga pagamento real.

## Staging / deploy

Deploy da Function + rules no projeto de staging. Custom claim admin continua sendo da Raiany.

App Check (`ENFORCE_APP_CHECK`) e Function de assinatura de plano **não** entram neste bloco; seguem para o BLOCO C.
