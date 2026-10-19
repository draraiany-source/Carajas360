# -*- coding: utf-8 -*-
"""Gera o relatório da Auditoria 3 (app completo) do Carajás 360.

Uso: python3 gerar_pdf_3.py SAIDA.pdf resultados.json
"""
import json
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase.pdfmetrics import registerFontFamily
from reportlab.platypus import (BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak, NextPageTemplate)

OUT = sys.argv[1]
RES = json.load(open(sys.argv[2], encoding='utf-8'))

F = '/usr/share/fonts/truetype/dejavu/'
pdfmetrics.registerFont(TTFont('DV', F + 'DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DVB', F + 'DejaVuSans-Bold.ttf'))
pdfmetrics.registerFont(TTFont('DVM', F + 'DejaVuSansMono.ttf'))
registerFontFamily('DV', normal='DV', bold='DVB', italic='DV', boldItalic='DVB')

INK = colors.HexColor('#1A2233')
MUTED = colors.HexColor('#5B6475')
LINE = colors.HexColor('#D9DEE7')
BRAND = colors.HexColor('#0D3D91')
SOFT = colors.HexColor('#F2F5FA')
SEV = {'Alta': colors.HexColor('#C4320A'), 'Média': colors.HexColor('#B54708'), 'Baixa': colors.HexColor('#475467')}
ST = {'Corrigido': colors.HexColor('#067647'), 'Parcial': colors.HexColor('#B54708'), 'Pendente': colors.HexColor('#B42318')}
INV = {'REAL': colors.HexColor('#067647'), 'PARCIAL': colors.HexColor('#B54708'), 'FALSO': colors.HexColor('#B42318'),
       'QUEBRADO': colors.HexColor('#B42318'), 'ENGANOSO': colors.HexColor('#B42318'), 'EM BREVE': colors.HexColor('#475467'),
       'REMOVIDO': colors.HexColor('#475467')}

ss = {
    'h1': ParagraphStyle('h1', fontName='DVB', fontSize=17, leading=22, textColor=INK, spaceBefore=4, spaceAfter=8),
    'h2': ParagraphStyle('h2', fontName='DVB', fontSize=12.5, leading=17, textColor=BRAND, spaceBefore=12, spaceAfter=5),
    'p': ParagraphStyle('p', fontName='DV', fontSize=9.5, leading=14, textColor=INK, spaceAfter=5),
    'small': ParagraphStyle('small', fontName='DV', fontSize=8, leading=11, textColor=MUTED),
    'cell': ParagraphStyle('cell', fontName='DV', fontSize=7.8, leading=10.2, textColor=INK),
    'cellb': ParagraphStyle('cellb', fontName='DVB', fontSize=7.8, leading=10.2, textColor=INK),
    'li': ParagraphStyle('li', fontName='DV', fontSize=9.5, leading=14, textColor=INK, leftIndent=12, bulletIndent=2, spaceAfter=2),
    'title': ParagraphStyle('title', fontName='DVB', fontSize=26, leading=32, textColor=INK, alignment=TA_LEFT),
    'sub': ParagraphStyle('sub', fontName='DV', fontSize=12, leading=17, textColor=MUTED),
    'kpi': ParagraphStyle('kpi', fontName='DVB', fontSize=20, leading=24, textColor=INK, alignment=TA_CENTER),
    'kpil': ParagraphStyle('kpil', fontName='DV', fontSize=8, leading=10, textColor=MUTED, alignment=TA_CENTER),
}
P = lambda t, s='p': Paragraph(t, ss[s])


def bullets(items):
    return [Paragraph(t, ss['li'], bulletText='•') for t in items]


def chip(text, color):
    return Paragraph(f'<font color="{color.hexval()}"><b>{text}</b></font>', ss['cell'])


def table(rows, widths):
    t = Table(rows, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BACKGROUND', (0, 0), (-1, 0), SOFT),
        ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE), ('TOPPADDING', (0, 0), (-1, -1), 3.5), ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
        ('LEFTPADDING', (0, 0), (-1, -1), 3), ('RIGHTPADDING', (0, 0), (-1, -1), 3),
    ]))
    return t


