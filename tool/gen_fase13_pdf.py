# -*- coding: utf-8 -*-
"""Gera docs/FASE13_CARAJAS360.pdf sem deps externas."""
from pathlib import Path

OUT = Path("docs/FASE13_CARAJAS360.pdf")
PAGES = []


def add(lines):
    PAGES.append(lines)


add([
    "CARAJAS 360",
    "FASE 13 — CORRECAO DE BLOQUEADORES",
    "Preparacao Android/iOS",
    "",
    "Data: 17/11/2026",
    "Branch: feat/modernizacao-visual",
    "Commit: 686d16c",
    "Versao app: 1.0.0+403",
    "Base auditoria FASE 12: 1.0.0+402",
    "Projeto Firebase: carajas360-a17c5",
    "",
    "========================================",
    "VEREDITO: NAO APTO PARA PUBLICACAO",
    "========================================",
    "",
    "Correcoes de codigo/testes feitas.",
    "Sem evidencia de turno IA real,",
    "pagamento sandbox E2E, AAB ou IPA.",
    "Faturamento Blaze NAO alterado.",
    "Deploy live NAO executado.",
])

add([
    "BLOQUEADORES RESOLVIDOS (CODIGO)",
    "",
    "- Testes Flutter alinhados a keys reais",
    "  (placeholders / identity / Explorar)",
    "  Suite focada: 19/19 passed",
    "",
    "- Functions unitarios: 163/163 pass",
    "",
    "- flutter analyze: sem errors",
    "  (warnings/infos preexistentes)",
    "",
    "- Diagnostico hosting live 404:",
    "  sem release live; so canal homolog",
    "  Script live exige -IAuthorizeLiveDeploy",
    "",
    "- Docs iOS / GO externos / roteiro E2E",
    "",
    "- Webhook MP: exige payments/{id}",
    "  + status aprovado (codigo)",
])

add([
    "BLOQUEADORES PENDENTES (EXTERNOS / GO)",
    "",
    "1. Billing Blaze = No",
    "2. Cloud Functions API HTTP 403",
    "3. aiAssistant nao deployavel sem Blaze",
    "4. Turno IA real sem evidencia",
    "5. Pagamentos sandbox E2E (sem GO)",
    "6. Hosting live 404 (sem GO)",
    "7. AAB assinado (sem key.properties)",
    "8. IPA / TestFlight (precisa macOS)",
    "9. Disco C: quase cheio (ENOSPC/Gradle)",
])

add([
    "FIREBASE E IA",
    "",
    "Causa do 403: API desabilitada +",
    "billing nao habilitado.",
    "",
    "aiAssistant: codigo OK (auth, grounded,",
    "chave so no backend). Deploy N/E.",
    "Evidencia conversa IA real: AUSENTE",
    "",
    "FLUXOS",
    "",
    "Cliente (codigo): OK | E2E: N/E",
    "Profissional (codigo): OK | E2E: N/E",
    "Roteiro: docs/FASE13_ROTEIRO_E2E.md",
    "",
    "PAGAMENTOS",
    "",
    "Unitarios: 163 pass",
    "PIX/cartao/webhook sandbox: N/E",
    "Cobranca real: NAO ativada",
])

add([
    "ANDROID / IOS / WEB",
    "",
    "Android:",
    "  Testes criticos: PASS",
    "  APK debug: NAO GERADO (Gradle/disco)",
    "  AAB: NAO GERADO (keystore + disco)",
    "",
    "iOS:",
    "  Preparacao: docs/IOS_BUILD_TESTFLIGHT.md",
    "  IPA: NAO GERADO (Windows)",
    "",
    "Web:",
    "  Homolog: HTTP 200",
    "  https://carajas360-a17c5--homolog-88u39zqx.web.app",
    "  Live / firebaseapp.com: HTTP 404",
])

add([
    "PROXIMAS ACOES EXTERNAS (OWNER)",
    "",
    "1. Liberar espaco em disco (C:)",
    "2. GO Blaze + habilitar Functions API",
    "3. Deploy aiAssistant (+ secret opcional)",
    "4. Conversa IA real + evidencia",
    "5. Contas teste -> roteiro E2E",
    "6. Token MP sandbox (nao producao)",
    "7. key.properties -> AAB + SHA256",
    "8. Mac + Apple Developer -> IPA",
    "9. GO explicito -> live_web_deploy.ps1",
    "",
    "========================================",
    "DECLARACAO FINAL",
    "",
    "NAO APTO para publicacao.",
    "Homolog: demo parcial (UI + profissionais).",
    "Sem declarar IA/pagamentos comerciais.",
    "========================================",
    "",
    "Fonte: docs/FASE13_CARAJAS360.md",
])


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def page_content(lines):
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


OUT.parent.mkdir(parents=True, exist_ok=True)

kids = []
body_objs = []
obj_num = 4
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

out = bytearray()
out.extend(b"%PDF-1.4\n")
offsets = [0]


def add_obj_str(s: str):
    offsets.append(len(out))
    out.extend(s.encode("latin-1", "replace"))


add_obj_str("1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n")
add_obj_str(
    f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(PAGES)} >>endobj\n"
)
add_obj_str("3 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n")
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
