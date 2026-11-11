# Carajás 360 — Expansão Marketplace de Serviços
## Fase 1: Auditoria do projeto existente e plano técnico

Branch: `feat/modernizacao-visual`. Nada publicado; regras e Functions alteradas apenas no repositório (sem deploy).

---

## 1. Estado real do projeto

**Stack:** Flutter 3.44 (Android, iOS, web) + Firebase (Auth, Firestore, Storage, Cloud Functions Gen1 Node, FCM, Hosting). Sem ORM: acesso via `lib/shared/services/firestore_facade.dart` (`FS`) e callables em `functions/index.js`.

**Tamanho:** ~40 mil linhas Dart em 19 módulos, ~2 mil linhas de Functions, 20 testes Dart (135 casos) e 10 suítes JS (115 casos).

**Modo homologação:** com chaves web placeholder, `HomologCatalog` fornece profissionais e locações de demonstração; dados de debug via `DemoData`.

### 1.1 Entidades atuais (coleções Firestore)

| Entidade sugerida | Já existe como | Situação |
|---|---|---|
| ServiceCategory | `Categories.all` (164, em código) + `ServiceTaxonomy` (23 verticais, 28 grupos, 79 serviços, em código) + coleção `serviceTaxonomy` (overlay) + coleção `categories` (sem uso) | Duplicada; admin não persiste; `serviceTaxonomy` sem regra (negada) |
| ServiceOffering | — | Não existe (só `minPrice` no prestador e `suggestedFixedPrice` no serviço) |
| ServiceArea | `providers.city` + `serviceAreas` (texto) | Sem CEP, coordenadas, raio ou bairro estruturado |
| ProviderProfile | `providers` | Existe; sem estados pendente/rejeitado/suspenso |
| CompanyProfile | `companies`, `employees`, `branches`, `contracts` | Existe; funcionário sem vínculo com usuário |
| ServiceRequest | `orders` (pedido direto) e `resolveRequests` (pedido aberto) | Dois conceitos paralelos |
| Quote | `resolveProposals` | Existe; aceitar não gera pedido |
| Booking | `bookings` (locação) e `appointments` (saúde, sem data) | Não existe para serviços |
| Payment | `payments`, `webhookEvents` | Backend Mercado Pago pronto, desligado; não ligado a pedidos na interface |
| Commission | calculada no repasse (`config/platform.commissionRate`, padrão 8%) | Existe |
| Payout | `transactions/payout_{orderId}`, `withdrawalRequests` | Crédito em carteira interna; saque manual |
| Review | `reviews` + trigger `updateProviderRating` | Existe |
| RecurringPlan | — | Não existe |
| SupportTicket | `support`, `disputes` | Existe; disputa sem tela de acesso nem aba no admin |
| AuditLog | `auditLogs` | Existe (imutável) |

### 1.2 Mapa dos 12 módulos pedidos

| Módulo | Pronto / reutilizável | Falta |
|---|---|---|
| 1. Carajás Serviços | Taxonomia com perguntas dinâmicas e `pricingMode`; Home, Explorar e perfil do profissional no novo design | Taxonomia única no Firestore; CRUD pelo admin; duração e regras de agenda por categoria; das 18 categorias pedidas, faltam montador de móveis, paisagismo, chaveiro e lavagem de estofados; as demais já existem |
| 2. Localização por CEP | Seletor de cidade (7 cidades fixas); `UserModel.lat/lng`; `ServiceMatching` aceita raio (não usado) | Consulta de CEP, geocodificação, coordenadas/geohash e área de cobertura do prestador, ordenação por proximidade, coleção `cities` |
| 3. Orçamento inteligente | `ServiceQuestion` (7 tipos), `pricingMode`, IA de descrição e estimativa | Tabela de preços do prestador; fórmula base + adicionais + deslocamento + taxas − descontos; `multiChoice` não renderizado |
| 4. Contratação multicanal | Máquina de estados no servidor; pedido assistido por IA com idempotência | Campo de origem; registro assistido por atendente; WhatsApp (não existe); funil único |
| 5. Agendamento | Locação tem reservas com bloqueio de datas | Agenda do prestador, slots, conflito transacional, reagendamento, lembretes, recorrência |
| 6. Pagamentos e comissões | PIX, cartão (tokenizado), carteira, repasse idempotente, webhook assinado, trava de chave de produção | Pagamento ligado ao pedido; escrow aplicado; estorno real; saque; split; conciliação; relatórios |
| 7. Painel do profissional | Online/offline, novos pedidos (aceitar/recusar), iniciar/concluir, ganhos | Agenda, propostas, financeiro, documentos, serviços e preços, estados de cadastro |
| 8. Painel das empresas | Cadastro, equipe, filiais, contratos | Equipe ligada a usuários, permissões, distribuição de pedidos, agenda compartilhada, isolamento |
| 9. IA | Callables Anthropic (chat, pedido assistido, rascunho de proposta) com cota | Consultar APIs reais (tool-calling), consentimento LGPD registrado, encaminhamento humano |
| 10. Administração | 10 abas: usuários, validação, categorias, financeiro, marketing, atendimento, denúncias, pedidos, auditoria, configurações (comissão) | Disputas, saques, rejeitar prestador, ver documentos (bug), KPIs por cidade/categoria, kill switch na interface, `maintenanceMode` aplicado |
| 11. Recorrentes | — | Tudo |
| 12. Vitrine 360 | — | Tudo (IDs compartilháveis, deep links, API autenticada) |

