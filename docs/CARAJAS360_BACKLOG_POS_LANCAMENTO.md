# CARAJAS360 - Backlog Pos-Lancamento / Pos-Freeze

**Contexto:** Release freeze F7 ACTIVE - itens abaixo **nao** fazem parte do gate F7 e **nao** devem ser tratados como concluidos para GO.

**Branch referencia:** `release/carajas360-rc1` @ `1c47a74`

## Pos-freeze - Assistencia e serviceAssist

| Item | Descricao | Estado | Notas |
|------|-----------|--------|-------|
| Cloud Function `serviceAssist` | Backend assistencia servicos (`functions/serviceAssist.js`) | Em repo; fora gate F7 | Testes npm incluidos na suite 115 pass |
| Testes `serviceAssist.test.js` | Cobertura unitaria functions | Presente | Nao substitui E2E piloto |
| Tela `assisted_request_screen` | Fluxo solicitacao assistida (Flutter) | Em repo; pos-freeze | Integracao produto a planejar pos-GO |
| Client test `service_assist_client_test.dart` | Cliente Flutter | Presente | |
| Regras Firestore / audit | Alteracoes associadas | Revisar antes de ativar em prod | Seguranca rules audit |

## Outros itens tipicos pos-lancamento (nao inventar prontidao)

- Publicacao URLs legais (corrigir 404)
- Producao AAB/APK e pipeline assinatura
- Teste fechado e piloto apos GO
- Ativacao financeira - ver plano dedicado (**nao** ativar na F7/F8)
- iOS build e TestFlight
- Telemetria / Crashlytics producao
- Otimizacao performance marketplace e chat em escala real

## Priorizacao

Prioridade zero continua sendo **desbloqueadores de GO** (artefato + legal + teste fechado). Backlog pos-freeze entra apos gate verde documentado.
