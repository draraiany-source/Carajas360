# Mapas de fluxo — Carajás 360 (FASE 14)

Commit `686d16c` · versão `1.0.0+403`

## Cliente

```mermaid
flowchart TD
  A[Home MainNav] --> B[Explorar /search]
  B --> C[Perfil /provider-profile]
  C -->|Pedir orçamento| D[/request-service]
  D --> E[createOrder]
  E --> F[Chat e/ou Meus pedidos]
  B -->|Resolve| G[/resolve]
  G --> H[/resolve-detail]
  H -->|Aceitar proposta CF| F
  F -->|canPay| I[Carteira / PIX / Cartão CF]
  I --> J[Execução / GPS]
  J --> K[Confirmar serviço]
  K --> L[/reviews Avaliar]
  A --> M[FAB /ai]
  M --> N[AiSvc aiAssistant]
```

## Profissional

```mermaid
flowchart TD
  A[Register asProvider] --> B[/provider-onboarding]
  B --> C[Admin aprova]
  C --> D[/provider-home online]
  D --> E[Pedido pendente]
  E -->|Aceitar + preço| F[Em andamento]
  F --> G[Concluir]
  D --> H[Oportunidades Resolve]
  H --> I[Enviar proposta]
  G --> J[Escrow / payout]
```

## Admin

```mermaid
flowchart TD
  A[/admin AdminGate] --> B[Usuários]
  A --> C[Validação providers]
  A --> D[Categorias]
  A --> E[Financeiro]
  A --> F[Atendimento]
  A --> G[Denúncias]
  A --> H[Disputas]
  A --> I[Pedidos]
  A --> J[Auditoria / Config]
```

## Contratação / orçamento / pagamento

| Origem | Botão / ação | Destino |
|--------|--------------|---------|
| Explorar card | Ver perfil | `/provider-profile` |
| Explorar card | Pedir orçamento | `/request-service` |
| Perfil | Solicitar orçamento | `/request-service` |
| Resolve detalhe | Aceitar proposta | CF `acceptResolveProposal` → `/my-orders` |
| Meus pedidos | Pagar | Sheet → wallet/PIX/cartão CF |
| Meus pedidos | Mensagens | ChatNav |
| Meus pedidos | Avaliar | `/reviews` |
| Provider home | Aceitar | Dialog preço → `acceptOrder` |
