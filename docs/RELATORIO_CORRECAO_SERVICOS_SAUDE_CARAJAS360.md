# Relatorio - Correcao Servicos e Saude (Carajas 360)

**Data:** 2026-09-21
**Escopo:** filtro categoria/subcategoria/profissionais; seed homolog; modulo Saude; marca UI.
Sem publicacao em producao.

## 1. Bugs encontrados

1. Em destaque ignorava grupo selecionado (mostrava eletricista em Veiculos/Juridico)
2. HomologCatalog usava match fuzzy contains
3. Chips da Search limitados a Casa/Limpeza
4. Seed homolog incompleto
5. Saude vazia em release homolog (DemoData bloqueado)
6. Medico misturado no seed geral de Servicos
7. Marca legada SaudeConecta/EntregaConecta na UI

## 2. Causas

1. NearbyProvidersList sem parametro group
2. providers() com c.contains(category)
3. _chipCategories hardcoded
4. Seed so Casa/Limpeza/Tech/Beleza parcial
5. Health usava DemoData.orEmpty
6. Mesmo catalogo compartilhado
7. Strings de branding legado

## 3. Arquivos alterados

- lib/core/catalog/homolog_catalog.dart
- lib/features/home/home_screen.dart
- lib/main.dart
- lib/shared/widgets/widgets.dart
- lib/features/health/health_screen.dart
- lib/features/support/support_screens.dart
- test/homolog_catalog_filter_test.dart
- docs/RELATORIO_CORRECAO_SERVICOS_SAUDE_CARAJAS360.md

## 4. Correcoes

- Match exato categories.contains(category); filtro por group via Categories
- matchProviders + testes anti-regressao (5/5 PASS)
- Seed expandido; healthSeed separado (hs1-hs6); medico fora do seed geral
- ServicesHub passa group; empty state; Ver todos com group
- SearchScreen initialGroup; chips do grupo; exclui Saude do marketplace geral
- Saude 360 + healthProviders + banner LGPD + Agendar
- UI: Saude 360, Entregas (MercadoPago intacto)
- ProvCard: city, ctaLabel

## 5. Testes

flutter test test/homolog_catalog_filter_test.dart -> 5/5 PASS

## 6. Pendencias

- Validacao visual no canal homolog apos deploy
- Expandir seed Agro/Maquinas/Drones sob demanda
- Refinar agenda completa no RequestService

## 7. Pronto para homologacao do filtro critico?

SIM (com testes). Deploy homolog manual antes do aceite final. Nao publicar producao.
