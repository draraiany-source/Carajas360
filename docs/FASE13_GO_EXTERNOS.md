# Ações externas necessárias (FASE 13) — sem executar sem GO

## 1. Firebase Billing / Blaze

**Estado observado:** `Billing Enabled: No` (MCP `firebase_get_environment`).  
**Efeito:** Cloud Functions API retorna **HTTP 403** (*API has not been used / disabled*).  
**Ação do owner (Console):**

1. Abrir https://console.firebase.google.com/project/carajas360-a17c5/usage/details  
2. Fazer upgrade para plano **Blaze** (pay-as-you-go).  
3. Habilitar APIs:
   - https://console.developers.google.com/apis/api/cloudfunctions.googleapis.com/overview?project=carajas360-a17c5  
   - Cloud Build, Artifact Registry (se o deploy pedir)

**Esta sessão NÃO altera faturamento.**

## 2. Deploy `aiAssistant`

Após Blaze + API:

```bash
cd functions && npm test
firebase deploy --only functions:aiAssistant --project carajas360-a17c5
# Opcional: BIND_ANTHROPIC_SECRET=true + Secret Manager ANTHROPIC_API_KEY
```

Sem chave Anthropic a Function ainda responde **grounded** (providers reais).

## 3. Hosting live

Causa do 404: **nenhuma release live**. Homolog OK.  
Script preparado: `scripts/live_web_deploy.ps1 -IAuthorizeLiveDeploy` (só com GO).

## 4. Mercado Pago sandbox

- Token TEST no Secret Manager / env  
- `PAYMENTS_ENABLED=true` **somente** sandbox  
- `PRODUCTION_PAYMENTS_ENABLED` permanece `false` até GO comercial  
- Testar PIX/cartão/webhook sem cobrança real de produção

## 5. Android assinatura

Criar `android/key.properties` (não versionar) a partir de `key.properties.example`.  
Sem isso: AAB/APK release bloqueados de propósito.
