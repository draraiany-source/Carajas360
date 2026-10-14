# -*- coding: utf-8 -*-
"""Gera docs/auditoria/RELATORIO_AUDITORIA.pdf (Carajás 360)."""
import json
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (BaseDocTemplate, Frame, PageTemplate, Paragraph, Spacer, Table,
                                TableStyle, PageBreak, KeepTogether)

OUT = sys.argv[1]
RES = json.load(open(sys.argv[2], encoding='utf-8'))

F = '/usr/share/fonts/truetype/dejavu/'
pdfmetrics.registerFont(TTFont('DV', F + 'DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('DVB', F + 'DejaVuSans-Bold.ttf'))
pdfmetrics.registerFont(TTFont('DVM', F + 'DejaVuSansMono.ttf'))
from reportlab.pdfbase.pdfmetrics import registerFontFamily
registerFontFamily('DV', normal='DV', bold='DVB', italic='DV', boldItalic='DVB')

INK = colors.HexColor('#1A2233')
MUTED = colors.HexColor('#5B6475')
LINE = colors.HexColor('#D9DEE7')
BRAND = colors.HexColor('#0D3D91')
SOFT = colors.HexColor('#F2F5FA')
SEV = {
    'Crítica': colors.HexColor('#B42318'), 'Alta': colors.HexColor('#C4320A'),
    'Média': colors.HexColor('#B54708'), 'Baixa': colors.HexColor('#475467'),
}
ST = {'Corrigido': colors.HexColor('#067647'), 'Parcial': colors.HexColor('#B54708'), 'Pendente': colors.HexColor('#B42318')}

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


# ─────────────────────────── Achados ───────────────────────────
# (id, severidade, área, achado, correção, status)
FINDINGS = [
    # Regras de segurança (Firestore/Storage)
    ('R1', 'Crítica', 'Regras', 'Criar pedido de serviço era sempre negado: o app grava payoutStatus="none" e a regra proibia o campo.', 'Regra aceita payoutStatus "none"; teste com os campos reais do app.', 'Corrigido'),
    ('R2', 'Crítica', 'Regras', 'Criar loja, produto ou anúncio de locação era sempre negado (o app envia nota/avaliações zeradas) e a tela ficava carregando.', 'Regras aceitam contadores zerados; app remove campos do servidor e mostra erro.', 'Corrigido'),
    ('R3', 'Crítica', 'Regras', 'Favoritar sempre falhava: ler um favorito ainda inexistente era negado.', 'Leitura liberada só no id do próprio usuário.', 'Corrigido'),
    ('R4', 'Alta', 'Regras', 'Quem tinha qualquer empresa conseguia inserir produto (com preço próprio) na loja de outra pessoa.', 'Com loja informada, ela precisa ser do autor; empresa do produto imutável.', 'Corrigido'),
    ('R5', 'Alta', 'Regras/Servidor', 'Prestador aprovado em uma especialidade podia trocar o nome ou incluir outras (inclusive de Saúde) mantendo o selo e recebendo consultas.', 'Mudança de nome/especialidade volta para análise; agenda de Saúde só atende especialidade do perfil aprovado.', 'Corrigido'),
    ('R6', 'Alta', 'Regras/Servidor', 'Suspensão não tinha efeito e podia ser burlada apagando o próprio perfil (recriado como ativo).', 'Exclusão do perfil só pelo admin/servidor; suspensão desativa a conta no Auth e revoga sessões.', 'Corrigido'),
    ('R7', 'Alta', 'Regras/Servidor', 'Preço da proposta do Resolve podia mudar depois de o cliente ver (valor exibido ≠ valor contratado).', 'Preço só pela callable; aceite confere o valor visto (expectedPriceCents).', 'Corrigido'),
    ('R8', 'Média', 'Regras', 'Contrato de outra empresa podia ser sequestrado trocando o companyId.', 'Empresa do contrato imutável e precisa ser do autor.', 'Corrigido'),
    ('R9', 'Média', 'Regras', 'Filiais e funcionários podiam ser movidos para outra empresa.', 'companyId imutável na atualização.', 'Corrigido'),
    ('R10', 'Média', 'Regras', 'Admin de qualquer área (ex.: marketing) podia se promover a master e chegar ao financeiro.', 'Papéis só mudam por admin master/claim e nunca no próprio perfil.', 'Corrigido'),
    ('R11', 'Média', 'Regras/Servidor', 'Qualquer pessoa podia mandar push com texto livre para qualquer usuário (bastava criar uma sala de chat).', 'Sala de chat não é mais vínculo; aviso de chat passou a ser enviado pelo servidor.', 'Corrigido'),
    ('R12', 'Média', 'Regras/Servidor', 'Lista completa de cupons (inclusive 100%) era pública, até sem login.', 'Coleção fechada; validação pelo servidor (checkCoupon).', 'Corrigido'),
    ('R13', 'Média', 'Regras', 'Prestador podia marcar o pedido como "avaliado" e esconder o botão Avaliar do cliente.', 'Só o cliente, e só com a avaliação gravada.', 'Corrigido'),
    ('R14', 'Média', 'Regras/App', 'Fotos de anúncio novo de locação nunca subiam (a regra exigia o anúncio já existente).', 'Upload na pasta do dono (rentalPhotos/{uid}).', 'Corrigido'),
    ('R15', 'Média', 'Regras/Servidor', 'Cliente definia o preço do pedido de serviço (ex.: R$ 0,01), usado no pagamento e para "fabricar" avaliações.', 'Preço proibido na criação; vem do orçamento do prestador no aceite.', 'Corrigido'),
    ('R16', 'Baixa', 'Regras', 'Entregas legadas graváveis pelo cliente (entregador e posição falsos).', 'Coleção congelada até existir fluxo no servidor.', 'Corrigido'),
    ('R17', 'Baixa', 'Regras', 'Empresa podia nascer ativa (sem aprovação) e alguém podia ocupar o id da empresa de outra pessoa.', 'Criação inativa e com id do dono.', 'Corrigido'),
    ('R18', 'Baixa', 'Regras', 'Data das mensagens do chat podia ser forjada.', 'Horário obrigatório do servidor.', 'Corrigido'),
    ('R19', 'Baixa', 'Regras', 'Storage: SVG aceito em caminhos públicos; dono não conseguia apagar as próprias fotos/documentos; arquivos da outra parte podiam ser sobrescritos.', 'Só formatos raster; exclusão pelo dono; sem sobrescrita.', 'Corrigido'),
    ('R20', 'Baixa', 'Regras', 'Chamado de suporte criado já "resolvido" ou "urgente" pelo cliente.', 'Campos e valores fixos na criação.', 'Corrigido'),
    ('R21', 'Baixa', 'Regras', 'Log de auditoria podia ser assinado em nome de outro admin.', 'adminId precisa ser o autor.', 'Corrigido'),
    ('R22', 'Baixa', 'Regras', 'Nome exibido na avaliação é escolhido pelo cliente.', 'Não corrigido nesta rodada (usar perfil público no servidor).', 'Pendente'),
    # Servidor (Cloud Functions)
    ('B1', 'Alta', 'Servidor', 'Pedido de serviço pago podia ser cancelado (ou expirado pela limpeza automática) sem reembolso: o dinheiro ficava retido.', 'Cancelar pedido pago gera reembolso; cancelar com cobrança em andamento é recusado; limpeza só de não pagos.', 'Corrigido'),
    ('B2', 'Alta', 'Servidor', 'Cobrança dupla: pagamento legado pela carteira convivia com Pix/cartão ativo; aprovação tardia de serviço era silenciosa.', 'Endpoint legado desativado; aprovação tardia/duplicada gera reembolso automático e pendência financeira.', 'Corrigido'),
    ('B3', 'Alta', 'Servidor', 'Cancelar uma cobrança "incerta" deixava o Pix pagável no gateway; recarga paga duas vezes creditava uma.', 'Cancela também no gateway; segunda aprovação de recarga é devolvida.', 'Corrigido'),
    ('B4', 'Alta', 'Servidor', 'Token do Mercado Pago e chave da IA podiam ir para o log em erros de rede.', 'Erros tratados sem cabeçalhos; timeout; consulta legada ignora pagamentos novos.', 'Corrigido'),
    ('B5', 'Média', 'Servidor/App', 'Dinheiro liberado só pela palavra do prestador ou da loja (o rastreamento simulado terminava em "Confirmar chegada", que concluía e pagava em ~20 s).', 'Prestador marca como feito e o cliente confirma (automático em 72 h); loja recebe após o cliente confirmar ou 7 dias da entrega.', 'Corrigido'),
    ('B6', 'Média', 'Servidor', 'Qualquer usuário (até o próprio cliente) aceitava pedido sem prestador, com preço sem limite.', 'Só prestador aprovado, nunca o cliente; orçamento de R$ 1 a R$ 1.000.000.', 'Corrigido'),
    ('B7', 'Média', 'Servidor', 'Locação: confirmar reserva vencida permitia duas reservas sobrepostas; manutenção sem transação; aviso de cancelamento ia para a pessoa errada.', 'Confirmação só antes do início; manutenção em transação; aviso ao locatário.', 'Corrigido'),
    ('B8', 'Média', 'Servidor', 'Cache do catálogo nos gatilhos era só por tempo: prestadores eram indexados com o catálogo antigo logo após mudanças (achado durante os testes).', 'Cache invalidado pela versão do catálogo.', 'Corrigido'),
    ('B9', 'Média', 'Servidor/App', 'Exclusão de conta deixava o usuário logado sem perfil ou mantinha dados pessoais.', 'App exclui no Auth primeiro; servidor remove perfil, favoritos, notificações e carrinho.', 'Corrigido'),
    ('B10', 'Baixa', 'Servidor', 'Estados do gateway posteriores à aprovação (reembolso parcial, disputa) vistos primeiro não aplicavam o pagamento.', 'Tratados como captura; reembolso feito fora do app vira pendência.', 'Corrigido'),
    ('B11', 'Baixa', 'Servidor', 'Reembolso recusado pelo gateway deixava o pedido preso em "cancelamento solicitado".', 'Pedido volta ao status anterior e pendência é aberta.', 'Corrigido'),
    ('B12', 'Baixa', 'Servidor', 'Cancelar uma tentativa de pagamento com carteira acabava pagando.', 'Cancela direto.', 'Corrigido'),
    ('B13', 'Baixa', 'Servidor', 'Assistente IA aceitava histórico forjado e não tinha timeout.', 'Histórico alternado validado; timeout de 30 s.', 'Corrigido'),
    ('B14', 'Baixa', 'Servidor', 'Ids vindos do app sem validação (erro interno); motivo de cancelamento sem limite; 1000+ itens lidos antes do limite.', 'Validação de ids, limites de texto e de itens.', 'Corrigido'),
    ('B15', 'Baixa', 'Servidor', 'Agenda de Saúde e locação podem ser bloqueadas por pedidos sem pagamento.', 'Decisão de produto (limite por cliente/expiração).', 'Pendente'),
    # Aplicativo (Flutter)
    ('A1', 'Alta', 'App', 'Pedido de serviço nunca recebia preço, então o botão Pagar nunca aparecia.', 'Prestador informa o orçamento ao aceitar.', 'Corrigido'),
    ('A2', 'Alta', 'App', 'Tela de favoritos quebrava quando havia um produto favorito.', 'Filtro por tipo e tratamento de erro.', 'Corrigido'),
    ('A3', 'Alta', 'App', 'Cadastro por telefone não terminava (campo de e-mail obrigatório e bloqueado).', 'Campo editável quando a conta não tem e-mail.', 'Corrigido'),
    ('A4', 'Alta', 'App', 'Cadastro via Google/Apple/telefone ficava sempre como cliente e apagava a foto do Google.', 'Tipo aplicado pelo servidor; campos nulos não são gravados.', 'Corrigido'),
    ('A5', 'Média', 'App', 'Verificação automática do SMS (Android) logava mas a tela não avançava.', 'Callback dispara a continuação do login.', 'Corrigido'),
    ('A6', 'Média', 'App', 'Telas com dados fictícios em produção: rastreamento simulado, Entregas, Indicação (R$ 10 prometidos), respostas prontas da IA e contadores do perfil.', 'Estados honestos ("indisponível"/"em breve"); fictício só em dev.', 'Corrigido'),
    ('A7', 'Média', 'App', 'Chat: sala "demo", mensagem perdida em erro, anexos Word/Excel sempre recusados, leitura e escrita a cada redesenho, rótulo "Você" errado.', 'Corrigidos; consulta limitada; nome real do remetente.', 'Corrigido'),
    ('A8', 'Média', 'App', 'Avaliação, empresa, configuração do admin, solicitação de serviço e agenda de Saúde ficavam carregando para sempre em caso de erro.', 'Tratamento de erro com aviso e botão de tentar de novo.', 'Corrigido'),
    ('A9', 'Média', 'App', 'Ações do prestador (online, aceitar, iniciar, recusar) falhavam em silêncio.', 'Mensagem de erro; botão online desativado até a aprovação.', 'Corrigido'),
    ('A10', 'Baixa', 'App', 'Caixa de entrada podia esconder conversas recentes; Meus Resolve sem estado de erro; rotas com id vazio; barra inferior estourava em 320 px.', 'Ordenação no servidor, estados de erro, rotas seguras, barra flexível.', 'Corrigido'),
    ('A11', 'Baixa', 'App', 'Painel admin abria para quem só tinha adminRole; pendências sem erro; botão sem ação; contatos de suporte fixos no código.', 'Mesmo critério das regras; erros visíveis; contatos lidos da configuração.', 'Corrigido'),
    ('A12', 'Baixa', 'App', 'Chave web do Google (Directions) usada dentro do app.', 'Chamada removida.', 'Corrigido'),
    ('A13', 'Baixa', 'Android', 'Permissões sem uso (imagens, inicialização) e flavor dev sem acesso aos emuladores; dependência lottie sem uso.', 'Permissões removidas; rede dev só para 10.0.2.2/localhost; lottie removido.', 'Corrigido'),
    ('A14', 'Alta', 'iOS', 'Projeto iOS incompleto (sem Xcode project, entitlements de Apple/push, plist por ambiente, chave do Maps fixa).', 'Exige macOS/Xcode; roteiro no relatório.', 'Pendente'),
]

counts = {}
for f in FINDINGS:
    counts.setdefault(f[5], 0)
    counts[f[5]] += 1
sev_counts = {s: sum(1 for f in FINDINGS if f[1] == s) for s in ['Crítica', 'Alta', 'Média', 'Baixa']}
fixed_crit_high = sum(1 for f in FINDINGS if f[1] in ('Crítica', 'Alta') and f[5] == 'Corrigido')
total_crit_high = sev_counts['Crítica'] + sev_counts['Alta']


def on_page(c, doc):
    c.saveState()
    c.setFont('DV', 7.5)
    c.setFillColor(MUTED)
    c.drawString(18 * mm, 10 * mm, 'Carajás 360 — Relatório de auditoria completa · homologação local · ' + RES['date'])
    c.drawRightString(A4[0] - 18 * mm, 10 * mm, f'Página {doc.page}')
    c.setStrokeColor(LINE)
    c.line(18 * mm, 13 * mm, A4[0] - 18 * mm, 13 * mm)
    c.restoreState()


def on_cover(c, doc):
    c.saveState()
    c.setFillColor(BRAND)
    c.rect(0, A4[1] - 9 * mm, A4[0], 9 * mm, stroke=0, fill=1)
    c.restoreState()


doc = BaseDocTemplate(OUT, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm, topMargin=18 * mm, bottomMargin=20 * mm,
                      title='Carajás 360 — Relatório de auditoria completa', author='Equipe Carajás 360 (com Claude Code)',
                      subject='Auditoria de segurança, backend e aplicativo; correções e testes')
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id='f')
doc.addPageTemplates([PageTemplate(id='cover', frames=[frame], onPage=on_cover),
                      PageTemplate(id='body', frames=[frame], onPage=on_page)])
W = doc.width
story = []

# ─────────────── Capa ───────────────
story += [Spacer(1, 40 * mm), P('Carajás 360', 'sub'), Spacer(1, 3 * mm),
          P('Relatório de auditoria completa', 'title'), Spacer(1, 4 * mm),
          P('Segurança (regras), servidor (Cloud Functions), aplicativo (Flutter) e módulos legados — achados, correções e testes', 'sub'),
          Spacer(1, 14 * mm)]
cover_rows = [
    ['Data', RES['date']],
    ['Ambiente', 'Homologação local (emuladores Firebase). Nada publicado; produção não tocada; sem pagamentos reais.'],
    ['Base auditada', f"branch {RES['branch']}, a partir do commit {RES['base']} (fim da Fase 7)"],
    ['Commit das correções', RES['commit']],
]
t = Table([[P(f'<b>{a}</b>', 'cell'), P(b, 'cell')] for a, b in cover_rows], colWidths=[38 * mm, W - 38 * mm])
t.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE),
                       ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5)]))
