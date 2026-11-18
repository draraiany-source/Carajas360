# -*- coding: utf-8 -*-
"""Gera PDF do edital de contratacao do programador."""
from pathlib import Path

OUT = Path("ENTREGA_PROGRAMADOR_CARAJAS360/EDITAL_CONTRATACAO_PROGRAMADOR.pdf")
# Copia tambem em docs/
OUT2 = Path("docs/EDITAL_CONTRATACAO_PROGRAMADOR.pdf")
PAGES = []


def add(lines):
    PAGES.append(lines)


add([
    "CARAJAS 360",
    "EDITAL DE CONTRATACAO — PROGRAMADOR",
    "Flutter / Firebase — Finalizacao do app",
    "",
    "Baseline: 1.0.0+403 | commit 686d16c",
    "Branch: feat/modernizacao-visual",
    "Pacote: ENTREGA_PROGRAMADOR_CARAJAS360 (FASE 14)",
    "Firebase: carajas360-a17c5",
    "",
    "========================================",
    "NAO E PROJETO PARA DESENVOLVER DO ZERO",
    "========================================",
    "",
    "App ja possui Flutter Web/Android/iOS,",
    "UI, clientes, profissionais, pedidos,",
    "chat, admin e documentacao tecnica.",
    "",
    "Reconstruir o app NAO sera aceito sem",
    "justificativa tecnica e aprovacao previa.",
])

add([
    "PERFIL BUSCADO",
    "",
    "Experiencia em:",
    "- Flutter multiplataforma",
    "- Firebase (Auth, Firestore, Hosting)",
    "- Cloud Functions",
    "- IA (callable / APIs)",
    "- Mercado Pago",
    "- Android (APK/AAB) e iOS (TestFlight)",
    "",
    "SERVICOS NECESSARIOS",
    "",
    "1. Corrigir pendencias do pacote de entrega",
    "2. Ativar Cloud Functions + IA existente",
    "3. Testar fluxos cliente e profissional",
    "4. Homologar pagamentos MP em sandbox",
    "5. Corrigir compilacao Android",
    "6. Gerar APK de testes e AAB assinado",
    "7. iOS + TestFlight",
    "8. Validar telas, botoes e navegacao",
    "9. Testes de seguranca e estabilidade",
    "10. Preparar publicacao (so com autorizacao)",
])

add([
    "ENTREGAS OBRIGATORIAS",
    "",
    "- Codigo no repositorio EXISTENTE",
    "- Relatorio de testes (PASS/FAIL/N-E)",
    "- IA comprovadamente funcional",
    "- Fluxos de contratacao funcionando",
    "- Pagamentos homologados (sandbox)",
    "- APK + AAB Android (+ SHA256 do AAB)",
    "- Build iOS no TestFlight",
    "- Web homolog validada",
    "- Documentacao final instalacao/manutencao",
    "",
    "Aceite: 12_CRITERIOS_ACEITE.pdf",
    "",
    "CONDICOES",
    "",
    "- Pagamento por etapas, apos validacao",
    "- Sem GO: sem live, sem MP producao,",
    "  sem lojas, sem alterar billing",
    "",
    "PROPOSTA DEVE INFORMAR",
    "",
    "Experiencia similar | prazo | orcamento",
    "Disponibilidade | acesso a macOS/Xcode",
    "Confirmacao de leitura do pacote FASE 14",
])

add([
    "TRANSPARENCIA — ESTADO ATUAL",
    "",
    "NAO APTO para publicacao (Fases 12-13).",
    "Homolog Web parcial OK (demo).",
    "Pendencias: Blaze/Functions API, deploy IA,",
    "pagamentos E2E, AAB/IPA, GO publicacao.",
    "",
    "Homolog:",
    "https://carajas360-a17c5--homolog-88u39zqx.web.app",
    "",
    "ZIP transferencia:",
    "ENTREGA_PROGRAMADOR_CARAJAS360_686d16c.zip",
    "",
    "========================================",
    "Trabalhar no repositorio existente.",
    "Nao reconstruir o Carajas 360.",
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


def write_pdf(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
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
    path.write_bytes(out)
    return path.stat().st_size


s1 = write_pdf(OUT)
s2 = write_pdf(OUT2)
print(f"PDF_OK {OUT} bytes={s1} pages={len(PAGES)}")
print(f"PDF_OK {OUT2} bytes={s2}")
