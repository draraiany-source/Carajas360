# Carajás 360 — Fase 7: testes completos e builds de homologação

> **Status:** testes completos executados em **homologação local (emuladores)**. Build **web hml** gerado e entregue.
> **APK/AAB e iOS não foram gerados:** o ambiente não tem Android SDK, e o download foi bloqueado pela rede (`dl.google.com` → 403). iOS exige macOS. **Nenhum APK é declarado aqui.**
> Nada foi publicado e produção não foi tocada. Sem pagamentos reais.

## 1. Regressão completa (código final das fases 1–7)

| Suíte | Comando | Resultado |
|---|---|---|
| Functions, unitários | `cd functions && npm test` | **65/65** |
| Regras + functions no emulador (todas as fases) | `firebase emulators:exec … node --test rules/*.test.js functions/*.test.js` | **102/102** |
| Flutter | `flutter test` | **97 passaram, 1 pulado** |
| Análise estática | `flutter analyze lib test test_driver` | **0 erros** (só avisos de APIs depreciadas já existentes) |
| Índices × consultas (novo) | `cd functions && npm run check:indexes` | **39 consultas compostas, 0 sem índice** |
| E2E Catálogo e busca (F2) | `tool/run_e2e.sh … catalog` | **16/16** |
| E2E Checkout e pagamentos (F3) | `… checkout` | **17/17** |
| E2E Resolve (F4) | `… resolve` | **13/13** |
| E2E Saúde e Locação (F5) | `… schedule` | **11/11** |
| E2E Chat, notificações e responsividade (F6) | `… phase6` | **16/16** |

**Total E2E: 73/73.**

Na primeira rodada, checkout e resolve falharam porque **eu** recompilei os harnesses sem `--dart-define=PAYMENTS_FAKE_TOKENS=true` (o formulário de cartão abriu no modo real e o E2E não preencheu os campos). Não era regressão do app. Recompilados com a flag, passaram (17/17 e 13/13). Para não repetir o erro, criei **`tool/run_e2e.sh`**, que compila cada harness com as flags corretas e roda os cinco E2E em emuladores limpos.

## 2. Problemas encontrados e corrigidos nesta fase

| Problema | Impacto | Correção |
|---|---|---|
| **5 índices compostos faltando**: avaliações do perfil do prestador (F6), histórico do cliente filtrado por status, atendimento admin por status, denúncias por status, marcar mensagens como lidas (`!=`) | O emulador não exige índice composto, então os testes passavam. Em homologação/produção essas telas dariam erro `failed-precondition` | Índices adicionados em `firestore.indexes.json`; verificador automático `tool/check_indexes.js` |
| Tela de carregamento do `web/index.html` ainda dizia "ServiçoConecta" | Marca antiga na primeira tela da web | Trocado para "Carajás 360" |

### O verificador de índices (`tool/check_indexes.js`)
- Lê as consultas do app (Dart) e das functions (JS), inclusive as feitas por referências guardadas em variáveis (`REQ.where…`, `C.orders.where…`).
- Cobre também as combinações dos montadores em passos: busca de prestadores (12 combinações), pedidos do prestador e do cliente com status, painéis admin.
- Confere cada consulta contra `firestore.indexes.json`: campos, ordem e `array-contains`.
- Falha com exit 1 quando falta índice. Os builders declarados no script precisam ser atualizados quando o código desses montadores mudar (está comentado no arquivo).

## 3. Verificações de segurança e configuração

**Segredos no Git:** nenhum. A varredura (tokens Mercado Pago `APP_USR-`/`TEST-`, chaves privadas, AWS, GitHub) só encontrou tokens **fictícios** dentro dos testes de redação de logs (`financeCore.test.js`).

**Variáveis das functions:** todas as lidas no código estão documentadas em `functions/.env.example`. Os segredos ficam marcados para o Secret Manager.

**Dependências** (`npm audit --omit=dev` em `functions/`): 9 alertas (7 moderados, 2 altos):
- todos são transitivos de **`firebase-admin` 12** (`node-forge`, `uuid`, `google-gax`, `teeny-request` e outros);
- a correção exige `firebase-admin` 14, que **é major** e pede também `firebase-functions` ≥ 5;
- **não atualizei nesta fase**: é uma migração de API (functions v1 → v2) que mudaria código já testado.
- Recomendação: tratar como tarefa própria antes de produção.

**Build hml sem configuração real:**
- `lib/firebase_options_hml.dart` e `android/app/src/hml/google-services.json` ainda são **modelos** (`COLE_SUA_…`), porque não existe projeto `carajas360-hml` configurado.
- Abri o build web hml no navegador. O app **não inicia**, mostra "Serviço temporariamente indisponível… Nenhuma operação foi realizada" e não fez nenhuma chamada ao Firebase (evidência: `evidencias/hml_sem_config.png`).
- É a proteção da Fase 1 funcionando: sem chaves reais, o build não cai por engano em dev ou em produção.

## 4. Builds