story += [t, Spacer(1, 12 * mm)]
kp = [[P(str(len(FINDINGS)), 'kpi'), P(str(counts.get('Corrigido', 0)), 'kpi'), P(f'{fixed_crit_high}/{total_crit_high}', 'kpi'), P(RES['tests_total'], 'kpi')],
      [P('achados confirmados', 'kpil'), P('corrigidos e testados', 'kpil'), P('críticos e altos corrigidos', 'kpil'), P('testes automatizados aprovados', 'kpil')]]
k = Table(kp, colWidths=[W / 4] * 4)
k.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), SOFT), ('BOX', (0, 0), (-1, -1), 0.5, LINE),
                       ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.white), ('TOPPADDING', (0, 0), (-1, 0), 9), ('BOTTOMPADDING', (0, 1), (-1, 1), 9)]))
story += [k, PageBreak()]
from reportlab.platypus import NextPageTemplate
story.insert(len(story) - 1, NextPageTemplate('body'))

# ─────────────── 1. Resumo ───────────────
story += [P('1. Resumo executivo', 'h1'),
          P(f"A auditoria encontrou <b>{len(FINDINGS)} problemas confirmados no código</b>: {sev_counts['Crítica']} críticos, {sev_counts['Alta']} altos, {sev_counts['Média']} médios e {sev_counts['Baixa']} baixos. "
            f"<b>{counts.get('Corrigido', 0)} foram corrigidos</b> e cobertos por testes automatizados; {counts.get('Pendente', 0)} ficaram pendentes, por exigirem macOS ou uma decisão de produto."),
          P('Os mais graves eram de dois tipos:'),
          *bullets([
              '<b>Fluxos que nunca funcionavam</b> por conflito entre o app e as regras de segurança: criar pedido de serviço, criar loja, produto ou anúncio, favoritar e enviar fotos de anúncio. Um pedido de serviço nunca recebia preço, então o cliente não conseguia pagar.',
              '<b>Dinheiro e confiança</b>:'
              '<br/>– pedido pago cancelado sem reembolso;'
              '<br/>– possibilidade de pagar duas vezes;'
              '<br/>– liberação do repasse apenas pela palavra do prestador ou da loja (o rastreamento <i>simulado</i> terminava em um botão que concluía e pagava);'
              '<br/>– inserção de produtos na loja de terceiros;'
              '<br/>– prestador mantendo o selo de verificado ao trocar de especialidade (inclusive de Saúde);'
              '<br/>– possibilidade de vazamento do token do Mercado Pago e da chave da IA em logs.',
          ]),
          P('Todos esses pontos foram corrigidos. A correção mais visível para o usuário é a nova regra de conclusão:'),
          *bullets([
              'o <b>prestador marca como feito e o cliente confirma</b> (confirmação automática em 72 h);',
              'a <b>loja recebe após o cliente confirmar o recebimento</b> (liberação automática em 7 dias após a entrega).',
          ]),
          P('<b>Resultado dos testes após as correções:</b>'),
          *bullets([
              f"regras e funções no emulador: {RES['emu']};",
              f"unitários das funções: {RES['fn_unit']};",
              f"Flutter: {RES['flutter']} (análise com {RES['analyze']});",
              f"E2E no navegador: {RES['e2e_total']};",
              f"índices × consultas: {RES['indexes']}.",
          ]),
          ]

