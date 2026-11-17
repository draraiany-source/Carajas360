# Critérios de aceite — Carajás 360 (Workana)

**Baseline:** commit `a95b2e5` · branch `feat/modernizacao-visual`  
Aceite **objetivo**: logs, HTTP status, builds, testes. Screenshots sozinhas **não** bastam.

---

## Aceite geral do serviço

O serviço só é aceito quando:

1. Todos os P0 do contrato estiverem fechados **ou** explicitamente adiados por escrito pela contratante.  
2. Marcos 1–4 tiverem critérios abaixo cumpridos.  
3. Documentação de entrega atualizada **sem** secrets.  
4. Nenhuma publicação live/loja sem GO escrito.

---

## Marco 1 — Críticos, Firebase e IA

| # | Critério | Prova |
|---|----------|-------|
| M1.1 | Cloud Functions listáveis no projeto | Output CLI sem 403 |
| M1.2 | `aiAssistant` deployada | Deploy log + callable responde |
| M1.3 | Turno IA com providers reais (grounded) | Log/resposta sem inventar preço |
| M1.4 | Storage bucket + `storage.rules` | Deploy OK + upload teste |
| M1.5 | Fotos orçamento em ambiente com Storage | Objeto no path + `photoUrls` no doc |
| M1.6 | `npm test` functions = 163 pass (ou ≥ baseline) | Log |

## Marco 2 — Fluxos, multimídia, pagamentos sandbox

| # | Critério | Prova |
|---|----------|-------|
| M2.1 | E2E cliente até avaliação (exceto prod pay) | Roteiro assinado + logs |
| M2.2 | E2E profissional até atendimento | Idem |
| M2.3 | Admin: aprovação + disputa smoke | Idem |
| M2.4 | Vídeo/áudio no orçamento **se no contrato** | Upload + visualização partes |
| M2.5 | PIX sandbox | Payment doc + status |
| M2.6 | Cartão sandbox | Idem |
| M2.7 | Webhook MP sandbox idempotente | Log + ledger 1x |

## Marco 3 — Android, iOS, devices

| # | Critério | Prova |
|---|----------|-------|
| M3.1 | APK instalável | Device + versão `1.0.0+…` |
| M3.2 | AAB assinado + SHA256 | Arquivo + hash |
| M3.3 | Smoke Android: login, explorar, orçamento c/ foto | Checklist device |
| M3.4 | IPA no TestFlight | Link/build number |
| M3.5 | Smoke iOS equivalente | Checklist device |

## Marco 4 — Homologação e prep publicação

| # | Critério | Prova |
|---|----------|-------|
| M4.1 | Checklist Android/iOS/Web preenchido | Doc assinado |
| M4.2 | Plano de testes com resultados | Pass/Fail reais |
| M4.3 | Termo de entrega código (tag/HEAD) | Git tag + ZIP docs |
| M4.4 | Live Web **somente se GO** | 200 ou adiamento escrito |
| M4.5 | Produção MP **somente se GO** | Flag + política |

---

## Critérios negativos (rejeição automática do marco)

- Rebuild completo do app sem autorização.  
- Secrets commitados no Git.  
- `PRODUCTION_PAYMENTS_ENABLED=true` sem GO.  
- Evidência apenas por prints sem logs/builds.  
- Regressão: functions tests ou fotos emulator caindo sem correção.