### 1.3 Mapa das 10 telas pedidas

| Tela | Base existente | Estado |
|---|---|---|
| 01 Home Carajás Serviços | `HomeScreen` (`carajas_home_screen.dart`) | Novo design pronto; falta localização por CEP |
| 02 Busca por CEP | `UniversalSearchScreen` | Busca/filtros prontos; CEP e proximidade faltam |
| 03 Catálogo de Profissionais | `UniversalSearchScreen` (grade/lista) | Pronto; disponibilidade falta |
| 04 Perfil do Profissional | `ProviderProfileScreen` | Pronto; faltam serviços com preço (ServiceOffering) |
| 05 Orçamento Inteligente | `ServiceRequestFlowScreen` + `RequestServiceScreen` | Duas telas a unificar; sem cálculo |
| 06 Agendamento | — | Nova |
| 07 Contratação e Pagamento | `PixScreen`, `CardPaymentScreen` | Não ligadas a pedidos; checkout novo |
| 08 Acompanhamento | `MyOrdersScreen` | Sem detalhe do pedido, pagamento, chat ou disputa |
| 09 Painel do Profissional | `ProviderHomeScreen` | Parcial, tema antigo |
| 10 Painel Administrativo | `AdminScreen` | Parcial, tema antigo |

---

## 2. Defeitos e riscos encontrados

### Corrigidos nesta fase (apenas no repositório, sem deploy)

| # | Problema | Correção |
|---|---|---|
| C1 | Cliente podia zerar a comissão gravando `commissionRate`, `commissionExempt` ou `billingMode` no pedido; o repasse usava esses valores | Repasse usa só `config/platform` (ou 8%); app deixa de gravar; regra bloqueia os três campos; teste estático adicionado |
| C2 | Avaliação feita em "Meus pedidos" era gravada sem `providerId`; a nota do profissional nunca era recalculada | Tela passa o `providerId` do pedido |

### P0 — bloqueiam operação real ou expõem dados

| # | Problema | Evidência |
|---|---|---|
| P0-1 | **Pedido direto não fecha**: nenhuma tela define preço, pede ou faz pagamento; concluir exige pedido pago | `orderPolicy.js:217-230`; `PixScreen` usa `orderId` sintético (`wallet_screen.dart:636`) |
| P0-2 | **Aceitar proposta (Resolve) não cria pedido**: sem acompanhamento, pagamento ou avaliação | `firestore_facade.dart` `acceptResolveProposal` |
| P0-3 | **Endereço e nome do cliente legíveis por qualquer usuário logado** em pedidos abertos; também fura a cobrança por lead | `firestore.rules:384-395` |
| P0-4 | **Webhook credita `userId` e créditos vindos do corpo**, sem consultar o Mercado Pago (pagamentos estão desligados; não ligar antes de corrigir) | `functions/index.js:1840-1905` |
| P0-5 | Transições perigosas: `completed → cancelled` sem estornar repasse; `cancelled → accepted`; qualquer usuário aceita pedido sem `providerId`; repasse imediato sem custódia | `orderPolicy.js:30-40,182-216`; `index.js:447-458` |
| P0-6 | Coleções sem regra (acesso negado): `serviceTaxonomy`, `leadUnlocks`, `creditPurchases`, `highlightPurchases` | `firestore.rules:464` |
| P0-7 | Escritas sem validação: prestador cria perfil com `rating`/`totalReviews`; qualquer usuário cria proposta; cliente confirma a própria reserva | `firestore.rules:76-81,411-430,158-168` |
| P0-8 | Kill switch financeiro não cobre PIX, cartão, carteira, saque e repasse | `index.js` |

### P1 — riscos e defeitos relevantes

- Matching de "Ver profissionais compatíveis" sempre vazio em produção (`service_marketplace_screen.dart:386`).
- Admin não vê documentos do prestador (lê campo `documents` inexistente) e não pode rejeitar.
- `providerHome` não verifica se o usuário é prestador.
- Chave do Google Maps usada direto no app para Directions; GPS de pedido de serviço sempre simulado.
- Plano PRO envia `tier` em vez de `plan` (servidor entende "free"); preços de planos inconsistentes entre telas.
- Estorno só marca o pedido; relatório de estornos sempre zero.
- Índices compostos possivelmente ausentes (`orders` por status + data, por prestador + status) — conferir no console.
- Admin lê todos os pedidos concluídos (custo e escala).
- Três telas criam pedido aberto com campos diferentes; duas telas de oportunidades (uma sem rota).
- ~80% das telas ainda no tema azul antigo.

---

## 3. Plano técnico por fases

Ordem pensada para que cada fase entregue um fluxo utilizável de ponta a ponta, sem quebrar o que já funciona. Tudo atrás de flags em `config/platform`.

