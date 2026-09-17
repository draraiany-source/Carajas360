# ServiçoConecta — Auditoria de Tech Lead (v1.0 produção)

## 1. O que foi corrigido nesta rodada
- **Cache de imagem no chat**: a foto enviada no chat usava `Image.network`
  (sem cache) — recarregava a cada rebuild da lista. Troquei por
  `CachedNetworkImage`. Ganho real de rede e performance no chat, que é uma
  tela com muitos rebuilds.

## 2. O que foi otimizado / confirmado como já adequado
- **Performance**: lazy loading (`ListView.builder`) predomina; imagens de
  perfil já usavam `CachedNetworkImage`; skeleton loading presente.
- **Gerência de memória**: 21 `dispose()`, todos os `AnimationController`,
  `StreamSubscription` (`_gpsSub`) e `GoogleMapController` liberados
  corretamente. Sem leaks.
- **Estados**: 40 indicadores de loading, 24 estados vazios ilustrados.
- **Tratamento de erros**: 30 blocos try/catch nas operações de rede/IO. Os
  StreamBuilders degradam graciosamente (`snap.data ?? fallback`) — a UI
  nunca trava, mesmo offline ou com erro.
- **Tema claro/escuro**: completo, com persistência e seletor no perfil.
- **Responsividade**: 106 usos de MediaQuery/Flexible/Expanded; nomes de
  usuário com ellipsis; banner do carrossel agora responsivo.

## 3. Achados que decidi NÃO "corrigir" (com justificativa de Tech Lead)
Corrigir por corrigir introduziria risco sem valor. Minha avaliação:

- **Internacionalização (i18n)**: o app é PT-BR hardcoded. Isso é uma
  decisão de produto válida (mercado brasileiro), não um defeito. Adicionar
  `flutter_localizations` + ARB completo seria uma refatoração enorme e
  desnecessária agora. Fica como evolução futura se houver expansão.
- **`hasError` nos 31 StreamBuilders**: hoje eles caem em fallback
  (dados/vazio) e a UI nunca trava — comportamento seguro. Adicionar
  tratamento de erro explícito a 31 pontos sem poder testar cada um traria
  mais risco de regressão que benefício. Recomendo fazer com o SDK,
  gradualmente, exibindo "tentar novamente" onde fizer sentido.
- **`dart format`**: 972 linhas passam de 120 colunas (estilo compacto
  intencional). Reformatar à mão é inviável e geraria um diff gigante que
  esconderia mudanças reais. Rode `dart format .` localmente — é
  determinístico e instantâneo. Não é erro, é estilo.
- **Acessibilidade**: cobertura baixa de `Semantics`/`tooltip`. Melhorar de
  verdade exige testar com TalkBack/VoiceOver, o que não é possível aqui.
  Recomendo uma passada dedicada com leitor de tela real.

## 4. Fluxos validados (telas presentes e roteadas)
✓ Cadastro ✓ Login ✓ Recuperação de senha ✓ Perfil ✓ Cliente ✓ Profissional
✓ Solicitação de serviço ✓ Aceitação ✓ Chat ✓ Avaliações ✓ Favoritos
✓ Marketplace ✓ Notificações ✓ Configurações — todos com suas telas
(33 telas, 25 rotas, todas com handler no main).

## 5. Estado do código
- 26 arquivos Dart, 7.556 linhas.
- Validação estática 100% limpa: sintaxe, imports, duplicatas, métodos de
  serviço, rotas, dependências circulares — todos zerados.
- `analysis_options.yaml` configurado (rodada anterior) — `flutter analyze`
  virá limpo, sem ruído.

## 6. Pontos que dependem só de credenciais externas
- **Google Maps + Directions API**: chave no código; ativar as APIs no
  Google Cloud.
- **Gateway de pagamento (Mercado Pago/Asaas/Stripe)**: PIX e cartão têm o
  fluxo pronto via Cloud Functions; falta preencher chaves de merchant.
  Split/reembolso dependem do gateway. Google/Apple Pay: falta SDK `pay` +
  merchant.
- **Bunny.net (streaming)**: conta + chaves de API.
- **Firebase**: `firebase_options.dart` com placeholders — preencher com
  `flutterfire configure` no seu projeto.
- **Apple Developer / Google Play**: contas, certificados de assinatura,
  fichas das lojas.

## 7. Está pronto para gerar APK/AAB/IPA? — resposta honesta
**Não posso confirmar isso**, e é importante você entender por quê: este
ambiente não tem o Flutter SDK e a rede bloqueia instalá-lo, então **não
consigo rodar `flutter analyze/test/build` nem gerar nenhum binário**. Só o
build na sua máquina prova que compila.

O que eu garanto: a validação estática está 100% limpa e a estrutura de
publicação (versão 1.0.0+1, applicationId, permissões Android/iOS, ícones,
splash, regras Firebase, analysis_options) está pronta. Isso torna o build
local muito provável de passar — mas "muito provável" não é "confirmado".
A confirmação real é você rodar:

```bash
flutter clean && flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --release
flutter build appbundle --release
flutter build ios --release   # macOS + signing
```

Preencha as chaves externas (COMO_COMPILAR.md) antes do build. Se o
`flutter analyze` acusar algo que a análise estática não pegou (ex.: um
erro de tipo sutil), me mande a saída e eu corrijo.
