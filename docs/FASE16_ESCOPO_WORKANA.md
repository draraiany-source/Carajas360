# Escopo técnico Workana — Carajás 360

**Produto:** marketplace regional de serviços (Flutter + Firebase)  
**Projeto Firebase:** `carajas360-a17c5`  
**Repositório / branch:** código existente · `feat/modernizacao-visual`  
**Commit baseline pacote:** `a95b2e5`  
**Versão app:** `1.0.0+403`  
**Homolog:** `https://carajas360-a17c5--homolog-88u39zqx.web.app`

## Objetivo do contrato

Finalizar, homologar e preparar publicação do **aplicativo já existente**.  
**Proibido:** recriar o app, trocar stack sem autorização, publicar em lojas/live sem GO da contratante.

## Dentro do escopo

1. Correções P0/P1 listadas em `PENDENCIAS_PROGRAMADOR`.  
2. Firebase: Blaze (ação owner), Storage, deploy Functions necessárias (`aiAssistant`, pagamentos sandbox).  
3. Carajás IA: turno real + erro honesto; sem inventar preços/diagnósticos.  
4. Orçamentos: fotos (já implementadas — validar prod); vídeo/áudio se contratado.  
5. Fluxos E2E cliente, profissional e admin com evidências.  
6. Mercado Pago **sandbox** (PIX/cartão/webhook); produção só com GO.  
7. Builds Android (APK/AAB) e iOS (IPA/TestFlight).  
8. Documentação de entrega e checklist de publicação.

## Fora do escopo (salvo aditivo)

- Redesign completo / “premium 3D” pixel-perfect (P2).  
- Novos módulos de negócio não listados.  
- Marketing, loja de apps conta da contratante, conteúdo legal (salvo links já existentes).  
- Cobrança real de produção sem GO escrito.

## Responsabilidades do programador

- Trabalhar sobre o Git existente; PRs/commits claros.  
- Executar testes automatizados e E2E; anexar logs (sem secrets).  
- Entregar builds e hashes; não versionar keystores/tokens.  
- Reportar bloqueios de owner (billing, Apple, MP) em ≤ 24h úteis.

## Responsabilidades da contratante

- Acesso Firebase/Git (ou ZIP + credenciais fora do chat público).  
- GO Blaze, GO live hosting, GO produção pagamentos.  
- Conta Apple Developer / Play Console / Mercado Pago.  
- Aprovação objetiva de cada marco (critérios de aceite).

## Cronograma estimado (4 marcos)

| Marco | Semanas típicas* | Foco |
|-------|------------------|------|
| 1 | 1–2 | P0 Firebase/IA/Storage |
| 2 | 2–3 | Fluxos + multimídia + MP sandbox |
| 3 | 2–3 | Android/iOS dispositivos |
| 4 | 1–2 | Homologação + prep publicação |

\*Estimativa; ajustar no contrato Workana.

## Termo de entrega do código-fonte

Ao final do Marco 4 (ou rescisão):

1. Branch/tag com HEAD acordado + changelog.  
2. Pacote docs atualizado (sem secrets).  
3. Instruções de build Web/Android/iOS.  
4. Lista de secrets necessários (nomes, não valores) e onde configurar.  
5. Evidências dos critérios de aceite cumpridos.

A propriedade intelectual do código entregue segue o contrato Workana firmado entre as partes.
