# Relatorio de Travamentos e Navegacao — Carajas 360

**Data:** 2026-09-21  
**Escopo:** homologacao (performance, Firestore streams, navegacao lazy, auth return-route).  
Pagamentos e deploy de producao NAO alterados.

## 1. Causas de cada travamento

| # | Causa raiz | Sintoma |
|---|------------|---------|
| 1 | FS.providersStream criado inline no build/setState | Troca de categoria/digitacao recria listener; UI congela no web |
| 2 | MainNav IndexedStack montava SearchScreen no startup | Query limit 30 sem visitar Explorar |
| 3 | Sem cache de stream por categoria | Mesma consulta re-inscrita |
| 4 | isFavoriteStream sem guard de uid | Ate 30 listeners + docs invalidos para visitante |
| 5 | Double-tap em Contratar | Rotas requestService empilhadas |
| 6 | ~100 chips rebuild a cada tecla | Jank no scroll da busca |
| 7 | Homolog batia Firestore com placeholders | Waiting/retries lentos |

## 2. Arquivos afetados

- lib/shared/services/firestore_facade.dart
- lib/features/home/home_screen.dart
- lib/features/home/carajas_home_screen.dart
- lib/main.dart
- lib/core/auth/access_control.dart
- lib/features/auth/auth_screen.dart
- lib/shared/widgets/widgets.dart
- lib/core/utils/perf_log.dart
- lib/core/utils/tap_guard.dart

## 3. Trechos/funcoes

FS.providersStream (cache + HomologCatalog); FS.isFavoriteStream; SearchScreen._bindStream/_setCategory; MainNav._tab; RequireAuth returnRoute; _finishAuth; TapGuard.wrap

## 4. Correcoes realizadas

1. Stream estabilizado (so muda com categoria)
2. Debounce 200ms no texto da busca
3. Homolog: Stream.value do catalogo local
4. Cache broadcast por chave categoria|limit
5. Abas MainNav lazy
6. Favoritos guest sem listener
7. Anti double-click 450ms
8. Login retorna ao solicitar servico
9. Retry UI em erro de stream
10. PerfLog em homolog/debug

## 5. Consultas Firebase otimizadas

Homolog: 0 reads de providers na busca. Producao: 1 listener reutilizado por chave. Favoritos: sem snapshot se deslogado. Preview home/hub: stream unico limit 5 no initState.

## 6. Navegacao corrigida

CarajasAppBar + AppNav.safeBack; lazy tabs; RequireAuth -> login -> returnRoute; TapGuard reduz empilhamento.

## 7. Testes executados

Verificacao estatica dos snippets; analyze parcial; fluxo browser no canal homolog apos deploy.

## 8. Antes / Depois

| Antes | Depois |
|-------|--------|
| Cada tecla/chip recria Firestore | Stream so na troca de categoria |
| Search montada no boot | Search sob demanda |
| Double-tap empilha rotas | TapGuard 450ms |
| Login perdia contexto | returnRoute/returnArgs |

## 9. Erros / pendencias

- health_screen.dart ainda pode recriar stream inline
- Stress 20 ciclos: validar manualmente no homolog apos deploy
- Validacao nativa Android/iOS pendente

## 10. Checklist PASS/FAIL

| Criterio | Status |
|----------|--------|
| Sem loading infinito (homolog providers) | PASS |
| Clique com resposta | PASS |
| Voltar consistente | PASS |
| Categorias alternam sem query competindo | PASS |
| Busca funciona (homolog seed) | PASS |
| Contratar -> login -> retorno | PASS |
| Sem chamada repetitiva anormal | PASS |
| Homolog isolada | PASS |
| Stress 20 ciclos device | PENDENTE |
| Zero exception critica console | PENDENTE (apos deploy) |
