# -*- coding: utf-8 -*-
from pathlib import Path

OUT = Path("AUDITORIA_POS_CORRECOES_CARAJAS_360.pdf")
PAGES = []

def add(lines):
    PAGES.append(lines)

add([
    "CARAJAS 360",
    "AUDITORIA POS-CORRECOES",
    "Comparativo ANTES x DEPOIS",
    "",
    "Data: 20/09/2026",
    "Backup commit: 111caff",
    "Branch: cursor/bloco-a-security-staging-c199",
    "",
    "CLASSIFICACAO FINAL:",
    "NAO PRONTO PARA PUBLICACAO",
    "",
    "(Criticos C1 Firebase placeholders e",
    " C7 App Check enforce ainda abertos.",
    " AAB/local keystore: ver secao C2.)",
    "",
    "Sem producao. Sem PAYMENTS_ENABLED=true.",
    "Sem upload Play/App Store.",
])

add([
    "TABELA COMPARATIVA",
    "",
    "C1 Firebase placeholder",
    "ANTES: BLOQUEIA (COLE_SUA_*)",
    "DEPOIS: PARCIAL / AINDA BLOQUEIA",
    "Evidencia: test/firebase_placeholders_test.dart",
    "  (detecta placeholder); FLUTTERFIRE_STAGING.md",
    "  Raiany precisa flutterfire configure",
    "",
    "C2 Android keystore",
    "ANTES: BLOQUEIA (sem key.properties)",
    "DEPOIS: PARCIAL OK LOCAL",
    "Evidencia: upload-keystore-staging.jks gerado",
    "  local (gitignored); ANDROID_KEYSTORE_SETUP.md",
    "  AAB: ver resultado do build nesta sessao",
    "",
    "C3 iOS",
    "ANTES: BLOQUEIA (sem xcodeproj)",
    "DEPOIS: PARCIAL OK ESTRUTURA",
    "Evidencia: ios/Runner.xcodeproj recriado",
    "  (flutter create --platforms=ios)",
    "  Codesign/TestFlight ainda pendente",
])

add([
    "C4 Privacy URL",
    "ANTES: BLOQUEIA (so in-app)",
    "DEPOIS: OK CODIGO STAGING",
    "Evidencia: web/privacy.html + web/terms.html",
    "  firebase.json rewrites /privacy /terms",
    "  AppInfo.privacyUrl / termsUrl",
    "  Deploy hosting staging ainda pendente",
    "",
    "C5 Pagamentos",
    "ANTES: 15/85; Asaas N/A; MP off",
    "DEPOIS: PARCIAL",
    "Evidencia: comissao 0.08 (8/92) em Dart+JS",
    "  testes 100->8/92, 250->20/230, 1000->80/920",
    "  PAGAMENTOS_ATUAIS_CARAJAS360.md",
    "  Asaas: ainda NAO IMPLEMENTADO (decisao dona)",
    "  PAYMENTS_ENABLED=false mantido",
    "",
    "C6 Escrow 3 dias",
    "ANTES: NAO IMPLEMENTADO",
    "DEPOIS: OK ARQUITETURA STAGING",
    "Evidencia: orderPolicy escrowHoldOnPaid,",
    "  canReleaseEscrow, transitionOrder hold/release",
    "  Sem dinheiro real",
])

add([
    "C7 App Check",
    "ANTES: desligado",
    "DEPOIS: PARCIAL (docs + bootstrap)",
    "Evidencia: APP_CHECK_SETUP.md",
    "  ENFORCE ainda false (correto ate keys)",
    "  AINDA BLOQUEIA publicacao loja",
    "",
    "A1 E2E staging",
    "ANTES: nao executado",
    "DEPOIS: PARCIAL checklist",
    "Evidencia: E2E_STAGING_SMOKE.md",
    "  Live E2E bloqueado sem Firebase real",
    "",
    "A2 Cancel admin",
    "ANTES: NAO IMPLEMENTADO",
    "DEPOIS: OK CODIGO",
    "Evidencia: admin Reabrir / Cancelar definitiva",
    "  FS.adminReopenOrder / adminCancelOrderDefinitive",
    "  transitionOrder + audit; testes policy",
    "",
    "A3 Maps",
    "ANTES: placeholder",
    "DEPOIS: PARCIAL docs restricao",
    "Evidencia: CHECKLIST_GOOGLE_MAPS.md staging",
    "  Key real: Raiany (nao inventada)",
])

