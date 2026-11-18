# Entrega ao programador — Carajás 360 (Fase 17)

**Repositório:** https://github.com/draraiany-source/Carajas360  
**Branch:** `feat/modernizacao-visual`  
**Firebase:** `carajas360-a17c5`  
**App:** Flutter `carajas_360` · versão `1.0.0+403` · pacote `br.com.carajas360`  
**Homolog Web:** https://carajas360-a17c5--homolog-88u39zqx.web.app  

## Classificação

**Apto para entrega ao programador, com pendências.**  
**Não** apto para publicação (lojas / hosting live) sem fechar P0 externos.

---

## 1. Clonar e instalar (desenvolvimento)

```bash
git clone https://github.com/draraiany-source/Carajas360.git
cd Carajas360
git checkout feat/modernizacao-visual

# Flutter
flutter pub get

# Cloud Functions (testes / deploy futuro)
cd functions
npm install
npm test
cd ..
```

Requisitos locais: Flutter SDK estável (compatível com `sdk: >=3.2.0 <4.0.0`), Node 20 para `functions/`, Chrome ou emulador para Web/Android.

### Rodar em desenvolvimento

```bash
flutter run -d chrome          # Web
flutter run -d android         # dispositivo/emulador
# iOS: somente em macOS com Xcode
```

O app usa Firebase do projeto `carajas360-a17c5` via `lib/firebase_options.dart` (chaves **cliente** públicas do Firebase — não são secrets de servidor).

---

## 2. Configuração sem credenciais secretas

| Item | Onde | Observação |
|------|------|------------|
| Projeto Firebase | `.firebaserc` | `carajas360-a17c5` |
| Options cliente | `lib/firebase_options.dart` | Já no repo |
| Android google-services | `android/app/google-services.json` | Config cliente |
| iOS GoogleService | `ios/Runner/GoogleService-Info.plist` | Config cliente |
| Assinatura Android release | `android/key.properties` | **Não versionado** — copiar de `key.properties.example` localmente |
| Keystore `.jks` | local | **Não versionado** |
| Anthropic / MP tokens | Secret Manager / env Functions | **Nunca** no app nem no Git |
| `.env` | — | Não usar no commit |

Para emuladores locais (opcional):

```bash
# Java no PATH (ex.: Android Studio JBR)
firebase emulators:start --only auth,firestore,storage
```

---

## 3. Testes disponíveis

```bash
# Unitários Flutter (fotos + config)
flutter test test/order_photos_test.dart test/order_photos_flow_test.dart test/firebase_placeholders_test.dart

# Suite Functions
cd functions && npm test && cd ..

# E2E fotos (requer emuladores Auth:9099 Firestore:8080 Storage:9199)
# npx firebase-tools@latest emulators:exec --only auth,firestore,storage --project carajas360-a17c5 "flutter test test/order_photos_emulator_e2e_test.dart --reporter expanded"
```

Resultados recentes (Fase 17): Flutter **14/14** · Functions **163/163**.

---

## 4. Documentação técnica

| Pasta / arquivo | Conteúdo |
|-----------------|----------|
| `docs/FASE17/` | Auditoria, matriz P0–P2, IA, pagamentos, Firebase, testes, checklist, PDFs + ZIP |
| `docs/FASE16_*.md` | Pacote Workana / critérios |
| `docs/FASE15_AUDITORIA_DEFINITIVA.md` | Auditoria definitiva |
| `docs/FASE13_GO_EXTERNOS.md` | Ações que exigem GO (Blaze, live, MP) |
| `docs/RELATORIO_ORCAMENTO_FOTOS_IA.md` | Fotos no orçamento |
| `ENTREGA_PROGRAMADOR_CARAJAS360/` | Pacote PDF guias 01–15 + FASE16 |
| `README_ENTREGA_PROGRAMADOR.md` | Este arquivo |

---

## 5. Pendências de produção (P0)

1. **Blaze** Firebase + Cloud Functions API  
2. **Storage** bucket + `firebase deploy --only storage`  
3. Deploy **`aiAssistant`** (e demais Functions necessárias)  
4. Mercado Pago **sandbox** (`PAYMENTS_ENABLED`, token TEST)  
5. Hosting **live** (hoje 404) — só com GO: `scripts/live_web_deploy.ps1 -IAuthorizeLiveDeploy`  
6. **AAB** Android (keystore local)  
7. **IPA** / TestFlight (macOS + Apple Developer)  
8. E2E autenticado cliente / profissional / admin  

Detalhes: `docs/FASE17/MATRIZ_PENDENCIAS.md` e `docs/FASE17/GO_AUTORIZACOES_EXTERNAS.md`.

---

## 6. O que preservar

- Identidade visual verde-esmeralda / branco / dourado (`lib/core/theme/brand.dart`)  
- Fluxos Web, Android, iOS existentes  
- IA (cliente sem chave; backend Functions)  
- Orçamentos com fotos, pagamentos (código), admin, categorias  

**Não** recriar o aplicativo. **Não** publicar nem ativar Blaze/produção sem autorização da contratante.

---

## 7. O programador consegue desenvolver?

**Sim**, após `git clone` + `flutter pub get` + `npm install` em `functions/`, é possível:

- Abrir o código e navegar o app em **homolog** / emuladores / `flutter run`  
- Rodar a suíte de testes automatizados  
- Seguir a documentação de P0 para produção  

**Não** sem GO externo: Functions em produção, Storage live, pagamentos sandbox reais, AAB/IPA de loja, hosting live.
