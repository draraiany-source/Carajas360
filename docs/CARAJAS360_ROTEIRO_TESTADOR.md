# CARAJAS360 - Roteiro do Testador (Teste Fechado)

**VERSION:** 1.0.0+402  
**PAYMENTS:** OFF — **nao testar cobranca real**  
**Uso:** somente apos entrega de AAB/APK RC; **nao** usar em piloto ate GO  
**Gate atual:** YELLOW — privacy live pode ainda estar 404; registrar FAIL se URL 404

## Antes de comecar

1. Confirmar versionCode/build 402 no app (Sobre / debug info se disponivel).
2. Confirmar que pagamentos estao desligados (sem checkout real).
3. Ter `CARAJAS360_BUG_REPORT_TEMPLATE.md` aberto para registrar achados.
4. **Nao** usar cartao/PIX real nem tokens de producao.

## Bloco A — Instalacao e conta

| ID | Passo | Resultado esperado | OK / FAIL / N-A |
|----|-------|--------------------|-----------------|
| A1 | Instalar APK/AAB via canal interno | App abre sem crash | |
| A2 | Login ou cadastro teste | Sessao estabelecida | |
| A3 | Logout e re-login | Sessao restaurada | |

## Bloco B — Navegacao principal

| ID | Passo | Resultado esperado | OK / FAIL / N-A |
|----|-------|--------------------|-----------------|
| B1 | Abrir marketplace | Lista/carregamento sem erro fatal | |
| B2 | Abrir pedidos | Tela responsiva | |
| B3 | Abrir chat/inbox | Sem permissao indevida | |
| B4 | Abrir perfil/configuracoes | Dados coerentes com conta teste | |
| B5 | Abrir suporte/FAQ | Links internos funcionam | |

## Bloco C — Resolve / servicos (RC)

| ID | Passo | Resultado esperado | OK / FAIL / N-A |
|----|-------|--------------------|-----------------|
| C1 | Abrir fluxo Resolve | UI carrega | |
| C2 | Criar rascunho solicitacao (se disponivel no RC) | Persistencia ou feedback claro | |
| C3 | Cancelar/voltar | Sem estado corrompido | |

Nota: fluxo assistido pos-freeze pode nao estar no escopo do gate F7; marcar N-A se ausente no build.

## Bloco D — Legal e privacidade

| ID | Passo | Resultado esperado | OK / FAIL / N-A |
|----|-------|--------------------|-----------------|
| D1 | Abrir link politica privacidade in-app | URL valida (**nao 404**) | |
| D2 | Abrir termos de uso | URL valida (**nao 404**) | |

Se 404: registrar FAIL e **nao** classificar teste fechado como GO.

## Bloco E — Financeiro (negativo)

| ID | Passo | Resultado esperado | OK / FAIL / N-A |
|----|-------|--------------------|-----------------|
| E1 | Tentar fluxo de compra/credito | Bloqueado ou mensagem clara; **sem cobranca** | |
| E2 | Verificar ausencia de token producao no cliente | N/A inspecao tecnica / sem cobranca | |

## Encerramento

- Resumo: dispositivo, build, data, testador ID (sem PII no Git).
- Anexar bugs usando template oficial.
- **Nao** classificar esta execucao como piloto — piloto permanece bloqueado.
- **Nao** ativar pagamentos.

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
