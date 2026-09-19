# -*- coding: utf-8 -*-
"""Gera AUDITORIA_FINAL_PUBLICACAO_CARAJAS_360.pdf sem deps externas."""
from pathlib import Path

OUT = Path("AUDITORIA_FINAL_PUBLICACAO_CARAJAS_360.pdf")

PAGES = []

def add_page(lines):
    PAGES.append(lines)

# Conteudo (ASCII-safe para Helvetica PDF built-in; acentos simplificados)
add_page([
    "CARAJAS 360",
    "AUDITORIA FINAL PARA PUBLICACAO",
    "",
    "Seguranca | Funcionamento | Estabilidade | Lojas",
    "",
    "Data: 19/09/2026",
    "Versao auditada: 1.0.0+1",
    "Commit: f367955e04f39f12d30a7879508fb49100317f80",
    "Branch: cursor/bloco-a-security-staging-c199",
    "Flutter 3.44.4 | Dart 3.12.2",
    "",
    "CLASSIFICACAO:",
    "NAO PRONTO PARA PUBLICACAO",
    "",
    "Ambiente: desenvolvimento/staging (sem producao)",
    "Pagamentos reais: NAO (PAYMENTS_ENABLED=false)",
    "Asaas: NAO IMPLEMENTADO (codigo usa Mercado Pago)",
])

add_page([
    "1. MAPA TECNICO ATUAL DO CARAJAS 360",
    "",
    "- Nome: Carajas 360 (legado: Servico Conecta)",
    "- Repo: github.com/draraiany-source/Carajas360.git",
    "- Package Dart: carajas_360",
    "- Android/iOS ID: br.com.carajas360",
    "- Firebase: carajas360-a17c5",
    "- Backend: Cloud Functions Node 20",
    "- DB: Firestore | Storage | Auth | FCM | Crashlytics",
    "- Admin: lib/features/admin/admin_screen.dart",
    "- Hosting: build/web (firebase.json)",
    "",
    "Ambientes:",
    "- DEV: emuladores + placeholders COLE_SUA_*",
    "- STAGING: projeto carajas360-a17c5 (client ainda placeholder)",
    "- PRODUCAO: NAO ativada",
    "",
    "APIs: Mercado Pago, Google Maps, Google/Apple Sign-In",
    "Asaas: NAO IMPLEMENTADO",
])

add_page([
    "2. COMPILACAO",
    "",
    "- Release Android: BLOQUEIA (sem key.properties/keystore)",
    "- Release iOS: BLOQUEIA (sem Runner.xcodeproj)",
    "- Release Firebase placeholder: BLOQUEIA (StateError)",
    "- CI branch: documentado verde em PROXIMO_PASSO_STAGING.md",
    "- Analyze/test locais: runtime longo nesta sessao;",
    "  nao marcar como OK sem saida completa no terminal",
    "",
    "3. FIREBASE SECURITY",
    "",
    "Auth: PARCIAL (login/logout/cadastro/exclusao OK no codigo)",
    "Firestore: OK deny-by-default; wallets/payments write false",
    "  users: campos type/plan/xp/verified protegidos",
    "  reviews: so completed + ID unico",
    "  catalogo publico: providers/categories read true (esperado)",
    "Storage: OK ownership + MIME + size limits",
    "App Check: BLOQUEIA (desligado; activate nao implementado)",
])

add_page([
    "4. RBAC",
    "",
    "- Cliente nao acessa admin (AdminGate) — OK",
    "- Prestador nao altera verified/rating — OK",
    "- Admin: claim admin/role ou type==admin — OK",
    "- adminRole sozinho NAO libera — OK",
    "- Botao Sair conta admin dedicado: PARCIAL",
    "  (Sair da conta no Perfil; painel so fecha)",
    "",
    "5. SEM LOGIN: PARCIAL (rotas publicas existem;",
    "   E2E dispositivo nao executado)",
    "",
    "6-8. FLUXOS CLIENTE/PRESTADOR/ADMIN",
    "- Codigo presente; E2E staging NAO EXECUTADO",
    "  (BLOQUEIA confianca de publicacao)",
    "- Admin tabs: Usuarios, Validacao, Categorias,",
    "  Financeiro, Marketing, Atendimento, Denuncias,",
    "  Auditoria, Configuracoes",
])

