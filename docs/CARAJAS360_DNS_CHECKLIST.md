# CARAJAS360 - Checklist DNS (carajas360.com.br)

**STATUS:** **EXTERNAL CONFIG REQUIRED**  
**Dominio (AppInfo / comentarios):** `carajas360.com.br`  
**E-mails no app:** `suporte@carajas360.com.br`, `privacidade@carajas360.com.br`  
**Fonte codigo:** `lib/core/constants/app_constants.dart` (`AppInfo.supportEmail` / `privacyEmail`)  
**F7:** DNS/MX **nao** validados neste fechamento documental — **nao** marcar PASS.

## 1. Objetivo

Garantir que contatos LGPD/suporte publicados no app e nas paginas legais **recebam** e-mail (MX) e que o dominio esteja sob controle da operacao.

## 2. Registros esperados (checklist — preencher apos validacao externa)

| Tipo | Nome / host | Valor esperado | Validado? |
|------|-------------|----------------|-----------|
| Registrar dominio | carajas360.com.br | Conta registrar sob controle | [ ] |
| A / CNAME (site opcional) | @ / www | Conforme hosting escolhido | [ ] |
| MX | @ | Provedor e-mail (Google Workspace, Microsoft 365, etc.) | [ ] |
| TXT SPF | @ | Politica SPF do provedor | [ ] |
| TXT DKIM | conforme provedor | Chaves DKIM | [ ] |
| TXT DMARC | _dmarc | Politica DMARC inicial | [ ] |

**Nao inventar** valores MX/IP neste documento.

## 3. Como validar (sem secrets)

1. Confirmar propriedade do dominio no painel do registrador.
2. No provedor de e-mail, criar caixas (ou grupos) `suporte@` e `privacidade@`.
3. Publicar MX (+ SPF/DKIM/DMARC) conforme instrucoes do provedor.
4. Propagacao: aguardar TTL; testar com ferramentas publicas, por exemplo:
   - `nslookup -type=MX carajas360.com.br`
   - `dig MX carajas360.com.br` (Linux/macOS)
   - Painel "Check MX" do provedor
5. Enviar e-mail de teste **de fora** para ambos os enderecos; confirmar recebimento (operacao — nao versionar conteudo).
6. Alinhar paginas `hosting/privacy.html` / `terms.html` e AppInfo se o dominio de contato mudar.

## 4. Relacao com hosting Firebase

URLs legais atuais apontam para `https://carajas360-a17c5.web.app/privacy` e `/terms`. Dominio custom (ex.: `www.carajas360.com.br`) e **opcional** e separado do MX — exige Firebase Hosting custom domain + DNS (EXTERNAL).

## 5. Gate F7

| Item | Status |
|------|--------|
| Emails no codigo | Definidos (carajas360.com.br) |
| MX operacional | EXTERNAL — NOT VERIFIED nesta fase |
| Entrega suporte@ / privacidade@ | EXTERNAL |

🟡 CONFIGURAÇÕES/TESTES EXTERNOS PENDENTES
