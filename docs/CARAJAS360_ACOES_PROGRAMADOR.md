# Acoes do Programador

1. Manter FEATURE FREEZE.
2. Garantir PRODUCTION_PAYMENTS_ENABLED=false e PAYMENTS_ENABLED controlado.
3. Deploy rules + functions so em staging ate autorizacao.
4. Gerar AAB release production-like com pagamentos OFF.
5. Completar E2E device quando houver aparelho/Firebase.
6. Nao misturar IDs Sandbox em configs de producao.
7. Manter audit logs e kill switch (financialKillSwitch).
8. Rotacionar qualquer secret se exposto (nao so apagar do Git).
9. Documentar cada build (versionCode/versionName/commit).
10. Nao publicar Play/App Store sem autorizacao.