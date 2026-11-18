# -*- coding: utf-8 -*-
"""Gera PDFs a partir dos Markdowns em docs/FASE17/."""
from pathlib import Path
import re
import zipfile

ROOT = Path("docs/FASE17")
HEAD = "f61deda"
VER = "1.0.0+403"
LINES_PER_PAGE = 58


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


def md_to_lines(text: str):
    lines = []
    for raw in text.splitlines():
        line = raw.rstrip()
        line = re.sub(r"^#+\s*", "", line)
        line = re.sub(r"\*\*(.+?)\*\*", r"\1", line)
        line = re.sub(r"`([^`]+)`", r"\1", line)
        line = line.replace("|", " ")
        line = re.sub(r"^[-*]\s+", "- ", line)
        line = re.sub(r"\s+", " ", line).strip()
        if not line or set(line) <= {"-", "="}:
            if lines and lines[-1] != "":
                lines.append("")
            continue
        # wrap long lines
        while len(line) > 95:
            cut = line.rfind(" ", 0, 95)
            if cut < 40:
                cut = 95
            lines.append(line[:cut].rstrip())
            line = line[cut:].lstrip()
        lines.append(line)
    return lines


def chunk_pages(lines):
    pages, cur = [], []
    for line in lines:
        cur.append(line)
        if len(cur) >= LINES_PER_PAGE:
            pages.append(cur)
            cur = []
    if cur:
        pages.append(cur)
    return pages or [["(vazio)"]]


def page_content(lines):
    cmds = ["BT", "/F1 10 Tf", "50 800 Td", "12 TL"]
    first = True
    for line in lines:
        text = escape(line[:110])
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
    print(f"OK {path.name} pages={len(pages)} bytes={path.stat().st_size}")


def main():
    pdfs = []
    for md in sorted(ROOT.glob("*.md")):
        lines = [
            f"CARAJAS 360 — FASE 17",
            f"Fonte: {md.name} | HEAD {HEAD} | {VER}",
            "",
        ] + md_to_lines(md.read_text(encoding="utf-8"))
        out = ROOT / (md.stem + ".pdf")
        write_pdf(out, chunk_pages(lines))
        pdfs.append(out)

    # Capa resumo
    cover = [
        "CARAJAS 360 — FASE 17 (PDF)",
        f"HEAD {HEAD} | App {VER}",
        "Branch: feat/modernizacao-visual",
        "Firebase: carajas360-a17c5",
        "",
        "CLASSIFICACAO",
        "APTO PARA ENTREGA AO PROGRAMADOR, COM PENDENCIAS",
        "NAO APTO PARA PUBLICACAO",
        "",
        "Arquivos PDF gerados:",
    ] + [f"- {p.name}" for p in pdfs]
    write_pdf(ROOT / "00_CAPA_FASE17.pdf", [cover])

    zip_path = ROOT / "ENTREGA_FASE17_PDFS.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for p in sorted(ROOT.glob("*.pdf")):
            zf.write(p, arcname=p.name)
        for p in sorted(ROOT.glob("*.md")):
            zf.write(p, arcname=f"md/{p.name}")
    print(f"OK ZIP {zip_path} bytes={zip_path.stat().st_size}")


if __name__ == "__main__":
    main()
