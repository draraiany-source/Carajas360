# -*- coding: utf-8 -*-
"""Gera docs/FASE14_ENTREGA_PROGRAMADOR.pdf (resumo FASE 14)."""
from pathlib import Path

OUT = Path("docs/FASE14_ENTREGA_PROGRAMADOR.pdf")
PAGES = []


def add(lines):
    PAGES.append(lines)


add([
    "CARAJAS 360",
    "FASE 14 — PACOTE DE ENTREGA AO PROGRAMADOR",
    "",
    "Data: 17/11/2026",
    "Commit baseline: 686d16c",
    "Commit pacote: 82dc012",
    "Versao app: 1.0.0+403",
    "Branch: feat/modernizacao-visual",
    "Firebase: carajas360-a17c5",
    "",
    "========================================",
    "ESTADO: NAO APTO PARA PUBLICACAO",
    "========================================",
    "",
    "NAO recriar o aplicativo.",
    "Trabalhar no repositorio existente.",
])

add([
    "PACOTE ENTREGUE",
    "",
    "Pasta: ENTREGA_PROGRAMADOR_CARAJAS360/",
    "  01_RELATORIO_EXECUTIVO.pdf",
    "  02_INVENTARIO_TELAS.pdf",
    "  03_MAPA_FLUXOS.pdf",
    "  04_PENDENCIAS_TECNICAS.pdf",
    "  05_GUIA_FIREBASE_IA.pdf",
    "  06_GUIA_PAGAMENTOS.pdf",
    "  07_GUIA_ANDROID.pdf",
    "  08_GUIA_IOS.pdf",
    "  09_GUIA_WEB.pdf",
    "  10_CHECKLIST_PUBLICACAO.pdf",
    "  11_ROTEIRO_TESTES.pdf",
    "  12_CRITERIOS_ACEITE.pdf",
    "  README_ENTREGA.md",
    "  MAPA_FLUXOS.md / SEGURANCA_CREDENCIAIS.md",
    "",
    "ZIP: ENTREGA_PROGRAMADOR_CARAJAS360_686d16c.zip",
    "SHA256:",
    "BF89716F5E2C5E3CD9BC1D7147D3CC396010963240AE8EA071C5D29DE7D238B9",
    "ZIP = documentacao (codigo via Git)",
])

add([
    "O QUE ESTA PRONTO",
    "",
    "- App Flutter Web/Android/iOS existente",
    "- Homolog Web + Explorar (profissionais reais)",
    "- UI Carajas IA (runtime Function pendente)",
    "- Pedidos, Resolve, chat, admin/Disputas",
    "- Policy/webhook em codigo",
    "- Pacote PDF 01-12 de transferencia",
    "",
    "PROGRAMADOR DEVE",
    "",
    "- Disco/Gradle -> APK e AAB+SHA256",
    "- Apos Blaze: deploy aiAssistant + evidencia",
    "- E2E cliente e profissional",
    "- Sandbox Mercado Pago (sem producao)",
    "- iOS no Mac (TestFlight) ou adiamento",
])

add([
    "PROPRIETARIA / CONTAS EXTERNAS",
    "",
    "- GO Blaze Firebase + APIs",
    "- Secrets Anthropic / Mercado Pago",
    "- GO hosting live e lojas",
    "- Apple Developer, Play Console",
    "",
    "BUILDS AINDA FALTANDO",
    "",
    "- APK debug",
    "- AAB release assinado + SHA256",
    "- IPA / TestFlight",
    "",
    "Homolog:",
    "https://carajas360-a17c5--homolog-88u39zqx.web.app",
    "",
    "========================================",
    "Aceite: 12_CRITERIOS_ACEITE.pdf",
    "Nao declarar pronto sem homologacao + GO.",
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

out = bytearray(b"%PDF-1.4\n")
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
    out.extend(b if isinstance(b, bytes) else b.encode("latin-1", "replace"))

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
