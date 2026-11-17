# README — Entrega Workana / Programador (FASE 16)

**Produto:** Carajás 360  
**Branch:** `feat/modernizacao-visual`  
**Commit (HEAD pacote):** `a95b2e5`  
**Versão:** `1.0.0+403`  
**Firebase:** `carajas360-a17c5`  
**Homolog:** https://carajas360-a17c5--homolog-88u39zqx.web.app  

## Veredito rápido

| Item | Resposta |
|------|----------|
| Contratar programador | **SIM** |
| Publicar Web live | **NÃO** |
| Publicar Android | **NÃO** |
| Publicar iOS | **NÃO** |
| IA funcional (LLM) | **NÃO** |
| Pagamentos homologados | **NÃO** |
| Orçamentos multimídia | **PARCIAL** (fotos OK em emulator; vídeo/áudio ausentes; Storage prod bloqueado) |

## Conteúdo deste pacote

### FASE 16 (Workana)
- `FASE16/RELATORIO_FINAL_CARAJAS360.pdf`
- `FASE16/ESCOPO_WORKANA_CARAJAS360.pdf`
- `FASE16/PENDENCIAS_PROGRAMADOR.pdf`
- `FASE16/CRITERIOS_ACEITE.pdf`
- `FASE16/CHECKLIST_ANDROID_IOS_WEB.pdf`
- `FASE16/PLANO_TESTES_FINAL.pdf`
- `ZIP_DOCUMENTACAO_FINAL.zip`

### Fontes Markdown (repo `docs/`)
- `FASE16_VALIDACAO_FINAL.md`
- `FASE16_ESCOPO_WORKANA.md`
- `FASE16_PENDENCIAS_PROGRAMADOR.md`
- `FASE16_CRITERIOS_ACEITE.md`
- `FASE16_CHECKLIST_ANDROID_IOS_WEB.md`
- `FASE16_PLANO_TESTES_FINAL.md`
- `FASE15_AUDITORIA_DEFINITIVA.md` (**obrigatório** — baseline)

### Pacote anterior (F14/F15)
PDFs 01–15, edital, guias Firebase/pagamentos/Android/iOS/Web.

## Regras
1. **Não** recriar o aplicativo.  
2. **Não** versionar tokens, keystores ou dados pessoais.  
3. **Não** publicar live/lojas sem GO da contratante.  
4. Aceite de marco = evidência objetiva (ver critérios).

## Comandos iniciais do programador
```bash
git checkout feat/modernizacao-visual
git log -1 --oneline   # esperado: a95b2e5 ou sucessor documentado
flutter pub get
cd functions && npm test && cd ..
flutter test test/order_photos_test.dart test/order_photos_flow_test.dart
```

## Segurança
Ver `SEGURANCA_CREDENCIAIS.md`. Secrets apenas em Secret Manager / máquina local.
