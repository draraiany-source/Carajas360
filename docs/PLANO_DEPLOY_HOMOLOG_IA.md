# Plano de deploy — Homologação Carajás IA (NÃO EXECUTADO)

**Projeto:** `carajas360-a17c5`  
**Canal alvo:** Hosting `homolog` + Functions `aiAssistant`  
**Status:** aguardando autorização explícita  
**Atualização:** personagem oficial anexada em `assets/carajas_ia/` — rebuild Web necessário no próximo GO de homolog.

---

## Comandos propostos (ordem)

```bash
# 1) Validar local
cd functions && npm test && npm run lint

# 2) Índices (inclui providers + categories) — aguarda GO
firebase deploy --only firestore:indexes --project carajas360-a17c5

# 3) (Opcional LLM) — exige plano Blaze + Secret Manager
# firebase functions:secrets:set ANTHROPIC_API_KEY --project carajas360-a17c5
# NÃO colar a chave em chat/relatório/Git.
# BIND_ANTHROPIC_SECRET=true  # só se o secret já existir

# 4) Staging grounded (recomendado primeiro — sem LLM)
# AI_ENABLED=false  (ou omitir chave)
firebase deploy --only functions:aiAssistant --project carajas360-a17c5

# 5) Rebuild Web com personagem oficial + UI Carajás IA
flutter build web --release
powershell -ExecutionPolicy Bypass -File scripts\homolog_web_preview.ps1 -Channel homolog -Expires 30d
# NÃO live
```

Android/iOS: gerar APK/IPA de staging localmente; **não** publicar nas stores neste plano.

---

## Recursos afetados

| Recurso | Efeito |
|---------|--------|
| Cloud Function `aiAssistant` (us-central1) | Substitui/atualiza a callable |
| Hosting channel `homolog` | Nova build Web |
| Firestore | Sem alteração de dados; rules IA já publicadas |
| Secret Manager | Só se Blaze + `secrets:set` (opcional) |
| Canal `live` / produção | **Fora do escopo** |

---

## Riscos

1. **Plano Spark:** Secret Manager / alguns comandos Functions falham até upgrade Blaze.  
2. **Deploy Functions** pode gerar custo Cloud Functions + (se chave) Anthropic.  
3. **HomologCatalog** desliga com keys reais — Auth passa a ser obrigatória; login quebrado se Email/Google não estiverem habilitados.  
4. **OAuth Google:** `oauth_client` vazio no Android SDK — Google Sign-In pode falhar; Email/senha preferível no piloto.  
5. **Canal live:** não incluir no comando (evitar publicação acidental).  
6. **Rollback:** redeploy da revisão Functions anterior + channel homolog anterior.

---

## Pré-condições antes do GO

- [ ] Autorização explícita para `functions:aiAssistant` e/ou `hosting:channel:deploy homolog`
- [ ] Auth Email (e/ou Google) habilitado no Console
- [ ] Domínios autorizados: `carajas360-a17c5--homolog-88u39zqx.web.app`
- [ ] Decisão: grounded-only **ou** Blaze + Anthropic secret
