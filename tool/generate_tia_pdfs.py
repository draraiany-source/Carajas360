#!/usr/bin/env python3
"""Gera os PDFs de entrega da Tia Carajás IA. Conteúdo honesto sobre o que foi feito e testado."""
from pathlib import Path
from fpdf import FPDF

FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
OUT = Path("/agent/repos/Carajas360/docs")


class Doc(FPDF):
    def __init__(self, title):
        super().__init__()
        self.doc_title = title
        self.add_font("DejaVu", "", FONT)
        self.add_font("DejaVu", "B", FONTB)
        self.set_auto_page_break(auto=True, margin=18)

    def header(self):
        self.set_font("DejaVu", "B", 9)
        self.set_text_color(12, 61, 36)
        self.cell(0, 8, "Carajás 360  ·  Tia Carajás IA", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(20, 107, 52)
        self.line(10, 16, 200, 16)
        self.ln(4)

    def footer(self):
        self.set_y(-12)
        self.set_font("DejaVu", "", 8)
        self.set_text_color(90, 90, 90)
        self.cell(0, 8, f"{self.doc_title}  ·  p. {self.page_no()}", align="C")

    def h1(self, text):
        self.set_font("DejaVu", "B", 16)
        self.set_text_color(12, 61, 36)
        self.multi_cell(0, 8, text)
        self.ln(2)

    def h2(self, text):
        self.ln(1)
        self.set_font("DejaVu", "B", 12)
        self.set_text_color(20, 90, 45)
        self.multi_cell(0, 7, text)
        self.ln(1)

    def p(self, text):
        self.set_font("DejaVu", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.4, text)
        self.ln(1)

    def bullet(self, text):
        self.set_font("DejaVu", "", 10)
        self.set_text_color(30, 30, 30)
        self.multi_cell(0, 5.4, "•  " + text)
        self.ln(0.4)


def write(name, title, sections):
    pdf = Doc(title)
    pdf.add_page()
    pdf.h1(title)
    pdf.p("Data do relatório: 25 de novembro de 2026. Ambiente: VM de desenvolvimento, sem credenciais do projeto Firebase carajas360-a17c5. Nada foi publicado em produção.")
    for heading, paragraphs in sections:
        pdf.h2(heading)
        for item in paragraphs:
            if item.startswith("- "):
                pdf.bullet(item[2:])
            else:
                pdf.p(item)
    path = OUT / name
    pdf.output(path)
    print(path, path.stat().st_size)


write(
    "IMPLEMENTACAO_TIA_CARAJAS_IA.pdf",
    "Implementação da Tia Carajás IA",
    [
        ("O que entrou no app", [
            "A Tia Carajás IA foi adicionada ao app Flutter já existente (pacote servico_conecta), em cima do redesign verde e amarelo. Não foi criado outro projeto.",
            "Nome único na interface nova: Tia Carajás IA. A apresentação fixa, que não é resposta de modelo, é: “Olá! Sou a Tia Carajás, sua assistente inteligente de serviços. Posso encontrar profissionais, solicitar orçamentos, analisar fotos, agendar atendimentos e acompanhar seus pedidos. Como posso ajudar você hoje?”",
            "O chat antigo com respostas prontas por palavra-chave foi removido. Se o provedor não está configurado, a tela mostra IA indisponível e não inventa profissional, preço ou agenda.",
        ]),
        ("Cliente", [
            "- Central em lib/features/tia/tia_screen.dart, web e mobile, com atalhos, anexo de foto, microfone, leitura em voz e botão de confirmar.",
            "- Solicitar serviço em quatro passos: descrição, fotos, revisão e escolha de proposta real.",
            "- Agendamento com calendário, horário desejado e pedido gravado como requested. Saúde exige registro verificado pelo admin.",
            "- Saúde lista as especialidades pedidas e só mostra cadastros do Firestore. Sem profissionais de demonstração.",
            "- Pedidos: o menu Acompanhar abre o painel com o status real, endereço e pagamento gravado.",
            "- Admin: aba Tia Carajás IA para ligar/desligar, kill switch, provedor, teto de tokens, orçamento, saudação, base de conhecimento e exclusão de conversas.",
            "- Navegação: a barra inferior do celular passa a ser Início, Tia Carajás IA, Agenda, Pedidos e Perfil. Explorar, mensagens e favoritos continuam na gaveta e na sidebar.",
        ]),
        ("Backend", [
            "Cloud Functions em functions/ai. O cliente só chama callables autenticadas (tiaChat, tiaAnalyzePhoto, tiaEstimate, tiaConfirm, tiaStatus, tiaHistory, tiaDeleteMyData, tiaAdminGet, tiaAdminUpdate, tiaAdminDeleteUser). A função antiga aiAssistant passou a usar o mesmo núcleo e falha com failed-precondition se a IA estiver indisponível.",
            "Provedores: Gemini (padrão, Google AI / Firebase AI via REST), OpenAI compatível e Anthropic. A escolha é config/ai.provider ou a primeira chave presente. Segredos só em process.env / Secret Manager. Nenhuma chave no Flutter.",
            "Ferramentas do modelo, executadas no servidor: buscar profissionais, agenda publicada, pedidos, propostas, categorias, planos, base de conhecimento, estimativa só com pedidos concluídos e propose_action. propose_action não grava. A gravação é tiaConfirm, depois do toque do usuário.",
            "Preços e notas que não aparecem no JSON das ferramentas são redatados. Texto com diagnóstico, dose ou conduta médica é substituído pelo aviso administrativo.",
        ]),
        ("Personagem", [
            "Arquivos em assets/tia_carajas/, um WebP por pose recortada dos mockups, fundo removido com rembg, mais avatar circular. O manifesto lista a fidelidade de cada arquivo.",
            "Poses entregues como recorte: recepcionando, apresentando, escutando_voz (recorte mais próximo, com headset), suporte, confirmando (recorte da tela de agenda, não um gesto exclusivo) e orientando.",
            "Pendentes de ilustrador ou artista 3D: corpo inteiro, analisando fotos, processando, apresentando orçamentos e comemorando. Não foram duplicadas artes falsas para essas poses. A interface usa o recorte mais próximo.",
            "Movimento: o avatar sobe e desce de leve enquanto ouve ou fala. Não há arquivo Rive nem animação 3D da personagem.",
        ]),
        ("Voz", [
            "No navegador, Web Speech API (reconhecimento e fala pt-BR), com diálogo de permissão antes do microfone. O áudio não vai para um servidor de voz.",
            "No Android, iOS e desktop, os plugins speech_to_text e flutter_tts. Não houve teste em aparelho físico nesta VM.",
        ]),
        ("O que não foi feito", [
            "Não houve deploy. firebase_options.dart e google-services.json continuam com placeholders e o projectId servicoconecta, não carajas360-a17c5.",
            "Não há build Android (APK) nem iOS. O build web de homologação local foi gerado com flutter build web -t tool/ui_preview.dart e não usa Firebase.",
            "WhatsApp: o pedido pode gravar a preferência whatsappOptIn. Não existe envio pela API do WhatsApp.",
            "Preços comerciais dos planos nascem nulos. Os tetos de mensagem, token e foto são limites técnicos iniciais, editáveis pelo admin em config/aiPlans.",
        ]),
    ],
)

write(
    "AUDITORIA_COMPLETA_IA.pdf",
    "Auditoria da Tia Carajás IA",
    [
        ("Escopo", [
            "Auditoria do desenho implementado neste branch, não de um ambiente publicado. Não houve acesso ao console do projeto carajas360-a17c5.",
        ]),
        ("Achados que o código já trata", [
            "- A IA não grava pedido, agenda, proposta ou perfil. Isso só ocorre em tiaConfirm, com usuário autenticado.",
            "- Agendamento de saúde é recusado se registrationVerified não for true. O prestador não pode marcar esse campo: a regra do Firestore inclui registrationVerified nas chaves protegidas.",
            "- Profissionais devolvidos ao modelo são só active e verified. Telefone, documento e selfie não entram no objeto público.",
            "- Estimativa de preço exige pelo menos cinco pedidos concluídos com preço na categoria. Abaixo disso a resposta diz que não há dados.",
            "- Conversas ficam em aiConversations e só o dono lê. Escrita direta do cliente está bloqueada nas rules. Apagar é callable do próprio usuário ou do admin.",
            "- config/ai, onde ficam gasto e kill switch, só o admin lê. A chave da API não é gravada nesse documento.",
            "- Rate limit: 20 chats por minuto, 8 análises de foto por hora, além do teto mensal do plano e do teto global de tokens (padrão 2.000.000) e do orçamento em USD se o admin definir.",
            "- App Check continua opcional por ENFORCE_APP_CHECK, como nas funções que já existiam.",
        ]),
        ("Achados em aberto", [
            "- As rules novas não foram executadas no emulador nesta VM. A suíte node cobre a lógica com banco em memória, não o arquivo firestore.rules.",
            "- A contagem de uso faz leitura e escrita simples. Duas mensagens simultâneas do mesmo usuário podem se sobrepor. Não é um bloqueio contábil perfeito.",
            "- A redação de preço é por dígitos presentes no JSON das ferramentas. Não é um detector de nomes inventados. O aviso é anexado quando o texto fala em profissionais e a busca voltou vazia. Os cartões da tela só usam o array providers.",
            "- A função de exclusão marca a auditoria, mas a retenção automática pelo campo retentionDays não tem job agendado. O admin precisa apagar ou um job futuro deve varrer aiConversations.",
            "- O cliente ainda pode criar pedido e agendamento pelos fluxos antigos (FS.createOrder, FS.createAppointment). Esses fluxos não passam pela Tia. createAppointment agora grava status requested quando o mapa pede isso; o padrão antigo scheduled permanece para chamadas que não pedem requested.",
            "- Dados de demonstração antigos (DemoData) continuam em outras telas, só fora de release. A saúde e a Tia não usam essa lista.",
        ]),
        ("Conclusão", [
            "O desenho separa conversa, ferramenta e confirmação. Não está pronto para produção enquanto os segredos, o App Check, as rules no emulador e o projectId real não forem conferidos por quem tem acesso ao Firebase.",
        ]),
    ],
)

write(
    "RELATORIO_TESTES_WEB_ANDROID_IOS.pdf",
    "Relatório de testes — Web, Android e iOS",
    [
        ("O que rodou nesta VM", [
            "- functions: npm test — 23 testes node, incluindo 11 da Tia. Passaram. Cobrem IA sem chave, kill switch, busca sem preço inventado, lista vazia, limite do plano gratuito, bloqueio de texto médico, recusa de agenda de saúde sem registro verificado, gravação de orçamento sem cobrança, estimativa com amostra insuficiente e foto sem provedor.",
            "- flutter test — 43 testes passaram. 1 teste de autenticação no emulador foi ignorado porque nada escutava em localhost:9099.",
            "- flutter analyze — nenhum erro. Os avisos deprecated_member_use de material.dart e withOpacity já existiam no projeto com o Flutter 3.50 e também aparecem nos arquivos novos, porque o SDK marca material.dart como obsoleto.",
            "- flutter build web -t tool/ui_preview.dart — compilou. Esse alvo não inicializa Firebase. Capturas em desktop e celular foram feitas com Chrome headless sobre esse build.",
        ]),
        ("O que a captura mostra", [
            "- Início: hero com a personagem, botão Conversar com a Tia Carajás IA e o cartão de ajuda na sidebar.",
            "- Explorar: faixa Fale com a IA. A lista fica em carregamento porque não há Firebase.",
            "- Central web e celular: apresentação, atalhos e painel de capacidades. Sem resposta simulada.",
            "- Solicitar serviço: quatro passos e o aviso de que o WhatsApp ainda não envia mensagem.",
            "- Agendamento: calendário, texto de que o horário publicado não existe e de que a confirmação depende do profissional. Lista vazia de profissionais.",
            "- Saúde: especialidades e estado vazio. Sem médicos fictícios.",
        ]),
        ("O que não rodou", [
            "- Emuladores Auth, Firestore, Storage e Functions não foram iniciados. Não houve teste de rules nem de callable contra o emulador.",
            "- Não há SDK Android configurado para gerar APK nesta sessão, e não há Mac para build iOS. Nenhum aparelho físico foi usado.",
            "- Microfone, voz, upload de foto e chamada real ao Gemini/OpenAI/Anthropic não foram exercitados. O build web só mostra a interface.",
            "- Teste de carga, acessibilidade com leitor de tela e navegação completa por teclado não foram executados. Os botões novos têm tooltip e o campo de texto aceita Enter.",
        ]),
    ],
)

write(
    "RELATORIO_SEGURANCA_IA.pdf",
    "Relatório de segurança da IA",
    [
        ("Modelo de ameaça", [
            "O risco principal é a IA afirmar um fato que não está no Firestore, ou executar contratação, cobrança e mudança de agenda sem o usuário confirmar. O segundo risco é vazar chave, conversa ou dado de saúde.",
        ]),
        ("Controles implementados", [
            "- Chave só no processo da função. O painel admin mostra apenas se a chave existe, nunca o valor.",
            "- Callable exige login. App Check pode ser obrigatório com ENFORCE_APP_CHECK=true, igual ao restante do backend.",
            "- O prompt manda tratar o texto do usuário como pedido, não como instrução de sistema. Há detecção simples de frases do tipo ignore previous instructions, usada para reforçar o prompt. Não é um filtro perfeito.",
            "- Saúde: o system prompt e um filtro de saída bloqueiam prescrição, diagnóstico, dose e conduta. O agendamento de especialidade de saúde só segue se o cadastro tiver registrationVerified.",
            "- Foto: limite de 1,2 MB, só jpeg, png ou webp. O resultado sempre leva o aviso de que não substitui avaliação presencial. A imagem não é gravada na conversa.",
            "- Confirmação idempotente por actionId, para um toque duplo não criar dois pedidos.",
            "- Rules: aiConversations, aiUsage e aiAudit não aceitam escrita do cliente. config/ai é leitura de admin.",
        ]),
        ("Limites conhecidos", [
            "- Prompt injection sofisticada não está coberta por um classificador. O modelo ainda pode produzir texto ruim; a tela não transforma esse texto em gravação.",
            "- O histórico enviado pelo cliente é limitado a 8 turnos e 1000 caracteres, mas o cliente pode mentir sobre o passado. As ferramentas releem o Firestore na hora da ação.",
            "- Não foi feito teste de invasão nem revisão externa.",
            "- LGPD: a exclusão apaga os documentos de conversa encontrados. Não há política automática de retenção rodando. Dados de pedido e agenda seguem as coleções já existentes e não são apagados junto com o chat.",
        ]),
        ("Antes de publicar", [
            "- Criar os segredos, ligar App Check, restringir domínios de Auth e conferir as rules no emulador com usuários cliente, prestador e admin.",
            "- Não colocar a chave em --dart-define, asset ou repositório.",
        ]),
    ],
)

write(
    "RELATORIO_CUSTOS_INTELIGENCIA_ARTIFICIAL.pdf",
    "Custos estimados da inteligência artificial",
    [
        ("Como a conta é evitada", [
            "Sem chave, nenhuma chamada sai. Com chave, cada mensagem passa por limite do plano, teto global de tokens e, se configurado, orçamento mensal em USD. O kill switch desliga a IA na hora.",
            "Voz e reconhecimento ficam no aparelho ou no navegador. Não há STT/TTS pago no servidor nesta versão.",
            "A estimativa de preço não chama o modelo: lê pedidos concluídos.",
        ]),
        ("Números usados no código, não uma fatura", [
            "São referências para o contador interno, em USD por 1 milhão de tokens. O admin pode substituir em config/ai.rates. Não conferi a tabela vigente de cada fornecedor nesta data.",
            "- Gemini: 0,10 entrada e 0,40 saída.",
            "- OpenAI compatível (referência gpt-4o-mini): 0,15 entrada e 0,60 saída.",
            "- Anthropic (referência do modelo já usado no projeto): 3 entrada e 15 saída. Esse provedor é o mais caro das três referências e não deve ser o padrão.",
            "O contador grava estimatedUsd em config/ai.spentUsdEstimate. É estimativa, não o extrato do Google ou da OpenAI.",
        ]),
        ("Tetos iniciais por plano", [
            "Preço de assinatura: null até o admin gravar. Não inventei mensalidade.",
            "- Gratuito: 30 mensagens, 20.000 tokens, 3 fotos por mês.",
            "- Premium: 300 mensagens, 200.000 tokens, 40 fotos.",
            "- Profissional: 800 mensagens, 500.000 tokens, 120 fotos.",
            "- Empresarial: 3.000 mensagens, 2.000.000 tokens, 400 fotos.",
            "Teto global padrão: 2.000.000 tokens no mês. Exemplo grosseiro com a referência Gemini, se todo o teto fosse saída: cerca de 0,80 USD. Se fosse entrada, cerca de 0,20 USD. Uma mistura real fica entre esses valores. Anthropic no mesmo volume sairia muito mais cara, por isso o padrão é Gemini.",
            "Foto usa o mesmo modelo com visão e conta como análise de foto e como tokens. Não há preço separado de visão na estimativa.",
        ]),
        ("O que falta para controlar custo de verdade", [
            "- Conferir o preço publicado do modelo escolhido e gravar usd por milhão em config/ai.",
            "- Definir monthlyUsdBudget. Sem esse número, só o teto de tokens segura a conta.",
            "- Alertas de billing no console do Google ou da OpenAI. O app não lê a fatura do provedor.",
            "- O contador pode errar para baixo se a resposta da API não trouxer usage.",
        ]),
    ],
)

write(
    "CHECKLIST_PUBLICACAO_CARAJAS360.pdf",
    "Checklist de publicação — Carajás 360 e Tia Carajás IA",
    [
        ("Firebase carajas360-a17c5", [
            "- Rodar flutterfire configure --project=carajas360-a17c5 e substituir lib/firebase_options.dart. O arquivo atual tem apiKey COLE_SUA e projectId servicoconecta.",
            "- Trocar android/app/google-services.json e o plist iOS pelos arquivos reais. O JSON atual tem project_number 000000000000.",
            "- Auth: habilitar os provedores já usados (e-mail, Google, Apple, telefone) e autorizar os domínios do app web.",
            "- App Check: registrar web, Android e iOS, colocar as chaves e só então ENFORCE_APP_CHECK=true.",
            "- Ativar Vertex AI ou a Generative Language API se a chave for do Gemini, e a API que o provedor escolhido exigir.",
        ]),
        ("Segredos das funções", [
            "Criar antes do deploy, senão a função sobe sem provedor e a Tia fica indisponível de propósito:",
            "- firebase functions:secrets:set GEMINI_API_KEY",
            "- firebase functions:secrets:set OPENAI_API_KEY  (use o valor disabled se não for usar)",
            "- firebase functions:secrets:set ANTHROPIC_API_KEY  (use disabled se não for usar)",
            "- OPENAI_BASE_URL se o endpoint não for https://api.openai.com",
            "As funções novas leem process.env. No deploy gen1 é preciso garantir que o segredo entre no ambiente da função. O padrão deste repositório já lia MERCADOPAGO_ACCESS_TOKEN e ANTHROPIC_API_KEY assim, sem runWith secrets. Confira no console se a variável aparece na função. Se não aparecer, associe o segredo na configuração da função antes de abrir para usuários.",
            "Não foi feito deploy daqui.",
        ]),
        ("Dados e regras", [
            "- Publicar firestore.rules, storage.rules e firestore.indexes.json.",
            "- Rodar os emuladores com um cliente, um prestador e um admin e repetir: chat, foto, orçamento, agenda de saúde sem registro, agenda com registro verificado, exclusão de conversa.",
            "- Marcar registrationVerified só pelo admin, depois de conferir CRM, CRP, CRN, CREFITO ou CRO.",
            "- Gravar preços dos planos em config/aiPlans se forem cobrados. Enquanto priceCents for null, a tela não deve anunciar um valor.",
            "- Definir monthlyTokenCap, monthlyUsdBudget e o kill switch.",
            "- Escrever os artigos da base de conhecimento. Sem artigos, a ferramenta diz que não há texto publicado.",
        ]),
        ("Builds", [
            "- Web: o preview local existe (flutter build web -t tool/ui_preview.dart). O build de produção precisa das options reais e não deve usar esse alvo, que não inicializa Firebase.",
            "- Android e iOS: não gerados nesta sessão. Faltam SDK de release, assinatura e máquina macOS para o iOS.",
            "- Personagem: as poses pendentes do manifesto precisam de arte nova antes de uma campanha que prometa dez poses 3D.",
        ]),
        ("Pronto quando", [
            "Um usuário de teste, com a chave só no servidor, pede um eletricista, vê apenas quem está no Firestore, confirma o orçamento na tela, recebe o pedido pendente sem cobrança e, com a chave removida, vê IA indisponível sem perder busca, pedido e chat humanos.",
        ]),
    ],
)