### Fase 2 — Base operacional e segurança (P0 + P1)

1. **Fechar o pedido (P0-1, P0-2, P0-5)**: proposta de preço do prestador → aceite do cliente → pagamento ligado ao `orderId` (PIX/cartão/carteira, ou "pagamento presencial" se aprovado) → execução → conclusão → avaliação. Resolve aceita proposta e cria o pedido. Revisar transições e aplicar custódia.
2. **Privacidade dos leads (P0-3)**: dados de contato do pedido aberto em subdocumento privado, liberado após desbloqueio ou aceite.
3. **Regras (P0-6, P0-7)** com testes no emulador.
4. **Taxonomia única no Firestore**: unificar `Categories` e `ServiceTaxonomy`, migração idempotente, CRUD no admin, campos por categoria (duração, critérios de orçamento, regras de agenda).
5. **Prestador**: estados pendente/aprovado/suspenso/rejeitado, admin vê documentos e rejeita com motivo.
6. **Localização**: Function proxy de CEP (ViaCEP com fallback BrasilAPI, cache), coleção `cities`, área de cobertura do prestador (cidades, bairros, raio + geohash), filtro e ordenação por proximidade; deslocamento real só com rota.
7. **Matching em produção** e unificação dos fluxos de pedido aberto.

### Fase 3 — Contratação (Telas 05, 06, 08)

- `serviceOfferings` (tabela de preços do prestador) e cálculo base + adicionais + deslocamento + taxas − descontos; sem tabela, orçamento personalizado.
- Agenda: disponibilidade semanal, bloqueios, duração, intervalos, reserva de horário em transação (sem conflito), revalidação na confirmação, reagendamento e cancelamento com regras.
- Detalhe do pedido com status, chat, suporte, disputa e avaliação.

### Fase 4 — Financeiro (Tela 07)

- Webhook consultando o Mercado Pago (P0-4) e catálogo de pacotes no servidor; kill switch em todas as operações (P0-8).
- Comissão por categoria e por profissional/empresa (configurável); extrato; repasses; estornos reais; conciliação; relatórios.
- Split somente via Mercado Pago Marketplace, se a conta for habilitada.

### Fase 5 — IA e multicanal

- Assistente com consultas às APIs reais (categorias, profissionais, preços, agenda, status); nunca confirma preço ou horário sem o backend; registro de consentimento; encaminhamento humano.
- Campo `origin` em todo pedido (app, site, WhatsApp, telefone, presencial, IA) e registro assistido por atendente; WhatsApp Business só com conta autorizada.

### Fase 6 — Expansão

- Recorrência (contratos, calendário, sem cobrança automática sem autorização expressa).
- Painel de empresas multiusuário com isolamento; KPIs por cidade e categoria no admin.
- Preparação Vitrine 360: IDs públicos estáveis, deep links, API autenticada (sem alterar o Vitrine 360).

### Prioridades

| Prioridade | Itens |
|---|---|
| P0 | P0-1 a P0-8 (Fase 2, itens 1–3) |
| P1 | Taxonomia única, estados do prestador, CEP e cobertura, matching, unificação de fluxos (Fase 2, itens 4–7) |
| P2 | Orçamento por tabela, agenda, detalhe do pedido, financeiro completo (Fases 3–4) |
| P3 | IA com ferramentas, multicanal, recorrência, empresas, Vitrine 360, demais telas no novo design (Fases 5–6) |

---

## 4. Estratégia de dados, backup e reversão

- **Antes de qualquer migração**: export gerenciado do Firestore (`gcloud firestore export gs://<bucket>`; exige plano Blaze e bucket — configuração externa).
- Migrações como scripts idempotentes versionados (`scripts/migrations/NNN_*.js`) com modo `--dry-run`, executados primeiro no emulador e depois em staging.
- Apenas campos e coleções novos; nada é apagado. Leitura compatível com o formato antigo até a migração terminar.
- Novas funcionalidades atrás de flags em `config/platform`; reversão = desligar a flag e, se preciso, restaurar o export.
- Regras e Functions só sobem com autorização explícita, após testes no emulador.

---

## 5. Decisões comerciais necessárias (não serão inventadas)

1. Percentual de comissão por categoria e se profissional/empresa podem ter taxa própria.
2. Se "pagamento presencial" e "pagar após a conclusão" serão permitidos e como a comissão é cobrada nesses casos.
3. Regras de cancelamento e reembolso (prazos e multas).
4. Prazo de custódia antes do repasse e forma de saque.
5. Tabela e preços de planos/créditos (hoje divergentes entre telas).
6. Confirmação do Mercado Pago como provedor e se a conta terá Marketplace (split).
7. WhatsApp Business: se haverá conta oficial e número.

## 6. Validação desta fase

| Verificação | Resultado |
|---|---|
| `flutter analyze` | PASS — 0 erros, 150 avisos (linha de base) |
| `flutter test` | PASS — 135 aprovados, 1 ignorado |
| `npm test` (Functions + auditoria das regras) | PASS — 116 aprovados |
| Regras e Functions no emulador | NOT TESTED |
| Deploy | NOT APPLICABLE — não autorizado |
