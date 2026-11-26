#!/usr/bin/env python3
"""Gera os PDFs de entrega em português, com classificação honesta."""

from pathlib import Path

from fpdf import FPDF

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONT_B = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
OUT = Path(__file__).resolve().parents[1] / "docs" / "entrega"
OUT.mkdir(parents=True, exist_ok=True)


class Doc(FPDF):
    def __init__(self, title: str):
        super().__init__()
        self.doc_title = title
        self.add_font("DejaVu", "", FONT)
        self.add_font("DejaVu", "B", FONT_B)
        self.set_auto_page_break(auto=True, margin=18)

    def header(self):
        self.set_font("DejaVu", "B", 9)
        self.set_text_color(12, 90, 60)
        self.cell(0, 6, "Carajás 360  ·  entrega técnica", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(198, 160, 60)
        self.set_line_width(0.4)
        self.line(10, 16, 200, 16)
        self.ln(4)

    def footer(self):
        self.set_y(-14)
        self.set_font("DejaVu", "", 8)
        self.set_text_color(90, 90, 90)
        self.cell(0, 8, f"{self.doc_title}  ·  página {self.page_no()}", align="C")

    def h1(self, text: str):
        self.set_font("DejaVu", "B", 16)
        self.set_text_color(16, 70, 48)
        self.multi_cell(0, 8, text)
        self.ln(2)

    def h2(self, text: str):
        self.ln(1)
        self.set_font("DejaVu", "B", 12)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 7, text)
        self.ln(1)

    def p(self, text: str):
        self.set_font("DejaVu", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.4, text)
        self.ln(1.2)

    def bullet(self, text: str):
        self.set_font("DejaVu", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.4, "• " + text)
        self.ln(0.4)


def write(name: str, title: str, blocks: list[tuple[str, str]]):
    pdf = Doc(title)
    pdf.add_page()
    pdf.h1(title)
    pdf.p("Data da auditoria: 26 de novembro de 2026. Branch de trabalho a partir de cursor/tia-carajas-ia-d04e (PR #3). Backup: branch cursor/backup-pre-entrega-45c4 e tag backup-pre-entrega-20261126.")
    pdf.p("Legenda: Implementada e testada · Implementada parcialmente · Não implementada · Bloqueada por integração externa · Aguardando credenciais · Reprovada nos testes. Nada aqui declara 100% sem a prova citada.")
    for kind, text in blocks:
        if kind == "h":
            pdf.h2(text)
        elif kind == "b":
            pdf.bullet(text)
        else:
            pdf.p(text)
    path = OUT / name
    pdf.output(path)
    print(path)


LEGEND = (
    "p",
    "Provas desta rodada: 38 testes Node das Cloud Functions (0 falhas) e 48 testes Flutter (0 falhas, 1 ignorado porque o emulador de Auth não estava ligado). Não houve deploy.",
)