# ─────────────── Inventário: (tela, antes, depois, observação) ───────────────
INVENTORY = [
    ('Início, entrada e perfil', [
        ('Abertura (splash)', 'REAL', 'REAL', 'Chips mostram só os módulos disponíveis (Serviços, Resolve, Saúde).'),
        ('Apresentação (onboarding)', 'FALSO', 'REAL', 'Saíram "300 serviços" e "GPS ao vivo"; agora descreve o que existe.'),
        ('Entrar / Cadastro', 'PARCIAL', 'REAL', 'Saída pós Google/SMS; CPF opcional para cliente; tipo "Entregador" oculto; termos com link.'),
        ('Início', 'PARCIAL', 'PARCIAL', 'Profissionais filtrados pela cidade; atualizar recarrega de verdade; 6 de 8 atalhos seguem "Em breve" (marcados).'),
        ('Busca', 'REAL', 'REAL', 'Toque no campo agora abre a busca.'),
        ('Perfil', 'PARCIAL', 'REAL', 'Estatísticas "—" e "Endereços" removidos; XP e níveis reais; botão voltar.'),
        ('Carteira', 'REAL', 'REAL', 'Aba "Planos" com preços fictícios removida.'),
        ('Assistente IA', 'PARCIAL', 'REAL', 'Não promete mais agendar/encontrar; aviso de que a IA pode errar.'),
        ('GPS / Entregas / Indique', 'EM BREVE', 'EM BREVE', 'Marcados "Em breve"; sem promessa de cashback.'),
        ('Excluir conta', 'PARCIAL', 'REAL', 'Servidor anonimiza perfil de prestador e avaliações e apaga arquivos pessoais.'),
    ]),
    ('Mercado e pedidos', [
        ('Mercado (vitrine)', 'PARCIAL', 'REAL', 'Busca e categorias filtram de verdade; sem nota "0.0" fixa.'),
        ('Carrinho / Finalizar pedido', 'REAL', 'REAL', 'Cupom recalcula a cotação; cotação velha descartada após erro.'),
        ('Pix / cartão / acompanhamento', 'REAL', 'REAL', 'Confirmar recebimento pede confirmação.'),
        ('Minha loja (painel)', 'PARCIAL', 'REAL', 'Loja vê itens, endereço e nome do cliente; menus corrigidos; exige login.'),
        ('Catálogo da loja', 'PARCIAL', 'REAL', 'Preço "1.234,56" aceito; estoque negativo bloqueado; excluir confirma.'),
        ('Perfil público da loja', 'QUEBRADO', 'REAL', 'Permite adicionar produtos ao carrinho.'),
        ('Meus pedidos', 'PARCIAL', 'REAL', 'Pedidos do Mercado aparecem junto com os de serviço.'),
    ]),
    ('Prestador, empresa, Resolve e admin', [
        ('Pedidos do prestador', 'PARCIAL', 'REAL', 'Não trava após 15 min; mostra se o pedido foi pago.'),
        ('Resolve (profissional escolhido)', 'QUEBRADO', 'REAL', 'Agora vê endereço, referência e telefone do cliente.'),
        ('Cadastro de prestador', 'PARCIAL', 'REAL', 'Só envia com documento e selfie.'),
        ('Empresa', 'PARCIAL', 'REAL', '"Leads" e "Assinatura" falsos removidos; contador da equipe real; erros tratados.'),
        ('Admin › Banners', 'FALSO', 'EM BREVE', 'Os banners nunca eram exibidos no app; criação desativada e aba marcada.'),
        ('Admin › Financeiro', 'ENGANOSO', 'REAL', '"Faturamento" virou "Volume de serviços (GMV)"; reembolsos aprovados reais.'),
        ('Admin › Cupons / Usuários', 'PARCIAL', 'REAL', 'Cupom ativa/desativa com validade; filtro avisa o limite de 50.'),
    ]),
    ('Saúde, Locação, chat e suporte', [
        ('Saúde (como funciona)', 'FALSO', 'REAL', 'Sem promessa de videochamada ou avaliações; 4 passos reais.'),
        ('Home Care', 'PARCIAL', 'REAL', 'Endereço obrigatório, visível só para paciente e profissional.'),
        ('Saúde (profissional)', 'PARCIAL', 'REAL', 'Vê nome, motivo e endereço do paciente; botão de conversa.'),
        ('Emergência', 'PARCIAL', 'REAL', 'Botão "Ligar 192".'),
        ('Locação (anúncio e reservas)', 'PARCIAL', 'REAL', 'Datas e horas no fuso de Belém; nome do anunciante real; compartilhar copia o texto.'),
        ('Chat', 'REAL', 'REAL', 'Aviso de pagamento corrigido; localização não falsificável; anexos só do app.'),
        ('Ajuda (FAQ)', 'PARCIAL', 'REAL', 'Respostas reescritas a partir dos fluxos reais.'),
    ]),
]

