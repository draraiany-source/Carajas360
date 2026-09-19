# CARAJAS 360 — Auditoria Final para Publicacao

**Data:** 19/09/2026  
**Versao:** 1.0.0+1  
**Commit:** f367955e04f39f12d30a7879508fb49100317f80  
**Branch:** `cursor/bloco-a-security-staging-c199`  
**Flutter:** 3.44.4 | **Dart:** 3.12.2  

## CLASSIFICACAO

# NAO PRONTO PARA PUBLICACAO

PDF: `AUDITORIA_FINAL_PUBLICACAO_CARAJAS_360.pdf`

---

## Resumo executivo

| Metrica | Valor |
|--------|-------|
| Criticos | 7 |
| Altos | 4 |
| Medios | 4 |
| Baixos | 3 |
| Pode publicar agora? | **NAO** |

### Principais bloqueios
1. Firebase client ainda com placeholders `COLE_SUA_*` (release lanca StateError)
2. Sem keystore Android (`key.properties`)
3. Sem `ios/Runner.xcodeproj`
4. Sem URL publica de Politica de Privacidade
5. Pagamentos: Asaas **NAO IMPLEMENTADO**; Mercado Pago desligado; comissao codigo 15/85 vs regra pedida 8/92; escrow **NAO IMPLEMENTADO**

### O que a Raiany resolve sozinha
1. `flutterfire configure` + colar google-services / plist de staging
2. Criar keystore local + `key.properties` (nao versionar)
3. Publicar URL de privacidade (dominio/hosting)

### O que precisa de desenvolvedor
1. Alinhar gateway (Asaas vs MP) e % comissao + escrow
2. Restaurar projeto Xcode / TestFlight
3. App Check + smoke E2E staging + listings loja

---

Ver detalhes completos no PDF gerado nesta pasta.