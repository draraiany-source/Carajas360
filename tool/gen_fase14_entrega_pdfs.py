# -*- coding: utf-8 -*-
"""Gera os 12 PDFs do pacote ENTREGA_PROGRAMADOR_CARAJAS360 (FASE 14)."""
from pathlib import Path

ROOT = Path("ENTREGA_PROGRAMADOR_CARAJAS360")
COMMIT = "686d16c"
VERSION = "1.0.0+403"
PROJECT = "carajas360-a17c5"
BRANCH = "feat/modernizacao-visual"
HOMOLOG = "https://carajas360-a17c5--homolog-88u39zqx.web.app"


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
    kids = []
    body_objs = []
    obj_num = 4
    for lines in pages:
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
        f"2 0 obj<< /Type /Pages /Kids [{' '.join(kids)}] /Count {len(pages)} >>endobj\n"
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
    return path.stat().st_size, len(pages)


DOCS = {
    "01_RELATORIO_EXECUTIVO.pdf": [
        [
            "CARAJAS 360 — PACOTE DE ENTREGA",
            "01 RELATORIO EXECUTIVO (FASE 14)",
            "",
            f"Versao: {VERSION}",
            f"Commit: {COMMIT}",
            f"Branch: {BRANCH}",
            f"Firebase: {PROJECT}",
            "Data: 17/11/2026",
            "",
            "========================================",
            "ESTADO: NAO APTO PARA PUBLICACAO",
            "========================================",
            "",
            "O app Flutter existe e e compartilhado",
            "Web/Android/iOS. NAO recriar.",
            "",
            "Pronto para DEMO parcial (homolog Web):",
            "- Home / Explorar com profissionais reais",
            "- UI Central Carajas IA (sem LLM runtime)",
            "- Fluxos de pedido/chat em codigo",
            "",
            "Bloqueado para lojas / live:",
            "- Blaze off + Functions API 403",
            "- aiAssistant nao deployada",
            "- Pagamentos E2E nao comprovados",
            "- Live hosting 404",
            "- AAB/IPA nao gerados neste commit",
        ],
        [
            "REFERENCIAS OBRIGATORIAS",
            "",
            "docs/AUDITORIA_FINAL_CARAJAS360.md (F12)",
            "docs/FASE13_CARAJAS360.md (F13)",
            "docs/AUDITORIA_TELAS_CARAJAS360.md",
            "docs/ENTREGA_PROGRAMADOR_CARAJAS360.md",
            "",
            f"Homolog: {HOMOLOG}",
            "",
            "DIVISAO DE RESPONSABILIDADES",
            "",
            "Programador: codigo, testes, builds,",
            "homologacao tecnica, deploy com GO.",
            "",
            "Proprietaria: Blaze, secrets, GO live,",
            "Apple/Google contas, dominio, MP token,",
            "autorizacao de publicacao.",
            "",
            "Externas: Firebase Blaze, Apple Developer,",
            "Play Console, Mercado Pago, Anthropic.",
        ],
    ],
    "02_INVENTARIO_TELAS.pdf": [
        [
            "02 INVENTARIO DE TELAS E ROTAS",
            f"Commit {COMMIT} | {VERSION}",
            "",
            "CLASSIFICACAO:",
            "IT = implementada e testada",
            "IS = implementada sem teste completo",
            "PI = parcialmente implementada",
            "PE = pendente",
            "BX = bloqueada por config externa",
            "",
            "MAINNAV (abas)",
            "Inicio (Home) .............. IS/PI",
            "Explorar (/search) ......... IT (homolog carga)",
            "Pedidos (/my-orders) ....... IS (pay BX)",
            "Mensagens (inbox) .......... IS",
            "Perfil ..................... IS",
            "FAB Carajas IA ............. IS UI / BX runtime",
        ],
        [
            "ROTAS PRINCIPAIS",
            "",
            "/onboarding, /login, /register .... IS",
            "/provider-profile ................. IS",
            "/request-service .................. IS",
            "/provider-home / onboarding ....... IS",
            "/resolve, /resolve-detail ......... IS",
            "/my-resolve, oportunidades ........ IS/PI",
            "/wallet, PIX, cartao .............. PI/BX",
            "/ai ................................ IS UI / BX CF",
            "/admin (+ Disputas) ............... IS",
            "/appointments, /health ............ IS/PI",
            "/favorites, /support, /reviews .... IS",
            "/gps, /coupons, marketplace ....... PI",
            "/service-request-flow ............. IS (F2)",
            "/opportunity-detail ............... IS (F2)",
            "",
            "Fonte detalhada:",
            "docs/AUDITORIA_TELAS_CARAJAS360.md",
            "(atualizar notas F2/F3: demo IDs removidos)",
        ],
        [
            "MODULOS lib/features/",
            "",
            "admin, ai_assistant, auth, chat,",
            "company, gps, health, home,",
            "marketplace, monetization, orders,",
            "profile, provider, rental, resolve,",
            "search, services, support, wallet",
            "",
            "BACKEND",
            "functions/ (Node 20, us-central1)",
            "firestore.rules, storage.rules",
            "indexes: firestore.indexes.json",
            "",
            "DEPENDENCIAS CHAVE",
            "Flutter 3.x, Firebase Auth/FS/Storage/",
            "Messaging/Analytics/Crashlytics/",
            "Cloud Functions, Maps, Geolocator",
        ],
    ],
    "03_MAPA_FLUXOS.pdf": [
        [
            "03 MAPA DE FLUXOS",
            f"{COMMIT} | ASCII (Mermaid em MD fonte)",
            "",
            "CLIENTE",
            "Home -> Explorar -> Perfil pro",
            "  -> Pedir orcamento (/request-service)",
            "  -> createOrder -> Chat e/ou Meus pedidos",
            "  -> (opcional) Resolve: publicar",
            "  -> aceitar proposta (acceptResolveProposal)",
            "  -> Meus pedidos -> Pagar (CF)",
            "  -> Execucao/GPS -> Confirmar",
            "  -> Avaliar (/reviews)",
            "",
            "Botoes tipicos Explorar:",
            "Ver perfil -> /provider-profile",
            "Pedir orcamento -> /request-service",
            "Favoritar (guest) -> /login",
            "Encontrar com IA -> /ai",
        ],
        [
            "PROFISSIONAL",
            "Cadastro/register asProvider",
            "  -> /provider-onboarding (docs)",
            "  -> Admin aprova",
            "  -> /provider-home online",
            "  -> pedido pendente -> Aceitar+preco",
            "  -> em andamento -> concluir",
            "  -> Resolve oportunidades -> proposta",
            "  -> recebimento (escrow/payout BX)",
            "",
            "ADMIN",
            "/admin AdminGate",
            "Abas: Usuarios, Validacao, Categorias,",
            "Financeiro, Marketing, Atendimento,",
            "Denuncias, Disputas, Pedidos,",
            "Auditoria, Config",
            "",
            "CONTRATACAO / ORCAMENTO",
            "Direto: QuoteRequestFlowScreen",
            "Aberto: Resolve + propostas",
            "Matching marketplace: ServiceRequestFlow",
        ],
        [
            "PAGAMENTOS (codigo)",
            "Meus pedidos canPay -> sheet",
            "  Carteira: payOrderWithWallet CF",
            "  PIX: generatePix / checkPayment",
            "  Cartao: processCardPayment",
            "Nunca marcar pago so no frontend",
            "",
            "IA",
            "FAB/CTA -> /ai -> AiSvc.askTurn",
            "  -> callable aiAssistant",
            "  Auth obrigatoria no envio",
            "  Erro honesto se Function ausente",
            "  Atalhos: busca, orcamento, status",
        ],
    ],
    "04_PENDENCIAS_TECNICAS.pdf": [
        [
            "04 PENDENCIAS TECNICAS",
            f"Base FASE 12+13 | {COMMIT}",
            "",
            "P0 BLOQUEADORES PUBLICACAO",
            "1. Blaze + Cloud Functions API",
            "2. Deploy aiAssistant (+ assist)",
            "3. Hosting live (404 hoje) — so com GO",
            "4. MP sandbox E2E comprovado",
            "5. AAB assinado do HEAD",
            "6. IPA/TestFlight (macOS)",
            "7. Disco C: estabilizar builds",
            "",
            "P1",
            "- E2E cliente autenticado",
            "- E2E profissional + aprovacao",
            "- OAuth dominios homolog",
            "- Refunds admin / fila saques",
            "- flutter test suite completa CI",
        ],
        [
            "PROGRAMADOR DEVE",
            "- Clonar no commit 686d16c",
            "- Rodar flutter test / analyze",
            "- Liberar disco; build APK debug",
            "- Apos Blaze: deploy Functions",
            "- Evidenciar IA e pagamentos teste",
            "- Gerar AAB+SHA256 com keystore",
            "- Homologar Web channel + live c/ GO",
            "",
            "NAO FAZER SEM GO",
            "- Alterar billing Firebase",
            "- PAYMENTS_ENABLED producao",
            "- firebase deploy hosting live",
            "- Publicar Play/App Store",
        ],
    ],
    "05_GUIA_FIREBASE_IA.pdf": [
        [
            "05 GUIA FIREBASE + CARAJAS IA",
            f"Projeto {PROJECT}",
            "",
            "ESTADO ATUAL",
            "Billing enabled: No (F13)",
            "functions_list: HTTP 403",
            "aiAssistant: codigo em functions/",
            "  exports.aiAssistant — NAO deployada",
            "",
            "APIS A HABILITAR (owner/console)",
            "- cloudfunctions.googleapis.com",
            "- cloudbuild, artifactregistry",
            "- (opcional) secretmanager",
            "",
            "PLANO",
            "Upgrade Blaze (pay-as-you-go)",
            "NAO alterar sem autorizacao dona",
        ],
        [
            "DEPLOY (apos Blaze + API)",
            "",
            "cd functions && npm test",
            "firebase deploy --only \\",
            "  functions:aiAssistant \\",
            f"  --project {PROJECT}",
            "",
            "Grounded-only (sem LLM):",
            "  sem ANTHROPIC_API_KEY / AI_ENABLED=false",
            "",
            "LLM opcional:",
            "  firebase functions:secrets:set \\",
            "    ANTHROPIC_API_KEY",
            "  BIND_ANTHROPIC_SECRET=true",
            "",
            "SEGURANCA",
            "- Chave NUNCA no app Flutter",
            "- Callable exige Auth",
            "- Admin/provider modes checados",
            "- Nao inventa profissionais/precos",
            "",
            "CUSTOS",
            "Functions invocacoes + Anthropic tokens",
            "Usar quota/rate limit ja no codigo",
            "",
            "TESTES REAIS PENDENTES",
            "Login -> /ai -> pergunta -> reply",
            "+ cards de providers Firestore",
            "Registrar screenshot/log",
        ],
    ],
    "06_GUIA_PAGAMENTOS.pdf": [
        [
            "06 GUIA PAGAMENTOS (MERCADO PAGO)",
            "NAO habilitar cobranca real sem GO",
            "",
            "CODIGO EXISTENTE",
            "functions: generatePix, checkPayment,",
            "processCardPayment, payOrderWithWallet,",
            "processRefund, mercadoPagoWebhook,",
            "purchaseCreditPackage, processPayout",
            "",
            "Flags:",
            "PAYMENTS_ENABLED",
            "PRODUCTION_PAYMENTS_ENABLED",
            "financialKillSwitch (config/platform)",
            "",
            "Comissao: config/platform.commissionRate",
            "(app OrderPolicy default 8%)",
            "",
            "Webhook: NAO confia em userId/credits",
            "do body — exige payments/{id} +",
            "status approved na API MP",
        ],
        [
            "ROTEIRO HOMOLOG SANDBOX",
            "",
            "1. Token TEST no Secret Manager",
            "2. MERCADOPAGO_WEBHOOK_SECRET",
            "3. PAYMENTS_ENABLED=true (sandbox)",
            "4. PRODUCTION_PAYMENTS_ENABLED=false",
            "5. Pedido com preco + canPay",
            "6. PIX: QR real sandbox; checkPayment",
            "7. Cartao: token teste MP",
            "8. Webhook: evento aprovado -> ledger",
            "9. Cancelamento / refund admin",
            "10. Conciliacao: payments + orders",
            "    paymentStatus + escrow held",
            "",
            "CRITERIOS PASS",
            "- Pedido unpaid -> paid so via CF/MP",
            "- UI nao marca pago sozinha",
            "- Kill switch bloqueia operacoes",
            "- Sem cobranca conta real",
        ],
    ],
    "07_GUIA_ANDROID.pdf": [
        [
            "07 GUIA ANDROID",
            f"applicationId br.com.carajas360",
            f"versionName/Code: ver pubspec {VERSION}",
            "",
            "AMBIENTE",
            "Flutter SDK, Android SDK, JDK 17",
            "Espaco livre disco: >10 GB recomendado",
            "",
            "GRADLE TRAVADO / DAEMON",
            "1. Fechar Java/Gradle orphans",
            "2. flutter clean",
            "3. Remover android/.gradle se lock",
            "4. Reabrir terminal; flutter pub get",
            "",
            "APK TESTES INTERNOS",
            "flutter build apk --debug",
            "Saida tipica:",
            "build/app/outputs/flutter-apk/",
            "  app-debug.apk",
            "",
            "FASE 13: build falhou (disco/daemon).",
            "Repetir apos liberar C:",
        ],
        [
            "ASSINATURA RELEASE",
            "1. keytool -genkey ... upload-keystore.jks",
            "2. Copiar android/key.properties.example",
            "   -> android/key.properties (NAO git)",
            "3. Preencher storeFile/passwords/alias",
            "",
            "AAB",
            "flutter build appbundle --release",
            "Arquivo:",
            "build/app/outputs/bundle/release/",
            "  app-release.aab",
            "Registrar SHA256:",
            "Get-FileHash app-release.aab -Algorithm SHA256",
            "",
            "PLAY STORE",
            "Play Console -> app br.com.carajas360",
            "Faixa interna/fechada antes de prod",
            "Politica: privacidade/termos ja em hosting/",
            "",
            "google-services.json: projeto real",
            "(cliente Firebase; nao e secret privado",
            "de servidor — ainda assim nao vazar)",
        ],
    ],
    "08_GUIA_IOS.pdf": [
        [
            "08 GUIA IOS / TESTFLIGHT",
            "Bundle ID: br.com.carajas360",
            "REQUER macOS + Xcode + Apple Developer",
            "Windows: IPA NAO geravel aqui",
            "",
            "SETUP",
            "cd ios && pod install && cd ..",
            "Abrir ios/Runner.xcworkspace",
            "Team + Signing Automatic",
            "GoogleService-Info.plist do Console",
            "",
            "PERMISSOES (Info.plist)",
            "Camera, Localizacao, etc. ja descritas",
            "",
            "BUILD",
            "flutter build ipa --release",
            "ou Product > Archive no Xcode",
            "",
            "TESTFLIGHT",
            "Distribute App -> TestFlight",
            "Preencher compliance export",
            "Convidar testadores internos",
        ],
        [
            "APP STORE",
            "Screenshots, privacy nutrition labels,",
            "conta desarrollador paga ativa",
            "Revisao Apple: conta demo se login",
            "",
            "Doc detalhado:",
            "docs/IOS_BUILD_TESTFLIGHT.md",
            "docs/CARAJAS360_IOS_CHECKLIST.md",
            "",
            "NAO afirmar IPA gerado sem arquivo.",
        ],
    ],
    "09_GUIA_WEB.pdf": [
        [
            "09 GUIA WEB / HOSTING",
            f"Projeto {PROJECT}",
            "",
            "HOMOLOG (ATIVO)",
            f"{HOMOLOG}",
            "Canal Firebase: homolog (expira)",
            "Script:",
            "scripts/homolog_web_preview.ps1",
            "  flutter build web --release",
            "  --no-wasm-dry-run",
            "  hosting:channel:deploy homolog",
            "",
            "LIVE (404 HOJE)",
            "https://carajas360-a17c5.web.app",
            "Causa: nenhuma release live",
            "Publicar SO com GO:",
            "scripts/live_web_deploy.ps1 \\",
            "  -IAuthorizeLiveDeploy",
            "",
            "firebase.json no repo aponta hosting/",
            "(paginas legais). Scripts de deploy",
            "montam build/web temporario.",
        ],
        [
            "AUTH / DOMINIOS",
            "Autorizar dominio do canal homolog",
            "e do dominio custom (quando houver)",
            "em Authentication > Settings",
            "",
            "VARIAVEIS",
            "Cliente: firebase_options.dart (keys",
            "web publicas do app)",
            "Servidor: env/Secret Manager nas",
            "Functions — nunca no frontend",
            "",
            "CACHE",
            "Scripts aplicam ?v=stamp em JS",
            "Headers no-cache index.html",
        ],
    ],
    "10_CHECKLIST_PUBLICACAO.pdf": [
        [
            "10 CHECKLIST PUBLICACAO",
            "Marcar so com evidencia.",
            "",
            "[ ] Blaze ativo + Functions API OK",
            "[ ] aiAssistant deployada",
            "[ ] Conversa IA real documentada",
            "[ ] PAYMENTS sandbox E2E pass",
            "[ ] PRODUCTION_PAYMENTS off ate GO",
            "[ ] Homolog Web smoke OK",
            "[ ] Live hosting 200 (apos GO)",
            "[ ] Dominios Auth OAuth OK",
            "[ ] AAB + SHA256 arquivado",
            "[ ] Smoke Android dispositivo",
            "[ ] IPA/TestFlight ou adiamento",
            "[ ] flutter test estavel / CI",
            "[ ] Regras Firestore revisadas",
            "[ ] Sem secrets no git",
            "[ ] GO explicito proprietaria",
            "",
            "Sem todos P0: NAO PUBLICAR",
        ],
    ],
    "11_ROTEIRO_TESTES.pdf": [
        [
            "11 ROTEIRO DE TESTES OBRIGATORIOS",
            "",
            "A. AUTOMATIZADOS",
            "cd functions && npm test  (163+)",
            "flutter analyze",
            "flutter test",
            "",
            "B. WEB HOMOLOG",
            "Home carrega",
            "Explorar lista profissionais",
            "Perfil -> orcamento (login)",
            "IA UI + erro/resposta Function",
            "",
            "C. CLIENTE E2E",
            "Cadastro -> busca -> perfil",
            "-> orcamento -> proposta/aceite",
            "-> pagamento teste -> concluir",
            "-> avaliar",
            "",
            "D. PROFISSIONAL E2E",
            "Cadastro -> aprovacao admin",
            "-> receber -> aceitar c/ preco",
            "-> executar -> recebimento teste",
        ],
        [
            "E. PAGAMENTOS SANDBOX",
            "PIX, cartao, webhook, refund",
            "Ver 06_GUIA_PAGAMENTOS.pdf",
            "",
            "F. SEGURANCA",
            "Usuario A nao le pedido de B",
            "AdminGate bloqueia nao-admin",
            "Sem demo IDs em chat/review",
            "",
            "G. MOBILE",
            "APK debug instalavel",
            "AAB upload faixa interna",
            "iOS TestFlight (Mac)",
            "",
            "Registrar PASS/FAIL/N-E com data",
            "e commit. Sem evidencia = N-E.",
        ],
    ],
    "12_CRITERIOS_ACEITE.pdf": [
        [
            "12 CRITERIOS DE ACEITE DO SERVICO",
            "Objetivos para aceitar o programador",
            "contratado. Todos devem ser MEDIVEIS.",
            "",
            "ACEITE TECNICO",
            "1. Repo no commit acordado + PRs",
            "2. functions npm test 100% pass",
            "3. flutter test sem falhas P0",
            "   (ou exclusoes justificadas)",
            "4. Homolog Web URL estavel 200",
            "5. aiAssistant responde com Auth",
            "   e providers reais (evidencia)",
            "6. Fluxo cliente E2E filmado/log",
            "7. Fluxo profissional E2E",
            "8. Sandbox MP: 1 PIX + 1 cartao",
            "   aprovados + webhook aplicado",
            "9. AAB do mesmo commit + SHA256",
            "10. APK debug entregue OU AAB",
            "11. iOS: IPA/TestFlight OU",
            "    documento de adiamento assinado",
        ],
        [
            "ACEITE PUBLICACAO (separado)",
            "So apos GO da proprietaria:",
            "- Live hosting 200",
            "- Play internal/closed",
            "- TestFlight externos",
            "- PRODUCTION_PAYMENTS so se GO",
            "",
            "REJEICAO AUTOMATICA",
            "- App recriado do zero",
            "- Dados ficticios mascarando erro",
            "- Secrets commitados",
            "- Declarar APTO sem evidencias",
            "- Deploy live/pagamentos sem GO",
            "",
            f"Baseline entrega: {COMMIT}",
            f"Versao documentada: {VERSION}",
            "Estado baseline: NAO APTO",
        ],
    ],
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    report = []
    for name, pages in DOCS.items():
        path = ROOT / name
        size, n = write_pdf(path, pages)
        report.append(f"{name}: {size} bytes, {n} pages")
        print(f"OK {path} bytes={size} pages={n}")
    (ROOT / "_pdf_build_log.txt").write_text("\n".join(report), encoding="utf-8")


if __name__ == "__main__":
    main()