# ─────────────── 2. Metodologia ───────────────
story += [P('2. Como a auditoria foi feita', 'h2'),
          *bullets([
              'Quatro frentes independentes, todas sobre o código atual:'
              '<br/>– regras do Firestore e do Storage;'
              '<br/>– Cloud Functions (pagamentos, pedidos, Resolve, Saúde, Locação, catálogo);'
              '<br/>– fluxos do aplicativo;'
              '<br/>– módulos legados (admin, empresa, rastreamento, suporte, carteira, IA, Android/iOS/web, dependências).',
              'Cada achado foi conferido no código, com arquivo e linha, e só entrou no relatório com um cenário concreto de falha ou abuso. Hipóteses sem confirmação foram descartadas.',
              'Correções mínimas no padrão do código existente. Cada correção de regra ou servidor ganhou teste no emulador que reproduz o abuso (negado) e o fluxo legítimo (aceito).',
              'Ao final, toda a regressão das fases 1–7 foi executada de novo, com os mesmos E2E das fases anteriores.',
          ])]

# ─────────────── 3. Achados ───────────────
story += [PageBreak(), P('3. Achados e correções', 'h1'),
          P('Severidade: <b>Crítica</b> = funcionalidade central sempre quebrada; <b>Alta</b> = perda financeira, fraude ou exposição de dados; '
            '<b>Média</b> = abuso possível com esforço ou falha relevante de fluxo; <b>Baixa</b> = endurecimento ou acabamento.', 'small'),
          Spacer(1, 3 * mm)]
