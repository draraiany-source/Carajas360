# Relatório de testes — FASE 17

## Automatizados (reexecutados 2026-11-18)

| Suite | Resultado | Evidência |
|-------|-----------|-----------|
| `flutter test` order_photos + flow + placeholders | **14/14 PASS** | `docs/evidence/fase17_flutter_tests.txt` |
| `cd functions && npm test` | **163/163 PASS** | `docs/evidence/fase17_functions_tests.txt` |
| Fotos E2E emulator (sessão anterior) | **PASS** | `docs/evidence/orcamento_fotos/emulator_e2e.txt` |

## Não executados / bloqueados (não marcar como PASS produção)

| Teste | Status | Motivo |
|-------|--------|--------|
| Login/cadastro real | N/E | Contas + sessão completa |
| Solicitação fotos **prod** Storage | BLOCKED | Bucket ausente |
| IA backend real | BLOCKED | CF 403 |
| Pagamento sandbox | N/E | Token/flags/deploy |
| Admin E2E | N/E | Conta admin |
| Android device / AAB | N/E | Build release |
| iOS device / IPA | N/E | macOS |
| Navegação Web live | FAIL pub | 404 |
| Navegação Web homolog | Parcial OK | HTTP 200; auth E2E N/E |

## Regra

Mocks/unitários **não** substituem E2E autenticado para declarar produção.
