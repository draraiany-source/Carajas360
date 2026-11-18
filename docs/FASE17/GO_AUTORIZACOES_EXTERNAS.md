# Autorizações externas necessárias — FASE 17

**Nenhuma operação abaixo foi executada nesta fase.** Aguardar GO explícito da contratante.

## 1. Firebase Blaze (pago)

- **Por quê:** Cloud Functions, Storage completo e vários runtimes exigem Blaze.  
- **Custo:** pay-as-you-go (Functions invocações, Storage GB, Hosting, egress). Monitorar cotas.  
- **Ação:** Console → Usage → Upgrade Blaze no projeto `carajas360-a17c5`.  
- **Depois:** habilitar Cloud Functions API.

## 2. Deploy Hosting LIVE (corrige HTTP 404)

- **Por quê:** canal live sem release → 404. Homolog já funciona.  
- **Risco:** expõe app na URL pública de produção.  
- **Ação com GO:**  
  `powershell -File scripts\live_web_deploy.ps1 -IAuthorizeLiveDeploy`  
- **Não** alterar domínio custom sem autorização.

## 3. Secret Anthropic (opcional)

- Só se quiser LLM além do grounded.  
- Secret Manager — **nunca** no app/Git.

## 4. Mercado Pago sandbox / produção

- Sandbox: token TEST + `PAYMENTS_ENABLED=true`.  
- Produção: GO comercial + `PRODUCTION_PAYMENTS_ENABLED`.

## 5. Apple Developer / Play Console

- Necessários para IPA/AAB de loja.
