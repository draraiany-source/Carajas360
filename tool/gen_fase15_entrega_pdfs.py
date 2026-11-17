# -*- coding: utf-8 -*-
"""Gera/atualiza PDFs 13-15 e resumo FASE 15 no pacote de entrega."""
from pathlib import Path

ROOT = Path("ENTREGA_PROGRAMADOR_CARAJAS360")
DOCS = Path("docs")
HEAD = "e07b633"
VER = "1.0.0+403"


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


def write_pdf(path: Path, pages):
    path.parent.mkdir(parents=True, exist_ok=True)
    kids, body_objs, obj_num = [], [], 4
    for lines in pages:
        page_n, content_n = obj_num, obj_num + 1
        kids.append(f"{page_n} 0 R")
        raw = page_content(lines).encode("latin-1", "replace")
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
        f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(pages)} >>endobj\n"
    )
    add_obj_str("3 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n")
    for b in body_objs:
        offsets.append(len(out))
        out.extend(b if isinstance(b, bytes) else b.encode("latin-1", "replace"))
    xref = len(out)
    n = len(offsets)
    out.extend(f"xref\n0 {n}\n".encode())
    out.extend(b"0000000000 65535 f \n")
    for off in offsets[1:]:
        out.extend(f"{off:010d} 00000 n \n".encode())
    out.extend(
        f"trailer<< /Size {n} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode()
    )
    path.write_bytes(out)
    print(f"OK {path} bytes={path.stat().st_size} pages={len(pages)}")


DOCS_PDF = {
    "13_AUDITORIA_MULTIMIDIA.pdf": [
        [
            "13 AUDITORIA MULTIMIDIA — ORCAMENTO",
            f"HEAD {HEAD} | {VER}",
            "",
            "FOTOS (IMPLEMENTADO E TESTADO)",
            "- Ate 10 fotos (OrderPhotos.maxCount)",
            "- Camera e galeria (OrderPhotoPicker)",
            "- Preview, remocao, substituicao",
            "- Limite 8 MB / formatos JPG PNG WebP HEIC",
            "- Upload Storage + attachOrderPhotos",
            "- Galeria no pedido (cliente/pro)",
            "- Testes unit + fluxo + emulador (e07b633)",
            "",
            "VIDEO CURTO NO ORCAMENTO",
            "Status: AUSENTE",
            "Pendencia: implementar no fluxo existente",
            "",
            "AUDIO EXPLICATIVO NO ORCAMENTO",
            "Status: AUSENTE no pedido",
            "(Audio existe no chat, nao no orcamento)",
        ],
        [
            "MODALIDADES",
            "",
            "A — Profissional especifico:",
            "  /provider-profile -> /request-service",
            "",
            "B — Multiplos compativeis:",
            "  /resolve ou marketplace matching",
            "  acceptResolveProposal -> Meus pedidos",
            "",
            "PRIVACIDADE",
            "Storage rules + pedido associado",
            "Nao inventar analise medica/preco via IA",
            "OrderPhotos.iaPromptHint: so descricao",
            "",
            "PROXIMO PASSO PROGRAMADOR",
            "Se contratado: video+audio no mesmo picker",
            "com limites, mime types e rules Storage",
        ],
    ],
    "14_TESTES_EVIDENCIAS.pdf": [
        [
            "14 TESTES E EVIDENCIAS — FASE 15",
            f"Data 17/11/2026 | HEAD {HEAD}",
            "",
            "APROVADO",
            "- functions npm test 163/163",
            "- flutter test order_photos + config 14/14",
            "- Homolog Web HTTP 200",
            "",
            "REPROVADO",
            "- Cloud Functions API HTTP 403",
            "- Billing Blaze = No",
            "- Live hosting HTTP 404",
            "",
            "NAO EXECUTADO",
            "- E2E cliente autenticado",
            "- E2E profissional",
            "- IA chamada real ao modelo",
            "- MP sandbox PIX/cartao/webhook",
            "- APK / AAB / IPA",
            "- Paridade visual premium 3D",
            "",
            "Sem evidencia = Nao Executado.",
            "Nao substituir por simulacao.",
        ],
    ],
    "15_PLANO_FINALIZACAO_PROGRAMADOR.pdf": [
        [
            "15 PLANO DE FINALIZACAO — PROGRAMADOR",
            f"Baseline {HEAD} | pacote F14 82dc012",
            "",
            "ORDEM SUGERIDA",
            "1. Ler README_ENTREGA + FASE15",
            "2. flutter pub get; npm test; flutter test",
            "3. Liberar disco; APK debug",
            "4. key.properties -> AAB + SHA256",
            "5. Owner: Blaze + APIs",
            "6. Deploy aiAssistant; prova IA",
            "7. E2E cliente + profissional",
            "8. MP sandbox (sem producao)",
            "9. Multimidia video/audio se no escopo",
            "10. Mac -> TestFlight",
            "11. GO -> live Web / lojas",
            "",
            "CRITERIOS ACEITE: PDF 12",
            "EDITAL: EDITAL_CONTRATACAO_*.pdf",
            "",
            "NAO reconstruir o app.",
            "NAO publicar sem GO.",
        ],
    ],
}

FASE15_SUMMARY = [
    [
        "CARAJAS 360 — FASE 15",
        "AUDITORIA DEFINITIVA E ENTREGA",
        "",
        f"HEAD: {HEAD}",
        f"Versao: {VER}",
        "Branch: feat/modernizacao-visual",
        "Firebase: carajas360-a17c5",
        "",
        "========================================",
        "VEREDITO A-E",
        "A Entrega programador ..... SIM",
        "B Prod. controlada ........ NAO",
        "C Publicacao Web .......... NAO",
        "D Publicacao Android ...... NAO",
        "E Publicacao iOS .......... NAO",
        "========================================",
    ],
    [
        "BLOQUEADORES EXTERNOS",
        "- Blaze off + Functions API 403",
        "- Live hosting 404",
        "- Sem AAB/IPA neste HEAD",
        "- IA real e MP sandbox N/E",
        "",
        "MULTIMIDIA",
        "Fotos orcamento: IMPLEMENTADO+TESTADO",
        "Video/audio orcamento: AUSENTE",
        "",
        "TESTES FASE 15",
        "Functions 163 PASS | fotos 14 PASS",
        "Homolog 200 | Live 404",
        "",
        "Pacote: ENTREGA_PROGRAMADOR_CARAJAS360",
        "Docs: docs/FASE15_AUDITORIA_DEFINITIVA.md",
        "",
        "NAO APTO PARA PUBLICACAO.",
    ],
]


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, pages in DOCS_PDF.items():
        write_pdf(ROOT / name, pages)
    write_pdf(DOCS / "FASE15_AUDITORIA_DEFINITIVA.pdf", FASE15_SUMMARY)
    # Atualiza manifesto
    (ROOT / "00_MANIFESTO.txt").write_text(
        f"PACOTE ENTREGA FASE15\nHEAD={HEAD}\nVER={VER}\n"
        f"A=SIM B=NAO C=NAO D=NAO E=NAO\n"
        f"BLAZE=No CF_API=403 LIVE=404 HOMOLOG=200\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