# ─────────────── Achados: (id, severidade, problema, correção, status) ───────────────
FINDINGS = [
    ('Camada compartilhada (todas as telas)', [
        ('E1', 'Alta', 'Tocar no campo de busca do Início não abria a busca.', 'O campo repassa o toque.', 'Corrigido'),
        ('E2', 'Alta', 'Modo escuro: 59 cartões ficavam brancos com texto claro (contraste 1,05:1).', 'Cartões seguem o tema ativo.', 'Corrigido'),
        ('E3', 'Alta', 'Notificação push: tocar não abria a tela; o servidor não mandava destino; token não renovado.', 'Servidor envia tipo/rota/id e limpa tokens inválidos; o app navega no toque e renova o token.', 'Corrigido'),
        ('E4', 'Alta', 'Sair da conta não apagava o token de push (aparelho compartilhado recebia avisos da conta anterior).', 'Logout apaga o token no servidor e no aparelho.', 'Corrigido'),
        ('E5', 'Média', 'Banners prometiam "5 estrelas", "motoboy e frete expresso" e "cupons exclusivos".', 'Textos neutros e verdadeiros.', 'Corrigido'),
        ('E6', 'Média', 'Card do profissional: selo "✅" sempre e "Bronze ★0.0" para novos; botão "📹 Online" enganoso.', '"Novo" sem avaliações; "Atende online" como modalidade; botão "Contratar".', 'Corrigido'),
        ('E7', 'Média', 'Relatório financeiro mostrava estornos sempre R$ 0; auditoria duplicada ao suspender.', 'Soma dos reembolsos aprovados (agregação); um registro por ação.', 'Corrigido'),
        ('E8', 'Média', 'Código morto/falso: reembolso fictício, categorias congeladas, baixa de estoque no app.', 'Removido.', 'Corrigido'),
        ('E9', 'Média', 'Cashback só quando o cliente confirma pelo app (autoconfirmação de 72 h não gera).', '—', 'Pendente'),
        ('E10', 'Média', 'Relatórios do admin baixam coleções inteiras; 45 fluxos criados dentro do build.', 'Marcar mensagens lidas limitado a 400.', 'Parcial'),
        ('E11', 'Baixa', 'Contraste de textos de aviso/dica; pubspec com marca antiga; web sem lang pt-BR.', 'Cores ajustadas; descrição Carajás 360; lang e descrição na web.', 'Corrigido'),
    ]),
    ('Início, entrada, perfil, carteira e IA', [
        ('A1', 'Alta', 'Apresentação prometia "300 serviços" e "GPS ao vivo".', 'Textos verdadeiros.', 'Corrigido'),
        ('A2', 'Alta', 'Carteira › Planos com preços fictícios e "Assinar".', 'Aba removida.', 'Corrigido'),
        ('A3', 'Alta', 'Perfil e Carteira abertos sem botão voltar (iPhone ficava preso).', 'Botão voltar quando há tela anterior.', 'Corrigido'),
        ('A4', 'Alta', 'Cadastro após Google/SMS sem saída; CPF obrigatório para cliente.', 'Voltar leva ao app; CPF opcional para cliente (pedido no pagamento).', 'Corrigido'),
        ('A5–A8', 'Média', '"Indique e ganhe cashback", "Endereços", estatísticas "—", IA prometendo agendar.', 'Removidos ou reescritos; XP e níveis reais.', 'Corrigido'),
        ('A9–A11', 'Média', 'Cidade não filtrava; atualizar era falso; tipo "Entregador" sem módulo.', 'Filtro por cidade; atualizar recarrega; tipo oculto.', 'Corrigido'),
        ('A12', 'Média', 'Exclusão de conta deixava perfil de prestador, avaliações e fotos.', 'Servidor anonimiza e apaga arquivos pessoais.', 'Corrigido'),
        ('A13', 'Média', 'Falha ao excluir conta deixava o app sem o aviso de "sessão expirada".', 'A marca é desfeita quando a exclusão falha.', 'Corrigido'),
        ('A14–A17', 'Média', 'Termos sem link; erros de senha/Apple sem aviso; exceções cruas na tela.', 'Links, try/catch e mensagens em português.', 'Corrigido'),
        ('A18–A25', 'Baixa', 'Acentos, saudação, acessibilidade, GPS em São Paulo, avaliação começando em 5 estrelas, tela de configuração em inglês.', 'Corrigidos.', 'Corrigido'),
    ]),
    ('Mercado e pedidos', [
        ('B-A1', 'Alta', 'Categorias do Mercado nunca filtravam.', 'Filtram os produtos.', 'Corrigido'),
        ('B-A2', 'Alta', 'A loja não via itens, endereço nem nome do cliente.', 'Pedido mostra itens, endereço e cliente.', 'Corrigido'),
        ('B-A3', 'Alta', '"Pedidos" da loja abria os pedidos de serviço.', 'Abre os pedidos da loja.', 'Corrigido'),
        ('B-A4', 'Alta', 'Busca do Mercado era decorativa.', 'Busca real.', 'Corrigido'),
        ('B-M1–M13', 'Média', '"Entrega rápida", cupom sem recotar, cotação velha, nota 0.0, "Cupons" da loja falso, erro virando cadastro, perfil da loja sem compra, Mercado fora de Meus pedidos, receber sem confirmação.', 'Corrigidos (13 itens).', 'Corrigido'),
        ('B-B1–B8', 'Baixa', 'Preço com vírgula, estoque negativo, excluir sem confirmação, fuso, rótulos, parcelas.', 'Corrigidos.', 'Corrigido'),
        ('B-B9', 'Baixa', 'Produtos de loja desativada continuam na vitrine.', '—', 'Pendente'),
        ('B-B10', 'Baixa', 'Rota "Minha loja" abria sem login; erro de carregamento engolido.', 'Exige login; erro com nova tentativa.', 'Corrigido'),
        ('B-B11', 'Baixa', 'O dono da loja pode alterar direto o contador público de produtos.', '— (exige mover o contador para o servidor)', 'Pendente'),
    ]),
    ('Prestador, empresa, Resolve e admin', [
        ('C1', 'Alta', 'Profissional escolhido no Resolve nunca via endereço/telefone do cliente.', 'Cartão com endereço, referência e telefone.', 'Corrigido'),
        ('C2', 'Alta', 'Pedido "Novo" travava após 15 min no app (servidor expira em 7 dias).', 'Aceitar/Recusar sempre disponíveis.', 'Parcial'),
        ('C3', 'Alta', 'Banners do admin nunca apareciam no app.', 'Aba "Em breve", criação desativada.', 'Corrigido'),
        ('C4', 'Alta', '"Faturamento" mostrava o volume de serviços (GMV).', 'Rótulo "Volume de serviços (GMV)".', 'Corrigido'),
        ('C5–C9', 'Média', 'Estornos sempre 0; usuários filtrados entre 50; prestador sem saber se foi pago; cadastro sem documentos.', 'Reembolsos reais; aviso do limite; selo de pagamento; documentos obrigatórios.', 'Corrigido'),
        ('C10–C17', 'Média', 'Leads/Assinatura falsos; contador da equipe; vírgula virando 0; cupom sem desativar; só 1º anexo; ações sem tratamento de erro.', 'Corrigidos.', 'Corrigido'),
        ('C6', 'Média', 'Painéis do admin leem coleções inteiras.', '—', 'Pendente'),
        ('C24', 'Baixa', 'Empresas não aprovadas (com e-mail/telefone) eram públicas.', 'Regras: só dono e admin até a aprovação.', 'Corrigido'),
        ('C18–C26', 'Baixa', 'Status em inglês, preço arredondado, nome fixo no chat, acessibilidade, alerta por contagem.', 'Corrigidos.', 'Corrigido'),
    ]),
    ('Saúde, Locação, chat e suporte', [
        ('D1', 'Alta', 'Chat dizia "Pague somente após o serviço", contrariando o pagamento protegido no app.', 'Texto alinhado ao modelo.', 'Corrigido'),
        ('D2', 'Alta', '"Como funciona" da Saúde prometia vídeo, avaliações e filtros inexistentes.', '4 passos reais.', 'Corrigido'),
        ('D3', 'Alta', 'Home Care sem endereço; consulta online sem orientação sobre o link.', 'Endereço obrigatório (servidor e app); orientação pela conversa.', 'Corrigido'),
        ('D4', 'Alta', 'Profissional de saúde não via quem marcou nem o motivo.', 'Nome, motivo, endereço e conversa.', 'Corrigido'),
        ('D5', 'Alta', 'Reservas de locação sem datas.', 'Início–fim no fuso de Belém.', 'Corrigido'),
        ('D6–D12', 'Média', 'Compartilhar falso; "Anunciante" fixo; editar reativava; excluir sem confirmação; hora fixa 08:00; visitante anunciando; erros escondidos.', 'Corrigidos.', 'Corrigido'),
        ('D13', 'Média', 'Localização falsificável e anexo com link livre no chat.', 'Formato exato; regras só aceitam o Storage do app na pasta da conversa.', 'Corrigido'),
        ('D14', 'Média', '"Apagar para todos" deixava a prévia com o texto.', 'Confirmação e prévia "Mensagem apagada".', 'Corrigido'),
        ('D15', 'Média', 'Anexos do chat acessíveis por link com token (LGPD).', '—', 'Pendente'),
        ('D16–D18', 'Média', 'Denúncia sem retorno; FAQ inexato; botão "📹 Online".', 'Corrigidos.', 'Corrigido'),
        ('D19–D30', 'Baixa', 'SAMU não discava; atalho "Agendar"; emojis; categoria "pickup"; exceções cruas; horário errado ao trocar; acessibilidade; respostas rápidas; editor de agenda.', 'Corrigidos.', 'Corrigido'),
    ]),
]

