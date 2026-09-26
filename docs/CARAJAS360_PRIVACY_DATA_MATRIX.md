# CARAJAS360 - Matriz de Dados e Privacidade (rascunho)

**Versao app:** 1.0.0+402  
**URLs legais F7:** privacidade e termos - **404** (bloqueador)  
**Uso:** base para Data safety (Play) e politica publicada - **nao** substitui assessoria juridica

## Legenda

| Coleta | Sim/Nao/Condicional | Finalidade | Compartilhamento | Retencao |
|--------|---------------------|------------|------------------|----------|

## Categorias (alto nivel - revisar contra codigo antes de publicar)

| Dado | Coleta | Finalidade | Compartilhamento | Base LGPD (rascunho) |
|------|--------|------------|------------------|----------------------|
| Identificadores conta (UID Firebase) | Sim | Autenticacao | Firebase/Google | Execucao contrato |
| E-mail / telefone (se cadastro) | Condicional | Conta, recuperacao | Firebase Auth | Execucao contrato |
| Mensagens chat | Condicional | Comunicacao in-app | Firebase (Firestore) | Execucao contrato |
| Pedidos / solicitacoes servico | Condicional | Operacao marketplace | Firebase | Execucao contrato |
| Localizacao | Condicional | Servicos locais (se feature ativa) | Maps/provider configurado | Consentimento |
| Fotos / anexos | Condicional | Perfil, pedidos, chat | Firebase Storage | Execucao contrato |
| Dados pagamento | **Nao na RC F7** | Pagamentos OFF | N/A ate ativacao | N/A |
| Logs / crash | Condicional | Estabilidade | Firebase Crashlytics se habilitado | Legitimo interesse |

## Terceiros tipicos (confirmar no projeto)

- Google Firebase (Auth, Firestore, Storage, Functions, Messaging)
- Provedor mapas (conforme configuracao)
- Gateway pagamento (Mercado Pago) - **inativo** com pagamentos OFF

## Direitos do titular

- Exportacao / exclusao: implementar fluxo in-app + processo operacional antes de GO loja.
- Contato privacidade: definir e publicar na politica (fora do Git).

## Acoes antes de loja

1. Publicar politica e termos (sem 404).
2. Alinhar Data safety form com esta matriz revisada.
3. Revisao juridica recomendada.