| Build | Situação | Arquivo |
|---|---|---|
| **Web hml** (`flutter build web --release --no-web-resources-cdn --dart-define=APP_ENV=hml`) | **Gerado** | `dist/carajas360-web-hml-fase7.zip` (fora do Git; enviado na conversa). SHA-256 no fim deste relatório |
| Android hml (APK/AAB) | **Não gerado** | Falta o Android SDK, e o download foi bloqueado pela política de rede do ambiente (`dl.google.com`) |
| iOS hml | **Não gerado** | Exige macOS com Xcode |

O build web é autocontido (CanvasKit incluído, sem CDN). **Ele só funciona depois que as chaves reais de homologação forem colocadas e o app for recompilado** (ver roteiro abaixo). Como está, prova que o código compila em modo release e que a proteção de ambiente bloqueia o uso.

**Configuração Android conferida (estática):**
- flavors `dev`/`hml`/`prod`: hml usa `br.com.servicoconecta.hml` e o nome "Carajás 360 HML";
- `google-services.json` separado por flavor;
- assinatura release lida de `key.properties` ou de variáveis de ambiente, nunca do Git.

Para gerar o APK numa máquina com Android SDK:
```
flutter build apk --flavor hml --release --dart-define-from-file=config/env/hml.json
```

## 5. Roteiro para colocar a homologação no ar (não executado — requer suas contas)

1. **Firebase:** criar o projeto `carajas360-hml`, ou ajustar `.firebaserc` se o id for outro.
   - Rodar `flutterfire configure --project=<id> --out=lib/firebase_options_hml.dart --android-package-name=br.com.servicoconecta.hml --ios-bundle-id=br.com.servicoconecta.hml`.
   - Colocar o `google-services.json` em `android/app/src/hml/`.
2. **Config do app:** copiar `config/env/hml.example.json` para `config/env/hml.json` (fora do Git) com a chave do Maps e a **public key de teste** do Mercado Pago.
3. **Functions:**
   - criar `functions/.env.<id-hml>` a partir de `.env.example`, com `PAYMENTS_GATEWAY=mercadopago`, `PAYMENTS_ENV=sandbox` e `PROD_PROJECT_IDS=servicoconecta`;
   - segredos no Secret Manager: `MERCADOPAGO_ACCESS_TOKEN` (**usuário de teste**), `MP_WEBHOOK_SECRET`, `ANTHROPIC_API_KEY`.
4. **Deploy só no hml:**
   ```
   firebase deploy --project hml --only firestore:rules,firestore:indexes,storage,functions
   ```
   Aguardar os índices ficarem "Enabled" no console.
5. **Migrações** (como admin, primeiro com `{dryRun: true}`): `migratePhase1Privacy`, `migrateCatalogV1`, `migratePublicProfiles`.
6. **Webhook:** cadastrar a URL de `paymentsWebhook` do hml no painel de testes do Mercado Pago.
7. **Builds:**
   - web: `flutter build web --release --dart-define-from-file=config/env/hml.json`, depois `firebase deploy --project hml --only hosting` (se usar Hosting);
   - Android: comando da seção 4.
8. **Roteiro manual:** repetir em hml, com cartões e Pix de teste do Mercado Pago, os fluxos cobertos pelos E2E:
   - busca;
   - checkout com cartão aprovado, recusado e Pix;
   - Resolve completo;
   - consulta e reserva;
   - chat e notificações;
   - reembolso no painel financeiro.

## 6. Pendências consolidadas (todas as fases)
- **Mercado Pago sandbox** não validado com credenciais reais: todos os testes usaram o gateway falso do emulador (Fase 3).
- **APK/AAB e iOS** não gerados (seção 4).
- **Projeto Firebase hml** não existe ou não está configurado: chaves ainda são modelo.
- **`firebase-admin` 12 → 14 e `firebase-functions` 4 → 5+:** alertas de segurança transitivos (seção 3).
- **E-mails de suporte** `@servicoconecta.com.br` mantidos: falta definir o domínio e as caixas do Carajás 360 (Fase 6).
- Consultas e locações **não são cobradas pelo app** (Fase 5). Ganhos do prestador no painel são **estimativa**: o oficial é o extrato da carteira (Fase 6).
- **App Check** ainda não obrigatório (`ENFORCE_APP_CHECK=false`) até ser configurado no projeto hml.

## 7. Arquivos desta fase
- **Novos:**
  - `tool/check_indexes.js` (verificador índices × consultas; script `npm run check:indexes` em `functions/`)
  - `tool/run_e2e.sh` (build + execução dos 5 E2E)
  - `docs/fase7/RELATORIO_FASE7.md`, `docs/fase7/evidencias/hml_sem_config.png`
- **Alterados:**
  - `firestore.indexes.json` (+5 índices)
  - `web/index.html` (marca na tela de carregamento)
  - `functions/package.json` (script)
  - `.gitignore` (`dist/`)

## 8. Commit
Branch `fase1-seguranca-ambientes-filtros`, commit "Fase 7: regressão completa, índices verificados e build web hml".

---
SHA-256 de `carajas360-web-hml-fase7.zip` (17,3 MB): `ef33f69d8a919b3779ad8fcef29407ed22f608bf9c821cc25dfb2d5b34fd1043`
