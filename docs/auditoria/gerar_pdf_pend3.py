# -*- coding: utf-8 -*-
"""Gera o relatório das pendências da Auditoria 3 (Carajás 360).

Uso: python3 gerar_pdf_pend3.py SAIDA.pdf resultados.json
"""
import json
import os
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
                                TableStyle, PageBreak, NextPageTemplate, Image)

OUT = sys.argv[1]
RES = json.load(open(sys.argv[2], encoding='utf-8'))
HERE = os.path.dirname(os.path.abspath(__file__))
EVID = os.path.join(HERE, '..', 'homologacao', 'evidencias', 'pend3')

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
# Classificação pedida: implementado e testado / aguardando teste externo /
# decisão de produto / bloqueado por credencial ou infraestrutura.
CL = {
    'Testado': colors.HexColor('#067647'),
    'Aguarda teste externo': colors.HexColor('#B54708'),
    'Decisão de produto': colors.HexColor('#6941C6'),
    'Bloqueado': colors.HexColor('#B42318'),
}

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
    'cap': ParagraphStyle('cap', fontName='DV', fontSize=7.5, leading=9.5, textColor=MUTED, alignment=TA_CENTER),
}
P = lambda t, s='p': Paragraph(t, ss[s])


def bullets(items):
    return [Paragraph(t, ss['li'], bulletText='•') for t in items]


def chip(text):
    return Paragraph(f'<font color="{CL[text].hexval()}"><b>{text}</b></font>', ss['cell'])


def table(rows, widths):
    t = Table(rows, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'TOP'), ('BACKGROUND', (0, 0), (-1, 0), SOFT),
        ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE), ('TOPPADDING', (0, 0), (-1, -1), 3.5), ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
        ('LEFTPADDING', (0, 0), (-1, -1), 3), ('RIGHTPADDING', (0, 0), (-1, -1), 3),
    ]))
    return t


