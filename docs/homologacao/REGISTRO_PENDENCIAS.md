# Carajás 360 — Registro de pendências e correções (entrega de homologação)

> Data: 16/10/2026 · Branch `fase1-seguranca-ambientes-filtros`.
> Base conferida: `67a7452` (PDF da auditoria) sobre `d4b646e` (correções da auditoria). Árvore local limpa, sem alterações posteriores a preservar nesta branch.
>
> **Ramos paralelos encontrados no remoto (não mesclados, preservados intactos):**
> - `cursor/bloco-a-security-staging-c199` (Cursor Agent, 18/09)
> - `fix/correcao-completa-final` (26/09)
>
> Os dois partem de `main` (`5013dcd`) e são **anteriores** a esta linha de trabalho. Não descendem de `d4b646e` e reescrevem os mesmos módulos (inclusive a troca de IDs para `br.com.carajas360` / `carajas360-a17c5`). Unificar exige decisão sua sobre qual linha prevalece.

**Legenda de validação**

| Sigla | Significado |
|---|---|
| **EMU** | Validado nos emuladores Firebase (regras, functions e app web via Playwright) |
| **CI** | Compilado no GitHub Actions |
| **HML** | Validado no projeto Firebase de homologação |
| **DISP** | Validado em dispositivo físico |
| **—** | Ainda não validado |

Nada desta entrega está validado em **HML** nem em **DISP**: o projeto de homologação não está configurado e não houve acesso a credenciais nem a dispositivos (ver §3).

## 1. Itens da auditoria e pendências funcionais

### R22 — autor das avaliações
- **Correção:**
  - As regras proíbem `clientName`/`clientPhoto` vindos do app.
  - O gatilho `onReviewCreated` grava nome e foto a partir de `publicProfiles` do autor autenticado (o `clientId` precisa ser o uid). O nome vira primeiro nome + inicial ("Maria S.").
  - `migrateReviewAuthors` (admin, `dryRun`) corrige as avaliações antigas.
- **Teste:**
  - regras: nome ou foto enviados pelo app são negados;
  - functions: nome forjado é sobrescrito.
- **Validação:** EMU ✅
- **Pendência externa:** rodar a migração em HML.

### B15 — reservas sem pagamento bloqueando a agenda (Saúde e Locação)
- **Correção:**
  - A reserva nasce `pending_payment` com `holdUntilMs`. A configuração fica em `config/booking` (15 min e 3 pendentes por cliente), só pela callable admin `updateBookingConfig`.
  - O limite é atômico: `bookingHolds/{cliente}` é lido e regravado na mesma transação. A concorrência no mesmo horário continua serializada pelo calendário.
  - O horário fica livre ao vencer o prazo; a tarefa `expireBookingHolds` (5 min) grava `expired` e cancela a cobrança aberta.
  - Pagamento aprovado depois do prazo: se o horário ainda está livre, confirma; se não, faz reembolso automático e abre uma pendência financeira.
  - Cancelamento e recusa de reserva paga geram reembolso.
  - As regras próprias de cada vertical foram mantidas: em Saúde, 2 h de antecedência e até 2 reagendamentos; em Locação, 24 h, e o anunciante confirma depois do pagamento.
- **Teste:** `homologacao.test.js`, 8 cenários:
  - 4 pedidos simultâneos resultam em 3 reservas;
  - mesmo horário pedido ao mesmo tempo: só uma reserva vence;
  - expiração com relógio controlado;
  - pagamento tardio com horário livre e com horário ocupado;
  - cartão recusado, depois pendente, depois aprovado;
  - reembolso;
  - Locação;
  - configuração.

  Além disso, `schedule.test.js` foi atualizado e há o E2E `schedule`.
- **Validação:** EMU ✅
- **Pendência externa:** —

### Cupons — limites
- **Correção:**
  - `maxUses` (total) e `perUserLimit` (por cliente) são verificados e reservados dentro da transação de `createMarketOrder` (`couponRedemptions`). O uso é devolvido se o pedido não for pago.
  - `checkCoupon` usa a mesma regra de validade do checkout.
  - O formulário admin valida os campos.
