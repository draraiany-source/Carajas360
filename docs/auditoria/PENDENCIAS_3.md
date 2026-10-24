# Carajás 360: pendências da Auditoria 3 (24/10/2026)

O relatório completo é o `RELATORIO_PENDENCIAS_3.pdf`, gerado por `gerar_pdf_pend3.py`. As capturas de tela estão em `docs/homologacao/evidencias/pend3/`.

Tudo foi feito em emulador e no CI. Nada foi publicado, produção não foi tocada e nenhuma credencial foi inventada. **O app não está pronto para lançamento:** nada foi validado em homologação real nem em aparelho.

## Situação por item

| Item | Situação |
|---|---|
| **Anexos do chat** | Testado no emulador e no navegador. O anexo é acessado pela callable `getChatMediaUrl`, que confere a participação na conversa no servidor e devolve uma URL assinada de 10 min. O link antigo com token foi revogado (migração no admin). Apagar para todos apaga o arquivo. *Aguarda teste externo:* URL assinada e revogação num bucket real. |
| **Mercado** | Testado. Produtos de loja desativada ou não aprovada saem da vitrine e da busca e ficam bloqueados no carrinho e no checkout, com validação no servidor. O `totalProducts` é recontado no servidor. Há reconciliação dos dados e uma fila "Lojas" para o admin aprovar. |
| **Expiração dos pedidos** | Testado. O `expiresAt` é gravado no servidor (7 dias). Aceite e recusa ficam bloqueados no backend após o prazo. A expiração é feita em transação, e o app usa a mesma referência. *Decisão:* o que fazer com pedido pago que expira (hoje vai para o suporte). |
| **Desempenho** | Testado. Os painéis do admin usam agregados no servidor e listas paginadas. O filtro de usuários roda na consulta, sem limite de 50. 57 pontos de fluxo criado no `build` foram corrigidos em 23 telas. *Aguarda:* índices ativos no projeto hml. |
| **Notificações** | Testado no emulador: token por aparelho, logout remove só o aparelho atual, tokens inválidos são limpos. *Bloqueado:* push web precisa das credenciais hml e da chave VAPID. *Aguarda:* entrega real em aparelho e no navegador. |
| **Perfil e cashback** | Testado: "Quero ser prestador" reaproveita cadastro, documentos e aprovação, sem autoaprovação. *Decisão:* cashback na confirmação automática de 72 h (não existe regra aprovada; nada foi inventado). |
| **Homologação externa** | iOS separado por ambiente, testado no CI. Login Google web pelo popup do Firebase e `authDomain` configurável. *Bloqueado:* projeto Firebase hml, Mercado Pago sandbox e conta Apple (ver `docs/homologacao/HOMOLOGACAO_EXTERNA.md`). |

## Testes

| Suíte | Resultado |
|---|---|
| Emulador (regras e functions) | 216/216 |
| Unitários das functions | 72/72 |
| Flutter | 212/212 |
| E2E nas suítes anteriores | 91/91 |
| E2E `pend3` no app real | 26/26 |
| Índices × consultas | 47 consultas, 0 sem índice |

A suíte E2E `pend3` encontrou e permitiu corrigir um bug real: o anexo do chat nunca terminava de carregar.

## Builds

- **CI no commit `588463c`:** APK hml, AAB prod, iOS hml e web hml aprovados.
- **A partir do commit `67e02ac`:** o GitHub Actions não aloca máquina (falha em 3 s, também ao reexecutar). É um bloqueio da conta, não do código. Confira em Settings › Billing › Actions.
- **Build local:** web hml compilado.
- **Link de homologação:** não existe.
