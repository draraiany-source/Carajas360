# Pacote de entrega — Carajás 360 (programador)

**Projeto Firebase:** `carajas360-a17c5`  
**App:** Flutter `carajas_360` · Android/iOS `br.com.carajas360`  
**Branch de trabalho:** `feat/modernizacao-visual`  
**Homolog Web:** `https://carajas360-a17c5--homolog-88u39zqx.web.app`  
**Live Hosting:** Site Not Found (não publicar sem GO)

---

## 1. Inventário de telas e rotas

Fonte canônica: `docs/AUDITORIA_TELAS_CARAJAS360.md`.

## 2. Mapa de navegação (fluxo cliente)

```
MainNav(Início)
  → Explorar (/search)
  → Perfil profissional (/provider-profile)
  → Orçamento (/request-service)
  → Chat (/chat) e/ou Meus pedidos (/my-orders)
  → Pagar (carteira/PIX/cartão via CF)
  → GPS (/gps) → Avaliar (/reviews)

Resolve: /resolve → /resolve-detail → acceptResolveProposal → /my-orders
IA: FAB / /ai (UI; runtime depende de Function)
Admin: /admin (AdminGate) + aba Disputas
```

## 3. Relatórios de correção

| Doc | Fase |
|------|------|
| `RELATORIO_CORRECAO_PROFISSIONAIS_E_IA.md` | IA UI + profissionais |
| `RELATORIO_FASE2_ORGANIZAR_TELAS.md` | Rotas / demo / disputas |
| `RELATORIO_FASE3_TELA_POR_TELA.md` | UX fluxo cliente |
| `RELATORIO_FASES_4_A_11.md` | Fases 4–11 |
| `MATRIZ_HOMOLOGACAO_FASE10.md` | Testes |

## 4. Status por plataforma

| Plataforma | Status |
|------------|--------|
| Web homolog | Canal ativo |
| Web live | Pendente GO |
| Android | Projeto OK; AAB N/E |
| iOS | Projeto OK; IPA/TestFlight N/E (macOS + Apple Developer) |

## 5. Pendências de publicação

1. GO Blaze + secrets Anthropic/MP  
2. Deploy Functions (`aiAssistant`, pagamentos se autorizado)  
3. GO hosting live  
4. Keystores / provisioning profiles  
5. Domínios Auth OAuth homolog/prod  
6. `PAYMENTS_ENABLED` + `PRODUCTION_PAYMENTS_ENABLED` só com política comercial

## 6. Instalação e compilação

```bash
flutter pub get
flutter run -d chrome          # ou dispositivo
flutter build web --release
flutter build appbundle        # Android (assinatura local)
# iOS: abrir ios/Runner.xcworkspace no Xcode (macOS)
```

Homolog Web (script existente): `scripts/homolog_web_preview.ps1`

Functions:

```bash
cd functions && npm test
# deploy somente com GO: firebase deploy --only functions:...
```

## 7. Segurança

- Não versionar `.env`, tokens MP, chaves Anthropic, keystores.  
- Webhook MP não credita a partir do body (exige `payments/{id}` + aprovado na API).  
- Frontend não marca pedido como pago sozinho.

## 8. IA

- Cliente: `AiSvc` → callable `aiAssistant` (sem chave no app).  
- Sem Function deployada: UI responde erro honesto + retry.