add_page([
    "9. CANCELAMENTO",
    "- cancelOrder via transitionOrder: OK",
    "- REABIR admin: NAO IMPLEMENTADO",
    "- CANCELAR DEFINITIVAMENTE admin: NAO IMPLEMENTADO",
    "",
    "10. PAGAMENTOS",
    "- Asaas: NAO IMPLEMENTADO",
    "- Mercado Pago: PARCIAL (PAYMENTS_ENABLED=false)",
    "- Comissao codigo: 15% plataforma / 85% prestador",
    "- Regra pedida 8%/92%: DIVERGENTE",
    "- Split gateway: NAO IMPLEMENTADO",
    "- BLOQUEIA PUBLICACAO",
    "",
    "11. ESCROW 3 dias: NAO IMPLEMENTADO",
    "12. Webhook MP sandbox: OK desenho (applied=false)",
    "    Webhook Asaas: NAO IMPLEMENTADO",
    "13. Maps: PARCIAL (placeholder)",
    "14. Chat rules: OK participantes",
    "15. Notificacoes FCM: PARCIAL (E2E nao)",
    "16. Avaliacoes rules: OK",
])

add_page([
    "17. IDENTIDADE / NOMES ANTIGOS",
    "",
    "Residuais servicoconecta / Servico Conecta:",
    "- lib/core/constants/app_constants.dart (emails)",
    "- lib/core/auth/dev_bypass_auth.dart",
    "- lib/features/wallet/wallet_screen.dart",
    "- comentarios home_screen / carajas_home_screen",
    "AgroConecta em lib/: nao encontrado",
    "",
    "18. UX: PARCIAL (comingSoon Fase 2)",
    "19. LGPD: Termos/Politica in-app OK;",
    "    URL publica: NAO IMPLEMENTADO — BLOQUEIA",
    "20. Exclusao conta: OK (anonimiza + 5 anos)",
    "",
    "21. GOOGLE PLAY",
    "- Exigencia (doc oficial): desde 31/08/2026",
    "  novos apps/updates target API 36",
    "- AAB: bloqueado sem keystore",
    "- Data Safety/listing: NAO PRONTO",
    "",
    "22. APP STORE: BLOQUEIA (sem Xcode project)",
    "23. Assets lojas: NAO CONCLUIDO",
])

add_page([
    "24-26. Performance/Rede/Logs: PARCIAL",
    "27. Backup: Git OK; Firestore ops PARCIAL",
    "28. Security tests unitarios: OK blocos;",
    "    E2E IDOR staging: NAO EXECUTADO",
    "29. Secrets: OK (so placeholders no Git)",
    "30. GitHub .gitignore: OK keystore/.env",
    "31. Ambientes DEV/STG/PROD: PARCIAL",
    "",
    "32. COLECOES Firestore (Col.*):",
    "users providers companies orders wallets",
    "transactions reviews chatRooms notifications",
    "coupons deliveries appointments contracts",
    "support auditLogs banners categories favorites",
    "reports employees branches stores products",
    "rentals bookings resolveRequests resolveProposals",
    "financialAudits rateLimits planChangeRequests",
    "+ config/platform payments legalRetention xpEvents",
])

add_page([
    "34. ACHADOS",
    "",
    "CRITICOS (BLOQUEIA PUBLICACAO):",
    "C1 Firebase COLE_SUA_* placeholders",
    "C2 Sem keystore Android",
    "C3 Sem Runner.xcodeproj iOS",
    "C4 Sem URL publica privacidade",
    "C5 Pagamentos Asaas N/A; MP off; 8/92 vs 15/85",
    "C6 Escrow NAO IMPLEMENTADO",
    "C7 App Check off",
    "",
    "ALTOS: A1 smoke staging; A2 cancel admin;",
    "A3 Maps key; A4 listings loja",
    "",
    "MEDIOS: emails legado; PDF auditoria WIP;",
    "separacao prod",
    "",
    "BAIXOS: withOpacity; chat voz stub",
    "",
    "35. CORRECOES NESTA AUDITORIA:",
    "Nenhuma alteracao funcional (somente documento).",
])

