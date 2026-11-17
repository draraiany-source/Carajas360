# Orçamento com fotos e IA — relatório

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Escopo:** completar anexos reais no pedido de orçamento (sem rebuild).

---

## Auditoria (antes)

| Item | Situação |
|------|----------|
| UI “Adicionar fotos” | Existia (`pickMultiImage`, máx. 5) |
| Upload Firebase Storage | **Ausente** — só texto “N fotos” na descrição |
| `OrderModel.photoUrls` | **Ausente** |
| Regras Storage `/orders/{id}/` | Já existiam (cliente/pro/admin) |
| Visita técnica | Ausente |
| Proposta com prazo/descrição | Aceite só com preço |
| IA multimodal | Ausente |

---

## Implementado

1. **Até 10 fotos** — câmera/galeria, preview, remover, substituir (`OrderPhotoPicker`).  
2. **Compressão** — `imageQuality: 72`, max 1600px; validação ≤ 8 MB; JPG/PNG/WebP/HEIC.  
3. **Upload** — `FS.uploadOrderPhoto` → `orders/{orderId}/photos/…` após `createOrder`.  
4. **Associação** — `FS.attachOrderPhotos` + regras Firestore (cliente, status pendente, só `photoUrls`/`photoCount`/`siteVisitRequested`).  
5. **Visita técnica** — switch no formulário + flag no pedido + tag no prestador.  
6. **Visualização** — `OrderPhotoGallery` em Meus pedidos e área do profissional.  
7. **Proposta** — diálogo valor + prazo + descrição; mensagem no chat.  
8. **IA opcional** — sugere descrição via `AiSvc` com prompt que **proíbe** inventar diagnóstico/preço (runtime depende de Function).  
9. **Testes unitários** — `test/order_photos_test.dart`.

---

## Fluxo comprovável (código)

```
Cliente escolhe fotos → createOrder → upload Storage → attachOrderPhotos
→ chat intro → Profissional vê galeria → envia proposta (valor/prazo/texto)
→ Cliente acompanha em Pedidos / Mensagens
```

**E2E autenticado com Storage real:** requer ambiente Firebase com regras deployadas e login — marcar como validado após GO de deploy `firestore.rules` + `storage.rules` + teste manual.

---

## Arquivos

- `lib/core/orders/order_photos.dart`
- `lib/features/orders/order_photo_picker.dart`
- `lib/features/orders/service_request_flow_screen.dart`
- `lib/features/orders/orders_screen.dart`
- `lib/features/provider/provider_home_screen.dart`
- `lib/shared/models/models.dart`
- `lib/shared/services/firestore_facade.dart`
- `lib/core/orders/service_request.dart`
- `firestore.rules`
- `test/order_photos_test.dart`

---

## Pendências honestas

- Deploy das regras atualizadas (sem GO automático nesta sessão).  
- Turno IA real só com Cloud Functions API ativa.  
- Teste manual E2E com conta real + evidência de URL no Storage.
