# AUDITORIA FASE 17 — Carajás 360

**Data:** 2026-11-18  
**Repositório:** https://github.com/draraiany-source/Carajas360  
**Branch:** `feat/modernizacao-visual`  
**HEAD auditado (início):** `031ab29`  
**App:** `carajas_360` `1.0.0+403`  
**Firebase:** `carajas360-a17c5`  
**Regra:** não recriar; não inventar evidências; sem Blaze/publicação sem GO.

---

## 1. Identidade e GitHub (pré-alteração)

| Item | Valor |
|------|--------|
| Remoto | `origin` → `https://github.com/draraiany-source/Carajas360.git` |
| Branch | `feat/modernizacao-visual` (= `origin` no início) |
| Projeto local | `C:\Users\Lenovo\Desktop\CARAJAS360` |
| `.firebaserc` | `default: carajas360-a17c5` |
| MCP Firebase (antes) | apontava pasta pediatria360 — **corrigido** para CARAJAS360 |
| Confirmação | `pubspec name: carajas_360` + iOS bundle `br.com.carajas360` |

## 2. Arquitetura

| Camada | Tecnologia |
|--------|------------|
| App | Flutter multiplataforma (Web/Android/iOS) |
| Auth | Firebase Auth |
| Dados | Cloud Firestore + rules |
| Arquivos | Firebase Storage + rules (`orders/{id}/photos/…`) |
| Backend | Cloud Functions (`functions/`, Node 20) |
| Hosting | Firebase Hosting (live + canal `homolog`) |
| Pagamentos | Mercado Pago via callables + webhook (flags) |
| IA | Callable `aiAssistant` (+ assist*) — sem chave no app |

## 3. Telas / rotas (amostra canônica)

Fonte: `lib/core/constants/app_constants.dart` + `docs/AUDITORIA_TELAS_CARAJAS360.md`.

Rotas nomeadas incluem: `/login`, `/register`, `/main`, `/search`, `/provider-profile`, `/request-service`, `/my-orders`, `/ai`, `/admin`, `/resolve`, `/provider-home`, `/wallet`, `/chat`, marketplace/rental/stores, etc. (~40+).

## 4. Backend (código vs runtime)

| Serviço | Código | Runtime observado F17 |
|---------|--------|------------------------|
| Auth / Firestore | SIM | Projeto ativo |
| Storage rules | SIM | **0 buckets** — Storage não provisionado |
| Cloud Functions | SIM (`aiAssistant`, PIX, card, webhook, payout…) | **API 403** — não listáveis |
| Hosting homolog | SIM | **HTTP 200** |
| Hosting live | Config SPA OK | **HTTP 404** (sem release live) |

## 5. Documentos fases 12–16

| Fase | Documento | Status |
|------|-----------|--------|
| 12 | `docs/AUDITORIA_FINAL_CARAJAS360.md` | Presente — NÃO APTO publicação |
| 13 | `docs/FASE13_*.md` + GO externos | Presente |
| 14 | `docs/FASE14_ENTREGA_PROGRAMADOR.md` | Presente |
| 15 | `docs/FASE15_AUDITORIA_DEFINITIVA.md` | Presente — entrega programador SIM |
| 16 | `docs/FASE16_*.md` + pacote Workana | Presente |

## 6. Classificação de funcionalidades (honesta)

| Área | Código | Teste real | Nota |
|------|--------|------------|------|
| UI / rotas / brand | IS | Parcial homolog | Verde `#006B35` / ouro `#FFC400` |
| Orçamento + fotos | IT código+unit+emulator | Prod Storage BX | Path implementado |
| Vídeo/áudio no orçamento | AU | — | Pendência P1 |
| Carajás IA UI | IS | — | Erro honesto se CF off |
| Carajás IA LLM | BX | N/E | Blaze + deploy |
| Pagamentos MP | IT unit | Sandbox N/E | Flags off |
| Admin | IS | E2E N/E | AdminGate |
| Android AAB | IS projeto | N/E | keystore/disco |
| iOS IPA | IS projeto | N/E | macOS |

Legenda: IS=implementado sem E2E completo · IT=implementado+testado no escopo · AU=ausente · BX=bloqueado externo · N/E=não executado

## 7. Brand

`Brand.green = #006B35`, `Brand.gold = #FFC400` — preservado. Sem redesign nesta fase.

## 8. Conclusão da auditoria

O produto **existe e está organizado** no GitHub. Bloqueadores de publicação/runtime (**Blaze, Storage bucket, live Hosting, builds mobile, E2E auth**) são **externos ou não comprovados**, não resolvíveis sem GO/credenciais/macOS.