groups = [('Regras de segurança (Firestore e Storage)', 'R'), ('Servidor (Cloud Functions)', 'B'), ('Aplicativo e plataformas', 'A')]
for title, pref in groups:
    rows = [[P('<b>ID</b>', 'cellb'), P('<b>Sev.</b>', 'cellb'), P('<b>Problema encontrado</b>', 'cellb'), P('<b>Correção</b>', 'cellb'), P('<b>Status</b>', 'cellb')]]
    for f in [x for x in FINDINGS if x[0].startswith(pref)]:
        rows.append([P(f[0], 'cellb'), chip(f[1], SEV[f[1]]), P(f[3], 'cell'), P(f[4], 'cell'), chip(f[5], ST[f[5]])])
    tb = Table(rows, colWidths=[10 * mm, 14 * mm, (W - 44 * mm) * 0.55, (W - 44 * mm) * 0.45, 20 * mm], repeatRows=1)
    tb.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BACKGROUND', (0, 0), (-1, 0), SOFT),
        ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 3), ('RIGHTPADDING', (0, 0), (-1, -1), 3),
    ]))
    story += [P(title, 'h2'), tb]

# ─────────────── 4. Mudanças de comportamento ───────────────
story += [PageBreak(), P('4. O que muda para quem usa o app', 'h1'),
          *bullets([
              '<b>Pedido de serviço:</b>'
              '<br/>– o cliente não informa mais o preço; o prestador envia o orçamento ao aceitar e o cliente paga esse valor;'
              '<br/>– para concluir, o prestador toca em "Marcar como concluído" e o cliente em "Confirmar conclusão"; sem resposta em 72 h, a conclusão é confirmada automaticamente e o repasse é liberado;'
              '<br/>– cancelar um pedido já pago gera o reembolso; com cobrança em andamento, é preciso cancelar a cobrança antes.',
              '<b>Mercado:</b> a loja marca "entregue" e o repasse sai quando o cliente toca em "Confirmar recebimento", ou automaticamente 7 dias depois.',
              '<b>Resolve:</b> se a proposta mudar de valor depois que o cliente viu, o aceite é recusado e a tela pede para conferir o novo valor.',
              '<b>Prestador:</b>'
              '<br/>– mudar o nome ou incluir uma especialidade nova coloca o perfil em nova análise (o selo volta após a aprovação);'
              '<br/>– o botão "online" só funciona depois da aprovação.',
              '<b>Cupons:</b> validados pelo servidor; a lista de códigos não é mais pública.',
              '<b>Suspensão pelo admin:</b> bloqueia o login de fato; reativar desfaz.',
              '<b>Chat:</b> o aviso de nova mensagem é enviado pelo servidor; não é mais possível enviar avisos para pessoas sem pedido ou proposta em comum.',
              '<b>Excluir conta:</b> pede login recente e apaga os dados pessoais no servidor. Pedidos e registros financeiros são mantidos por obrigação legal.',
              '<b>Telas sem serviço real</b> mostram "indisponível" ou "em breve", em vez de dados inventados: rastreamento em tempo real, Entregas, Indicação e respostas prontas da IA.',
          ])]

