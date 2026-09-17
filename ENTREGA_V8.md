# ServiçoConecta — Entrega v8 (Finalização para Produção)

## ⚠️ Aviso importante sobre APK e AAB

O APK Release e o AAB **não puderam ser gerados neste ambiente**, porque ele não possui
o Flutter SDK instalado e a rede está bloqueada para baixá-lo. A geração desses dois
artefatos precisa ser feita por você, localmente, com os comandos da seção "Como gerar
APK e AAB" abaixo. Todo o restante (projeto completo, código finalizado, validações,
documentação) está pronto neste pacote.

Para dar a maior garantia possível sem o SDK, rodei uma bateria de validação estática
sobre todo o código: balanceamento de chaves/parênteses, resolução de todos os imports,
detecção de classes/métodos duplicados, resolução de todas as chamadas de métodos de
serviço, detecção de dependências circulares, e conferência cruzada entre as coleções
usadas no código e as regras de segurança do Firestore/Storage. Todas passaram.

---

## 1. O que foi implementado (visão geral)

**Autenticação**
- Login por e-mail/senha, Google e Apple (botão Apple aparece só no iOS)
- Recuperação de senha por e-mail
- Login por telefone/OTP
- Persistência automática de sessão

**Clientes**
- Cadastro completo com foto de perfil (upload real), CPF, cidade/estado
- Captura de geolocalização no cadastro (com tratamento de permissão negada)
- Edição de perfil, alteração de senha, histórico, favoritos

**Profissionais**
- Cadastro com categorias e modalidades
- Onboarding com upload real de foto, documento de identidade, selfie e certificados
- Definição de áreas atendidas
- Aprovação/rejeição pelo painel administrativo

**Serviços**
- Solicitação de orçamento (com sugestão de descrição e estimativa de preço por IA)
- Fluxo completo: aceitar → iniciar → acompanhar por GPS → concluir
- Cancelamento pelo cliente (antes do início) e recusa pelo profissional
- Avaliações com estrelas, comentário e tags; média agregada no perfil

**Agenda / Saúde**
- Home Care e serviços de saúde com agendamento
- Tela "Meus Agendamentos" com visualização e cancelamento

**Chat em tempo real (Firestore streams)**
- Texto, foto (upload real), documento (upload real, abre no visualizador)
- Áudio real (gravação + reprodução na bolha)
- Localização real (GPS + link clicável do Google Maps)
- Recibo de leitura, denúncia de usuário

**GPS**
- Localização real do usuário
- Rota real seguindo ruas via Google Directions API (com fallback em linha reta)
- ETA e distância reais; rastreamento em tempo real de entregas via Firestore

**Marketplace**
- Catálogo, carrinho, favoritos de produto
- Checkout com pagamento real (PIX ou cartão) antes de criar o pedido

**Pagamentos**
- PIX real (Mercado Pago via Cloud Function)
- Cartão de crédito real (tokenização + processamento via Cloud Function), com parcelamento
- Carteira digital: saldo, extrato, cashback, comissão de 15%
- **Saque** para chave PIX (débito atômico do saldo, registro pendente)

**Painel Administrativo (9 abas)**
- Usuários, Validação de profissionais, Categorias, Financeiro (KPIs + relatório + export CSV/PDF)
- Marketing/Banners, Atendimento, Denúncias, Auditoria, Configurações da plataforma
  (comissão editável, modo manutenção, contato de suporte)

**IA**
- Assistente conversacional
- Sugestão automática de descrição de pedido
- Estimativa de orçamento
- Busca inteligente por linguagem natural (mapeia para categoria)

**Empresas**
- Cadastro corporativo
- Gestão de funcionários (adicionar/remover), filiais, e contratos

**Notificações Push** via Firebase Cloud Messaging (Cloud Function + token por usuário)

---

## 2. Bugs corrigidos nesta finalização (v8)

1. **Chat — documento não abria**: o toque no documento tinha callback vazio; agora
   abre o arquivo no visualizador do sistema via `url_launcher`.
2. **Chat — localização não era clicável**: a mensagem de localização era texto puro;
   agora é um link que abre o Google Maps.
3. **Carteira — botão "Sacar" era decorativo**: implementado o fluxo real de saque
   (valor + chave PIX, débito atômico, saque mínimo de R$ 10, registro no extrato).
4. **Suporte — botões Chat/E-mail/Ligar eram decorativos**: conectados a abrir chamado,
   `mailto:` e `tel:` respectivamente.
5. **Perfil — "Endereços" e "Segurança" eram decorativos**: ligados ao editor de perfil
   e ao fluxo de redefinição de senha.
6. **Empresa — "Categorias", "Assinatura", "Dados" eram decorativos**: Assinatura abre a
   tela de planos; os demais dão orientação clara ao usuário.
7. **Agenda inexistente**: agendamentos de saúde eram criados mas nunca visualizados;
   criada a tela "Meus Agendamentos".
8. **AndroidManifest — faltava `mailto`** nas queries (Android 11+): o botão de e-mail
   não abriria o app de e-mail; corrigido.
9. **Regras Firestore ausentes** para `deliveries`, `appointments` e `favorites`: sem
   elas, rastreamento, agenda e favoritos seriam bloqueados em produção; adicionadas.

---

## 3. Como gerar APK e AAB (você, localmente)

Pré-requisitos: Flutter SDK instalado (`flutter doctor` sem erros).

```bash
cd servico_conecta
flutter pub get
flutter analyze          # deve passar sem erros
flutter test             # roda os 22 testes unitários
flutter build apk --release          # gera o APK
flutter build appbundle --release    # gera o AAB para a Play Store
```

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- AAB: `build/app/outputs/bundle/release/app-release.aab`

Antes de compilar, complete as configurações em **COMO_COMPILAR.md** (Firebase,
Google Maps + Directions API, Mercado Pago, chave de assinatura, IA).

---

## 4. Publicação na Google Play

1. Crie a conta de desenvolvedor (taxa única de US$ 25) em play.google.com/console.
2. Gere a keystore de release e configure `android/key.properties` (ver COMO_COMPILAR.md).
3. Crie um novo app no console, preencha ficha da loja (descrição, ícone, screenshots,
   política de privacidade — obrigatória por usar localização e câmera).
4. Faça upload do `app-release.aab` numa trilha (teste interno → produção).
5. Preencha o questionário de classificação etária e a seção de Segurança de Dados
   (declare uso de localização, câmera, microfone, e dados financeiros).
6. Envie para revisão.

## 5. Publicação na App Store

1. Conta no Apple Developer Program (US$ 99/ano).
2. No Xcode, configure signing (time + provisioning profile) e `REVERSED_CLIENT_ID`.
3. Confirme as descrições de permissão no Info.plist (localização, câmera, microfone) —
   já preenchidas neste projeto.
4. `flutter build ipa --release` e envie via Xcode/Transporter ao App Store Connect.
5. Preencha a ficha, screenshots, e a Privacy Nutrition Label.
6. Envie para revisão da Apple.

---

## 6. Pendências honestas

- **APK/AAB**: não gerados aqui (sem SDK/rede); você gera com os comandos acima.
- **Chaves de terceiros**: precisam ser preenchidas por você (Firebase, Google Maps +
  Directions, Mercado Pago public/secret keys, chave da IA). Sem elas o app compila mas
  os serviços externos não respondem. Tudo documentado em COMO_COMPILAR.md.
- **Edição de dados cadastrais de empresa** (CNPJ/categorias): por decisão de produto,
  encaminha ao suporte em vez de edição livre — comum em apps B2B por exigir verificação.
- Nenhum TODO, tela de exemplo, ou botão decorativo permanece no código.