all_f = [f for _, g in FINDINGS for f in g]
counts = {s: sum(1 for f in all_f if f[4] == s) for s in ST}
sev = {s: sum(1 for f in all_f if f[1] == s) for s in SEV}
high_fixed = sum(1 for f in all_f if f[1] == 'Alta' and f[4] == 'Corrigido')


def on_page(c, d):
    c.saveState()
    c.setFont('DV', 7.5)
    c.setFillColor(MUTED)
    c.drawString(18 * mm, 10 * mm, 'Carajás 360 — Auditoria 3 (app completo) · homologação local · ' + RES['date'])
    c.drawRightString(A4[0] - 18 * mm, 10 * mm, f'Página {d.page}')
    c.setStrokeColor(LINE)
    c.line(18 * mm, 13 * mm, A4[0] - 18 * mm, 13 * mm)
    c.restoreState()


def on_cover(c, d):
    c.saveState()
    c.setFillColor(BRAND)
    c.rect(0, A4[1] - 9 * mm, A4[0], 9 * mm, stroke=0, fill=1)
    c.restoreState()


doc = BaseDocTemplate(OUT, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=20 * mm,
                      title='Carajás 360 — Auditoria 3 (app completo)', author='Equipe Carajás 360 (com Claude Code)',
                      subject='Inventário de telas, achados, correções e testes')
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id='f')
doc.addPageTemplates([PageTemplate(id='cover', frames=[frame], onPage=on_cover),
                      PageTemplate(id='body', frames=[frame], onPage=on_page)])
