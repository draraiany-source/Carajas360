# Segurança e credenciais (FASE 14)

## Varredura neste pacote / baseline `686d16c`

| Item | Situação |
|------|----------|
| `android/key.properties` | **Ausente** (só `.example`) — correto |
| Keystores `.jks` | **Não** no repo |
| `functions/.env` com tokens | Usar só `.env.example` |
| Secrets Anthropic/MP | Secret Manager / env runtime — **não** no Git |
| `firebase_options` / `google-services.json` / plist | Keys **de cliente** Firebase (públicas no app) — não são tokens de servidor; ainda assim não espalhar desnecessariamente |

## O que NÃO incluir no ZIP nem em tickets

- Senhas de keystore / App Store Connect
- `MERCADOPAGO_ACCESS_TOKEN`, `ANTHROPIC_API_KEY`, webhook secrets
- Service account JSON
- Dump de usuários reais / PII

## Procedimento seguro

1. Credenciais só em Secret Manager, CI secrets ou arquivo local ignorado pelo `.gitignore`.
2. Rotacionar qualquer chave que tenha sido colada em chat.
3. Deploy Functions/Hosting só com conta do projeto e GO quando for live/pagamentos.
4. Revisar `git status` antes de commit: nunca `key.properties`, `.env`, `*.jks`.