# (item, o que foi feito, como foi verificado, classificação)
ITEMS = [
    ('1. Anexos do chat', [
        ('Acesso autenticado', 'Mensagem guarda o caminho no Storage (mediaPath), sem link com token. Visualização e download pedem a URL à callable getChatMediaUrl, que confere no servidor se quem pede está na conversa agora e devolve URL assinada de 10 min.', 'Emulador: participante baixa; outro usuário, visitante e usuário removido da conversa são negados (callable e Storage direto). E2E: a tela chama a callable e nenhuma requisição leva token=.', 'Testado'),
        ('Upload', 'Upload só para a pasta da conversa, com o uid do remetente no nome; o token criado pelo Storage é removido no envio. Regras recusam mediaPath de outra conversa e mediaUrl novo.', 'Regras do Firestore e do Storage no emulador.', 'Testado'),
        ('Anexos antigos', 'Migração admin (Configurações › Migrações): converte para mediaPath e revoga o token antigo; links externos são descartados e registrados; idempotente. O app nunca abre o link antigo.', 'Emulador: o link antigo abria antes e não abre depois; 2ª execução não altera nada.', 'Testado'),
        ('Apagar para todos', 'Apaga o arquivo no servidor (o cliente não pode apagar).', 'Emulador.', 'Testado'),
        ('URL assinada e revogação em bucket real', 'getSignedUrl exige a permissão signBlob da conta de serviço; no emulador a revogação usa caminho alternativo.', 'Não testável sem o projeto hml.', 'Aguarda teste externo'),
        ('Bug encontrado nos testes de navegador', 'A busca da URL nunca concluía (o futuro aguardava a si mesmo): imagem, documento e áudio ficavam carregando para sempre. Corrigido.', 'E2E pend3 falhava antes e passa depois.', 'Testado'),
    ]),
    ('2. Mercado', [
        ('Lojas desativadas ou não aprovadas', 'Campo storeActive mantido só pelo servidor (gatilhos de loja e produto). Vitrine, busca, categorias, perfil da loja e lista de lojas mostram só lojas ativas e aprovadas; acesso direto e carrinho marcam "Indisponível" e bloqueiam a finalização.', 'Emulador e E2E (vitrine sem a loja desativada e sem a não aprovada; carrinho bloqueado ao desativar a loja).', 'Testado'),
        ('Validação no servidor', 'Cotação e createMarketOrder recusam loja desativada ou não aprovada dentro da transação, sem reservar estoque.', 'Emulador.', 'Testado'),
        ('Contador de produtos', 'totalProducts recontado no servidor com count() (idempotente, sem contagem dupla em reexecução); o lojista não altera o contador nem storeActive.', 'Emulador, inclusive gatilho executado duas vezes.', 'Testado'),
        ('Dados existentes e aprovação', 'Reconciliação (simular/aplicar) e nova fila "Lojas" para o admin aprovar — sem ela, lojas novas nunca poderiam vender.', 'Emulador e E2E (simulação no painel).', 'Testado'),
    ]),
    ('3. Expiração dos pedidos', [
        ('expiresAt no servidor', 'Gravado na criação (7 dias, a regra vigente), sem o cliente poder forjar; pedidos antigos sem o campo usam a mesma fórmula e uma migração preenche.', 'Emulador (regras e gatilho).', 'Testado'),
        ('Bloqueio no backend e concorrência', 'Aceite e recusa pelo prestador recusados após o prazo; expiração em transação que relê o status. Pedido pago não é cancelado: vai ao suporte.', 'Emulador: corrida aceite × expiração termina em um estado coerente; tarefa idempotente.', 'Testado'),
        ('Mesma referência no app', 'Card mostra "Expira em…"; vencido mostra "Expirado" e desabilita as ações.', 'E2E (pedido válido e vencido).', 'Testado'),
        ('Pedido pago que expira', 'Hoje vai para o suporte; cancelar e reembolsar automaticamente é possível com o reembolso que já existe.', '—', 'Decisão de produto'),
    ]),
    ('4. Desempenho e paginação', [
        ('Painéis administrativos', 'KPIs e relatório financeiro vêm de agregações no servidor (count/sum), com perfil conferido; listas do admin paginadas por cursor com "Carregar mais".', 'Emulador: agregados batem com os dados semeados; perfis negados.', 'Testado'),
        ('Filtro de usuários', 'Filtro por tipo na consulta, com índice; acabou o limite dos 50 mais recentes.', 'Emulador com 130 usuários (páginas 50/50/4) e E2E com 61 (página 2 via "Carregar mais").', 'Testado'),
        ('Fluxos criados no build', 'Streams e futures criados uma vez (initState/campo/Memo) e cancelados no dispose: 57 pontos em 23 telas, além do admin.', 'Teste de widget prova uma única assinatura em rebuilds; suíte Flutter completa.', 'Testado'),
        ('Índices em homologação', 'O emulador não exige índices compostos; precisam estar "Enabled" no projeto hml.', 'Checador estático: 47 consultas, 0 sem índice.', 'Aguarda teste externo'),
    ]),
    ('5. Notificações', [
        ('Token por aparelho', 'users/{uid}/devices/{deviceId}; renovação atualiza só este aparelho; logout remove só este aparelho; exclusão de conta apaga todos; token legado migrado.', 'Emulador (regras e envio simulado).', 'Testado'),
        ('Envio e tokens inválidos', 'Multicast aos 20 aparelhos mais recentes; remove só tokens inválidos, com proteção contra corrida.', 'Emulador com transporte simulado.', 'Testado'),
        ('Push web', 'Service worker com SDK fixo; config do Firebase gerada por ambiente (nunca valores de exemplo); chave VAPID por ambiente; sem chave, desligado sem erro.', 'Script de geração testado; hoje sai desligado (credenciais hml ausentes).', 'Bloqueado'),
        ('Entrega real (aberto, segundo plano, encerrado)', 'Rota do toque unificada nos três estados e na web.', 'Lógica testada em Flutter; entrega real exige aparelho e credenciais.', 'Aguarda teste externo'),
    ]),
    ('6. Perfil e cashback', [
        ('Quero ser prestador', 'Item no Perfil que reaproveita cadastro, documentos e aprovação existentes; estados não iniciado, incompleto, em análise, recusado (pedir nova análise) e aprovado. Sem autoaprovação.', 'Regras no emulador (cliente não grava aprovação) e E2E (fluxo abre).', 'Testado'),
        ('Cashback na confirmação automática (72 h)', 'Não há regra aprovada para serviço: comportamento atual mantido (sem crédito) e decisão registrada com as opções. Créditos existentes são únicos e estornados no reembolso.', 'Emulador: crédito único em chamadas concorrentes; estorno parcial e total.', 'Decisão de produto'),
    ]),
    ('7. Homologação externa', [
        ('Separação de ambientes e iOS', 'Flavor iOS hml com bundle id br.com.servicoconecta.hml; CI falha se o build hml usar o id de produção.', 'GitHub Actions (macOS) no commit 588463c: build iOS hml aprovado.', 'Testado'),
        ('Login Google web e authDomain', 'Login web pelo popup do Firebase (sem client id fixo); authDomain configurável por ambiente.', 'Build web hml local.', 'Aguarda teste externo'),
        ('Firebase hml e Mercado Pago sandbox', 'Código e checador prontos; faltam projeto, chaves e credenciais de teste.', 'tool/check_hml_config.js lista o que falta.', 'Bloqueado'),
    ]),
]

