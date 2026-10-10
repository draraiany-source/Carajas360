# Carajás 360 — Relatório técnico da Fase 2

**Escopo:** taxonomia administrável e busca funcional.
**Ambiente:** apenas emuladores locais (dev). Nada foi publicado, nenhum projeto em nuvem foi alterado e nenhum pagamento foi feito.
**Base:** branch `fase1-seguranca-ambientes-filtros` (commit `d7e22c0`).

## 0. Conferência da Fase 1 (antes de começar)
- Functions 22/22, Flutter 62 testes, emulador 32/32, `flutter analyze` sem erros. **Sem bloqueios.**
- Divergência confirmada no código: a aba "Categorias" do admin listava a constante Dart `Categories.all`. Os botões Salvar/Excluir só exibiam mensagens; **nada era gravado**. Ao mesmo tempo existia uma coleção `categories` no Firestore que nenhuma tela lia.
- Dado fictício que escapou na Fase 1: a tela de Entregas exibia uma oferta fixa ("Centro → Bela Vista · R$ 8,50") que **criava pedido real** ao ser aceita. Agora ela só aparece em dev com `DEMO_DATA`.

## 1. Esquema do catálogo (fonte única)

Coleção `catalogNodes/{id}`, com 3 níveis fixos: **categoria → grupo → serviço**.

| Campo | Descrição |
|---|---|
| `id` | ID estável (doc id). Os 133 IDs legados foram mantidos (ex.: `eletricista`); IDs novos usam `cat_` / `grp_` / `svc_` |
| `level` | `category` \| `group` \| `service` (não pode mudar depois de criado) |
| `name`, `description`, `slug` | `slug` é gerado no servidor |
| `parentId` | Nível superior. Obrigatório para grupo (→ categoria) e serviço (→ grupo) |
| `icon`, `color` | Emoji/código curto e cor `#RRGGBB` |
| `order` | Ordem entre irmãos |
| `active` | Situação própria do item |
| `effectiveActive` | Calculado no servidor: o item **e** todos os ancestrais ativos |
| `vertical` | `services` \| `health` \| `market` \| `rental` \| `delivery` (herdada da categoria) |
| `keywords`, `synonyms` | Usados na busca |
| `searchTerms` | Termos normalizados, calculados no servidor |
| `modalities` | `presential` \| `online` \| `home_care` |
| `commercialModel` | `quote` (orçamento) \| `fixed` (preço fixo) \| `both` |
| `path` | `[categoria, grupo, serviço]` |
| `questionnaireId`, `questionnaireVersion` | Questionário publicado vinculado |
| `createdAt`, `updatedAt`, `editedAt`, `editedBy`, `source`, `seedVersion` | Auditoria e origem |

Coleções auxiliares:
- `catalogMeta/current`: `version`. O app avisa "Catálogo atualizado" quando ela muda.
- `catalogMeta/legacyIdMap`: mapa de compatibilidade.
- `catalogMigrations/v1`: relatório da migração.
- `serviceQuestionnaires/*`: questionários versionados.

**Validação no servidor** (`functions/catalogCore.js` → `validateNode`):
- campos obrigatórios;
- nível superior existente e do nível correto (serviço só sob grupo, grupo só sob categoria);
- ID único;
- nome duplicado entre irmãos recusado;
- hierarquia circular recusada;
- modalidades e modalidade comercial dentro das listas válidas.

**Normalização de texto idêntica no app e no servidor**, garantida por vetores compartilhados em `functions/catalog/normalization_vectors.json`.

## 2. Catálogo regional (seed v1)
O seed v1 (`functions/catalog/seed_v1.json`) tem 181 nós:
- **22 categorias**: as 18 regionais pedidas + 4 verticais especializadas (Saúde, Mercado–Lojas, Locação, Entregas);
- 82 grupos;
- 77 serviços.

Exemplo: **Automóveis → Mecânica (`mecanico`) → Freios**.

Mapeamento dos grupos antigos para as categorias novas:

| Grupo antigo | Destino |
|---|---|
| Casa | Casa e Reformas |
| Tech | Tecnologia e Design (informática e celular foram para Assistência Técnica) |
| Veículos | Mecânico → Automóveis; Motorista → Transporte e Mudanças; `aluguel_*` → Locação |
| Máquinas (`aluguel_*`) | Locação |
| Lojas | Mercado–Lojas |
| Agro (31 itens) | 7 grupos: Consultoria, Operação de Máquinas, Lavoura, Topografia, Infraestrutura Rural, Pecuária, Transporte Rural |
| Drones | 3 grupos |

