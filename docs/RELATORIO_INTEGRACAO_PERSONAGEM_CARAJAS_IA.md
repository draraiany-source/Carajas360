# Relatório de integração — Personagem oficial Carajás IA (Prompt 10)

**Data:** 16/11/2026  
**Projeto:** Carajás 360 (mesmo app — sem app novo)  
**Backend:** reutiliza `aiAssistant` / `AiSvc` (sem Function duplicada)  
**Publicação produção:** **não** executada

---

## 1. Personagem

Mulher 3D humanizada (cabelos castanhos, blazer esmeralda, crachá Carajás IA), integrada como avatar/recepção/FAB em Web e mobile via Flutter compartilhado.

**Nota:** a imagem de referência aprovada **não veio anexada** neste prompt. Assets atuais foram gerados a partir da especificação textual. Substituir pelos masters oficiais da proprietária quando disponíveis (ver inventário).

---

## 2. Inventário de assets

| Arquivo | Uso | Status |
|---------|-----|--------|
| `assets/carajas_ia/carajas_ia_portrait.jpg` | Recepção / hero | Presente (gerado) |
| `assets/carajas_ia/carajas_ia_avatar.jpg` | Chat / nav / FAB | Presente (gerado) |
| `assets/carajas_ia/carajas_ia_fullbody.jpg` | Recepção wide | Presente (gerado) |
| `assets/carajas_ia/carajas_ia_fab.jpg` | Ícone flutuante | Presente (= avatar) |
| `assets/carajas_ia/carajas_ia_web_horizontal.jpg` | Banner Web | Presente (gerado) |
| PNG fundo transparente (master) | Contorno/cabelos | **PENDENTE — fornecer** |
| Sprite/Lottie piscar olhos | Animação facial | **PENDENTE (opcional)** |

Não foi feito recorte grosseiro de fundo (conforme regra).

---

## 3. Arquivos alterados / criados

- `lib/features/ai_assistant/ai_screen.dart` — recepção, avatar, typing, embedded
- `lib/features/ai_assistant/carajas_ia_assets.dart`
- `lib/features/ai_assistant/carajas_ia_character.dart`
- `lib/features/ai_assistant/carajas_ia_actions.dart`
- `lib/features/ai_assistant/carajas_ia_fab.dart`
- `lib/main.dart` — FAB Web (painel) + mobile (rota `/ai`)
- `lib/shared/widgets/brand_shell.dart` — ícone nav com avatar
- `pubspec.yaml` — pasta `assets/carajas_ia/`
- `test/carajas_ia_character_test.dart`
- `assets/carajas_ia/*`

---

## 4. Integração UX

| Item | Implementação |
|------|----------------|
| FAB discreto | `CarajasIaFab` no `MainNav` |
| Painel lateral Web | Dialog deslizante + `AiAssistantScreen(embedded: true)` |
| Mobile | FAB → rota `/ai` (RequireAuth) |
| Boas-vindas | Texto oficial Prompt 10 |
| Atalhos | Explorar, orçamento assistido, Saúde, marketplace, dúvidas |
| Typing | `CarajasIaTypingIndicator` + avatar |
| Fechar | botão no painel embedded |
| Reduced motion | respeita `MediaQuery.disableAnimations` |
| Sem animação facial fake | documentado — sem sprite de piscar |

---

## 5. Segurança / LGPD (inalterado no backend)

Auth, quotas, consentimento Saúde, isolamento `scopedConversationId`, rules `aiConversations`/`aiUsage`, sem chave no client — mantidos do Prompt 9.

---

## 6. Testes

| Caso | Resultado |
|------|-----------|
| Unit personagem + avatar + ações | **APROVADO** |
| Smoke mobile + painel embedded + FAB | **APROVADO** (overflow mobile corrigido) |
| Parse `AiTurnResult` | **APROVADO** |
| Abertura Web/Android/iOS runtime | **NÃO APROVADO** (sem device/build runtime nesta sessão) |
| Mensagens E2E `aiAssistant` | **BLOQUEADO** (Function deploy pendente) |
| Capturas Web/Mobile reais | Pendentes (disco local crítico; smoke widget OK) |

---

## 7. Desempenho

- Assets JPG ~160–290 KB cada; `FilterQuality.medium`
- Sem Lottie facial; animações leves (scale/fade/slide)
- Painel Web não monta segunda árvore de navegação completa além do dialog

---

## 8. Checklist de homologação

- [ ] Substituir JPG gerados pelo PNG master oficial (fundo transparente)
- [ ] GO rebuild + canal `homolog` (não `live`)
- [ ] GO deploy `functions:aiAssistant` (grounded)
- [ ] Teste visual Web (FAB + painel + fechar)
- [ ] Teste Android (FAB + teclado + avatar)
- [ ] Teste iOS (macOS build)
- [ ] Auth E2E + histórico isolado
- [ ] Domínio homolog autorizado

## 9. Pendências

1. Master oficial da personagem (referência não anexada).  
2. Deploy Functions + homolog Web.  
3. Capturas reais multiplataforma.  
4. OAuth Android / Auth Email conforme relatório Prompt 9.

**Veredito:** componentes reais integrados no app existente; **não** declarar personagem/comercial operacional sem masters oficiais + E2E.
