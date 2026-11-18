# -*- coding: utf-8 -*-
"""Gera docs/CONTRATACAO_PROGRAMADOR_CARAJAS360.pdf sem deps externas."""
from pathlib import Path

OUT = Path("docs/CONTRATACAO_PROGRAMADOR_CARAJAS360.pdf")
PAGES = []


def add(lines):
    PAGES.append(lines)


add([
    "CARAJAS 360",
    "CONTRATACAO DE PROGRAMADOR",
    "Flutter / Firebase — Finalizacao (nao rebuild)",
    "",
    "Data do briefing: 17/11/2026",
    "Status do produto: NAO APTO para publicacao",
    "Homolog Web: parcial | Live: 404 | IA runtime: pendente",
    "",
    "IMPORTANTE",
    "- Nao e desenvolvimento do zero.",
    "- App Flutter Web/Android/iOS ja existe.",
    "- Documentacao e auditorias disponiveis.",
    "- Rebuild integral so com justificativa e aprovacao.",
])

add([
    "PERFIL BUSCADO",
    "",
    "Experiencia em:",
    "- Flutter (Web, Android, iOS)",
    "- Firebase (Auth, Firestore, Hosting)",
    "- Cloud Functions",
    "- IA (callable / integracao segura)",
    "- Mercado Pago (sandbox e producao)",
    "- Publicacao Play Store e TestFlight",
    "",
    "Trabalho no REPOSITORIO EXISTENTE.",
])

add([
    "SERVICOS NECESSARIOS",
    "",
    "1. Corrigir pendencias documentadas (P0)",
    "2. Ativar Cloud Functions e IA existente",
    "3. Testar fluxos E2E cliente e profissional",
    "4. Homologar Mercado Pago em sandbox",
    "5. Corrigir build Android; gerar APK e AAB",
    "6. Compilar iOS e publicar TestFlight",
    "7. Validar telas, navegacao e funcoes",
    "8. Testes de seguranca e estabilidade",
    "9. Preparar publicacao Web/Play/App Store",
    "   SOMENTE com autorizacao explicita",
])

add([
    "ENTREGAS OBRIGATORIAS",
    "",
    "- Codigo no repo existente (sem app novo)",
    "- Relatorio de testes com evidencias",
    "- IA comprovadamente funcional (turno real)",
    "- Fluxos de contratacao funcionando",
    "- Pagamentos homologados (sandbox)",
    "- APK + AAB Android assinados",
    "- Build iOS no TestFlight",
    "- Web validada (live so com GO)",
    "- Docs finais de instalacao/manutencao",
    "",
    "Pagamento por ETAPAS, apos validacao.",
])

add([
    "BLOQUEADORES P0 (PRIORIDADE)",
    "",
    "1. Cloud Functions API / Blaze + deploy IA",
    "2. Hosting live (so com GO)",
    "3. Turno LLM real grounded",
    "4. Mercado Pago sandbox E2E",
    "5. AAB assinado do commit candidato",
    "6. iOS + TestFlight (macOS + Apple Dev)",
    "",
    "Docs de transferencia:",
    "- ENTREGA_PROGRAMADOR_CARAJAS360.md",
    "- AUDITORIA_FINAL_CARAJAS360.md (+ PDF)",
    "- AUDITORIA_TELAS_CARAJAS360.md",
    "- MATRIZ_HOMOLOGACAO_FASE10.md",
])

add([
    "O QUE INFORMAR NA PROPOSTA",
    "",
    "- Experiencia em projetos semelhantes",
    "- Prazo estimado POR ETAPA",
    "- Orcamento (preferencia por etapa)",
    "- Disponibilidade no repo existente",
    "- Acesso a macOS para iOS (ou parceiro)",
    "- Confirmacao: sem rebuild sem aprovacao",
    "",
    "FORMA DE TRABALHO",
    "- Preservar codigo e identidade visual",
    "- Sem inventar profissionais/precos",
    "- Sem publicar lojas/live sem GO",
    "- Evidencias obrigatorias em cada etapa",
    "",
    "Contato: enviar proposta ao contratante.",
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
