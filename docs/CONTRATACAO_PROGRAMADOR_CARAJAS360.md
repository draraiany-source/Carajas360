# Contratação de Programador Flutter/Firebase — Finalização do Carajás 360

**Tipo:** finalização de produto existente (marketplace de serviços)  
**Não é:** desenvolvimento do zero / reconstrução integral sem aprovação  
**Status atual (auditoria 17/11/2026):** **NÃO APTO para publicação** — homolog Web parcial; pendências P0 documentadas  
**Documentação de transferência:** `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md` · `docs/AUDITORIA_FINAL_CARAJAS360.md`

---

## 1. Sobre a vaga

Procuro desenvolvedor(a) experiente em **Flutter**, **Firebase**, **Cloud Functions**, **inteligência artificial**, **Mercado Pago**, **Android** e **iOS** para **finalizar** o aplicativo marketplace de serviços **Carajás 360**, já desenvolvido.

### Importante

- **Não** é um projeto para desenvolver do zero.
- O app já possui estrutura Flutter para **Web, Android e iOS**, interface visual (identidade verde/branco/dourado), módulos de clientes, profissionais, pedidos, chat e administração.
- Existe **documentação técnica organizada**, relatórios de auditoria, mapas de fluxo e pacote de transferência ao programador.
- **Não serão aceitas** propostas para reconstruir integralmente o aplicativo sem justificativa técnica e **aprovação prévia**.

---

## 2. O que já existe (base real)

| Item | Situação |
|------|----------|
| App Flutter multiplataforma | Sim — pacote `carajas_360`, IDs `br.com.carajas360` |
| Firebase projeto | `carajas360-a17c5` |
| Homolog Web | Canal ativo (demo parcial) |
| Hosting live | Indisponível (404) — só com autorização |
| UI Carajás IA | Pronta no app |
| Callable IA / Functions runtime | Pendente (API/Blaze/deploy) |
| Código de pagamentos (MP) | Presente; homologação sandbox pendente |
| Documentação / auditorias | Fases 1–12 documentadas |

Fontes: `docs/AUDITORIA_FINAL_CARAJAS360.md`, `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md`.

---

## 3. Serviços necessários

1. Revisar e corrigir as **pendências técnicas documentadas** (P0 da auditoria final).  
2. Configurar **Firebase Cloud Functions** e ativar a **IA existente** (callable + evidência de turno real).  
3. Testar os **fluxos completos** de clientes e profissionais (E2E).  
4. Homologar **pagamentos Mercado Pago em sandbox** (PIX/cartão/webhook — sem produção sem GO).  
5. Corrigir problemas de **compilação Android**.  
6. Gerar **APK** para testes e **AAB assinado**.  
7. Compilar e testar a versão **iOS**, incluindo **TestFlight**.  
8. Validar telas, botões, navegação e funcionalidades.  
9. Realizar testes de **segurança** e **estabilidade**.  
10. Preparar publicação **Web, Google Play e App Store**, **somente mediante autorização explícita**.

---

## 4. Entregas obrigatórias (por etapa)

| Entrega | Critério de aceite |
|---------|-------------------|
| Código no repositório existente | PRs/commits na branch acordada; sem fork “app novo” |
| Relatório de testes | Aprovado / Reprovado / Não testado + evidências |
| IA funcional | Turno real comprovado (não só UI) |
| Fluxos de contratação | Cliente e profissional ponta a ponta |
| Pagamentos homologados | Sandbox MP com evidência; produção só com GO |
| APK + AAB Android | Artefatos + versão/SHA256 |
| iOS TestFlight | Build disponível para testers |
| Web validada | Homolog estável; live só com GO |
| Docs finais | Instalação, manutenção, secrets (sem versionar segredos) |

**Pagamento dividido por etapas**, condicionado à validação das entregas.

---

## 5. Bloqueadores P0 (escopo prioritário)

Conforme auditoria final:

1. Ativar Cloud Functions API / Blaze e deploy das functions necessárias (incl. IA).  
2. Hosting live — **apenas com GO**.  
3. IA com resposta real grounded em profissionais.  
4. Mercado Pago sandbox E2E (webhook seguro já endurecido no código).  
5. AAB assinado do commit candidato.  
6. iOS + TestFlight (macOS + conta Apple Developer).

---

## 6. O que solicitar na proposta

Informar:

- Experiência em projetos **semelhantes** (Flutter + Firebase + pagamentos + lojas).  
- **Prazo estimado** por etapa (não só prazo total).  
- **Orçamento** (preferência: por etapa alinhada às entregas).  
- **Disponibilidade** para trabalhar no **repositório existente**.  
- Se possui **macOS** para iOS/TestFlight (ou parceria).  
- Confirmação de que **não** propõe rebuild integral sem aprovação.

---

## 7. Forma de trabalho

- Continuidade no código e na identidade visual atuais.  
- Sem inventar dados/profissionais/preços.  
- Sem publicar lojas ou live sem autorização por escrito.  
- Evidências obrigatórias (logs, screenshots, builds, matriz de testes).

---

## 8. Documentos a enviar ao contratado

1. `docs/ENTREGA_PROGRAMADOR_CARAJAS360.md`  
2. `docs/AUDITORIA_FINAL_CARAJAS360.md` (+ PDF)  
3. `docs/AUDITORIA_TELAS_CARAJAS360.md`  
4. `docs/RELATORIO_FASES_4_A_11.md`  
5. `docs/MATRIZ_HOMOLOGACAO_FASE10.md`  
6. Acesso ao repositório / Firebase (conforme política de segredos)

---

*Texto de contratação alinhado ao estado real do Carajás 360 em 17/11/2026. Atualizar após fechamento dos P0.*