# ─────────────── 5. Testes ───────────────
trows = [[P('<b>Suíte</b>', 'cellb'), P('<b>Resultado</b>', 'cellb'), P('<b>Observação</b>', 'cellb')]]
for a, b, c in RES['tests']:
    trows.append([P(a, 'cell'), P(f'<b>{b}</b>', 'cell'), P(c, 'cell')])
tt = Table(trows, colWidths=[62 * mm, 30 * mm, W - 92 * mm], repeatRows=1)
tt.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BACKGROUND', (0, 0), (-1, 0), SOFT),
                        ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE), ('TOPPADDING', (0, 0), (-1, -1), 4), ('BOTTOMPADDING', (0, 0), (-1, -1), 4)]))
story += [P('5. Testes executados após as correções', 'h1'), tt, Spacer(1, 3 * mm),
          P('<b>Testes novos desta auditoria:</b>'),
          *bullets([
              '<font name="DVM">firebase-tests/rules/audit.rules.test.js</font>: 13 testes de regras;',
              '4 testes de Storage;',
              '<font name="DVM">firebase-tests/functions/audit.test.js</font>: 12 testes de integração no servidor;',
              '<font name="DVM">test/audit_fixes_test.dart</font>: testes do app.',
          ]),
          P('<b>Testes antigos ajustados</b> (codificavam o comportamento defeituoso):'),
          *bullets([
              'prestador alterando o preço da proposta direto no banco;',
              'repasse do Mercado na marcação "entregue";',
              'agenda de Saúde com especialidade fora do perfil aprovado.',
          ]),
          P('<b>Problemas encontrados pelos próprios testes durante a auditoria:</b>'),
          *bullets([
              'cache do catálogo nos gatilhos (B8);',
              'referência interna de pagamentos removida antes do uso (corrigida antes da entrega).',
          ]),
          ]

