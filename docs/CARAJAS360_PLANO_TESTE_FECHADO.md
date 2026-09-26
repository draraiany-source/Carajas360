# CARAJAS360 - Plano de Teste Fechado

**Status:** PREPARADO — **NAO INICIADO** (gate F7 = YELLOW)  
**VERSION:** 1.0.0+402  
**Branch:** `release/carajas360-rc1` @ `1c47a74`  
**PAYMENTS:** OFF  
**Piloto:** bloqueado ate GO separado (`CARAJAS360_PLANO_PILOTO.md` / GO_NO_GO)

## 1. Objetivo

Validar fluxos criticos em dispositivos reais com build RC **antes** de qualquer piloto. Este plano existe; a execucao **nao** comecou na F7.

## 2. Pre-requisitos (bloqueadores atuais)

| Pre-requisito | Estado F7 |
|---------------|-----------|
| AAB/APK RC disponivel | **PASS** (hashes em `fase7_android_build.md`) |
| URLs privacidade/termos live | **FAIL 404** — deploy hosting pendente |
| Roteiro testador | `CARAJAS360_ROTEIRO_TESTADOR.md` |
| Template bug | `CARAJAS360_BUG_REPORT_TEMPLATE.md` |
| Device Android + adb/emulador | **DEVICE REQUIRED** — NOT TESTED |
| Pagamentos reais | **OFF** — nao testar cobranca real |

**Nao iniciar sessoes de teste fechado como GO formal ate privacy live 200 + device disponivel.**

## 3. Escopo funcional (sem pagamento real)

- Autenticacao e perfil basico
- Navegacao modulos principais (marketplace, chat, pedidos, suporte — conforme flags atuais)
- Resolve / assistencia (somente o que existir no build RC; funcoes pos-freeze fora de escopo do gate)
- Confirmar que fluxos financeiros permanecem desabilitados ou em modo seguro

**Exclusao:** cobranca real, split, webhook producao.

## 4. Ambiente

- Firebase: projeto de homolog/staging conforme config do time (nao documentar secrets aqui).
- Build: RC assinado versaoCode 402 quando disponivel (APK/AAB ja produzidos).
- Dispositivos: minimo 1 Android fisico; iOS se build disponivel (hoje NOT TESTED).

## 5. Entradas e saidas

| Entrada | Responsavel |
|---------|-------------|
| Binario RC | Engenharia |
| Contas de teste | Operacoes (fora do Git) |
| Roteiro | QA / produto |

| Saida | Artefato |
|-------|----------|
| Bugs | template oficial / tracker externo |
| Relatorio execucao | anexo ao re-GO F7/F8 |

## 6. Criterio de saida do teste fechado

- Roteiro executado em >= 1 dispositivo Android com build RC.
- 0 abertos P0 para continuar rumo a piloto (criterio sugerido; decisao final no GO).
- Nenhuma ativacao de pagamentos durante o teste.
- Privacy/terms live sem 404.

## 7. Estado F7

**Teste fechado: NAO INICIADO.** Motivo: privacy live 404 + DEVICE REQUIRED. Artefato AAB/APK ja existe — preparacao tecnica parcial OK; GO formal ainda YELLOW.

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