Novos grupos/serviços sem prestadores foram criados apenas onde a estrutura pedia (Auto Elétrica, Freios, Design Gráfico, Serviços Empresariais etc.).

**Verticais preservadas:**
- Itens de Mercado e Locação não aparecem nas telas de serviços.
- Saúde aparece só na vertical Saúde.
- Nenhuma categoria de serviço libera módulo "Em desenvolvimento". Os módulos continuam em `platform_modules.dart` e o hub mostra apenas as verticais disponíveis.

## 3. Migração sem perda e mapa de compatibilidade
Callable `migrateCatalogV1`, somente admin:
- **Simulação** com `{dryRun:true}`: conta o que faria e não grava nada.
- **Idempotente**: cria só os nós ausentes. Item idêntico é ignorado; item que difere é **reportado como conflito e nunca sobrescrito**. Edições do admin são preservadas.
- **Relatório de conflitos**, gravado em `catalogMigrations/v1`:
  - `conflicts`;
  - `unknownReferences`: IDs usados em perfis, pedidos, solicitações, lojas, locações e empresas que não existem no catálogo;
  - `legacyAdminCategories`: documentos da coleção antiga `categories`;
  - contagens.
- **Sem exclusões automáticas.** A coleção `categories` foi congelada (escrita negada) e mantida para inventário.
- **Prestadores:**
  - nenhum é reclassificado: `categories` continua exatamente como estava;
  - quem declarou um grupo (ex.: `mecanico`) aparece no grupo e na categoria, **mas não** em serviços específicos que não declarou (ex.: Freios);
  - o prestador completa as especialidades pela nova tela "Minhas especialidades".
- **Mapa de compatibilidade** (`catalogMeta/legacyIdMap`): `idsPreserved` (os 133 IDs, sem renomear) e `groupNameToCategory` (grupo antigo → categoria nova). A rota de busca continua aceitando o argumento antigo `category`.
- **Reversão** (`rollbackCatalogV1`): explícita, simulação por padrão, exige `confirm:"ROLLBACK_CATALOG_V1"` e remove apenas nós do seed nunca editados. Os campos de busca dos prestadores são aditivos e inofensivos, por isso permanecem.
- **Histórico:**
  - o servidor grava `serviceSnapshot` em pedidos e solicitações novos, via gatilhos `onOrderSnapshot` / `onResolveSnapshot`;
  - o app exibe o nome pelo snapshot, ou pelo catálogo (itens inativos continuam legíveis), ou pelo ID cru;
  - nenhum item do catálogo é apagado pela interface.

## 4. Administração
Aba "Catálogo" no painel admin (`lib/features/admin/catalog_admin_tab.dart`):
- árvore categoria → grupo → serviço;
- criar, editar, subir/descer (reordenar), ativar/desativar (com confirmação e contagem de itens afetados);
- configurar ícone, descrição, sinônimos, palavras-chave, modalidades e orçamento/preço fixo;
- **prévia do cliente** com teste de busca;
- botão "Migração v1" (simulação → executar);
- editor de questionários.

**Garantias:**
- Toda escrita passa pelas callables `catalogUpsert` / `catalogSetActive` / `catalogReorder`, que exigem admin, validam no servidor e gravam em `auditLogs`. As regras negam escrita direta para todos, inclusive admin.
- Desativar recalcula `effectiveActive` da subárvore: o item sai das seleções e as regras negam **novos** pedidos e solicitações com ele (`catalogActive()`). Históricos não são apagados.
- As mudanças chegam em tempo real às telas, sem nova versão do app (verificado no E2E: um serviço criado no admin apareceu no hub aberto sem recarregar).

## 5. Telas conectadas ao catálogo
A constante `Categories.all` **foi removida do app**. As telas abaixo usam o catálogo compartilhado:
- Home;
- hub Serviços;
- Busca;
- cadastro do prestador e a nova tela "Minhas especialidades";
- solicitação direta (bloqueia serviço desativado e operação offline);
- Resolve (seletor em cascata; antes só mostrava os 30 primeiros chips);
- Saúde ("Todos" agora consulta a vertical; Online/Presencial/Home Care e busca por nome filtram de fato);
- Locação;
- Loja;
- Empresa;
- histórico de pedidos (nome pelo snapshot);
- admin.

Componentes reutilizáveis em `lib/core/catalog/`:
- `CatalogBuilder`: estados carregando / erro + tentar novamente / vazio / cache offline / "catálogo atualizado";
- `CatalogChipSelector`: lista rolável no celular; no tablet/desktop quebra em linhas;
- `CatalogDropdownSelector`;
- `CatalogMultiSelect`: preserva especialidades antigas/desativadas e não adiciona nada sozinho;
- `CatalogLabel`.

