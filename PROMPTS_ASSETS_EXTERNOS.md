# Prompts para geração de assets externos — ServiçoConecta

Estes assets não podem ser gerados como código (exigem ferramentas de
animação, modelagem 3D ou síntese de áudio). Abaixo, prompts detalhados
para mantê-los consistentes com a identidade visual do ServiçoConecta.

## Identidade visual (use em todos os prompts)
- **Cores**: azul primário `#0D47A1`, azul claro `#1976D2`, verde `#2E7D32`,
  dourado premium `#F9A825`. Fundo claro `#F5F7FA`.
- **Estilo**: flat design moderno, cantos arredondados, traços limpos,
  visual amigável e profissional (referências: apps do porte de iFood,
  Uber, Mercado Pago). Sem realismo excessivo, sem gradientes pesados.

---

## 1. Animações Lottie (50+)

Gere em LottieFiles (lottiefiles.com), Rive (rive.app) ou After Effects +
Bodymovin. Exporte como `.json` e coloque em `assets/animations/`.
Já declaramos a pasta no pubspec e temos o pacote `lottie` integrado, então
basta chamar `Lottie.asset('assets/animations/NOME.json')`.

Para cada animação, prompt base:
> "Flat design Lottie animation, ServiçoConecta brand colors (deep blue
> #0D47A1, green #2E7D32, gold accents #F9A825), smooth easing, looping
> where appropriate, transparent background, minimal and modern, 512x512."

Lista completa (nome do arquivo → descrição da animação):
- `splash.json` — logo do app montando-se com um brilho suave
- `onboarding_1.json` a `onboarding_5.json` — ícones animados de cada tela
- `login.json` — cadeado abrindo / avatar acenando
- `register.json` — formulário sendo preenchido com check verde
- `forgot_password.json` — envelope voando com chave
- `loading.json` — spinner circular na cor da marca (loop)
- `skeleton.json` — linhas de shimmer (loop)
- `search.json` — lupa varrendo (loop)
- `location.json` — pino de GPS pulsando (loop)
- `gps_tracking.json` — carro/moto percorrendo uma rota
- `map.json` — mapa com pino saltando
- `professional_found.json` — perfil com check verde e confete
- `client_found.json` — aperto de mãos
- `chat.json` — balões de conversa aparecendo (loop)
- `message_sent.json` — avião de papel voando
- `message_received.json` — balão entrando com "pop"
- `notification.json` — sino balançando
- `favorite.json` — coração enchendo
- `appointment.json` — calendário com check
- `service_started.json` — engrenagens girando
- `service_completed.json` — check grande com confete
- `review.json` — 5 estrelas preenchendo em sequência
- `stars.json` — estrelas cintilando (loop)
- `wallet.json` — carteira abrindo com moedas
- `pix.json` — ícone PIX com ondas de confirmação
- `card_approved.json` — cartão com check verde
- `payment_declined.json` — cartão com X vermelho balançando
- `cashback.json` — moedas caindo na carteira
- `coupon.json` — cupom sendo destacado
- `profile_updated.json` — avatar com check
- `upload_complete.json` — barra de progresso completando com check
- `document_sent.json` — documento voando para nuvem
- `error.json` — X vermelho com balanço
- `no_internet.json` — nuvem desconectada com wifi cortado
- `no_results.json` — lupa vazia com "?" 
- `empty_list.json` — caixa aberta vazia
- `premium.json` — coroa dourada brilhando (loop)
- `subscription.json` — cartão premium com estrelas
- `achievement.json` — troféu surgindo com brilho
- `medal.json` — medalha girando
- `ranking.json` — pódio subindo
- `invite.json` — envelope com "+1"
- `referral.json` — dois avatares conectados por presente
- `settings.json` — engrenagem girando (loop)
- `help.json` — balão com "?" 
- `support.json` — headset com ondas
- `update.json` — seta circular de refresh (loop)
- `security.json` — escudo fechando com check
- `logout.json` — porta abrindo com seta saindo

---

## 2. Mascote (30+ poses)

Personagem: um **elo/link estilizado antropomórfico** ou uma **ferramenta
amigável** (chave de boca sorridente), na cor azul da marca com detalhes
verdes. Nome sugerido: "Conecta".

Prompt base (Midjourney / DALL·E / Figma):
> "Friendly mascot character for a services marketplace app called
> ServiçoConecta, flat vector style, deep blue #0D47A1 body with green
> #2E7D32 accents, rounded friendly shapes, big expressive eyes, simple
> and modern, white background, full body, [POSE]."

Versões: **3D** (Blender/Spline render PNG transparente), **flat** (SVG/PNG),
**SVG** (vetor editável). Coloque em `assets/mascot/`.

Poses (substitua [POSE]):
feliz acenando; procurando com lupa; trabalhando com ferramentas;
entregando um pacote; comemorando com braços erguidos; pensando (mão no
queixo); confuso/erro; joia de sucesso; segurando cartão/pagamento;
com pino de GPS; conversando (balão de chat); dando boas-vindas
(onboarding); com coroa premium; com headset de suporte; segurando
estrelas de avaliação; dormindo (estado ocioso); carregando (correndo);
com escudo de segurança; com carteira; com cupom; com troféu; apontando
para cima; polegar para cima; segurando celular; com chave (login);
acenando adeus (logout); com presente (indicação); com megafone
(novidades); meditando (vazio/zen); com lista/prancheta.

---

## 3. Sons (8 efeitos)

Gere em ferramentas como Freesound, Sonniss, ou geradores (jsfxr, ChipTone).
Exporte `.mp3` (ou `.wav`) curtos (<1s, exceto conquista) em `assets/sounds/`.
Integração no Flutter via `audioplayers` (já no projeto):
`AudioPlayer().play(AssetSource('sounds/NOME.mp3'))`.

- `message.mp3` — "pop" curto e suave (mensagem recebida)
- `success.mp3` — acorde ascendente positivo (~0.6s)
- `error.mp3` — tom descendente curto e discreto
- `button.mp3` — clique tátil sutil (~0.1s)
- `payment.mp3` — "ca-ching" de caixa registradora suave
- `notification.mp3` — sino curto de duas notas
- `achievement.mp3` — fanfarra curta de conquista (~1.2s)
- `alert.mp3` — dois beeps de atenção

---

## Observação
Todos os SVGs (ícones, ilustrações, backgrounds) e as microinterações
em Flutter **já estão prontos e integrados** — não precisam de ferramenta
externa. Este documento cobre apenas o que exige geração fora do código.
