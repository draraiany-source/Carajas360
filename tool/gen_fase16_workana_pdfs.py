# -*- coding: utf-8 -*-
"""FASE 16 — gera PDFs Workana + atualiza README/manifesto + ZIP."""
from pathlib import Path
import zipfile

ROOT = Path("ENTREGA_PROGRAMADOR_CARAJAS360")
DOCS = Path("docs")
OUT = ROOT / "FASE16"
HEAD = "a95b2e5"
VER = "1.0.0+403"
BRANCH = "feat/modernizacao-visual"
FIREBASE = "carajas360-a17c5"


def escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")


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
    print(f"OK {path} bytes={path.stat().st_size} pages={len(pages)}")


PDFS = {
    "RELATORIO_FINAL_CARAJAS360.pdf": [
        [
            "CARAJAS 360 — RELATORIO FINAL (FASE 16)",
            f"Data: 2026-11-17 | Branch: {BRANCH}",
            f"HEAD: {HEAD} | Versao: {VER}",
            f"Firebase: {FIREBASE}",
            "Baseline: docs/FASE15_AUDITORIA_DEFINITIVA.md (existe)",
            "",
            "========================================",
            "VEREDITO",
            "Contratar programador .......... SIM",
            "Publicar Web live .............. NAO",
            "Publicar Android ............... NAO",
            "Publicar iOS ................... NAO",
            "IA funcional (LLM real) ........ NAO",
            "Pagamentos homologados ......... NAO",
            "Orcamentos multimídia .......... PARCIAL",
            "  (fotos IT emulator; video/audio AU;",
            "   Storage prod bloqueado)",
            "========================================",
        ],
        [
            "CONFERENCIA",
            "- Codigo Git atualizado na branch",
            "- Telas/rotas inventariadas (~40+)",
            "- Fluxos cliente/pro/admin: codigo IS; E2E auth N/E",
            "- Fotos orcamento: unit + emulator PASS",
            "- Homolog Web HTTP 200 | Live 404",
            "- Billing Blaze: false | CF API: 403",
            "",
            "TESTES FASE 16",
            "- functions npm test: 163/163 PASS",
            "- flutter photos/config: 14/14 PASS",
            "- E2E autenticado completo: NAO EXECUTADO",
            "",
            "NAO APTO PARA PUBLICACAO.",
            "Pronto para transferencia Workana.",
            "",
            "MD: docs/FASE16_VALIDACAO_FINAL.md",
        ],
    ],
    "ESCOPO_WORKANA_CARAJAS360.pdf": [
        [
            "ESCOPO TECNICO WORKANA — CARAJAS 360",
            f"HEAD {HEAD} | {VER} | {FIREBASE}",
            "",
            "OBJETIVO",
            "Finalizar e homologar o app EXISTENTE.",
            "Proibido recriar o sistema.",
            "",
            "DENTRO DO ESCOPO",
            "1. Correcoes P0/P1",
            "2. Firebase Blaze (owner), Storage, Functions",
            "3. Carajas IA turno real",
            "4. Orcamentos: validar fotos prod; video/audio se contrato",
            "5. E2E cliente / profissional / admin",
            "6. Mercado Pago SANDBOX",
            "7. Builds Android e iOS",
            "8. Documentacao de entrega",
        ],
        [
            "FORA DO ESCOPO (sem aditivo)",
            "- Redesign completo",
            "- Novos modulos de negocio",
            "- Publicacao lojas/live sem GO",
            "- Cobranca producao sem GO",
            "",
            "MARCOS",
            "1 Criticos + Firebase + IA",
            "2 Fluxos + multimídia + MP sandbox",
            "3 Android/iOS devices",
            "4 Homologacao + prep publicacao",
            "",
            "RESP. PROGRAMADOR: Git, testes, builds, sem secrets",
            "RESP. CONTRATANTE: acessos, GO Blaze/live/MP, Apple/Play",
            "",
            "MD: docs/FASE16_ESCOPO_WORKANA.md",
        ],
    ],
    "PENDENCIAS_PROGRAMADOR.pdf": [
        [
            "PENDENCIAS PROGRAMADOR — P0/P1/P2",
            f"HEAD {HEAD}",
            "",
            "P0 (publicacao/seguranca)",
            "P0-1 Live Web 404",
            "P0-2 Blaze / Functions API 403",
            "P0-3 Storage bucket producao",
            "P0-4 IA sem LLM deployado",
            "P0-5 Pagamentos sandbox N/E",
            "P0-6 AAB/APK deste HEAD",
            "P0-7 IPA / TestFlight",
            "",
            "P1",
            "P1-1 Video no orcamento",
            "P1-2 Audio no orcamento",
            "P1-3 E2E cliente",
            "P1-4 E2E profissional",
            "P1-5 E2E admin",
        ],
        [
            "P2",
            "P2-1 Paridade visual premium",
            "P2-2 Estabilizar widget tests",
            "P2-3 OAuth domains",
            "P2-4 Dominio custom",
            "",
            "JA COMPROVADO",
            "- Functions 163/163",
            "- Fotos emulator E2E",
            "- Homolog 200",
            "- Firestore photoUrls rules deploy",
            "",
            "Cada P0 tem problema/modulo/causa/solucao/",
            "dependencias/aceite no MD completo.",
            "MD: docs/FASE16_PENDENCIAS_PROGRAMADOR.md",
        ],
    ],
    "CRITERIOS_ACEITE.pdf": [
        [
            "CRITERIOS DE ACEITE — WORKANA",
            f"Baseline {HEAD}",
            "",
            "Aceite por logs/builds/HTTP — nao so prints.",
            "",
            "MARCO 1",
            "Functions listaveis; aiAssistant deploy;",
            "turno IA grounded; Storage+upload fotos;",
            "npm test >= baseline.",
            "",
            "MARCO 2",
            "E2E cliente/pro/admin; video/audio se contrato;",
            "PIX+cartao+webhook sandbox.",
            "",
            "MARCO 3",
            "APK; AAB+SHA256; TestFlight; smoke devices.",
            "",
            "MARCO 4",
            "Checklists; termo codigo; live/MP so com GO.",
        ],
        [
            "REJEICAO AUTOMATICA DO MARCO",
            "- Rebuild sem autorizacao",
            "- Secrets no Git",
            "- PRODUCTION_PAYMENTS sem GO",
            "- So screenshots sem logs",
            "- Regressao testes sem correcao",
            "",
            "MD: docs/FASE16_CRITERIOS_ACEITE.md",
        ],
    ],
    "CHECKLIST_ANDROID_IOS_WEB.pdf": [
        [
            "CHECKLIST ANDROID / iOS / WEB",
            f"HEAD {HEAD} | {VER}",
            "",
            "WEB",
            "[x] Projeto Flutter Web",
            "[x] Homolog HTTP 200",
            "[ ] Live (404)",
            "[ ] OAuth domains finais",
            "",
            "ANDROID",
            "[x] Projeto android/",
            "[x] key.properties.example",
            "[ ] key.properties local",
            "[ ] APK debug HEAD",
            "[ ] AAB + SHA256",
            "[ ] Teste device",
        ],
        [
            "iOS",
            "[x] Projeto ios/ existe",
            "[ ] Certs / provisioning",
            "[ ] IPA",
            "[ ] TestFlight",
            "[ ] Teste device",
            "",
            "PUBLICAVEL AGORA?",
            "Web live: NAO | Android: NAO | iOS: NAO",
            "Homolog: SIM parcial (interno)",
            "",
            "MD: docs/FASE16_CHECKLIST_ANDROID_IOS_WEB.md",
        ],
    ],
    "PLANO_TESTES_FINAL.pdf": [
        [
            "PLANO DE TESTES FINAL — FASE 16",
            f"HEAD {HEAD}",
            "",
            "A AUTOMATIZADOS (EXECUTADOS)",
            "A1 functions 163/163 PASS",
            "A2 flutter photos/config 14/14 PASS",
            "A3 fotos emulator E2E PASS (sessao anterior)",
            "",
            "B INFRA",
            "B1 Homolog 200 | B2 Live 404",
            "B3 Blaze false | B4 Storage 0 buckets",
            "",
            "C/D/E FLUXOS AUTH",
            "Cliente / Pro / Admin: NAO EXECUTADOS",
            "",
            "F IA turno real: NAO EXECUTADO",
            "G Video/audio orcamento: AUSENTE",
            "H ACL fotos emulator: PASS",
        ],
        [
            "REGISTRO",
            "Pass automacao: 163 + 14 (+ E2E fotos)",
            "E2E auth: 0",
            "Builds mobile: 0",
            "",
            "Conclusao: backend/fotos OK;",
            "publicacao e fluxos auth NAO comprovados.",
            "",
            "MD: docs/FASE16_PLANO_TESTES_FINAL.md",
        ],
    ],
}


