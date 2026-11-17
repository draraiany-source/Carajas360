# Orçamento com fotos e IA — relatório (atualizado)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Commits:** `b58a96b` (+ follow-ups)  
**Escopo:** anexos reais no orçamento — sem rebuild.

---

## Verificação do pedido

| Requisito | Status | Evidência |
|-----------|--------|-----------|
| Até 10 fotos, câmera/galeria, preview/remover/trocar | **APROVADO (código)** | `OrderPhotoPicker` |
| Compressão + validação formato/tamanho | **APROVADO (código+teste)** | `OrderPhotos` + `test/order_photos_test.dart` |
| Storage seguro + associação ao pedido | **PARCIAL** | Código upload OK; **Firebase Storage NÃO está habilitado** no projeto |
| Visualização cliente/pro | **APROVADO (código)** | `OrderPhotoGallery` em pedidos + provider home |
| Visita técnica | **APROVADO (código)** | switch + `siteVisitRequested` |
| Proposta valor/prazo/descrição | **APROVADO (código)** | diálogo aceitar + mensagem chat |
| IA opcional sem inventar preço | **APROVADO (código)** | `suggestOrderDescriptionFromPhotos`; runtime CF pendente |
| Regras Firestore photoUrls | **APROVADO (deploy)** | `firestore:rules` deployado 2026-11-17 |
| Regras Storage | **REPROVADO / bloqueado** | CLI: *Firebase Storage has not been set up* |
| E2E upload real + visualização | **NÃO COMPROVADO** | Bloqueado até criar bucket Storage no Console |
| Web/Android/iOS | **APROVADO (código)** | `image_picker` + `putData` (bytes) |

---

## Evidências desta sessão

| Artefato | Resultado |
|----------|-----------|
| `flutter test test/order_photos_test.dart test/order_photos_flow_test.dart` | **8/8 pass** |
| Deploy `firestore.rules` | **OK** — `docs/evidence/order_photos_firestore_rules_deploy.txt` |
| Deploy `storage` | **FALHOU** — Storage não iniciado no projeto |
| Log tentativa Storage | `docs/evidence/fase12/order_photos_rules_deploy.txt` |

---

## Bloqueador P0 para “comprovar upload real”

No Console Firebase → **Storage → Get Started** (criar bucket padrão, ex. `carajas360-a17c5.appspot.com`).

Depois, com GO:

```bash
npx firebase-tools@latest deploy --only storage --project carajas360-a17c5
```

Roteiro E2E (conta cliente + pro):

1. Solicitar orçamento com 1–3 fotos  
2. Confirmar objetos em `orders/{orderId}/photos/`  
3. Confirmar `photoUrls` no documento Firestore  
4. Abrir Meus pedidos (cliente) e área do prestador (galeria)  
5. Prestador envia proposta (valor/prazo/texto)  
6. Cliente vê mensagem / aceita fluxo de pagamento existente  

---

## Fluxo no código (já implementado)

```
Fotos locais → createOrder → uploadOrderPhoto → attachOrderPhotos
→ chat → OrderPhotoGallery (cliente/pro) → proposta (valor/prazo/descrição)
```

---

## Pacote entrega programador

Atualizado em `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md` e pasta `ENTREGA_PROGRAMADOR_CARAJAS360/` (README + este relatório).

**Conclusão honesta:** funcionalidade **implementada no app e regras Firestore publicadas**; **upload/armazenamento real ainda NÃO comprovado** porque o **Firebase Storage do projeto não foi criado**. Não marcar E2E como concluído até o bucket existir e o roteiro acima passar.