add_page([
    "37. CHECKLIST PUBLICACAO (resumo)",
    "[ ] Android release  [ ] iOS  [ ] App Check",
    "[x] Rules deny-default  [x] Storage seguro",
    "[x] Secrets no Git protegidos  [x] RBAC basico",
    "[ ] E2E cliente/prestador/admin",
    "[ ] Asaas/MP sandbox completo  [ ] Split alinhado",
    "[ ] Privacy URL  [x] Exclusao conta",
    "[ ] Data Safety  [ ] AAB  [ ] TestFlight",
    "[~] Nome Carajas 360 (emails residuais)",
    "",
    "38. NAO PUBLICAR AUTOMATICAMENTE — confirmado",
    "",
    "40. CONCLUSAO OBRIGATORIA",
    "",
    ">>> NAO PRONTO PARA PUBLICACAO <<<",
    "",
    "BLOQUEIOS:",
    "1. Firebase placeholder (release crash)",
    "2. Sem keystore / sem Xcode",
    "3. Sem privacy URL publica",
    "4. Pagamentos/escrow/comissao nao prontos",
    "5. App Check + E2E staging ausentes",
    "",
    "JA PRONTO: rules, RBAC, LGPD exclusao,",
    "IDs tecnicos, pagamentos desligados com seguranca",
    "",
    "PROXIMOS: flutterfire configure; alinhar",
    "Asaas vs MP e %; keystore; iOS; privacy URL;",
    "teste interno Play (sem producao)",
])

def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

def page_content(lines):
    # PDF text object: start near top, 11pt leading
    cmds = ["BT", "/F1 10 Tf", "50 800 Td", "12 TL"]
    first = True
    for line in lines:
        text = escape(line)
        if first:
            cmds.append(f"({text}) Tj")
            first = False
        else:
            cmds.append("T*")
            cmds.append(f"({text}) Tj")
    cmds.append("ET")
    return "\n".join(cmds)

objects = []
# 1 catalog, 2 pages tree, 3 font, then page+content pairs

font_obj = 3
objects.append("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n")

page_objs = []
content_objs = []
obj_num = 4
kids = []

for lines in PAGES:
    page_n = obj_num
    content_n = obj_num + 1
    kids.append(f"{page_n} 0 R")
    stream = page_content(lines)
    objects.append(
        f"{page_n} 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        f"/Contents {content_n} 0 R /Resources << /Font << /F1 {font_obj} 0 R >> >> >>endobj\n"
    )
    objects.append(
        f"{content_n} 0 obj<< /Length {len(stream.encode('latin-1','replace'))} >>stream\n"
        f"{stream}\nendstream\nendobj\n"
    )
    obj_num += 2

objects.insert(1,
    f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(PAGES)} >>endobj\n"
)
objects.insert(2,
    f"{font_obj} 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n"
)

# Rebuild properly: catalog(1), pages(2), font(3), then pages...
final = []
final.append("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n")
final.append(f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(PAGES)} >>endobj\n")
final.append(f"3 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n")
# page objects start at 4
obj_num = 4
kids = []
body_objs = []
for lines in PAGES:
    page_n = obj_num
    content_n = obj_num + 1
    kids.append(f"{page_n} 0 R")
    stream = page_content(lines)
    raw = stream.encode("latin-1", "replace")
    body_objs.append(
        f"{page_n} 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
        f"/Contents {content_n} 0 R /Resources << /Font << /F1 3 0 R >> >> >>endobj\n"
    )
    body_objs.append(
        f"{content_n} 0 obj<< /Length {len(raw)} >>stream\n".encode("latin-1")
        + raw
        + b"\nendstream\nendobj\n"
    )
    obj_num += 2

final[1] = f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(PAGES)} >>endobj\n"

# Write PDF with xref
out = bytearray()
out.extend(b"%PDF-1.4\n")
offsets = [0]
def add_obj_str(s: str):
    offsets.append(len(out))
    out.extend(s.encode("latin-1", "replace"))

add_obj_str(final[0])
add_obj_str(final[1])
add_obj_str(final[2])
for b in body_objs:
    offsets.append(len(out))
    if isinstance(b, bytes):
        out.extend(b)
    else:
        out.extend(b.encode("latin-1", "replace"))

xref_pos = len(out)
n = len(offsets)
out.extend(f"xref\n0 {n}\n".encode())
out.extend(b"0000000000 65535 f \n")
for off in offsets[1:]:
    out.extend(f"{off:010d} 00000 n \n".encode())
out.extend(
    f"trailer<< /Size {n} /Root 1 0 R >>\nstartxref\n{xref_pos}\n%%EOF\n".encode()
)
OUT.write_bytes(out)
print(f"PDF_OK {OUT.resolve()} bytes={OUT.stat().st_size} pages={len(PAGES)}")