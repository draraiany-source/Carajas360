# AUDITORIA_TELAS_CARAJAS360 — FASE 1

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual` (`880e47a`)  
**Projeto Firebase:** `carajas360-a17c5`  
**App:** Flutter multiplataforma (`android` / `ios` / `web`) — pacote `carajas_360`  
**IDs nativos:** Android/iOS `br.com.carajas360`  

**Regra desta fase:** inventário e status por evidência de código — **não** declarar pronto só porque a UI aparece.

---

## 1. Arquitetura real

| Camada | Tecnologia |
|--------|------------|
| Cliente | Flutter (Web, Android, iOS) |
| Auth / DB / Storage / Push | Firebase Auth, Firestore, Storage, Messaging, Analytics, Crashlytics |
| Backend | Cloud Functions (`functions/`, região `us-central1`) |
| Rotas | `Routes` em `lib/core/constants/app_constants.dart` + `onGenerateRoute` em `lib/main.dart` |
| Shell | `MainNav` — Início / Explorar / Pedidos / Mensagens / Perfil + FAB Carajás IA |
| Dados | `FS.*` (Firestore), `CloudFn` / `PaySvc` (callables), `AiSvc` → `aiAssistant` |

### Ambiente observado
| Ambiente | Status |
|----------|--------|
| Homolog Hosting | Ativo: `https://carajas360-a17c5--homolog-88u39zqx.web.app` |
| Live Hosting | **Site Not Found** |
| Function `aiAssistant` | **Não deployada** (API Cloud Functions / Blaze pendentes) |
| Profissionais na Web | Corrigido em `880e47a` (REST + Future cache + índices) — evidência em `docs/evidence/homolog_ia/explorar_profissionais_ok.png` |

---

## 2. Pastas de features (`lib/features/`)

| Pasta | Papel |
|-------|--------|
| `admin` | Painel administrativo (abas) |
| `ai_assistant` | Central IA, FAB, personagem |
| `auth` | Onboarding, login, registro, splash (órfã) |
| `chat` | Inbox e sala |
| `company` | Perfil empresa |
| `gps` | Rastreamento / conclusão |
| `health` | Saúde + agenda aninhada |
| `home` | Home premium + hub serviços |
| `marketplace` | Mercado / lojas |
| `monetization` | Créditos, PRO, destaques, disputas (cliente), oportunidades |
| `orders` | Pedidos, favoritos, fluxo de orçamento |
| `profile` | Perfil, notificações, avaliações |
| `provider` | Área e perfil do profissional |
| `rental` | Locação e reservas |
| `resolve` | Pedidos Resolve + assistido |
| `search` | Explorar / busca universal |
| `services` | Marketplace de categorias |
| `support` | Suporte, cupons, delivery |
| `wallet` | Carteira / PIX / cartão |

---

## 3. Abas MainNav (sem rota nomeada quando embutidas)

| Aba | Widget | Arquivo | Auth | Dados | Estado |
|-----|--------|---------|------|-------|--------|
| Início | `HomeScreen` | `home/carajas_home_screen.dart` | Aberto | `providersStream`, user, notif | **parcial** (IA CTA OK; modules “em breve”) |
| Explorar | `UniversalSearchScreen` | `search/universal_search_screen.dart` | Aberto | `providersStream` (+ REST Web) | **parcial** → carga OK no homolog pós-fix |
| Pedidos | `MyOrdersScreen` | `orders/orders_screen.dart` | Gate na tela | pedidos, pagamento, disputa | **parcial** (pagamentos dependem de CF/MP) |
| Mensagens | `ChatInboxScreen` | `chat/chat_inbox_screen.dart` | Gate na tela | `chatRoomsStream` | **funcional** |
| Perfil | `ProfileScreen` | `profile/profile_screens.dart` | Aberto | `userStream` | **funcional** |

---

## 4. Inventário de rotas nomeadas

Legenda de estado: **funcional** | **parcial** | **quebrada** | **ausente**

