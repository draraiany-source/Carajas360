# Acoes da Proprietaria (fora do codigo)

1. Criar/confirmar projeto Firebase de **producao** separado do staging (se ainda nao existir).
2. Baixar google-services.json / GoogleService-Info.plist / flutterfire configure — **nao** colar secrets no chat.
3. Criar contas de teste Auth em staging (CLIENTE, PROFISSIONAL, PRO, ADMIN) — senhas so no gerenciador pessoal.
4. No Mercado Pago: manter Sandbox ate homologacao E2E; depois preparar conta producao.
5. Colocar tokens apenas no Google Secret Manager / CI secrets.
6. Configurar DNS e e-mails @carajas360.com.br (MX) quando dominio estiver pronto.
7. Publicar Politica de Privacidade e Termos no dominio final.
8. Decidir App Check (Play Integrity / DeviceCheck).
9. Assinar keystore de upload Android e guardar senhas offline (nao no Git).
10. Autorizar por escrito: PRODUCTION_PAYMENTS_ENABLED e publicacao nas lojas (fase futura).
11. Fornecer dispositivo Android ou emulador para E2E.
12. Confirmar comissao inicial desejada no Admin staging (nao assumir 8% sem ver config).