# Relatório de fluxos — FASE 17

## Cliente (desejado)

`Cadastro → Login → Localização → Busca → Filtros → Perfil → Solicitação → Fotos → Orçamento → Contratação → Pagamento → Acompanhamento → Conclusão → Avaliação`

| Trecho | Código | Evidência F17 |
|--------|--------|---------------|
| Auth / rotas | IS | Rotas em `app_constants` |
| Busca / Explorar | IS | Homolog explorou profissionais (fases anteriores) |
| Solicitação + fotos | IT (código+tests) | `OrderPhotoPicker` / unit / emulator |
| Proposta / aceite | IS | UI + Functions transitions (unit) |
| Pagamento | PI/BX | Unit OK; sandbox N/E |
| Avaliação | IS | Rules/tests Functions |
| E2E autenticado ponta a ponta | — | **NÃO EXECUTADO** |

## Prestador

`Cadastro → Verificação → Perfil → Categorias → Área → Solicitações → Orçamento → Aceite → Execução → Recebimento → Avaliações`

| Trecho | Status F17 |
|--------|------------|
| Provider home / propostas | Código IS |
| Categorias (urbano/rural/máquinas/drones/locação) | Preservar cadastro existente — **não apagadas** nesta fase |
| E2E | **NÃO EXECUTADO** |

## Admin

AdminGate + gestão/disputas/pagamentos: código IS; E2E **N/E**. Usuário comum bloqueado por gate (código).

## Navegação

Nenhuma rota órfã crítica reintroduzida nesta fase. Correções de rotas foram nas FASE 2–3 (docs).