all_rows = [r for _, g in ITEMS for r in g]
cnt = {k: sum(1 for r in all_rows if r[3] == k) for k in CL}


def on_page(c, d):
    c.saveState()
    c.setFont('DV', 7.5)
    c.setFillColor(MUTED)
    c.drawString(18 * mm, 10 * mm, 'Carajás 360 — Pendências da Auditoria 3 · ' + RES['date'])
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
                      title='Carajás 360 — Pendências da Auditoria 3', author='Equipe Carajás 360 (com Claude Code)',
                      subject='Correções, testes, builds e o que falta para publicar')
frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id='f')
doc.addPageTemplates([PageTemplate(id='cover', frames=[frame], onPage=on_cover),
                      PageTemplate(id='body', frames=[frame], onPage=on_page)])
W = doc.width
story = []

story += [Spacer(1, 40 * mm), P('Carajás 360', 'sub'), Spacer(1, 3 * mm),
          P('Pendências da Auditoria 3', 'title'), Spacer(1, 4 * mm),
          P('Correções executadas, evidências, testes e o que ainda falta para publicar', 'sub'), Spacer(1, 14 * mm)]
cover = [['Data', RES['date']],
         ['Ambiente', 'Emuladores Firebase e GitHub Actions. Nada publicado; produção não tocada; sem pagamentos reais; nenhuma credencial inventada.'],
         ['Branch', RES['branch']],
         ['Commits', RES['commits']]]
t = Table([[P(f'<b>{a}</b>', 'cell'), P(b, 'cell')] for a, b in cover], colWidths=[38 * mm, W - 38 * mm])
t.setStyle(TableStyle([('VALIGN', (0, 0), (-1, -1), 'TOP'), ('LINEBELOW', (0, 0), (-1, -1), 0.4, LINE),
                       ('TOPPADDING', (0, 0), (-1, -1), 5), ('BOTTOMPADDING', (0, 0), (-1, -1), 5)]))
story += [t, Spacer(1, 12 * mm)]
kp = [[P(str(cnt['Testado']), 'kpi'), P(str(cnt['Aguarda teste externo']), 'kpi'), P(str(cnt['Decisão de produto']), 'kpi'), P(str(cnt['Bloqueado']), 'kpi')],
      [P('implementados e testados', 'kpil'), P('aguardando teste externo', 'kpil'), P('decisões de produto', 'kpil'), P('bloqueados (credencial/infra)', 'kpil')]]