DOCS = [
    (
        "01_AUDITORIA_COMPLETA_CARAJAS360.pdf",
        "01 · Auditoria completa",
        [
            LEGEND,
            ("h", "O que já existia"),
            ("p", "O aplicativo Flutter cobre home, busca, perfil de profissional, pedidos, chat, carteira, saúde, marketplace, aluguel, empresa, admin, suporte e a Tia Carajás IA. As Functions já tinham repasse com comissão, Pix/cartão condicionados a credencial e as ferramentas de leitura da Tia."),
            ("h", "Correções desta rodada"),
            ("b", "Tiles de categoria: em 1280×800 a área útil fica perto de 1032 px (sidebar de 248). A grade antiga usava 2 colunas e esticava os cards. Agora a altura é fixa em 112 px e a largura máxima é 168 px. Teste de widget mediu o primeiro tile. Classificação: Implementada e testada."),
            ("b", "Banner: em largura menor que 720 px os botões empilham, o retrato da Tia sai de cima do texto e o título reduz. Classificação: Implementada e testada na regra de layout; falta screenshot de aparelho físico."),
            ("b", "TypeError de flutter_tts na web: a voz da Tia na web já usava a Web Speech API. Foi adicionado um polyfill de speechSynthesis antes do bootstrap e a criação do plugin no celular ficou preguiçosa. Classificação: Implementada parcialmente — o erro de console em navegador real não foi reproduzido nesta máquina."),
            ("h", "O que não foi varrido tela a tela"),
            ("p", "Não houve passagem manual em Android e iOS físicos. Vários botões antigos continuam dependendo do Firebase. Onde o fluxo grava dado privado, a navegação agora pede login. Explorar a home, a busca e o perfil público não exige conta."),
        ],
    ),
    (
        "02_FLUXO_COMPLETO_CLIENTE.pdf",
        "02 · Fluxo do cliente",
        [
            LEGEND,
            ("p", "Explorar sem login: botões «Explorar sem entrar» na apresentação e no login, e a rota da Tia deixou de exigir conta só para abrir a tela. Ações que gravam (orçamento, chat, favorito, favoritar) chamam o login. Classificação: Implementada parcialmente."),
            ("p", "Cidade: o seletor de região que já existia no topo foi preservado."),
            ("p", "Conversa com a Tia, fotos, orçamento, propostas, aceite, agenda e avaliação existem em telas e em callables. A confirmação explícita é obrigatória nas ferramentas novas: sem confirmed=true nada contratual é gravado. O modelo de IA não consegue marcar confirmed."),
            ("p", "Pagamento: sem credencial o estado é aguardando_credenciais e approved permanece false. Classificação: Aguardando credenciais."),
            ("p", "O percurso inteiro Cadastro → Avaliação não foi executado num emulador com quatro contas nesta rodada. Classificação do fluxo ponta a ponta: Implementada parcialmente."),
        ],
    ),
    (
        "03_FLUXO_COMPLETO_PRESTADOR.pdf",
        "03 · Fluxo do prestador",
        [
            LEGEND,
            ("p", "Cadastro de prestador, documentos, portfólio, agenda e painel já existiam nas telas Flutter e nas regras (verified e registrationVerified só mudam por admin)."),
            ("p", "Nova ferramenta enviarOrcamento grava mão de obra, materiais, total, prazo, disponibilidade, condições, garantia e validade, com os números reais do prestador. Aceite do cliente é transacional e recusa uma segunda contratação."),
            ("p", "Atualização de status usa a máquina aguardando_orcamentos → … → concluído. Conclusão sem paymentStatus=paid é recusada. Classificação: Implementada e testada no backend; a tela do prestador ainda mostra sobretudo o status legado. Implementada parcialmente na UI."),
        ],
    ),
    (
        "04_FLUXO_COMPLETO_TIA_CARAJAS_IA.pdf",
        "04 · Tia Carajás IA",
        [
            LEGEND,
            ("p", "Sem chave de Gemini, OpenAI ou Anthropic a Tia responde indisponível e não inventa texto. Isso já era testado e continua."),
            ("p", "As ferramentas em português (buscarProfissionais, criarRascunhoSolicitacao, confirmarSolicitacao, enviarSolicitacao e as demais da lista) rodam no backend, exigem login, gravam auditoria e não leem pedido de outra pessoa. O botão de orçamento da Tia tenta essa sequência e, se a function ainda não estiver publicada, volta ao tiaConfirm antigo."),
            ("p", "Histórico: tiaHistory passa a ser carregado ao abrir a Central. Limites de mensagens, tokens e fotos do plano e o teto global já eram aplicados no orquestrador; a Central mostra o uso do mês quando o backend responde. Classificação: Implementada parcialmente (UI ligada; não houve conversa real com provedor de IA)."),
            ("p", "Aguardando credenciais: GEMINI_API_KEY, OPENAI_API_KEY ou ANTHROPIC_API_KEY no Secret Manager."),
            ("p", "Poses: só as sete artes de assets/tia_carajas. Pendentes, sem arte nova: corpo inteiro, analisando fotos, processando, apresentando orçamentos, comemorando. O código usa o fallback já documentado no manifest."),
        ],
    ),
    (
        "05_AUDITORIA_PAINEL_ADMINISTRATIVO.pdf",
        "05 · Painel administrativo",
        [
            LEGEND,
            ("p", "O painel admin já existente (usuários, prestadores, banners, cupons, suporte, configuração da IA) foi preservado. Feature flags novas ficam em config/featureFlags, gravadas só pela callable atualizarFeatureFlags, restrita a admin."),
            ("p", "Flags previstas: explorar, tia, orcamentos, agenda, pagamentos, whatsapp, saude, chat. A tela admin ainda não tem um formulário dedicado para todas elas. Classificação: Implementada parcialmente."),
            ("p", "registrationVerified e verified continuam protegidos nas regras do Firestore. Não houve teste de emulador de regras nesta rodada (Java está na máquina, o suite de emuladores não foi executado). Classificação das regras novas: Implementada parcialmente."),
        ],
    ),
    (
        "06_RELATORIO_TESTES_PONTA_A_PONTA.pdf",
        "06 · Relatório de testes",
        [
            ("p", "Cloud Functions (node --test): 38 testes aprovados, 0 falhas. Cobrem política de pedido, Tia, ferramentas da plataforma, gateway sem credencial e lembrete de agenda."),
            ("p", "Flutter test: 48 aprovados, 0 falhas, 1 ignorado (auth_flow_emulator_test: emulador na porta 9099 recusou conexão). Inclui layout dos tiles em 1032 px, rótulos do ciclo de vida, boleto que não aprova pagamento, modelos, política de repasse e a Central da Tia sem Firebase."),
            ("p", "Não executado: integration_test no dispositivo, teste de regras no emulador, cenário com quatro contas, pagamento sandbox real, build Android e build iOS (não há SDK de Android/Xcode nesta máquina)."),
            ("p", "Classificação do E2E completo: Não implementada como ensaio único. As partes de domínio citadas estão Implementadas e testadas em unidade."),
            ("p", "Evidência visual: docs/entrega/evidencias/categorias_desktop_1032.png, gerada pelo teste de widget na largura útil de um desktop 1280."),
        ],
    ),
    (
        "07_AUDITORIA_FINANCEIRA.pdf",
        "07 · Auditoria financeira",
        [
            LEGEND,
            ("p", "O Mercado Pago já era o gateway do projeto, desligado salvo PAYMENTS_ENABLED e MERCADOPAGO_ACCESS_TOKEN. Foi adicionada uma camada que também nomeia Asaas e Pagar.me."),
            ("p", "iniciarCobranca exige confirmação, grava uma intenção com approved=false e status aguardando_credenciais, não altera paymentStatus do pedido e é idempotente pela chave. Teste cobre isso."),
            ("p", "Nenhum teste nem código novo marca pagamento como aprovado sem webhook. O adapter, mesmo com token presente, não aprova localmente: a aprovação continua nos callables antigos e no webhook."),
            ("p", "Boleto no cliente retorna erro explícito de credencial. Classificação: Aguardando credenciais."),
            ("p", "Comissão de 15% no repasse foi preservada e continua testada. Split configurável pelo admin na UI não foi refeito. Classificação: Implementada parcialmente."),
            ("p", "Estorno: cancelar um pedido já pago marca refundRequested e não marca refunded. Classificação: Implementada parcialmente."),
        ],
    ),
    (
        "08_AUDITORIA_SEGURANCA_LGPD.pdf",
        "08 · Segurança e LGPD",
        [
            LEGEND,
            ("p", "Callables novas exigem autenticação. consultarPedido recusa pedido de outro usuário (teste). Regras: serviceDrafts, orderEvents, paymentIntents e platformAudit sem escrita pelo cliente. Fotos de solicitação em service-requests só para o cliente, a lista sharedWith ou admin."),
            ("p", "A Tia não recebe confirmed=true quando o ator é o modelo. Prompt injection continua no guardrail anterior."),
            ("p", "Exclusão: excluirMinhaConta apaga conversas e rascunhos da própria pessoa e marca deletionRequestedAt. Pedidos e pagamentos são mantidos pelo prazo legal e a resposta diz isso. Não apaga o usuário do Auth automaticamente."),
            ("p", "firebase_options.dart segue com projectId servicoconecta e chaves COLE_SUA_. Documentado o comando flutterfire configure --project=carajas360-a17c5. Ambientes separados estão em docs/AMBIENTES.md (APP_ENV=local|homolog|prod). Não foram inventados arquivos de opções."),
            ("p", "Teste de regras no emulador: Não implementada nesta rodada."),
            ("p", "WhatsApp Cloud API: consultarIntegracaoWhatsApp devolve aguardando_credenciais e sends=false."),
        ],
    ),
    (
        "09_RELATORIO_WEB_ANDROID_IOS.pdf",
        "09 · Web, Android e iOS",
        [
            LEGEND,
            ("p", "Web: flutter build web --release --dart-define=APP_ENV=homolog gera build/web. A pasta build/ está no gitignore; o artefato de build acompanha a entrega fora do Git quando o comando termina. PWA: manifest com nome Carajás 360 e display standalone."),
            ("p", "Fonte Plus Jakarta Sans (OFL) foi empacotada para não depender da CDN. Ícones de categoria usam os SVGs já versionados (Feather/Lucide, ver docs/entrega/LICENCAS_ICONES.md)."),
            ("p", "Android e iOS: o código e os projetos nativos foram preservados. Não há Android SDK nem Xcode nesta máquina, então não há APK/IPA. Instruções continuam em COMO_COMPILAR.md. Classificação dos binários móveis: Bloqueada por integração externa (toolchain)."),
            ("p", "Responsividade: a regra do banner e da grade está testada. Não houve viewport de celular real além do teste de largura."),
        ],
    ),
    (
        "10_PENDENCIAS_REAIS_PUBLICACAO.pdf",
        "10 · Pendências reais para publicar",
        [
            ("h", "Credenciais e configuração, sem segredos"),
            ("b", "flutterfire configure --project=carajas360-a17c5 e o equivalente num projeto Firebase só de homologação."),
            ("b", "google-services.json e GoogleService-Info.plist gerados por esse comando. Os atuais são placeholder."),
            ("b", "MERCADOPAGO_ACCESS_TOKEN + PAYMENTS_ENABLED=true. Opcional: ASAAS_API_KEY ou PAGARME_API_KEY e PAYMENT_PROVIDER."),
            ("b", "Uma chave de IA no Secret Manager (Gemini, OpenAI ou Anthropic)."),
            ("b", "WHATSAPP_TOKEN e WHATSAPP_PHONE_ID se o WhatsApp for ligado."),
            ("b", "OAuth Google, Apple, Maps."),
            ("h", "Produto"),
            ("b", "Ensaio E2E no emulador com cliente, prestador, empresa e admin."),
            ("b", "Testes das regras Firestore/Storage no emulador."),
            ("b", "Builds Android e iOS em máquina com SDK."),
            ("b", "Poses faltantes da Tia (manifest pending_poses)."),
            ("b", "Formulário admin para todas as feature flags."),
            ("b", "Webhook de estorno ligado ao gateway quando houver credencial."),
        ],
    ),
    (
        "11_CHECKLIST_FINAL_PUBLICACAO.pdf",
        "11 · Checklist final",
        [
            ("b", "Backup criado antes das mudanças: sim."),
            ("b", "Histórico Git preservado: sim, branch nova sobre a do PR #3."),
            ("b", "Deploy feito por este agente: não."),
            ("b", "Pagamento simulado como aprovado: não."),
            ("b", "Dados de demonstração misturados com produção: não. O catálogo de exemplo só aparece com DEV_BYPASS_LOGIN em não-release e Firebase desligado, com faixa explícita."),
            ("b", "Chave no frontend: não foi adicionada."),
            ("b", "Testes de unidade desta rodada: 38 Functions + 48 Flutter aprovados."),
            ("b", "Pronto para loja: não. Ver pendências do documento 10."),
        ],
    ),
    (
        "12_ENTREGA_FINAL_PROGRAMADOR.pdf",
        "12 · Entrega ao programador",
        [
            ("p", "Leia docs/AMBIENTES.md e docs/entrega/LICENCAS_ICONES.md. As callables novas estão em functions/platform/tools.js e são exportadas por functions/index.js. Lembretes: lembretesAgenda, a cada 60 minutos. Semente de homologação: functions/seed/homologacao.js, que recusa rodar sem FIRESTORE_EMULATOR_HOST."),
            ("p", "UI alterada com cuidado para não trocar a paleta verde-esmeralda, dourado e branco nem a logomarca. A Tia continua nos assets existentes."),
            ("p", "Para publicar a web de homologação, gere ou reutilize build/web e publique no Hosting do projeto de homologação, nunca no de produção, enquanto firebase_options apontar para placeholder."),
            ("h", "Comandos"),
            ("b", "cd functions && npm test"),
            ("b", "flutter test"),
            ("b", "flutter build web --release --dart-define=APP_ENV=homolog"),
            ("b", "flutter build apk  e  flutter build ipa  numa máquina com os SDKs, depois do flutterfire configure."),
        ],
    ),
    (
        "13_AUDITORIA_FUNCIONAL_POLIMENTO_FINAL.pdf",
        "13 · Auditoria funcional e polimento",
        [
            LEGEND,
            ("h", "Interface"),
            ("b", "Cards vazios de profissionais: a home distingue carregando, erro e vazio. O vazio diz que a lista não é preenchida com nomes fictícios e oferece a Tia. Classificação: Implementada parcialmente (home nova; outras listas antigas deixam de injetar demo fora do bypass)."),
            ("b", "Ícones de categoria: SVGs já existentes, licença registrada. Classificação: Implementada e testada no widget da grade."),
            ("b", "Fonte local Plus Jakarta Sans. Classificação: Implementada. Não houve prova visual de cada peso da fonte variável."),
            ("b", "Contraste e hierarquia: ajustes pontuais no banner e nos tiles. Não foi uma repaginação completa. Classificação: Implementada parcialmente."),
            ("h", "Tia"),
            ("b", "Histórico persistido no Firestore e recarregado na Central. Limites de plano e teto global já existiam; o uso do mês aparece na barra quando há sessão. Classificação: Implementada parcialmente."),
            ("h", "Fluxo completo"),
            ("b", "Cadastro, login, localização, busca, seleção, fotos, orçamento, propostas, contratação, agenda, pagamento, acompanhamento, conclusão e avaliação existem em partes do código. Não foram percorridos de ponta a ponta com contas reais nesta VM. Classificação: Implementada parcialmente, com pagamento Aguardando credenciais."),
            ("h", "Firebase"),
            ("b", "Rules de rascunho, eventos, intenções de pagamento, auditoria e fotos de solicitação foram apertadas. Não rodaram no emulador. Classificação: Implementada parcialmente."),
            ("b", "Navegação pública sem login para explorar; login para gravar. Classificação: Implementada parcialmente (pontos de entrada principais)."),
            ("h", "Botões"),
            ("b", "Não é verdade que todos os botões do app foram clicados. Os que esta rodada tocou (busca do banner, Tia, explorar sem entrar, solicitar, chat, favorito) têm ação. Pendente: varredura manual do restante. Classificação: Implementada parcialmente."),
            ("h", "Evidência"),
            ("p", "docs/entrega/evidencias/categorias_desktop_1032.png mostra a grade na largura de desktop, com tiles baixos e ícones SVG. Não substitui um ensaio em celular."),
        ],
    ),
]


def main():
    for name, title, blocks in DOCS:
        write(name, title, blocks)


if __name__ == "__main__":
    main()
