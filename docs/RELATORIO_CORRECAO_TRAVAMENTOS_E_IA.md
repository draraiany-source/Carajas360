# Relatório — Correção de travamentos + Central Carajás 360 IA

**Data:** 16/11/2026  
**Projeto:** Carajás 360 (mesmo repositório)  
**Produção / live:** não publicada nesta etapa

---

## 1. Travamentos identificados e corrigidos

| # | Causa | Sintoma | Correção |
|---|--------|---------|----------|
| 1 | `providersStream` em homolog gerava `Stream.value` **novo a cada build** | Freeze/jank Web ao digitar/filtrar | Cache por chave também no modo homolog |
| 2 | `HealthScreen` recriava stream no getter `_stream` a cada `setState` | Lista Saúde congelava / loading eterno | Stream estável em `initState`; filtros locais |
| 3 | Telas de monetização/oportunidades sem `cancel` de `listen` | Vazamento + `setState` após dispose | `StreamSubscription` + `dispose` |
| 4 | Callables sem timeout explícito | UI “pensando” sem feedback | Timeout 28–30s em `CloudFn.call` |
| 5 | Erro Saúde/IA sem retry | Usuário preso após falha | Botão **Tentar novamente** |

Pendências anteriores (relatório 2026-09) de lazy MainNav / TapGuard / Favoritos guest **mantidas**.

---

## 2. Central Carajás 360 IA

| Item | Status |
|------|--------|
| Módulo existente | **Sim** — Prompt 9/10 |
| Menu Perfil | **Carajás 360 IA** |
| FAB + painel Web | Integrado (`CarajasIaFab`) |
| Backend | Callable `aiAssistant` (sem chave no client) |
| Grounding | Só providers Firestore; sem inventar preços |
| Retry em falha | Implementado |
| Function deployada | **Pendente GO** (grounded só após deploy) |
| Evidência E2E LLM | **Não** — sem declarar operacional comercial |

Homolog Web (UI): https://carajas360-a17c5--homolog-88u39zqx.web.app  

---

## 3. Testes executados nesta sessão

| Teste | Resultado |
|-------|-----------|
| `carajasAi` unit (sessão anterior) | 9/9 |
| Smoke personagem / FAB (sessão anterior) | PASS |
| Analyze arquivos alterados | Em execução / ver evidência |
| E2E fluxo Cliente→Pagamento | **NÃO EXECUTADO** (Auth + Functions + pagamento desligado) |
| E2E Profissional / Admin completo | **NÃO EXECUTADO** |
| Runtime Android/iOS | **NÃO EXECUTADO** neste host |

---

## 4. Como testar

### Web
```bash
flutter run -d chrome
# ou abrir homolog:
# https://carajas360-a17c5--homolog-88u39zqx.web.app
```
Fluxo: Início → FAB Carajás IA / Perfil → Carajás 360 IA → Saúde → Explorar.

### Android
```bash
flutter run -d android
```

### iOS (macOS)
```bash
flutter run -d ios
```

### Functions (staging — só com autorização)
```bash
firebase deploy --only functions:aiAssistant --project carajas360-a17c5
```

---

## 5. Pendências restantes

1. Deploy `aiAssistant` + Auth E2E  
2. Liberar espaço em disco local (builds grandes)  
3. Domínio homolog no Firebase Auth authorized domains  
4. Master PNG transparente da personagem  
5. Stress 20 ciclos device + captura console  
6. Fluxos pagamento (PAYMENTS_ENABLED=false — correto)

**Veredito:** app estabilizado nos pontos críticos acima; IA integrada na UI; **não** declarar sistema pronto comercialmente sem E2E e Function ao vivo.