k = Table(kp, colWidths=[W / 4] * 4)
k.setStyle(TableStyle([('BACKGROUND', (0, 0), (-1, -1), SOFT), ('BOX', (0, 0), (-1, -1), 0.5, LINE),
                       ('INNERGRID', (0, 0), (-1, -1), 0.5, colors.white), ('TOPPADDING', (0, 0), (-1, 0), 9), ('BOTTOMPADDING', (0, 0), (-1, 1), 9)]))
story += [k, Spacer(1, 10 * mm),
          P('<b>Não está pronto para lançamento.</b> Os testes rodaram em emulador e no CI; nada foi validado no projeto de homologação real nem em aparelho. Funcionalidades ainda indisponíveis seguem marcadas "Em breve".', 'p'),
          NextPageTemplate('body'), PageBreak()]

story += [P('1. Resumo', 'h1'),
          P('As sete frentes pedidas foram executadas no projeto existente, sem recriar o app nem acrescentar módulos. Os dados existentes são preservados: cada mudança de formato tem migração idempotente, acionável em Admin › Configurações › Migrações de dados.'),
          P('<b>Testes após as correções:</b>'),
          *bullets([f'{a}: <b>{b}</b>' for a, b, _ in RES['tests']]),
          P('<b>Classificação usada:</b> <font color="#067647"><b>Testado</b></font> = implementado e testado; '
            '<font color="#B54708"><b>Aguarda teste externo</b></font> = implementado, depende de projeto real, aparelho ou credencial para testar; '
            '<font color="#6941C6"><b>Decisão de produto</b></font>; <font color="#B42318"><b>Bloqueado</b></font> = falta credencial ou infraestrutura.', 'small')]

story += [PageBreak(), P('2. O que foi feito, item a item', 'h1')]
for title, rows in ITEMS:
    r = [[P('<b>Item</b>', 'cellb'), P('<b>O que foi feito</b>', 'cellb'), P('<b>Verificação</b>', 'cellb'), P('<b>Situação</b>', 'cellb')]]
    for a, b, c, d in rows:
        r.append([P(a, 'cellb'), P(b, 'cell'), P(c, 'cell'), chip(d)])
    story += [P(title, 'h2'), table(r, [30 * mm, (W - 58 * mm) * 0.58, (W - 58 * mm) * 0.42, 28 * mm])]

# Evidências (E2E no app real)
# Telas de celular em grade de 3; telas largas (admin) em largura cheia.
phones = [('1_mercado_vitrine.png', 'Vitrine só com lojas vendáveis'),
          ('3_carrinho_loja_desativada.png', 'Carrinho: loja desativada bloqueia'),
          ('7_prestador_expirado_e_valido.png', 'Pedido válido × expirado'),
          ('4_perfil_quero_ser_prestador.png', 'Perfil: "Quero ser prestador"')]
wide = [('9_admin_usuarios_pagina2.png', 'Admin › Usuários filtrados por tipo: página 2 após "Carregar mais"'),
        ('11_admin_simular_resultado.png', 'Admin › Configurações › Migrações de dados: simulação do Mercado')]
ev = [PageBreak(), P('3. Evidências no navegador (app real contra os emuladores)', 'h1'),
      P('Capturas da suíte E2E <font name="DVM">pend3</font> (26/26). Todas em <font name="DVM">docs/homologacao/evidencias/pend3/</font>. '
        'O cenário "Quero ser prestador" foi verificado até a escolha de especialidades; no E2E o catálogo não estava semeado, por isso a tela seguinte mostra "Catálogo não configurado".', 'small'),
      Spacer(1, 2 * mm)]
cells = [[Image(os.path.join(EVID, f), width=40 * mm, height=40 * mm * 2.25, kind='proportional'), P(c, 'cap')]
         for f, c in phones if os.path.exists(os.path.join(EVID, f))]
