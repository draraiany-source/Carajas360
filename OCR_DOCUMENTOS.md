# OCR de documentos — arquitetura (sem serviço pago)

**Não implementar** Vision, Textract, ML Kit Cloud nem qualquer OCR cobrado neste bloco.

## O que já existe (upload manual)

1. Prestador envia foto, RG/CNH, selfie e certificados no onboarding  
   (`FS.uploadProviderFile` → Storage `providers/{uid}/{kind}/…`).
2. Admin abre documentos e **aprova na mão** (`FS.approveProvider`).
3. `verified` / `approved` **não** podem ser setados pelo próprio prestador (rules + `providerSelfUpdateBlocked`).

Não há extração de CPF, nome ou validade de documento no client ou nas Functions.

## Objetivo futuro (quando a Raiany contratar um provedor)

```
[App] foto/PDF
    → Storage (já existe)
    → Callable `analyzeProviderDocument` (ainda NÃO criada)
        → provedor OCR (ML Kit on-device OU Vision/Textract — escolher depois)
        → grava `documentReviews/{id}` { status: pending|needs_review, fields, confidence }
        → NUNCA marca `verified: true` sozinho
[Admin] confere campos + foto e só então aprova
```

## Regras que precisam continuar verdadeiras

| Regra | Motivo |
|---|---|
| OCR **nunca** autoaprova | Self-verification é fraude clássica |
| CPF extraído ≠ CPF oficial até admin | Check digit já existe no backend; OCR erra |
| Bytes do documento não vão para log | PII |
| Sem API key no client | Mesmo padrão Maps/MP |
| Fallback = fluxo manual atual | Staging não depende de OCR |

## Opções de provedor (decisão futura — sem contratar agora)

| Opção | Prós | Contras |
|---|---|---|
| ML Kit on-device (texto) | Sem custo por chamada | Fraco em RG brasileiro; modelo no APK |
| Cloud Vision / Document AI | Qualidade | Pago; precisa billing + DPA |
| Textract | Tabelas | Pago; AWS extra |
| Humano só (atual) | Zero custo, auditável | Escala ruim |

**Recomendação até release candidato:** manter revisão humana. OCR é P2 (`BACKLOG_FASE_2.md`).

## Dados a extrair *se* um dia ligar (rascunho)

- Tipo: RG / CNH / selfie
- Nome, CPF (validar dígitos no backend, não confiar no OCR)
- Número do documento, UF, validade
- `confidence` por campo; abaixo do limiar → `needs_review`

Não persistir imagem em `auditLogs`. Só `storagePath` + hash.

## Fora deste bloco

- Conta Google Cloud Vision / AWS.
- Secrets de OCR.
- Selo azul automático.
- Qualquer chamada paga.