| Rota | Tela | Arquivo | Auth | Dados / APIs | Ações principais | Estado | Problemas / testes |
|------|------|---------|------|--------------|------------------|--------|-------------------|
| `/` | `MainNav` | `main.dart` | — | shell | abas | **parcial** | `SplashScreen` existe mas **não** é usada |
| `/onboarding` | `OnboardingScreen` | `auth/auth_screen.dart` | — | local | continuar | **funcional** | E2E visitante |
| `/login` | `LoginScreen` | `auth/auth_screen.dart` | — | Auth, `FS.saveUser` | entrar, Google/Apple | **parcial** | Domínio homolog Auth; OAuth |
| `/register` | `RegisterScreen` | `auth/auth_screen.dart` | — | user + provider profile | criar conta | **funcional** | Fluxo profissional |
| `/main` | `MainNav` | `main.dart` | — | shell | abas | **funcional** | — |
| `/search` | `UniversalSearchScreen` | `search/…` | — | providers | buscar, IA, orçamento | **parcial** | Filtros, paginação, cache Web |
| `/universal-search` | idem | idem | — | idem | idem | **parcial** | Alias |
| `/chat` | `ChatScreen` | `chat/chat_screen.dart` | RequireAuth | messages | enviar mídia/áudio | **parcial** | Fallback `roomId: demo` |
| `/chat-inbox` | `ChatInboxScreen` | `chat/chat_inbox_screen.dart` | RequireAuth | rooms | abrir sala | **funcional** | — |
| `/wallet` | `WalletScreen` | `wallet/wallet_screen.dart` | RequireAuth | wallet, `walletOp` | PIX, saque, créditos | **parcial** | CF + Mercado Pago |
| `/profile` | `ProfileScreen` | `profile/…` | — | user | módulos, export | **funcional** | LGPD export/delete |
| `/notifications` | `NotificationsScreen` | `profile/…` | RequireAuth | notif | marcar lida | **funcional** | Guest demo |
| `/reviews` | `ReviewScreen` | `profile/…` | RequireAuth | `saveReview` | avaliar | **parcial** | `orderId` default demo |
| `/health` | `HealthScreen` | `health/…` | — | providers, appointments | agendar | **parcial** | Agenda só aninhada |
| `/delivery` | `DeliveryScreen` | `support/…` | — | `createOrder` | pedir | **parcial** | Não é frota completa |
| `/marketplace` | `MarketplaceScreen` | `marketplace/…` | — | products | comprar | **parcial** | Gateway |
| `/store` | `StoreScreen` | `marketplace/store_screen.dart` | — | store/products | CRUD | **funcional** | Dono |
| `/stores` | `StoresListScreen` | idem | — | stores | abrir perfil | **funcional** | Nested profile |
| `/rental` | `RentalScreen` | `rental/…` | — | rentals | reservar | **parcial** | Nested detail |
| `/bookings` | `MyBookingsScreen` | `rental/…` | RequireAuth | bookings | aceitar/recusar | **funcional** | — |
| `/admin` | `AdminScreen` | `admin/…` | AdminGate | KPIs, users, finance… | aprovar, export | **parcial** | Sem fila `disputes`/saques |
| `/gps` | `GpsScreen` | `gps/…` | — | gps, order | concluir | **parcial** | Contexto demo |
| `/support` | `SupportScreen` | `support/…` | RequireAuth | tickets | abrir ticket | **funcional** | — |
| `/coupons` | `CouponsScreen` | `support/…` | — | coupons | validar | **parcial** | Lista demo |
| `/ai` | `AiAssistantScreen` | `ai_assistant/…` | Aberto (callable auth) | `AiSvc` → `aiAssistant` | chat, atalhos | **quebrada*** | *UI OK; turno real sem Function |
| `/company` | `CompanyProfileScreen` | `company/…` | RequireAuth | company… | salvar | **parcial** | Leads stub |
| `/favorites` | `FavoritesScreen` | `orders/favorites_…` | RequireAuth | favorites | abrir | **funcional** | — |
| `/my-orders` | `MyOrdersScreen` | `orders/…` | RequireAuth | orders + pay | pagar, GPS, review | **parcial** | Pagamentos |
| `/request-service` | `QuoteRequestFlowScreen` | `orders/service_request_…` | RequireAuth | `createOrder` | enviar | **funcional** | — |
| `/provider-profile` | `ProviderProfileScreen` | `provider/…` | — | provider, reviews | solicitar | **funcional** | — |
| `/provider-home` | `ProviderHomeScreen` | `provider/…` | RequireAuth | provider orders | aceitar… | **funcional** | — |
| `/provider-onboarding` | `ProviderOnboardingScreen` | `provider/…` | — | upload docs | enviar | **funcional** | — |
| `/services-hub` | `ServicesHubScreen` | `home/home_screen.dart` | — | modules | categorias | **funcional** | — |
| `/service-marketplace` | `ServiceMarketplaceScreen` | `services/…` | — | taxonomy, Resolve | solicitar | **funcional** | — |
| `/service-request-flow` | — | — | — | — | — | **ausente** | Constante sem `case`; UI via push |
| `/resolve` | `ResolveScreen` | `resolve/…` | — | resolveRequests | publicar | **funcional** | — |
| `/resolve-detail` | `ResolveDetailScreen` | `resolve/…` | RequireAuth | proposals, accept CF | aceitar | **funcional** | id vazio → My Resolve |
| `/resolve-opportunities` | `OpportunitiesHubScreen` | `monetization/…` | RequireAuth | oportunidades, AI draft | propor | **parcial** | AI draft sem Function |
| `/my-resolve` | `MyResolveScreen` | `resolve/…` | RequireAuth | my requests | detalhe | **funcional** | — |
| `/opportunity-detail` | — | — | — | — | — | **ausente** | Widget existe; rota não ligada |
| `/credit-packages` | `CreditPackagesScreen` | `monetization/…` | RequireAuth | purchase CF | comprar | **parcial** | Webhook |
| `/carajas-pro` | `CarajasProScreen` | idem | RequireAuth | plan change | assinar | **parcial** | Pedido, não cobrança instantânea |
| `/highlights-buy` | `HighlightsBuyScreen` | idem | RequireAuth | highlight CF | comprar | **parcial** | Idem |
| `/dispute-help` | `DisputeHelpScreen` | idem | RequireAuth | `disputes` | enviar | **parcial** | Sem inbox admin |
| `/assisted-request` | `AssistedRequestScreen` | `resolve/assisted_…` | RequireAuth | AiSvc assist* | gerar/publicar | **parcial** | Functions IA |
| desconhecida | `MainNav` | `main.dart` | — | — | — | **parcial** | Silencia erros de deep link |

