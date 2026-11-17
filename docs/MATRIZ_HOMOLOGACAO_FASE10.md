# Matriz de homologação — FASE 10

**Data:** 2026-11-17 · Branch `feat/modernizacao-visual`  
**Legenda:** A = Aprovado · R = Reprovado · N/E = Não executado

| # | Caso | Tipo | Resultado | Nota |
|---|------|------|-----------|------|
| 1 | Unitários `order_policy` / marketplace F2 | unit | A | Incluídos no `flutter test` |
| 2 | Suite `flutter test` completa | unit/widget | R parcial | ~190 A; falhas widget Explorar sem `Firebase.initializeApp` |
| 3 | Auth login/registro | E2E | N/E | Exige conta real / domínio Auth |
| 4 | Permissões Firestore (regras) | integração | A (código) | Emulador não rodado nesta sessão |
| 5 | Pagamento sandbox MP | sandbox | N/E | `PAYMENTS_ENABLED` off; sem GO |
| 6 | Webhook MP (body não confiável) | código | A | Lookup `payments/{id}` + status MP |
| 7 | IA turno real | E2E | N/E | Function não deployada |
| 8 | IA UI + erro honesto | manual/código | A | Mensagem `unavailable` |
| 9 | Carga profissionais Web homolog | regressão | A | Evidência prévia `docs/evidence/homolog_ia/` |
| 10 | Navegação fluxo cliente (código) | código | A | Fases 3–4 |
| 11 | Responsividade Home/Explorar | visual | N/E | Sem captura nova nesta sessão |
| 12 | Android build debug | build | N/E | Não executado aqui |
| 13 | iOS build | build | N/E | Requer macOS |
| 14 | LGPD export/delete paths | código | A | Telas/perfil existentes |
| 15 | Segurança: sem demo IDs sensíveis | código | A | Fases 2–5 |

**Critério piloto sugerido:** 0 P0 de código abertos; pagamentos/IA/live só após GO.