# ─────────────── 6. Pendências ───────────────
story += [P('6. Pendências e recomendações', 'h1'),
          *bullets([
              '<b>iOS (A14):</b> regenerar o projeto (<font name="DVM">flutter create --platforms=ios .</font>), adicionar os entitlements de Sign in with Apple e de push, entregar o token APNs ao Firebase, criar um plist por ambiente e ler a chave do Maps por configuração. Exige macOS com Xcode.',
              '<b>APK/AAB:</b> não gerados. Este ambiente não tem o Android SDK e a rede bloqueia o download (dl.google.com). O comando está no relatório da Fase 7.',
              '<b>Dependências:</b> os 9 alertas do npm audit (2 altos) são transitivos do firebase-admin 12. A correção exige firebase-admin 14 com firebase-functions 5 ou superior, uma migração própria (functions v1 → v2).',
              '<b>Homologação real:</b> o projeto Firebase de homologação não está configurado (chaves ainda são modelo). O Mercado Pago sandbox ainda não foi validado com credenciais de teste reais.',
              '<b>Decisões de produto:</b>'
              '<br/>– limite de reservas e consultas sem pagamento por cliente (B15);'
              '<br/>– limite de uso de cupom por cliente e total;'
              '<br/>– "Meus chamados" com respostas no suporte;'
              '<br/>– aplicar o "modo manutenção";'
              '<br/>– ação "recusar" na aprovação de prestadores;'
              '<br/>– nome do avaliador vindo do perfil público (R22).',
              '<b>Ajustes menores:</b>'
              '<br/>– a solicitação de serviço gera dois avisos ao prestador (mensagem e nova solicitação);'
              '<br/>– o file_picker usa versão beta;'
              '<br/>– o client id do Google Sign-In web ainda é modelo;'
              '<br/>– os e-mails de suporte (agora configuráveis no admin) ainda usam o domínio antigo.',
          ])]

