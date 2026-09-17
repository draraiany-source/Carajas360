# Auditoria Carajás 360

**Data:** 2026-09-16  
**Projeto:** `C:\Users\Lenovo\Desktop\Carajas360`  
**Repositório:** https://github.com/draraiany-source/Carajas360.git  
**Escopo:** auditoria + correções seguras + backup Git (sem avançar Fase 2 / Play Store / keystore / pagamentos reais)

---

## Resumo executivo

| Item | Resultado |
|------|-----------|
| Erros de compilação Dart (`flutter analyze`) | **0 erros** |
| Avisos / infos | **~90 warnings + ~90 infos** (principalmente deprecações `withOpacity` / estilo) |
| Testes | Suíte unitária executada nesta sessão (ver seção Testes) |
| Segredos reais no código | **Não encontrados** (apenas placeholders) |
| `.gitignore` raiz | **Criado** (estava ausente) |
| Funcionalidades Fase 1 | Preservadas (Home, Serviços, Resolve, Pedidos, Mensagens, Perfil) |

---

## Problemas encontrados

### Críticos / bloqueadores de produção (pendentes — não corrigidos nesta auditoria)

1. **Firebase não configurado de verdade** — `lib/firebase_options.dart`, `android/app/google-services.json` e `ios/Runner/GoogleService-Info.plist` ainda com placeholders `COLE_SUA_*`.
2. **Maps / Mercado Pago** — chaves via `--dart-define` / `local.properties`; defaults ainda placeholder (`RuntimeConfig`).
3. **Release / Play Store** — exige `android/key.properties` + keystore (propositalmente não criado).
4. **Cloud Functions** — token MP e Anthropic via `functions.config()`; CORS aberto (`*`) em endpoints HTTP.
5. **Emulador Android** — AVD `Carajas360_Pixel7` criado anteriormente, mas hypervisor driver não instalado neste PC (exige admin/UAC).

### Segurança / regras

6. **Firestore** — várias coleções com `allow read: if true` (catálogo público); writes sensíveis (carteira) já endurecidos em auditorias anteriores.
7. **Storage rules** — orders restrito a participantes (já corrigido antes).
8. **Sem `.env` / service-account / keystore reais** no working tree (bom).

### Qualidade de código

9. **Imports não usados** em alguns arquivos (corrigidos nesta sessão).
10. **Deprecações Flutter** — dezenas de `withOpacity` / `background` / `activeColor` / `desiredAccuracy` (não bloqueiam build).
11. **Infos de estilo** — `curly_braces_in_flow_control_structures` em vários arquivos.
12. **Artefatos locais** — dezenas de `*_analyze*.txt`, `build/`, `node_modules/` (não devem ir ao Git).
13. **Pasta antiga** `ServicoConecta v1.5 COMPLETO` ausente no Desktop; fonte ativa em `Carajas360`.
14. **`ios/Flutter/ephemeral/`** apontava caminho antigo gerado (arquivo gerado; ignorado pelo Git).

### Navegação / Fase 1

15. Rotas Fase 1 presentes em `lib/main.dart` e `Routes` (`carajas_home`, serviços hub, resolve, orders, chat inbox, profile).
16. Módulos Fase 2 (Vagas, Fretes, Imóveis, Obras, Auto, Kids) marcados `comingSoon` em `platform_modules.dart` — **não implementados / não avançados**.
17. Tela legada `HealthScreen` ainda rota disponível (módulo antigo Serviço Conecta) — preservada, sem expansão Fase 2.

---

## Correções realizadas nesta auditoria

1. **Criado `.gitignore` raiz** cobrindo Flutter/Android/iOS, `node_modules`, secrets, logs de auditoria, `build/`, keystores, `.env`, etc.
2. **Criado `functions/.gitignore`** (`node_modules`, `.env`, `.runtimeconfig.json`, logs).
3. **Removidos imports mortos / desnecessários:**
   - `lib/features/ai_assistant/ai_screen.dart`
   - `lib/features/chat/chat_screen.dart`
   - `lib/features/health/health_screen.dart`
   - `lib/features/provider/provider_home_screen.dart`
   - `lib/auth_smoke_main.dart`
4. **Confirmado remote Git** `origin` → `https://github.com/draraiany-source/Carajas360.git` (sem criar remote extra).
5. **Branch principal** `main` (já era a branch local).

Nenhuma funcionalidade Fase 1 removida. Sem avanço para Vagas/Fretes/Imóveis/Saúde nova/Obras/Auto/Kids, keystore, Play Store ou pagamentos reais.

---

## Problemas pendentes (próximos passos autorizados)

- Rodar `flutterfire configure` e substituir placeholders Firebase.
- Definir `MAPS_API_KEY` / `--dart-define` Maps e Mercado Pago.
- Deploy: `firebase deploy --only firestore:rules,storage,functions`.
- Instalar Android Emulator Hypervisor Driver (admin) e validar no emulador.
- Criar keystore + `key.properties` quando for publicar.
- Reduzir gradualmente deprecações `withOpacity` → `withValues`.
- Revisar reads públicos no Firestore (minimizar exposição).

---

## Arquivos alterados

| Arquivo | Ação |
|---------|------|
| `.gitignore` | Criado |
| `functions/.gitignore` | Criado |
| `AUDITORIA_CARAJAS360.md` | Criado (este relatório) |
| `lib/features/ai_assistant/ai_screen.dart` | Import não usado removido |
| `lib/features/chat/chat_screen.dart` | Imports limpos |
| `lib/features/health/health_screen.dart` | Import não usado removido |
| `lib/features/provider/provider_home_screen.dart` | Import desnecessário removido |
| `lib/auth_smoke_main.dart` | Import desnecessário removido |

---

## Testes executados

| Comando | Resultado |
|---------|-----------|
| `flutter pub get` | OK |
| `flutter analyze --no-fatal-infos` | **0 errors**, 180 issues (90 warnings + 90 infos) |
| `flutter test` (models + auth_validators + widget) | **27 passed**, exit 0 (nesta sessão, com `ProgramFiles(x86)` definido) |
| `test/auth_flow_emulator_test.dart` | Skip automático se Auth emulator `:9099` indisponível (não falha a suíte) |
| Build release | Não executado (keystore fora de escopo) |

Arquivos sensíveis **não** versionados / mantidos fora do commit:

- `android/local.properties` (ignorado)
- `android/key.properties` (não existe; exemplo versionável)
- `*.jks` / keystores (não presentes)
- `.env` / `functions/.env` (não presentes)
- `service-account*.json` (não presentes)
- `build/`, `.dart_tool/`, `node_modules/`
- Logs temporários `*_analyze*.txt`, `_tmp_*.txt`, etc.

Placeholders **seguros para versionar** (sem segredos reais):

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- `android/key.properties.example`

---

## Recomendações futuras

1. Configurar Firebase real + deploy de rules/functions antes de testes de produção.
2. Instalar hypervisor e validar Fase 1 no emulador Pixel 7 (`Carajas360_Pixel7`).
3. Só então keystore + AAB + Play Console.
4. Tratar deprecações em lotes pequenos (tema/widgets) sem refatoração ampla.
5. Não habilitar módulos Fase 2 até autorização explícita.
6. Manter carteira / pagamentos apenas server-side (já encaminhado).

---

## Conclusão

Auditoria concluída com **0 erros Dart**, correções **seguras** de Git/segurança/imports, relatório gerado e projeto preparado para commit/push no GitHub oficial, **sem** alterar o escopo da Fase 1 nem introduzir segredos.
