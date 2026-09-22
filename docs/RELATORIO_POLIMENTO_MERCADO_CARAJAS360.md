# Relatorio de Polimento — Mercado 360 (Carajas 360)

**Data:** 2026-09-21  
**Escopo:** modulo Mercado (marketplace). Pagamento PIX/cartao preservado; sem deploy de producao.

## 1. Arquivos modificados

| Arquivo | Mudanca |
|---------|---------|
| lib/features/marketplace/marketplace_screen.dart | Reescrita UI/UX: modelo, seed gated, busca, grid, cards, detalhe, checkout multi-step |
| lib/features/wallet/wallet_screen.dart | Demo: MercadoConecta -> Mercado 360 |
| lib/shared/services/firestore_facade.dart | Guard isProductFavoriteStream quando uid null |
| docs/RELATORIO_POLIMENTO_MERCADO_CARAJAS360.md | Este relatorio |

## 2. Funcionalidades implementadas

- Branding **Mercado 360** (sem MercadoConecta)
- MarketProduct expandido: imageUrl, oldPrice, deliveryEta, available, isHomologSeed
- Seed SEED/MOCK/HOMOLOGACAO so com placeholders Firebase ou debug
- Release com keys reais: seed vazio (so Firestore)
- Categorias preservadas: Todos, Mercado, Farmacia, Pet Shop, Materiais, Refeicoes, Agro, Maquinas, Ferramentas
- Chips com Material Icons + destaque claro
- Busca real (produto, loja, categoria) com debounce 200ms
- Estado vazio: Nenhum resultado encontrado
- Grid responsivo 2/3/4/5 colunas; cards compactos (mainAxisExtent)
- Card: imagem/placeholder, nome, loja, preco, preco anterior, desconto, avaliacao, prazo, Adicionar, favorito, indisponivel
- Detalhe do produto (sheet) com quantidade
- Checkout: carrinho -> endereco -> entrega/retirada -> PIX/cartao -> confirmacao
- Auth obrigatoria antes do pagamento (returnRoute marketplace)
- Imagem via URL (CachedNetworkImage) + placeholder profissional
- Favoritos com guard para visitante

## 3. Bugs corrigidos

1. Header storefront/cart confuso — botoes separados
2. Cards gigantes (aspectRatio 0.65) — mainAxisExtent compacto
3. Emoji como imagem primaria — placeholder + URL
4. isProductFavoriteStream sem uid — Stream.value(false)
5. Checkout unico sem endereco/modo — fluxo multi-step
6. Busca decorativa — agora funcional
7. Nome legado MercadoConecta — Mercado 360

## 4. Testes executados

| Teste | Resultado |
|-------|-----------|
| Analise estatica (imports, encoding UTF-8, snippets chave) | PASS |
| Categorias ids/nomes preservados no codigo | PASS |
| Seed gated (hasPlaceholderKeys / kDebugMode) | PASS |
| MercadoConecta removido do codigo Dart | PASS |
| dart analyze marketplace_screen (subagente) | PASS (No issues) |
| Fluxo visual browser homolog pos-deploy | PENDENTE (deploy homolog manual) |
| Stress dispositivo Android/iOS | PENDENTE |

## 5. Pendencias

- Validacao visual em Chrome/Edge/Android apos deploy homolog
- Imagens reais de produtos no Firestore (hoje fallback placeholder)
- Acompanhar pedido marketplace no MyOrdersScreen (rastreio dedicado)
- Screenshots oficiais apos deploy do build atual

## 6. Confirmacao — funcionalidades anteriores

| Area | Status |
|------|--------|
| Filtros de categoria (ids/nomes) | Preservados |
| PIX / CardPaymentScreen | Mesma navegacao; so descricao atualizada |
| StoreScreen / fluxos vendedor | Nao alterados |
| createCartOrder / paymentStatus interno | Payload estendido; gateway intacto |
| Carrinho em memoria | Preservado e aprimorado |

## 7. Pronto para homologacao final?

**SIM** — com checklist visual pos-deploy no canal homolog (placeholders).  
Nao publicar em producao.