README = f"""# README — Entrega Workana / Programador (FASE 16)

**Produto:** Carajás 360  
**Branch:** `{BRANCH}`  
**Commit (HEAD pacote):** `{HEAD}`  
**Versão:** `{VER}`  
**Firebase:** `{FIREBASE}`  
**Homolog:** https://carajas360-a17c5--homolog-88u39zqx.web.app  

## Veredito rápido

| Item | Resposta |
|------|----------|
| Contratar programador | **SIM** |
| Publicar Web live | **NÃO** |
| Publicar Android | **NÃO** |
| Publicar iOS | **NÃO** |
| IA funcional (LLM) | **NÃO** |
| Pagamentos homologados | **NÃO** |
| Orçamentos multimídia | **PARCIAL** (fotos OK em emulator; vídeo/áudio ausentes; Storage prod bloqueado) |

## Conteúdo deste pacote

### FASE 16 (Workana)
- `FASE16/RELATORIO_FINAL_CARAJAS360.pdf`
- `FASE16/ESCOPO_WORKANA_CARAJAS360.pdf`
- `FASE16/PENDENCIAS_PROGRAMADOR.pdf`
- `FASE16/CRITERIOS_ACEITE.pdf`
- `FASE16/CHECKLIST_ANDROID_IOS_WEB.pdf`
- `FASE16/PLANO_TESTES_FINAL.pdf`
- `ZIP_DOCUMENTACAO_FINAL.zip`

### Fontes Markdown (repo `docs/`)
- `FASE16_VALIDACAO_FINAL.md`
- `FASE16_ESCOPO_WORKANA.md`
- `FASE16_PENDENCIAS_PROGRAMADOR.md`
- `FASE16_CRITERIOS_ACEITE.md`
- `FASE16_CHECKLIST_ANDROID_IOS_WEB.md`
- `FASE16_PLANO_TESTES_FINAL.md`
- `FASE15_AUDITORIA_DEFINITIVA.md` (**obrigatório** — baseline)

### Pacote anterior (F14/F15)
PDFs 01–15, edital, guias Firebase/pagamentos/Android/iOS/Web.

## Regras
1. **Não** recriar o aplicativo.  
2. **Não** versionar tokens, keystores ou dados pessoais.  
3. **Não** publicar live/lojas sem GO da contratante.  
4. Aceite de marco = evidência objetiva (ver critérios).

## Comandos iniciais do programador
```bash
git checkout {BRANCH}
git log -1 --oneline   # esperado: {HEAD} ou sucessor documentado
flutter pub get
cd functions && npm test && cd ..
flutter test test/order_photos_test.dart test/order_photos_flow_test.dart
```

## Segurança
Ver `SEGURANCA_CREDENCIAIS.md`. Secrets apenas em Secret Manager / máquina local.
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, pages in PDFS.items():
        write_pdf(OUT / name, pages)
        # cópia também em docs/
        write_pdf(DOCS / name, pages)

    (ROOT / "README_ENTREGA.md").write_text(README, encoding="utf-8")
    (OUT / "README_ENTREGA.md").write_text(README, encoding="utf-8")
    (ROOT / "00_MANIFESTO.txt").write_text(
        f"PACOTE ENTREGA FASE16\nHEAD={HEAD}\nVER={VER}\nBRANCH={BRANCH}\n"
        f"CONTRATAR=SIM PUBLICAR_WEB=NAO ANDROID=NAO IOS=NAO\n"
        f"IA=NAO PAGAMENTOS=NAO MULTIMIDIA=PARCIAL\n"
        f"BLAZE=No LIVE=404 HOMOLOG=200\n"
        f"TESTS_FUNCTIONS=163 TESTS_FLUTTER_PHOTOS=14\n",
        encoding="utf-8",
    )

    zip_path = ROOT / "ZIP_DOCUMENTACAO_FINAL.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        # FASE16 PDFs + README
        for p in sorted(OUT.glob("*")):
            if p.is_file():
                zf.write(p, arcname=f"FASE16/{p.name}")
        # MDs FASE 15/16
        for name in [
            "FASE15_AUDITORIA_DEFINITIVA.md",
            "FASE16_VALIDACAO_FINAL.md",
            "FASE16_ESCOPO_WORKANA.md",
            "FASE16_PENDENCIAS_PROGRAMADOR.md",
            "FASE16_CRITERIOS_ACEITE.md",
            "FASE16_CHECKLIST_ANDROID_IOS_WEB.md",
            "FASE16_PLANO_TESTES_FINAL.md",
            "RELATORIO_ORCAMENTO_FOTOS_IA.md",
            "FASE13_GO_EXTERNOS.md",
        ]:
            src = DOCS / name
            if src.exists():
                zf.write(src, arcname=f"docs/{name}")
        # manifesto + seguranca + readme raiz pacote
        for name in ["00_MANIFESTO.txt", "README_ENTREGA.md", "SEGURANCA_CREDENCIAIS.md"]:
            p = ROOT / name
            if p.exists():
                zf.write(p, arcname=name)
        # PDFs F14-ish úteis se existirem
        for p in sorted(ROOT.glob("*.pdf")):
            zf.write(p, arcname=f"pacote_anterior/{p.name}")
    print(f"OK ZIP {zip_path} bytes={zip_path.stat().st_size}")


if __name__ == "__main__":
    main()