W = doc.width
story = []

# Capa
story += [Spacer(1, 40 * mm), P('Carajás 360', 'sub'), Spacer(1, 3 * mm),
          P('Auditoria completa do aplicativo', 'title'), Spacer(1, 4 * mm),
          P('O que existe em cada tela, o que era real ou fictício, o que foi corrigido e o que ainda falta', 'sub'),
          Spacer(1, 14 * mm)]
cover = [['Data', RES['date']],
         ['Ambiente', 'Homologação local (emuladores Firebase). Nada publicado; produção não tocada; sem pagamentos reais.'],
         ['Base auditada', f"branch {RES['branch']}, commit {RES['base']}"],
         ['Commit das correções', RES['commit']]]
t = Table([[P(f'<b>{a}</b>', 'cell'), P(b, 'cell')] for a, b in cover], colWidths=[38 * mm, W - 38 * mm])
t.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE),
                       ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5)]))
story += [t, Spacer(1, 12 * mm)]
kp = [[P(str(len(all_f)), 'kpi'), P(str(counts['Corrigido']), 'kpi'), P(f"{high_fixed}/{sev['Alta']}", 'kpi'), P(RES['tests_total'], 'kpi')],
      [P('grupos de achados', 'kpil'), P('corrigidos', 'kpil'), P('altos corrigidos', 'kpil'), P('testes automatizados aprovados', 'kpil')]]
