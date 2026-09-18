# DEV_BYPASS_LOGIN — modo de teste temporário

Permite **navegar o app em debug/staging sem Firebase Auth**.  
Não é conta real. Não é admin. Não liga pagamento. Não muda rules.

## Ligar (máquina local, debug)

```bash
flutter run --debug --dart-define=DEV_BYPASS_LOGIN=true
```

Web:

```bash
flutter run -d chrome --debug --dart-define=DEV_BYPASS_LOGIN=true
```

O splash vai para a home. `RequireAuth` aceita o usuário mock `dev-bypass-user` (`type=client`).

Faixa **DEV BYPASS** no canto da tela = flag ligada.

## Desligar (obrigatório antes de publicar)

1. **Não** passar `--dart-define=DEV_BYPASS_LOGIN=true`.
2. Default do código é **`false`**.
3. Em **release** (`kReleaseMode`) a flag é **ignorada** mesmo se o define vier `true`.
4. Builds de loja: `flutter build apk|appbundle|ios --release` **sem** esse define.

## Garantias

| Item | Comportamento |
|---|---|
| Default | `false` |
| Release | `enabled = define && !kReleaseMode` → sempre false |
| Admin | `AccessControl.isAdmin` / `AdminGate` **negam** (mock é client, sem claims) |
| Pagamentos | `PAYMENTS_ENABLED` continua false; callables recusam no bypass sem Auth real |
| Rules | `firestore.rules` / `storage.rules` **não** foram alteradas |
| Auth real | Código de login Firebase permanece |

## Limitações

- Placeholders Firebase (`COLE_SUA_…`) continuam. Writes/callables **podem falhar** sem Auth real — esperado.
- Streams de pedidos/chat/carteira no bypass devolvem lista vazia (não fingem backend).
- DemoData segue só debug; o bypass **não** amplia DemoData.
- E-mail do mock usa domínio residual `@servicoconecta.com.br` (não inventamos `@carajas360.com.br`).

**Não usar em produção. Não merge como atalho permanente.**
