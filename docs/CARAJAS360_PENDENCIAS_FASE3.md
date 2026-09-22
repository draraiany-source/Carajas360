# CARAJAS360_PENDENCIAS_FASE3.md

## Bloqueadores para producao (nao para homologacao final)

1. **P0-02** Firebase options / google-services / plist reais — CONFIGURACAO EXTERNA
2. Secrets MP / webhook em Secret Manager — CONFIGURACAO EXTERNA
3. Custom claim admin inicial — CONFIGURACAO EXTERNA
4. E2E nativo nao executado — NOT TESTED

## P1 abertos

- P1-03 Webhook aplicar credito/PRO so com desenho + PAYMENTS_ENABLED — DECISÃO OWNER
- P1-04 ENFORCE_APP_CHECK — DECISÃO OWNER
- P1-05 Saque PIX real vs so ledger — DECISÃO OWNER
- P1-06 Emails @carajas360 vs servicoconecta — DECISÃO OWNER / DNS

## P2 abertos

- Visibilidade de resolveRequests open
- Consentimento OAuth mais explicito
- Idempotencia PIX por minuto
- Docs antigos citando 15%
- Feature flags Admin UI completa

## P3

- Expurgo automatico LGPD 5 anos
- Directions Google real
- Dominio email autorizado

## Corrigido nesta fase

- P0-01 IDOR chat→perfil
- P1-01 Comissao Admin no payout
- P1-02 Unlock so profissional + slots
- Rules disputes
- Relatorio financeiro alinhado a config/snapshot

## Contas de teste

⚠️ DECISÃO DO PROPRIETÁRIO — criar no Auth homolog sem versionar senhas:
- CLIENTE TESTE
- PROFISSIONAL GRATUITO
- PROFISSIONAL PRO
- ADMIN TESTE