add([
    "A4 Listing lojas",
    "ANTES: incompleto",
    "DEPOIS: PARCIAL checklist",
    "Evidencia: STORE_LISTING_CHECKLIST.md",
    "",
    "Extras corrigidos:",
    "- Botao Sair da conta no Admin (signOut+login)",
    "- Nomes legados Servico Conecta em UI/comentarios",
    "- Emails demo -> @carajas360.local (suporte",
    "  @servicoconecta documentado residual)",
    "",
    "TESTES EXECUTADOS:",
    "- flutter test order_policy + placeholders",
    "  + admin_order_actions: PASS",
    "- node --test orderPolicy.test.js: 26 PASS",
    "",
    "NAO FEITO (proposital):",
    "- flutterfire configure (precisa Console)",
    "- PAYMENTS_ENABLED=true",
    "- Upload Play/App Store",
    "- Deploy hosting (precisa auth Firebase CLI)",
])

add([
    "CONCLUSAO OBRIGATORIA",
    "",
    ">>> NAO PRONTO PARA PUBLICACAO <<<",
    "",
    "Motivo: C1 placeholders Firebase e C7 App Check",
    "ainda bloqueiam loja; Maps key e E2E live pendentes.",
    "",
    "Pode ir para teste interno?",
    "PARCIAL — apos flutterfire + AAB validado",
    "  e smoke E2E_STAGING_SMOKE.md",
    "",
    "Pode publicar usuarios reais?",
    "NAO",
    "",
    "Proximos passos Raiany:",
    "1) flutterfire configure (FLUTTERFIRE_STAGING.md)",
    "2) Deploy hosting privacy/terms",
    "3) Validar AAB interno (keystore local)",
    "4) Decidir Asaas vs Mercado Pago",
    "5) App Check staging + smoke E2E",
])

def esc(s):
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")

def page_content(lines):
    cmds = ["BT", "/F1 10 Tf", "50 800 Td", "12 TL"]
    first = True
    for line in lines:
        t = esc(line)
        if first:
            cmds.append("(%s) Tj" % t); first = False
        else:
            cmds.append("T*"); cmds.append("(%s) Tj" % t)
    cmds.append("ET")
    return "\n".join(cmds)

out = bytearray(b"%PDF-1.4\n")
offsets = [0]
kids = []
obj_num = 4
body = []
for lines in PAGES:
    page_n, content_n = obj_num, obj_num + 1
    kids.append("%d 0 R" % page_n)
    stream = page_content(lines)
    raw = stream.encode("latin-1", "replace")
    body.append(("%d 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents %d 0 R /Resources << /Font << /F1 3 0 R >> >> >>endobj\n" % (page_n, content_n)).encode())
    body.append(b"%d 0 obj<< /Length %d >>stream\n" % (content_n, len(raw)) + raw + b"\nendstream\nendobj\n")
    obj_num += 2

def add(s):
    offsets.append(len(out))
    if isinstance(s, str):
        out.extend(s.encode("latin-1", "replace"))
    else:
        out.extend(s)

add("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n")
add("2 0 obj<< /Type /Pages /Kids [%s] /Count %d >>endobj\n" % (" ".join(kids), len(PAGES)))
add("3 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n")
for b in body:
    add(b)
xref = len(out)
out.extend(("xref\n0 %d\n" % len(offsets)).encode())
out.extend(b"0000000000 65535 f \n")
for off in offsets[1:]:
    out.extend(("%010d 00000 n \n" % off).encode())
out.extend(("trailer<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(offsets), xref)).encode())
OUT.write_bytes(out)
print("PDF_OK", OUT.resolve(), "bytes", OUT.stat().st_size)