- **Teste:** 3 compras simultâneas com limite 2 resultam em 2; repetir com o mesmo cliente é recusado; cancelar devolve o uso.
- **Validação:** EMU ✅

### Meus chamados
- **Correção:**
  - Conversa em `support/{id}/messages`, acessível só pelo autor e pela equipe; o papel de quem escreve é conferido.
  - Um gatilho atualiza o status do chamado e avisa o cliente.
  - Telas novas: lista, conversa e o modo suporte no admin.
- **Teste:** regras e functions; E2E `hml` (lista, resposta, aviso).
- **Validação:** EMU ✅

### Modo manutenção
- **Correção:**
  - `config/platform.maintenanceMode` só pode ser alterado pelo admin master.
  - O servidor recusa operações de pedido, pagamento, Resolve e reservas para quem não é admin.
  - As regras bloqueiam pedidos, mensagens e avaliações criados direto pelo app.
  - O app mostra a tela de manutenção; o admin continua usando, com aviso.
- **Teste:** regras, functions e E2E `hml`.
- **Validação:** EMU ✅

### Recusa de prestador
- **Correção:**
  - `reviewProvider` (aprovar ou recusar com motivo, com registro em auditoria e aviso ao prestador).
  - `requestProviderReview` (pedir nova análise).
  - O app mostra o motivo e o botão "Pedir nova análise".
- **Teste:** functions e E2E `hml`.
- **Validação:** EMU ✅

### Notificações duplicadas
- **Correção:** a nova solicitação gera um aviso pelo servidor. A mensagem automática do chat leva `orderId` e não gera outro aviso; o app deixou de chamar `pushNotif`.
- **Teste:** functions (um aviso, nenhum aviso de chat).
- **Validação:** EMU ✅

### Contatos e valores de exemplo
- **Correção:**
  - O e-mail e o telefone inventados foram removidos do suporte.
  - O DPO e as dicas de telefone e e-mail viraram textos neutros.
  - `tool/check_hml_config.js` lista o que ainda é modelo.
- **Teste:** widget (sem contato inventado) e o próprio script.
- **Validação:** EMU ✅
- **Pendência externa:** você precisa informar o e-mail e o telefone reais de suporte (`config/platform`).

### Dependências
- **Correção:** `firebase-functions` 7.4 com API v1 explícita e `firebase-admin` 13.10, em Node 22.
- **Resultado do audit:** de 9 alertas (2 altos) para 8 moderados, todos de `uuid@9`. As bibliotecas só chamam `uuid.v4()`, então o código não está exposto. Detalhes em `DEPLOY_E_REVERSAO.md` §5.
- **Teste:** emulador completo com as versões novas (todos os tipos de gatilho).
- **Validação:** EMU ✅

### Catálogo público sem login
- **Correção:**
  - "Explorar sem entrar" no onboarding e no login.
  - Favoritar, chat, Reservar, agenda de Saúde e Pedidos pedem login e voltam à ação depois de entrar.
- **Teste:** E2E `app`, com o aplicativo real.
- **Validação:** EMU ✅

### Confirmações automáticas de 72 h e 7 dias
- **Correção:** relógio do servidor deslocável **só no emulador** (`TEST_CLOCK`). Os prazos reais não mudaram. As tarefas também rodam pela callable `adminRunMaintenance`.
- **Teste:** com 71 h ainda aguarda e com 72 h confirma; com 7 dias − 1 h retém e com 7 dias libera; repasse único.
- **Validação:** EMU ✅

### Gateway (aprovado, recusado, pendente, reembolso, webhooks duplicados e fora de ordem)
- **Cobertura:** gateway simulado do emulador em `payments.test.js` (Mercado) e `homologacao.test.js` (reservas).
- **Validação:** EMU ✅
- **Pendência externa:** o **sandbox real do Mercado Pago** não pôde ser usado. `api.mercadopago.com` está bloqueado pela rede deste ambiente e não há credenciais de teste.

## 2. Resultados de testes (emulador / CI)

