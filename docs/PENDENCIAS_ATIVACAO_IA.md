# Pendências para ativação comercial — Carajás IA

## Bloqueantes
1. Deploy Cloud Functions (`aiAssistant`) — **aguarda GO** (`docs/PLANO_DEPLOY_HOMOLOG_IA.md`).  
2. Rebuild + deploy canal **homolog** (não `live`) — **feito** (URL abaixo); renovar se expirar.  
3. Auth Email/Google + domínio homolog autorizados (SDK real já aplicado no repo).  
4. E2E: cliente/saúde/provider/admin com cartões reais e limites.  
5. Anthropic opcional: exige **Blaze** + Secret Manager; sem isso usar grounded-only.  
6. App Check / OAuth Android (`oauth_client` vazio) se web/Google Sign-In público.

## Fortemente recomendados
6. Job de purge `aiConversations` > 30 dias.  
7. DPIA / revisão jurídica LGPD + texto de consentimento Saúde.  
8. Monitoramento de custo (`aiUsage` dashboard admin).  
9. ~~Rebuild + deploy canal **homolog** com UI Carajás IA.~~ → https://carajas360-a17c5--homolog-88u39zqx.web.app  
10. Não ligar no canal `live` sem GO explícito e evidências.  
11. Hosting **live** hoje: Site Not Found — não confundir com homolog.

## Status oficial
**UI da Central IA visível no homolog.**  
**IA NÃO operacional para turnos reais** até deploy da Function `aiAssistant` + Auth E2E. Sem respostas simuladas fingindo LLM.