`CatalogSelection` limpa grupo e serviço incompatíveis ao trocar a categoria. Cada troca de seleção recria a consulta (via `key`), então nunca aparecem resultados antigos enquanto a nova consulta carrega.

## 6. Busca funcional (estratégia e limitações)
**Catálogo:**
- busca local sobre o catálogo inteiro (pequeno, ~180 nós, carregado e em cache);
- tolera acentos, maiúsculas, hífen e espaço (`ar-condicionado` = `ar condicionado` = `arcondicionado`);
- usa sinônimos e palavras-chave (`faxina` → Diarista; `autoelétrico` / `auto elétrica` → Auto Elétrica).

**Profissionais (no servidor, paginada por cursor):**
- O gatilho `onProviderIndex` mantém um único array `searchTokens`: `s:` serviço, `g:` grupo, `c:` categoria, `m:` modalidade, `n:` prefixos do nome normalizado. Também mantém `cityKey`.
- A consulta usa **um** `array-contains` (limite do Firestore), mais cidade, faixa e ordenação. Os demais filtros são conferidos no app durante a paginação, com no máximo 4 lotes por página.
- Se o texto digitado corresponde fortemente a um item do catálogo, a busca usa o serviço; um chip permite trocar para "buscar no nome".

**Empresas:** só verificadas e ativas, por prefixo do nome. Ganharam uma tela pública mínima (`CompanyPublicScreen`).

**Produtos e locação:** não entram na busca; aparecem atalhos claros para as verticais Mercado e Locação.

**Limitações (documentadas):**
- Não é busca textual completa: encontra por início de palavra do nome. Não há tolerância a erro de digitação nem busca dentro da descrição. Busca textual completa exige serviço externo (Algolia, Typesense ou extensão do Firestore), **não configurado** e não simulado.
- Combinar muitos filtros secundários raros pode exigir vários lotes de leitura por página (limitado a 4; o restante vem em "Carregar mais").
- Ordenar por preço exclui quem não informou preço inicial (comportamento do `orderBy` do Firestore, avisado na tela).
- **Distância e disponibilidade não existem** como filtro (não há dados reais); a tela informa isso.

## 7. Filtros e paginação
Filtros disponíveis: categoria, grupo, serviço, cidade (cidades da região), modalidade, avaliação mínima, preço inicial máximo e ordenação (avaliação, nº de avaliações, menor preço).

- Paginação por cursor (`startAfterDocument`), com rolagem infinita e botão "Carregar mais".
- Indicador de carregamento adicional, erro com "Tentar novamente" e "Fim dos resultados".
- Só profissionais `active` e `verified`. As regras também impedem listar pendentes.

**Índices novos** (`firestore.indexes.json`):
- 11 de `providers`: `searchTokens` CONTAINS e/ou `cityKey`, com ordenação por `rating`, `minPrice` ou `totalReviews`;
- 2 de `companies`;
- 1 de `serviceQuestionnaires`.

## 8. Questionários (somente estrutura)
`serviceQuestionnaires/{id}`:
- `serviceId`, `title`, `status` (`draft` / `published` / `archived`), `version`;
- `questions[]` com tipo (text, long_text, number, single_choice, multi_choice, boolean, date, attachment), `required`, `options` e `showIf` (equals / not_equals / in / answered).

**Validação no servidor:** IDs únicos, opções obrigatórias em perguntas de escolha, condição só referencia pergunta **anterior** (impede ciclo e referência inexistente) e o valor da condição precisa ser uma opção válida.

**Versões:** publicar cria uma versão imutável, arquiva a anterior e vincula a nova ao nó do catálogo. Editar uma versão publicada gera um novo rascunho.

O editor no admin avisa que **os questionários ainda não são exibidos aos clientes**; a aplicação nas solicitações fica para a fase do Resolve.

## 9. Estados e cache
- Firestore com persistência offline: o último catálogo fica no aparelho e é **identificado** com a faixa "Offline: exibindo o catálogo salvo…".
- Solicitação direta e Resolve **não enviam** offline (mensagem explícita).
- Erro aparece como erro com "Tentar novamente", nunca como lista fictícia. Catálogo vazio aparece como "Catálogo não configurado".

