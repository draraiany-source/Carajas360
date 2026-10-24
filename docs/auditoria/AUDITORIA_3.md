# Carajás 360 — Auditoria 3: aplicativo completo (19/10/2026)

**Pergunta:** o que o usuário vê em cada tela é real?

**Método:**
- 5 frentes em paralelo:
  - início/entrada/perfil/carteira/IA;
  - Mercado;
  - prestador/empresa/Resolve/admin;
  - Saúde/Locação/chat/suporte;
  - camada compartilhada (tema, componentes, push, serviços e regras).
- Cada tela foi seguida no código, do botão até a função do servidor.
- Cada tela foi classificada como REAL, PARCIAL, FALSO, ENGANOSO, QUEBRADO ou EM BREVE.

**Escopo:** nada foi publicado; tudo rodou só no emulador local.

**Princípio:** nada fictício na frente do usuário. O que não existe foi removido ou marcado como "Em breve".

O relatório completo, com o inventário tela a tela, está em `RELATORIO_AUDITORIA_3.pdf`. Ele é gerado por `gerar_pdf_3.py`.

## Números

- **132 achados individuais**, agrupados em 50 linhas no PDF.
- **Corrigidos:** todos os achados altos, menos um. O pedido do prestador ficou parcial, porque falta o campo de expiração no servidor.
- **Pendentes:** a lista está no fim deste documento.

## Principais correções

**Promessas falsas removidas ou reescritas:**
- "300 serviços" e "GPS ao vivo";
- Planos com preço;
- Leads e Assinatura da empresa;
- cashback por indicação;
- videoconsulta;
- "Pague somente após o serviço";
- banners com "5 estrelas" e "frete expresso";
- banners do admin, que nunca apareciam no app;
- "Faturamento" que era o volume de serviços (GMV).

**Fluxos quebrados consertados:**
- o profissional escolhido no Resolve vê o endereço e o telefone do cliente;
- a loja vê os itens, o endereço e o nome do cliente;
- a busca e as categorias do Mercado filtram de verdade;
- o perfil da loja permite comprar;
- o Home Care exige endereço;
- o profissional de saúde vê quem marcou;
- as reservas de locação mostram as datas;
- o pedido do prestador não trava mais depois de 15 minutos;
- o cadastro depois do Google ou SMS tem saída.

**Privacidade:**
- sair da conta apaga o token de push;
- excluir a conta anonimiza o perfil de prestador e as avaliações e apaga os arquivos pessoais;
- empresas não aprovadas, com e-mail e telefone, deixam de ser públicas;
- anexo do chat só é aceito se vier do Storage do app, na pasta da conversa;
- a localização no chat não pode mais ser falsificada.

**Qualidade:**
- modo escuro (59 cartões ilegíveis);
- busca do Início;
- notificação que abre a tela certa;
- acessibilidade (rótulos e áreas de toque);
- mensagens de erro em português, sem exceção crua.

## Testes (19/10/2026)

| Suíte | Resultado |
|---|---|
| Regras + functions no emulador | 164/164, mais 4 novos (`firebase-tests/rules/audit3.rules.test.js`, `firebase-tests/functions/audit3.test.js`) |
| Unitários das functions | 65/65 |
| Flutter (`flutter test`) | 170/170, com 1 pulado. Inclui 4 arquivos novos (`test/audit3_*_test.dart`). `flutter analyze` sem erros. |
| E2E web | ver o PDF |

## Pendências

> Atualização de 24/10/2026: estas pendências foram tratadas. Veja `PENDENCIAS_3.md` e `RELATORIO_PENDENCIAS_3.pdf` para saber o que foi testado, o que aguarda teste externo, o que depende de decisão de produto e o que está bloqueado.

- **Push:**
  - um token por usuário;
  - na web, falta service worker e chave VAPID.
- **Anexos do chat:** acessíveis por link com token (LGPD). Precisam ser servidos por função.
- **Admin:**
  - os painéis leem coleções inteiras (precisa de agregados no servidor);
  - cerca de 45 fluxos são criados dentro do build.
- **Pedido do prestador:** falta a expiração no servidor.
- **Mercado:**
  - esconder produtos de loja desativada;
  - o contador público de produtos da loja ainda pode ser alterado pelo dono.
- **Cashback:** a autoconfirmação de 72 h não gera cashback (decisão de produto).
- **Configuração:**
  - `authDomain` ainda no domínio antigo;
  - o client id do Google web ainda é modelo;
  - o iOS tem um único bundle id.
- **Cliente que quer virar prestador:** só existe no cadastro.