---

## 5. Admin — abas internas (`AdminScreen`)

| Aba | Função | Dados | Estado |
|-----|--------|-------|--------|
| Usuários | Suspender/reativar | `adminUsersStream` | **funcional** |
| Validação | Aprovar providers/empresas | pending streams | **funcional** |
| Categorias | Taxonomia | publish/save | **funcional** |
| Financeiro | Relatório / export | `fetchFinancialReport` | **parcial** |
| Marketing | Banners / cupons | banners, coupons | **funcional** |
| Atendimento | Tickets | support | **funcional** |
| Denúncias | Reports de usuário | `reportsStream` | **parcial** — **não** é `disputes` |
| Pedidos | Reabrir/cancelar | orders admin | **funcional** |
| Auditoria | Logs | `auditLogStream` | **funcional** |
| Configurações | Platform config | config stream | **funcional** |

---

## 6. Telas aninhadas (sem rota `Routes.*`)

| Widget | Entrada | Nota |
|--------|---------|------|
| `SplashScreen` | órfã | Não ligada a `/` |
| `PixScreen` / `CardPaymentScreen` | push wallet/orders | Pagamento |
| `AppointmentsScreen` | Health | Agenda |
| `OpportunityDetailScreen` | hub oportunidades | Constante não wired |
| `ServiceRequestFlowScreen` | search/hub | Constante não wired |
| `LegalScreen` / `ReferralScreen` / `ThemeSettingsScreen` | perfil | — |
| `StoreProfileScreen` | lista lojas | — |
| `RentalDetailScreen` / `MyRentalsScreen` | rental | — |

---

## 7. Checklist de auditoria × cobertura