k = Table(kp, colWidths=[W / 4] * 4)
k.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), SOFT), ('BOX', (0, 0), (-1, -1), 0.5, LINE),
                       ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.white), ('TOPPADDING', (0, 0), (-1, 0), 9), ('BOTTOMPADDING', (0, 1), (-1, 1), 9)]))
story += [k, NextPageTemplate('body'), PageBreak()]

# 1. Resumo
story += [P('1. Resumo', 'h1'),
          P('Esta auditoria percorreu <b>todas as telas do aplicativo</b> para responder a uma pergunta: o que o usuário vê é real? '
            'Cada tela foi classificada como <b>real</b> (funciona de ponta a ponta), <b>parcial</b>, <b>falsa</b> (mostra algo que não existe), '
            '<b>enganosa</b>, <b>quebrada</b> ou <b>em breve</b>.'),
          P(f"Foram {RES['raw_findings']} achados individuais, agrupados em {len(all_f)} linhas neste relatório "
            f"({sev['Alta']} altas, {sev['Média']} médias, {sev['Baixa']} baixas). "
            f"<b>{counts['Corrigido']} grupos foram corrigidos</b>, {counts['Parcial']} parcialmente e {counts['Pendente']} ficaram pendentes (exigem servidor novo ou decisão de produto)."),
          P('<b>Princípio aplicado:</b> nada fictício na frente do usuário. O que não existe foi removido ou marcado "Em breve"; nenhum dado inventado foi mantido.'),
          P('<b>Principais mudanças:</b>'),
          *bullets([
              'promessas falsas removidas: "300 serviços", "GPS ao vivo", planos com preço, leads, assinatura, cashback por indicação, videoconsulta, "pague só depois";',
              'fluxos quebrados consertados: o profissional do Resolve vê o contato do cliente, a loja vê os itens e o endereço, o Home Care exige endereço, as reservas mostram datas;',
              'privacidade: logout apaga o token de push, a exclusão de conta anonimiza o prestador e apaga arquivos, empresas não aprovadas deixam de ser públicas, anexos do chat só do app;',
              'modo escuro, busca do Início, notificações que abrem a tela certa e acessibilidade (rótulos e áreas de toque).',
          ]),
          P('<b>Testes:</b>'),
          *bullets([f'{a}: <b>{b}</b>' for a, b, _ in RES['tests']])]

# 2. Método
story += [P('2. Como foi feita', 'h2'),
          *bullets([
              'Cinco frentes em paralelo, sobre o código atual: início/entrada/perfil/carteira/IA; Mercado e pedidos; prestador/empresa/Resolve/admin; Saúde/Locação/chat/suporte; camada compartilhada (tema, componentes, push, serviços, regras).',
              'Cada tela foi aberta no código, do botão à função do servidor, e classificada. Cada achado traz arquivo e cenário concreto; hipóteses sem confirmação foram descartadas.',
              'As correções seguem o padrão do código existente, sem recriar o app. Funções e dados existentes foram preservados.',
              'Depois das correções, toda a regressão foi executada de novo (unitários, emulador, Flutter e E2E no navegador).',
          ])]

# 3. Inventário
story += [PageBreak(), P('3. Inventário das telas', 'h1'),
          P('Status <b>antes</b> e <b>depois</b> desta auditoria. Telas sem mudança relevante e já reais (login por e-mail, notificações, Pix, chamados, editor de agenda etc.) não estão listadas.', 'small'),
          Spacer(1, 2 * mm)]
