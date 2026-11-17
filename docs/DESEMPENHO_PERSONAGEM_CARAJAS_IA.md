# Relatório de desempenho — Personagem Carajás IA

**Data:** 16/11/2026

| Asset | Tamanho aprox. | Uso |
|-------|----------------|-----|
| avatar.jpg | ~281 KB | Chat / FAB / nav |
| portrait.jpg | ~262 KB | Recepção compacta |
| fullbody.jpg | ~163 KB | Recepção mobile large |
| web_horizontal.jpg | ~196 KB | Recepção Web wide |
| fab.jpg | ~281 KB | (= avatar) |

## Medidas de runtime
- `FilterQuality.medium` nas imagens
- Animações: scale/fade/slide ≤ 1,4 s; desligadas com `disableAnimations`
- Sem Lottie facial / sem sprite de piscar (economiza CPU/GPU)
- Painel Web: um dialog; não duplica árvore `MainNav`
- Backend: mesma callable `aiAssistant` (sem custo extra de Function nova)

## Não medido nesta sessão
- FPS em device físico Android/iOS
- Lighthouse / Web Vitals do canal homolog pós-rebuild
