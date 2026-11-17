# Pendências para o programador — Carajás 360 (FASE 16)

**HEAD:** `a95b2e5` · **App:** `1.0.0+403` · **Firebase:** `carajas360-a17c5`  
Baseline: `docs/FASE15_AUDITORIA_DEFINITIVA.md` + revalidação FASE 16.

Legenda: **P0** bloqueia publicação/segurança · **P1** funcionalidade importante · **P2** melhoria.

---

## P0

### P0-1 Live Web 404
- **Problema:** `carajas360-a17c5.web.app` retorna 404.  
- **Módulo:** Hosting.  
- **Causa:** Nenhuma release live.  
- **Solução:** Deploy com GO (`scripts/live_web_deploy.ps1 -IAuthorizeLiveDeploy`).  
- **Dependências:** GO contratante.  
- **Aceite:** HTTP 200 + rotas principais.

### P0-2 Blaze / Cloud Functions API 403
- **Problema:** Functions não listáveis/deployáveis.  
- **Módulo:** Firebase backend.  
- **Causa:** `billingEnabled: false`.  
- **Solução:** Owner upgrade Blaze + habilitar Cloud Functions / Build / Artifact Registry.  
- **Dependências:** Conta Google owner.  
- **Aceite:** `firebase functions:list` OK; deploy de ao menos `aiAssistant`.

### P0-3 Storage produção
- **Problema:** Bucket Storage não provisionado; upload live impossível.  
- **Módulo:** Orçamento fotos (`orders/{id}/photos/`).  
- **Arquivos:** `storage.rules`, `FS.uploadOrderPhoto`.  
- **Causa:** Billing / Storage not set up.  
- **Solução:** Criar bucket + `firebase deploy --only storage`.  
- **Dependências:** P0-2.  
- **Aceite:** Upload real + leitura cliente/pro + deny estranho.

### P0-4 Carajás IA sem LLM
- **Problema:** UI existe; turno real não comprovado.  
- **Arquivos:** `lib/shared/services/ai_service.dart`, `functions` `aiAssistant`.  
- **Solução:** Deploy Function + secret Anthropic opcional (fallback grounded).  
- **Dependências:** P0-2.  
- **Aceite:** Resposta real + profissionais grounded; sem inventar preço.

### P0-5 Pagamentos sandbox
- **Problema:** Código/unit OK; E2E sandbox N/E.  
- **Arquivos:** `functions` pagamentos/webhook; `payment_gateway.dart`.  
- **Solução:** Token TEST + `PAYMENTS_ENABLED=true` só sandbox; `PRODUCTION_PAYMENTS_ENABLED=false`.  
- **Dependências:** P0-2 + conta MP.  
- **Aceite:** PIX/cartão/webhook sandbox com logs.

### P0-6 Android release
- **Problema:** AAB/APK deste HEAD não gerados.  
- **Módulo:** `android/`.  
- **Solução:** Disco + `key.properties` (não versionar) + `flutter build appbundle`.  
- **Aceite:** AAB + SHA256 + instalação em device.

### P0-7 iOS / TestFlight
- **Problema:** IPA não gerado (entrega feita em Windows).  
- **Módulo:** `ios/`.  
- **Solução:** macOS + Xcode + Apple Developer.  
- **Aceite:** Build no TestFlight + smoke device.

---

## P1

| ID | Problema | Módulo | Solução | Aceite |
|----|----------|--------|---------|--------|
| P1-1 | Vídeo no orçamento ausente | Solicitação | Picker + Storage + preview | Upload validado |
| P1-2 | Áudio no orçamento ausente | Solicitação | Reusar padrão do chat | Áudio no order |
| P1-3 | E2E cliente N/E | Fluxos | Contas teste + roteiro | Fluxo completo |
| P1-4 | E2E profissional N/E | Provider | Conta pro + admin | Até recebimento |
| P1-5 | E2E admin N/E | Admin | Conta admin | Disputas/pagamentos |

---

## P2

| ID | Problema | Solução |
|----|----------|---------|
| P2-1 | Paridade visual premium N/E | Só se aditivo |
| P2-2 | Widget tests instáveis (histórico) | Estabilizar CI |
| P2-3 | OAuth domains | Console Auth |
| P2-4 | Domínio custom | DNS + Hosting |

---

## Já comprovado (não reabrir sem regressão)

- Functions unitários **163/163**.  
- Fotos orçamento: unitários + E2E **emuladores** (upload/ACL/delete).  
- Homolog Web **HTTP 200**.  
- Firestore rules de `photoUrls` deployadas.
