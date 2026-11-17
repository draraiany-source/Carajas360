# Orçamento com fotos e IA — relatório (atualizado)

**Data:** 2026-11-17  
**Branch:** `feat/modernizacao-visual`  
**Escopo:** anexos reais no orçamento — sem rebuild.

---

## Verificação do pedido

| Requisito | Status | Evidência |
|-----------|--------|-----------|
| Até 10 fotos, câmera/galeria, preview/remover/trocar | **APROVADO (código)** | `OrderPhotoPicker` |
| Compressão + validação formato/tamanho | **APROVADO (código+teste)** | `OrderPhotos` + `test/order_photos_test.dart` |
| Storage seguro + associação ao pedido | **APROVADO (E2E emulator)** | upload `orders/{id}/photos/` + `photoUrls` |
| Visualização cliente/pro | **APROVADO (código + E2E ACL)** | galeria UI + leitura permitida no E2E |
| Visita técnica | **APROVADO (código + E2E)** | `siteVisitRequested` no pedido |
| Proposta valor/prazo/descrição | **APROVADO (código)** | diálogo aceitar + mensagem chat |
| IA opcional sem inventar preço | **APROVADO (código)** | `suggestOrderDescriptionFromPhotos`; runtime CF pendente |
| Regras Firestore photoUrls | **APROVADO (deploy)** | `firestore:rules` 2026-11-17 |
| Regras Storage (read/write/delete) | **APROVADO (E2E emulator)** | delete ACL corrigido; deploy prod bloqueado |
| E2E upload + permissões + exclusão | **APROVADO (emuladores)** | `emulator_e2e.txt` — All tests passed |
| Produção (bucket live) | **BLOQUEADO** | billing ausente / Storage não provisionado |
| Web/Android/iOS | **APROVADO (código)** | `image_picker` + `putData` (bytes) |

---

## Evidências

| Artefato | Resultado |
|----------|-----------|
| `flutter test test/order_photos_test.dart test/order_photos_flow_test.dart` | **8/8 pass** |
| `test/order_photos_emulator_e2e_test.dart` via `emulators:exec` | **PASS** — upload, read client/pro, deny stranger, attach Firestore, delete |
| Deploy `firestore.rules` | **OK** |
| Criar bucket / deploy `storage` em produção | **FALHOU** — `billingEnabled: false` / Storage not set up |
| Log E2E | `docs/evidence/orcamento_fotos/emulator_e2e.txt` |

### Trecho E2E (emuladores Auth+Firestore+Storage)

```
PASS: storage: uploaded orders/.../photos/....jpg
PASS: storage: client can read photo (200)
PASS: storage: provider can read photo (200)
PASS: storage: stranger denied (403)
PASS: firestore: photoUrls/photoCount/siteVisit associated
PASS: firestore: provider can view order with photos
PASS: firestore: stranger cannot view order (403)
PASS: storage: client deleted photo (204)
E2E_ORDER_PHOTOS_OK ...
All tests passed!
```

---

## Bloqueador produção (bucket live)

Projeto `carajas360-a17c5` sem billing (`billingEnabled: false`).  
Criação de `gs://carajas360-a17c5.firebasestorage.app` via gcloud retorna 403.  
Após vincular billing / Get Started no Console:

```bash
npx firebase-tools@latest deploy --only storage --project carajas360-a17c5
```

Repetir smoke autenticado no app (homolog) com 1–3 fotos reais.

---

## Fluxo no código

```
Fotos locais → createOrder → uploadOrderPhoto → attachOrderPhotos
→ chat → OrderPhotoGallery (cliente/pro) → proposta (valor/prazo/descrição)
```

Path Storage: `orders/{orderId}/photos/{ts}_{uid}.{ext}`  
ACL: cliente do pedido, profissional do pedido, admin. Estranho = 403.  
Delete: partes do pedido (regra dedicada; `request.resource` não existe em delete).

---

## Como reproduzir o E2E local

```bash
# Java no PATH (ex.: Android Studio JBR)
set JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
npx firebase-tools@latest emulators:exec --only auth,firestore,storage --project carajas360-a17c5 "flutter test test/order_photos_emulator_e2e_test.dart --reporter expanded"
```

---

## Pacote entrega programador

Atualizado em `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md` e pasta `ENTREGA_PROGRAMADOR_CARAJAS360/`.

**Conclusão:** funcionalidade **implementada e comprovada nos emuladores** (upload, armazenamento, permissões, associação, exclusão). **Bucket de produção ainda não existe** — não marcar smoke live até billing + deploy `storage`.
