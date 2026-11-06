# Modernização Carajás 360 — Fase 1 (Auditoria) e Tela 01 (Página Inicial)

Branch: `feat/modernizacao-visual` (a partir de `fix/correcao-completa-final` @ `47aefed`).
Nada foi publicado em produção. Pagamentos reais continuam desligados.

## 1. Auditoria do repositório

### Funcionalidades existentes (preservadas)
- Autenticação (e-mail/celular), cadastro de cliente/prestador/entregador, envio de documentos do prestador.
- Navegação principal com 5 abas: Início, Explorar (busca universal), Pedidos, Mensagens, Perfil.
- Busca universal, busca por categoria/grupo (`SearchScreen`), hub de serviços, marketplace de serviços.
- Pedido de orçamento (Resolve), solicitação direta a profissional (`requestService`), meus pedidos.
- Chat 1:1 com sala canônica, caixa de entrada, notificações.
- Favoritos (stream + alternância), Carajás PRO, pacotes de créditos, suporte/FAQ, disputas.
- Módulos: Serviços, Saúde, Marketplace/lojas, Aluguel, GPS, Carteira, IA, Empresa, Admin.
- Backend: 21+ Cloud Functions (`transitionOrder`, `generatePix`, `mercadoPagoWebhook`…), regras Firestore/Storage.

### Com defeito ou comportamento enganoso
- Carteira gera código PIX fixo de exemplo quando não há gateway (`wallet_screen.dart`) — risco.
- Admin "Abrindo documento..." apenas exibe aviso (`admin_screen.dart`).
- Constantes de rota `serviceRequestFlow` e `opportunityDetail` sem tela (caem na navegação principal).
- Chat/avaliação/GPS usam id `'demo'` como fallback; "Leads" da empresa fixo em `'0'`.
- Web de homologação roda em modo demonstração (chaves Firebase web são placeholders); login real não funciona no link de homologação.
- Encontrados nesta fase e corrigidos na Tela 01: cadastro de prestador sem botão Voltar quando aberto pela Home; "Conversar" sem retorno para visitante; categoria Saúde ignorada pela busca.

### Ausentes (telas da referência sem equivalente completo)
- Detalhes do Serviço, Perfil público do profissional, Acompanhamento em linha do tempo,
  Solicitações Recebidas (só seção dentro do painel do prestador), Central de Ajuda completa.
- Parciais: Planos (Carajás PRO/créditos), Lista de Profissionais (`SearchScreen`), Explorar.
- "Em breve": Vagas, Fretes, Imóveis, Obras, Auto, Kids.

### Riscos técnicos
- Arquivos grandes: `firestore_facade.dart` (~2000 linhas), `admin_screen.dart` (~1800).
- Analyzer: 0 erros, 150 avisos/infos pré-existentes (nenhum nos arquivos da Tela 01).
- Tema global ainda azul (`AppColors`); telas internas mudam de identidade até a Fase 2/3.
- Sem mocks de Firebase para testes de widget de telas conectadas.

### Plano de correção
Fase 2 (design system verde/dourado global) → Fase 3 telas 02–10, uma por vez →
Fase 4 complementares → Fase 5 integração → Fase 6 segurança → Fase 7 homologação → Fase 8 candidata.

## 2. Tela 01 — Página Inicial

### Implementado
- Paleta oficial em `lib/core/theme/brand.dart` (#006B35, #003D24, #E7F5EB, #FFC400, #F7FAF8, #17251D, #66756C).
- Logotipo reutilizável `BrandWordmark`.
- Desktop: menu lateral verde-escuro (item ativo dourado) com as 5 abas + Favoritos,
  Planos e Assinaturas, Divulgue seu Serviço, Ajuda e Suporte. Mobile mantém a barra inferior (recolorida).
- Barra superior: busca, cidade selecionável (salva no perfil quando logado), notificações (contador real),
  mensagens, conta.
- Banner: "Buscar serviços agora" e "Solicitar serviço".
- 9 categorias ligadas a grupos/categorias reais + "Mais categorias".
- Profissionais em destaque e profissionais da cidade (dados do Firestore; catálogo de homologação só no modo demo),
  com selo de verificado apenas quando `verified = true`, avaliação real ("Novo" sem avaliações), favorito e conversa.
- Cartão "Cadastre seu serviço" (visitante → cadastro como prestador; logado → envio de documentos).
- Atalhos: pedir orçamento, pedidos, mensagens, favoritos.
- Faixa de confiança sem números fictícios e sem prometer garantia ou pagamento seguro.
- Módulos da região e serviços populares preservados. Removidos blocos "Em breve" sem ação.

### Testes
- `flutter analyze`: 0 erros; arquivos alterados sem avisos.
- `flutter test`: 134 aprovados, 1 ignorado (pré-existente).
- `flutter build web --release`: OK.
- Smoke de navegação real (Chrome headless, `scripts/web_nav_smoke.mjs`): relatório em
  `docs/evidence/tela01/report.json`, capturas em `docs/evidence/tela01/`.

### Pendências
- Perfil público do profissional (Tela 08) inexistente: cartões levam a "Solicitar serviço".
- Distância real (geolocalização) não existe no modelo; "perto de você" usa a cidade cadastrada.
- Contagem de não lidas de mensagens não exibida (sem consulta agregada disponível).
- Telas internas ainda no tema azul até a Fase 2.
- Seta de voltar do login/cadastro sem rótulo acessível.
