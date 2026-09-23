# Carajas 360 — Resposta a Incidentes

## 1. Pagamento duplicado
1. Pausar via financialKillSwitch=true em config/platform.
2. Localizar eventId/paymentId no webhookEvents + transactions.
3. Nao apagar historico; lancar compensatorio.
4. Registrar audit log.

## 2. Split/comissao incorreta
1. Nao reescrever pedidos antigos (snapshot commissionRate).
2. Corrigir config para novas contratacoes.
3. Compensar manualmente com audit.

## 3. Conta comprometida / secret vazado
1. ROTATION_REQUIRED=true — rotacionar imediatamente no provedor.
2. Revogar token antigo MP / Firebase / Maps.
3. financialKillSwitch on ate confirmar.

## 4. Gateway indisponivel
1. Manter PAYMENTS_ENABLED conforme politica; mensagem amigavel ao usuario.
2. Filas/pendencias: creditPurchases status pending.

## 5. Webhook perdido
1. Reconciliar pelo paymentId no painel MP vs payments/transactions.
2. Reprocessar com o mesmo eventId (idempotente).

## 6. Vazamento de dados
1. Isolar acesso Admin.
2. Seguir LGPD: notificar se aplicavel; export/delete conforme politica.

## Contatos operacionais
Definir fora do Git apos dominio real (suporte@ / privacidade@).