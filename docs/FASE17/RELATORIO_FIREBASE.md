# Relatório Firebase — FASE 17

**Projeto:** `carajas360-a17c5`  
**Diretório CLI/MCP (corrigido F17):** `C:\Users\Lenovo\Desktop\CARAJAS360`

| Serviço | Estado F17 | Evidência |
|---------|------------|-----------|
| Authentication | Configurado no app | Options reais (não placeholder) |
| Firestore | Ativo + rules no repo | Deploy rules fotos (fase anterior) |
| Storage rules | No repo; delete ACL orders OK | Emulator E2E anterior |
| Storage bucket | **Ausente (0)** | `gcloud storage buckets list` |
| Cloud Functions | Código completo | List API **403** |
| Billing Blaze | **No** | MCP + gcloud |
| Hosting homolog | **200** | Canal `homolog` |
| Hosting live | **404** | Sem release live |
| App Check | Código/enforce opcional | Validar pós-deploy |

## Web 404 (live) — investigação

| Hipótese | Resultado |
|----------|-----------|
| SPA rewrites ausentes | **Não** — `firebase.json` tem rewrite `**` → `index.html` |
| Build quebrado | Homolog build recente **200** |
| Domínio errado | `carajas360-a17c5.web.app` é o site default |
| Sem release no canal live | **SIM — causa raiz** |

**Correção:** deploy live **somente com GO** — `scripts/live_web_deploy.ps1 -IAuthorizeLiveDeploy`.  
Homolog permanente para testes: https://carajas360-a17c5--homolog-88u39zqx.web.app  

**Não alteramos domínio nem publicamos live nesta fase.**

## Segurança / LGPD (resumo)

- Rules: wallets/payments sensíveis backend-only (testes estáticos Functions)  
- Storage orders: só partes do pedido  
- `deleteMyAccount` callable (código)  
- Privacy/Terms paths no hosting  
- **Não** versionar `key.properties` / `*.jks` / tokens