| Item solicitado | Situação |
|-----------------|----------|
| Página inicial | Existe — Home |
| Explorar / busca / filtros | Existe — UniversalSearch |
| Perfil profissional | Existe — `/provider-profile` |
| Login / cadastro / onboarding profissional | Existe |
| Orçamento / propostas / contratação | Existe (quote + Resolve + provider home) |
| Pagamento | Existe (wallet/PIX/cartão) — **parcial** ops |
| Meus pedidos / mensagens / avaliações / favoritos | Existe |
| Agenda dedicada | **Ausente** como rota — só nested Health |
| Central IA | UI existe — **runtime quebrado** sem Function |
| Notificações / suporte / termos | Existe |
| Admin users/categorias/pagamentos | Abas admin — disputas/saques **falta** |
| Relatórios admin | Parcial (financeiro/auditoria) |
| Gestão de disputas (ops) | **Ausente** no admin |
| Vagas / fretes / imóveis / obras / kids | **Ausente** (“em breve”) |

---

## 8. Pagamentos e Functions relevantes

Callables: `generatePix`, `checkPayment`, `processCardPayment`, `payOrderWithWallet`, `walletOp`, `processRefund`, `purchaseCreditPackage`, `purchaseHighlight`, `requestPlanChange`, `aiAssistant`, `assistServiceRequest`, `publishAssistedRequest`, `assistProposalDraft`, `acceptResolveProposal`, …  

HTTP: `mercadoPagoWebhook`.  

**Não** marcar pagamento aprovado só pelo frontend.

---

## 9. Android / iOS (existência)

| Plataforma | Evidência | Status auditoria |
|------------|-----------|------------------|
| Android | `android/`, `applicationId br.com.carajas360` | Projeto existe — AAB/assinatura **não** auditados nesta fase |
| iOS | `ios/`, bundle `br.com.carajas360` | Projeto existe — IPA/TestFlight **não** gerados nesta fase; exige macOS + Apple Developer |

---

## 10. Riscos priorizados (próximas fases)

| Prioridade | Item |
|------------|------|
| P0 | Deploy `aiAssistant` (+ assist) após Blaze/API |
| P0 | Hosting **live** (hoje Site Not Found) — só com GO |
| P0 | Pagamentos: token MP, `PAYMENTS_ENABLED`, webhook, fila de saque |
| P1 | Ligar rotas órfãs `/service-request-flow`, `/opportunity-detail` | **FASE 2 ✓** |
| P1 | Admin de `disputes` + refunds | **Disputas ✓** (refunds → FASE 3+) |
| P1 | Agenda como rota se produto exigir | **FASE 2 ✓** `/appointments` |
| P2 | Remover `demo` IDs / DemoData em caminhos sensíveis | **FASE 2 ✓** chat/reviews/GPS |
| P2 | Unificar UIs duplicadas de oportunidades | parcial (hub → rota nomeada) |
| P3 | Modernização visual nas telas ainda densas (admin/financeiro) |

---

## 11. Conclusão da FASE 1

- O Carajás 360 **já é** um app Flutter completo com dezenas de telas e rotas reais — **não** precisa ser recriado.  
- Lacunas críticas para comercialização: **IA runtime**, **live hosting**, **pagamentos/ops**, **disputas admin**.  
- Homolog Web com Explorar + profissionais reais e UI da IA **já comprovados**; turnos LLM **não**.  

**FASE 2 concluída** — `docs/RELATORIO_FASE2_ORGANIZAR_TELAS.md`.  
**FASE 3 concluída** — `docs/RELATORIO_FASE3_TELA_POR_TELA.md`.  
**FASES 4–11 (código + docs)** — `docs/RELATORIO_FASES_4_A_11.md`, `docs/MATRIZ_HOMOLOGACAO_FASE10.md`, `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md`.  

**Ainda exigem GO:** live hosting, deploy Functions/IA, pagamentos produção, AAB/IPA.

---

*Arquivo gerado na FASE 1 do Prompt Mestre de Finalização. Evidências: `docs/RELATORIO_CORRECAO_PROFISSIONAIS_E_IA.md`, `docs/RELATORIO_FASE2_ORGANIZAR_TELAS.md`, `docs/RELATORIO_FASE3_TELA_POR_TELA.md`, `docs/RELATORIO_FASES_4_A_11.md`, `docs/evidence/homolog_ia/`.*
