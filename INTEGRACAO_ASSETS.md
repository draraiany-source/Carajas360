# Integração dos Assets Oficiais — ServiçoConecta

Todos os assets oficiais do pacote `servico_conecta_assets.zip` foram extraídos e
integrados ao projeto Flutter (v7 → mantida a arquitetura, sem recriação).

## O que foi feito

### 1. Assets copiados
Os 727 arquivos de assets (SVG + PNG @1x/@2x/@3x + Lottie) foram copiados para
`assets/`, organizados exatamente como no pacote oficial. Documentação do pacote
(README, manual de marca, manifesto CSV) foi removida do bundle por não ser asset
de runtime.

### 2. Dependências adicionadas ao pubspec
- `flutter_svg: ^2.0.10+1` — renderização dos ícones/ilustrações vetoriais
- `lottie: ^3.1.2` — animações

### 3. pubspec.yaml — 19 diretórios de assets registrados
Todos os diretórios (logos, icons, splash, banners, categories, categories/outline,
avatars, lottie, markers, marketplace, wallet, chat, gps, empty_states, onboarding,
illustrations, images) declarados. As densidades @2x/@3x são resolvidas
automaticamente pelo Flutter a partir do arquivo base.

### 4. Arquivo central de assets
Criado `lib/core/constants/app_assets.dart` centralizando todos os caminhos —
evita strings mágicas e faz o mapeamento entre os IDs de categoria do código e os
slugs dos arquivos oficiais, com **fallback seguro para emoji** quando não há asset
correspondente (ex.: categorias como `esteticista`, `dj`, `personal_trainer` que
não têm ícone oficial continuam usando emoji, sem quebrar).

### 5. Substituições de placeholders por assets oficiais
- **Logo**: emoji 🔗 → `logo_mark` / `wordmark` oficiais na splash, login, header
  da home e diálogo "sobre".
- **Ícone do app**: PNGs oficiais copiados para as 5 densidades mipmap do Android,
  os 18 tamanhos do `AppIcon.appiconset` do iOS (por correspondência de dimensão),
  e favicon + ícones PWA da Web.
- **Splash nativa**: logo branco centralizado sobre o gradiente da marca (Android
  `launch_background.xml`).
- **Onboarding**: 5 ilustrações oficiais nas 5 telas.
- **Banners da Home**: carrossel horizontal com os banners promocionais oficiais
  (substituiu o card estático "30% OFF").
- **Ícones de categoria**: `CatChip` agora usa o SVG oficial da categoria quando
  disponível (com fallback para emoji).
- **Estados vazios**: ilustrações oficiais em busca sem resultado, carrinho vazio,
  chat sem mensagens, pedidos, favoritos, extrato da carteira, agendamentos.
- **Lottie**: animação de pagamento aprovado na confirmação do PIX.

### 6. Referências quebradas
Nenhuma. O projeto v7 não usava `Image.asset`/`SvgPicture` (categorias eram emoji,
logo era texto), então não havia caminhos antigos a corrigir. Os placeholders
`.gitkeep` e o `app_icon.png` placeholder foram removidos.

## Verificações estáticas executadas (todas passaram)
- Todos os 112 caminhos gerados por `AppAssets` existem no disco.
- Todos os assets referenciados estão cobertos por um diretório declarado no pubspec.
- Nenhum diretório declarado no pubspec está vazio.
- Sintaxe balanceada em todos os 23 arquivos Dart.
- Todos os arquivos que usam `SvgPicture`/`Lottie`/`AppAssets` têm os imports corretos.
- Nenhuma referência `AppAssets.xxx` inexistente.

## O que NÃO pôde ser feito neste ambiente
- **Itens 8 e 9** (compilar e testar carregamento das imagens em Android/iOS/Web):
  exigem o Flutter SDK, que não está disponível aqui e cuja instalação a rede
  bloqueia. A validação foi feita por conferência estática (todo caminho existe e
  está declarado). Rode localmente para confirmação visual:

  ```bash
  flutter pub get
  flutter analyze
  flutter run            # ou flutter build apk/appbundle/web --release
  ```

  Como todos os caminhos foram verificados contra o disco e o pubspec, não deve
  haver erro de asset no build.