for title, rows in INVENTORY:
    r = [[P('<b>Tela</b>', 'cellb'), P('<b>Antes</b>', 'cellb'), P('<b>Depois</b>', 'cellb'), P('<b>O que mudou</b>', 'cellb')]]
    for a, b, c, d in rows:
        r.append([P(a, 'cellb'), chip(b, INV[b]), chip(c, INV[c]), P(d, 'cell')])
    story += [P(title, 'h2'), table(r, [42 * mm, 19 * mm, 19 * mm, W - 80 * mm])]

# 4. Achados
story += [PageBreak(), P('4. Achados e correções', 'h1'),
          P('<b>Alta</b> = o usuário é enganado, fica preso ou o fluxo principal não funciona; <b>Média</b> = falha relevante de fluxo ou dado; <b>Baixa</b> = acabamento.', 'small'),
          Spacer(1, 2 * mm)]
for title, rows in FINDINGS:
    r = [[P('<b>ID</b>', 'cellb'), P('<b>Sev.</b>', 'cellb'), P('<b>Problema</b>', 'cellb'), P('<b>Correção</b>', 'cellb'), P('<b>Status</b>', 'cellb')]]
    for f in rows:
        r.append([P(f[0], 'cellb'), chip(f[1], SEV[f[1]]), P(f[2], 'cell'), P(f[3], 'cell'), chip(f[4], ST[f[4]])])
    story += [P(title, 'h2'), table(r, [15 * mm, 12 * mm, (W - 47 * mm) * 0.55, (W - 47 * mm) * 0.45, 20 * mm])]

# 5. Testes
tr = [[P('<b>Suíte</b>', 'cellb'), P('<b>Resultado</b>', 'cellb'), P('<b>Observação</b>', 'cellb')]]
for a, b, c in RES['tests']:
    tr.append([P(a, 'cell'), P(f'<b>{b}</b>', 'cell'), P(c, 'cell')])
story += [PageBreak(), P('5. Testes executados após as correções', 'h1'), table(tr, [58 * mm, 28 * mm, W - 86 * mm]), Spacer(1, 3 * mm),
          P('<b>Testes novos desta auditoria:</b>'),
          *bullets(RES['new_tests']),
          P('<b>Não testado</b> (exige recurso fora deste ambiente):'),
          *bullets([
              'push real em aparelho (Firebase Cloud Messaging não roda no emulador): o toque e o envio foram conferidos por leitura e por testes de rota;',
              'APK/iOS: sem Android SDK nem macOS aqui; o CI do GitHub gera os builds;',
              'modo escuro e leitores de tela foram conferidos no código e em testes de widget, não num aparelho real.',
          ])]

# 6. Pendências
story += [P('6. O que ainda falta', 'h1'),
          *bullets([
              '<b>Push:</b> um token por usuário (o último aparelho recebe); push na web exige service worker e chave VAPID.',
              '<b>Anexos do chat (LGPD):</b> o link com token dá acesso a quem o tiver; o ideal é servir por função com checagem de participante.',
              '<b>Admin:</b> painéis leem coleções inteiras; precisam de agregados no servidor (contadores e somas).',
              '<b>Desempenho:</b> cerca de 45 fluxos de dados criados dentro do <i>build</i> das telas.',
              '<b>Pedido do prestador:</b> falta campo de expiração no servidor para desabilitar o aceite no momento certo.',
              '<b>Mercado:</b> esconder produtos de loja desativada (o status da loja não vem no produto); o contador público de produtos da loja ainda pode ser alterado pelo dono.',
              '<b>Cashback:</b> a confirmação automática de 72 h não gera cashback (decisão de produto).',
              '<b>Configuração:</b> <font name="DVM">authDomain</font> ainda no domínio antigo; client id do Google Sign-In web ainda é modelo; iOS com um bundle id só.',
              '<b>Cliente que quer virar prestador:</b> hoje só no cadastro; falta entrada no Perfil.',
          ]),
          P('<b>Antes de divulgar:</b> estas pendências não impedem a homologação, mas o projeto Firebase de homologação e o Mercado Pago sandbox '
            'ainda não foram configurados com credenciais reais. Nenhuma configuração fictícia foi apresentada como concluída.'),
          Spacer(1, 4 * mm),
          P('<b>Arquivos alterados:</b> ' + RES['files'], 'small')]

doc.build(story)
print('ok', OUT)