# ─────────────── 7. Como aplicar ───────────────
story += [P('7. Como aplicar em homologação', 'h1'),
          P('<b>Primeiro, só no projeto de homologação:</b>'),
          *bullets([
              'publicar regras, índices e funções: <font name="DVM">firebase deploy --project hml --only firestore:rules,firestore:indexes,storage,functions</font>;',
              'aguardar os novos índices ficarem "Enabled". São 7 nesta auditoria: avaliações, histórico por status, suporte, denúncias, mensagens lidas, confirmação automática e liberação do Mercado.',
          ]),
          P('<b>Atenção a quatro mudanças de comportamento:</b>'),
          *bullets([
              'prestadores já aprovados que mudarem nome ou especialidade entram em nova análise;',
              'cupons deixam de ser lidos pelo app;',
              'o pagamento legado pela carteira (payOrderWithWallet) foi desativado;',
              'pedidos do Mercado entregues passam a aguardar a confirmação do cliente.',
          ]),
          P('<b>Depois, publicar o app e testar:</b>'),
          *bullets([
              'publicar o app web de homologação e, numa máquina com SDK, gerar o APK hml (comando no relatório da Fase 7);',
              'repetir em homologação os fluxos dos E2E e os cenários da seção 4, com contas de teste.',
          ]),
          Spacer(1, 4 * mm),
          P('<b>Arquivos alterados:</b> ' + RES['files'], 'small')]

doc.build(story)
print('ok', OUT)