| Suíte | Resultado | Onde |
|---|---|---|
| Regras + functions (emulador) | 152 testes; última suíte completa 151/152. A falha intermitente (prazo do gatilho de aviso do Resolve sob carga) foi corrigida em `ab41baa` e passa 2/2 isolada. Suíte completa anterior: 152/152 | EMU |
| Unitários das functions | 65/65 | local |
| Flutter (`flutter test`) | 124 + 1 pulado; `flutter analyze` sem erros | local |
| E2E web (7 fluxos, Playwright) | 91/91: schedule 16, hml 10, app 3, catalog 16, checkout 17, resolve 13, phase6 16 | EMU |
| Índices × consultas | 46 consultas compostas, 0 faltando | estático |
| Build iOS (`--no-codesign`, macOS) | ✅ run 5 (`086f708`) | CI |
| Build web hml | ✅ run 5 (`086f708`) | CI |
| Build APK hml + AAB prod (assinatura de teste) | run 4: os dois compilaram, a verificação de manifesto passou e o APK foi publicado como artefato (só a leitura de metadados falhou, já corrigida). Run 5: ver resumo da entrega | CI |

## 3. Bloqueios reais (precisam de você)

1. **Projeto Firebase de homologação.** Precisamos de:
   - acesso ao projeto, ou que você crie `carajas360-hml`;
   - uma credencial de implantação: conta de serviço com papel de Firebase Admin, ou `firebase login:ci` para uso no CI como *secret*.

   Sem isso não há **link web de homologação**, os APK/IPA abrem em "configuração indisponível" e nada foi validado em HML. A lista exata de arquivos e valores aparece em `node tool/check_hml_config.js`.
2. **Mercado Pago sandbox.** Precisamos do *access token* e da *public key* de **usuário de teste**, e do webhook cadastrado com a assinatura. Além disso, a rede deste ambiente bloqueia `api.mercadopago.com`; o teste real tem que rodar no projeto hml ou no CI.
3. **Login Google.** Falta o *Web client ID* do projeto hml e o domínio autorizado.
4. **iOS.**
   - Projeto completo e compilado sem assinatura no CI (ver §2).
   - Para IPA e dispositivo faltam: conta Apple Developer, *bundle id* e *provisioning*, a capacidade Sign in with Apple, chave APNs no Firebase e o `GoogleService-Info` do hml.
5. **Dispositivos.** Não houve dispositivo Android/iOS disponível. Instalação e push em aparelho ficam para você, seguindo o roteiro manual abaixo.
6. **Contatos de suporte reais** e domínio de e-mail do Carajás 360.
7. **Unificação com os ramos paralelos** (ver topo do documento).

## 4. Roteiro manual em homologação (depois dos bloqueios 1 a 3)

Use as contas criadas por `tool/seed_hml_accounts.js`: cliente, prestador, loja e admin. As senhas aparecem só no terminal de quem executa.

1. **Cadastro e conta:**
   - cadastro, login, recuperação de senha e exclusão de conta;
   - os dados somem do servidor;
   - visitante navega sem login.
2. **Prestador:**
   - o admin aprova, recusa com motivo e suspende;
   - o prestador pede nova análise;
   - mudar especialidade volta para análise.
3. **Serviço, ponta a ponta:**
   - solicitação, orçamento no aceite, pagamento (Pix e cartão de teste), início;
   - o prestador marca como concluído e o cliente confirma;
   - cancelar um pedido pago gera reembolso.
4. **Mercado:**
   - compra com cupom (limite);
   - a loja marca entregue;
   - o cliente confirma o recebimento e a loja recebe o repasse.
5. **Saúde:**
   - reservar e pagar em menos de 15 min;
   - deixar expirar e ver o horário liberado;
   - o profissional cancela uma consulta paga e o valor é reembolsado.
6. **Locação:**
   - reservar e pagar; o anunciante confirma;
   - outra reserva: o anunciante recusa e o valor é reembolsado.
7. **Comunicação:** chat com anexo, avisos (uma notificação por solicitação), favoritos, avaliação (nome do perfil público) e chamado com resposta.
8. **Manutenção:** o admin master liga o modo; usuário comum é bloqueado e o admin continua usando.
9. **Gateway no sandbox:**
   - pagamentos aprovado, recusado, pendente e reembolsado;
   - repetir webhook pelo painel do Mercado Pago;
   - conferir no extrato que não houve crédito nem repasse duplicado.