## 10. Regras
- `catalogNodes` e `catalogMeta`: leitura pública, escrita `false`.
- `catalogMigrations`: só admin lê.
- `serviceQuestionnaires`: publicados públicos, rascunhos só admin.
- `categories` (legado): congelada.
- `orders` (exceto marketplace) e `resolveRequests` exigem `catalogActive(category)` e não aceitam `serviceSnapshot` vindo do app.
- `companies`: `searchTokens` / `cityKey` são exclusivos do servidor.

## 11. Testes executados

| # obrigatório | Teste | Onde | Resultado |
|---|---|---|---|
| 1 | Migração executada duas vezes sem duplicar | `firebase-tests/functions/catalog.test.js` (emulador) + `catalogCore.test.js` | ✅ |
| 2 | IDs antigos preservados (133) | integração + `test/catalog_test.dart` | ✅ |
| 3 | Cadastro no admin aparecendo nas telas | integração (validação, auditoria, versão) + **E2E navegador**: o serviço apareceu no hub aberto sem recarregar | ✅ |
| 4 | Desativação impedindo novas seleções | integração (`effectiveActive` da subárvore), regras (pedido/solicitação negados), widget e E2E (sumiu das seleções) | ✅ |
| 5 | Histórico antigo legível | integração (snapshot mantido após desativar e renomear) + `nameOf` com ID desconhecido | ✅ |
| 6 | Casa → Veículos (Automóveis) → Jurídico sem incompatíveis | `catalog_selection_test.dart` + **E2E** (Casa, Automóveis, Mecânica, Jurídico; grupo limpo) | ✅ |
| 7 | Prestador com múltiplas especialidades | unit JS + Dart + integração (tokens) | ✅ |
| 8 | Busca com acentos e sinônimos | vetores compartilhados (Dart + JS) + **E2E**: faxina, ar-condicionado, ar condicionado, autoelétrico, auto elétrica, "jose" → José Ávila | ✅ |
| 9 | Paginação além da 1ª página | integração (cursor sem login, 45 registros, sem duplicados) + **E2E** (1ª página: 40; "Carregar mais" achou o 45º) | ✅ |
| 10 | Usuário comum impedido de alterar o catálogo | regras (escrita direta negada até para admin) + integração (callables recusam não-admin) | ✅ |
| 11 | Falha de consulta com erro e retry | widget (`CatalogBuilder`: erro → tentar novamente → conteúdo) + merge de streams propagando erro | ✅ |
| 12 | Responsividade mobile e web | widget (360/768/1280 px sem overflow) + E2E (celular 400 px e desktop 1280 px; capturas em `docs/fase2/evidencias/`) | ✅ |

**Totais:**

| Suíte | Resultado |
|---|---|
| Functions unitários (`npm test`) | 33/33 |
| Emulador (regras + integração das Fases 1 e 2) | 49/49 |
| Flutter (`flutter test`) | todos aprovados; o único ignorado (`auth_flow_emulator_test`) passa sob emulador |
| E2E navegador (`firebase-tests/e2e/catalog.e2e.js`) | 16/16 |
| `flutter analyze` | 0 erros (só avisos/infos antigos de estilo e deprecação) |
| Build web hml (release) | OK |

**Como rodar o E2E:** compile `test_driver/e2e_catalog_main.dart` (harness só de dev) com `flutter build web --profile --no-web-resources-cdn --dart-define=APP_ENV=dev`. Como a política de rede deste ambiente bloqueia `www.gstatic.com`, o script serve o SDK JS do Firebase a partir de um pacote npm local.

**Não executados:** builds Android/iOS (sem Android SDK e sem Xcode; previstos para a Fase 7) e validação dos índices num projeto real (não há projeto hml; o emulador não exige índices).

## 12. Aplicar em homologação
1. `firebase deploy --project hml --only firestore:rules,firestore:indexes,functions` (e espere os índices ficarem ativos).
2. Admin: aba Catálogo → "Migração v1" → revise a simulação (conflitos, referências desconhecidas, categorias legadas) → Executar.
3. Publique o app hml **depois** da migração. As regras novas exigem o catálogo para criar pedidos e solicitações.

## 13. Pendências
- Categorias de **produto** do Mercado (Mercado, Farmácia, Pet…) continuam uma lista própria da tela: classificam produtos, não serviços. Unificar junto com o checkout (Fase 3).
- Prestadores com IDs desconhecidos (fora do catálogo) aparecem no relatório da migração e ficam com o token preservado; um admin precisa decidir o destino deles.
- Busca textual completa depende de serviço externo (não configurado).
- O questionário ainda não é aplicado nas solicitações (Fase 4).
- Os banners "SaúdeConecta / EntregaConecta" e as promoções em imagem ficam para a padronização da Fase 6.