if cells:
    g = Table([[c[0] for c in cells], [c[1] for c in cells]], colWidths=[W / len(cells)] * len(cells))
    g.setStyle(TableStyle([('ALIGN', (0, 0), (-1, -1), 'CENTER'), ('VALIGN', (0, 0), (-1, -1), 'TOP')]))
    ev.append(g)
for f, c in wide:
    pth = os.path.join(EVID, f)
    if os.path.exists(pth):
        ev += [Spacer(1, 4 * mm), Image(pth, width=W, height=W * 0.7, kind='proportional'), P(c, 'cap')]
story += ev

tr = [[P('<b>Suíte</b>', 'cellb'), P('<b>Resultado</b>', 'cellb'), P('<b>Observação</b>', 'cellb')]]
for a, b, c in RES['tests']:
    tr.append([P(a, 'cell'), P(f'<b>{b}</b>', 'cell'), P(c, 'cell')])
story += [PageBreak(), P('4. Testes e builds', 'h1'), table(tr, [58 * mm, 28 * mm, W - 86 * mm]), Spacer(1, 3 * mm),
          P('<b>Builds:</b>'),
          *bullets(RES['builds']),
          P('<b>Não testado:</b>'),
          *bullets([
              'push real em aparelho e navegador (aberto, segundo plano, encerrado);',
              'URL assinada e revogação de token em bucket real; abertura visual de anexos (no emulador a URL não é assinada e a imagem responde 403, comportamento esperado e documentado);',
              'login Google/Apple reais, Pix e cartão no sandbox do Mercado Pago;',
              'execução das migrações num banco real;',
              'telas em aparelho físico.',
          ])]

story += [P('5. O que falta para publicar', 'h1'),
          P('<b>Decisões de produto:</b>'),
          *bullets([
              'cashback na confirmação automática de serviço (72 h) — e se o crédito via walletOp deve ser limitado à confirmação pelo cliente;',
              'cashback proporcional no Mercado quando houve reembolso parcial antes da liberação;',
              'pedido pago que expira: suporte (atual) ou cancelamento com reembolso automático;',
              'aprovar prestador também troca o tipo da conta para "prestador"?;',
              'bloqueio de loja pelo admin: hoje é retirar a aprovação (o dono controla "ativa");',
              'projeto de produção: servicoconecta ou carajas360-a17c5 (define authDomain e ids).',
          ]),
          P('<b>Credenciais e infraestrutura (você):</b>'),
          *bullets([
              'projeto Firebase de homologação (opções, google-services, plist, chave VAPID, APNs, domínios autorizados);',
              'Mercado Pago sandbox (usuário de teste, token no Secret Manager, webhook);',
              'conta Apple para distribuir o iOS;',
              '<b>GitHub Actions:</b> desde o commit 67e02ac os jobs falham em 3 segundos sem receber máquina (nenhum passo executado), também ao reexecutar. É um bloqueio da conta (provavelmente cota de minutos ou cobrança); confira em Settings › Billing › Actions. O mesmo pipeline passou no commit 588463c.',
          ]),
          P('<b>Depois de configurar homologação:</b> implantar regras, índices e funções (só hml), aguardar os índices, rodar as três migrações em Admin › Configurações (Mercado primeiro com "Simular"), aprovar as lojas existentes na fila "Lojas" e repetir os fluxos com contas de teste e aparelhos reais.'),
          P('<b>Link de homologação:</b> não existe — o Hosting hml depende do projeto acima.'),
          Spacer(1, 4 * mm),
          P('Detalhes de configuração: <font name="DVM">docs/homologacao/HOMOLOGACAO_EXTERNA.md</font>; decisões: <font name="DVM">docs/homologacao/REGISTRO_PENDENCIAS.md</font>.', 'small')]

doc.build(story)
print('ok', OUT)
