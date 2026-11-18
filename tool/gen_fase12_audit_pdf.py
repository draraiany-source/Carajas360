# -*- coding: utf-8 -*-
"""Gera docs/AUDITORIA_FINAL_CARAJAS360.pdf (FASE 12) sem deps externas."""
from pathlib import Path

OUT = Path("docs/AUDITORIA_FINAL_CARAJAS360.pdf")
PAGES = []


def add(lines):
    PAGES.append(lines)


# Helvetica built-in: ASCII-safe (acentos simplificados)
add([
    "CARAJAS 360",
    "AUDITORIA FINAL (FASE 12)",
    "Homologacao final e liberacao para publicacao",
    "",
    "Data: 17/11/2026",
    "Branch: feat/modernizacao-visual",
    "Commit auditado: 9880c6f (relatorio c40771a)",
    "Versao app: 1.0.0+402",
    "Projeto Firebase: carajas360-a17c5",
    "",
    "========================================",
    "VEREDITO: NAO APTO PARA PUBLICACAO",
    "========================================",
    "",
    "Homolog Web parcial OK para demo.",
    "NAO publicar lojas nem hosting live.",
    "Nenhuma publicacao automatica foi feita.",
])

add([
    "BLOQUEADORES P0",
    "",
    "1. Hosting live HTTP 404",
    "   carajas360-a17c5.web.app / .firebaseapp.com",
    "",
    "2. Cloud Functions API HTTP 403",
    "   API nao habilitada no projeto",
    "",
    "3. Carajas IA sem turno LLM real",
    "   UI OK; callable aiAssistant nao deployavel",
    "",
    "4. Pagamentos E2E nao comprovados",
    "   Sem GO; PAYMENTS_ENABLED / sandbox N/E",
    "",
    "5. AAB do commit HEAD ausente",
    "   Build desta sessao sem artefato",
    "",
    "6. iOS / TestFlight nao testados",
    "   Ambiente Windows; sem IPA",
])

add([
    "FASES 1-11 (AUDITORIA FASE 12)",
    "",
    "1 Auditoria telas .......... APROVADO",
    "2 Organizar rotas/demo ...... APROVADO (codigo)",
    "3 Tela a tela cliente ....... APROVADO (codigo)",
    "4 Fluxo E2E cliente ......... NAO TESTADO (E2E)",
    "5 Fluxo profissional ........ NAO TESTADO (E2E)",
    "6 Pagamentos/webhook ........ REPROVADO p/ publicacao",
    "7 Carajas IA ................ REPROVADO p/ publicacao",
    "   (UI APROVADA; runtime LLM REPROVADO)",
    "8 Erro profissionais ........ APROVADO (homolog)",
    "9 Android/iOS ............... REPROVADO / NAO TESTADO",
    "10 Matriz homologacao ....... APROVADO (documento)",
    "11 Entrega programador ...... APROVADO (documento)",
])

add([
    "MATRIZ DE VERIFICACAO",
    "",
    "Homolog Home/Explorar ....... APROVADO",
    "  Evidencia: HTTP 200; 3 profissionais",
    "",
    "Functions npm test .......... APROVADO",
    "  Evidencia: 163/163 pass",
    "  docs/evidence/fase12_functions_test.txt",
    "",
    "Flutter test ................ REPROVADO",
    "  Evidencia: +190 ~1 -12",
    "  docs/evidence/fase12_flutter_test.txt",
    "",
    "IA UI (Central) ............. APROVADO",
    "  docs/evidence/fase12/homolog_ia_ui.png",
    "",
    "IA turno LLM ................ REPROVADO",
    "  Functions API 403",
    "",
    "Pagamentos E2E / MP ......... NAO TESTADO",
    "Live hosting ................ REPROVADO (404)",
    "AAB HEAD .................... NAO TESTADO",
    "iOS/TestFlight .............. NAO TESTADO",
    "E2E cliente/profissional .... NAO TESTADO",
])

add([
    "EVIDENCIAS GERADAS",
    "",
    "- docs/AUDITORIA_FINAL_CARAJAS360.md",
    "- docs/evidence/fase12_functions_test.txt",
    "- docs/evidence/fase12_flutter_test.txt",
    "- docs/evidence/fase12/homolog_ia_ui.png",
    "- docs/evidence/fase12/INDEX.txt",
    "- docs/evidence/homolog_ia/explorar_profissionais_ok.png",
    "",
    "Homolog:",
    "https://carajas360-a17c5--homolog-88u39zqx.web.app",
    "",
    "AAB desta sessao: NAO GERADO",
    "IPA / TestFlight: NAO GERADO",
])

add([
    "CRITERIOS PARA REAVALIAR COMO APTO",
    "",
    "1. Functions API + Blaze; deploy aiAssistant;",
    "   turno IA real evidenciado",
    "2. Hosting live 200 apos GO explicito",
    "3. Sandbox MP: PIX/cartao/webhook teste",
    "4. E2E cliente e profissional documentados",
    "5. AAB do commit candidato + SHA256",
    "6. iOS archive ou adiamento formal Apple",
    "7. flutter test estavel (ou exclusoes)",
    "8. Autorizacao explicita de publicacao",
    "",
    "========================================",
    "DECLARACAO FINAL",
    "",
    "NAO APTO para publicacao nas lojas.",
    "NAO APTO para go-live do hosting principal.",
    "",
    "Homolog: parcialmente apto para demonstracao",
    "Web (Home + Explorar + UI IA), sem declarar",
    "IA/pagamentos comerciais prontos.",
    "========================================",
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
