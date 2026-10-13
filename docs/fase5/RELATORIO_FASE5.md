# Carajás 360 — Fase 5: Saúde e Locação

> **Status:** concluída em **homologação local (emuladores)**.
> Consultas e locações **não são cobradas pelo app** nesta fase: o valor é calculado e registrado, mas o pagamento é combinado com o profissional ou o anunciante.
> Nada foi publicado e produção não foi tocada.

Escopo: seções 7 (Saúde) e 8 (Locação) do pedido original.

## 1. Situação encontrada (antes de editar)

**Saúde**
| Ponto | Encontrado |
|---|---|
| Agendamento | Gravado direto pelo app com `{type, mode, time, price}`. **Sem profissional e sem data**, só um horário de uma lista fixa (08:00–17:00) |
| Preço | Padrão inventado (R$ 150; urgente R$ 0; home care R$ 200) quando o profissional não tinha preço |
| Disponibilidade / conflito | Não existiam; dois pacientes podiam marcar o mesmo horário |
| Cancelamento | O paciente mudava o status direto, sem regra |
| Atalhos "Urgente / Agendar / Home Care" | Criavam consultas sem profissional |
| Privacidade | Sem consentimento; dados misturáveis com o Resolve (oportunidades públicas aceitavam categorias de saúde) |
| "Todos", filtros Online/Presencial/Home Care e busca | Já corrigidos na Fase 2 (consulta real na vertical Saúde); conferidos e mantidos |

**Locação**
| Ponto | Encontrado |
|---|---|
| Criação da reserva | O app gravava `bookings` e **depois** tentava escrever em `notifications`, o que as regras bloqueiam: falso erro com a reserva já salva (exatamente o achado da auditoria) |
| Preço / total | Calculados no app; as regras permitiam criar com qualquer `total` |
| Conflito de datas | Checado só no app, e a lista de reservas de outros clientes nem era legível pelas regras (a checagem não funcionava) |
| Transições | Qualquer participante mudava `status` para qualquer valor |
| Mercado × Locação | Já separados (coleções e telas distintas); mantidos |

## 2. O que foi implementado

### Saúde

**Agenda do profissional** (`healthSchedules/{uid}`), publicada pela nova tela "Agenda de Saúde" no painel do prestador:
- faixas por dia da semana, intervalo entre horários e dias bloqueados;
- por especialidade da vertical Saúde: duração, valor e modalidades;
- fuso fixo **America/Belem** (UTC−3, sem horário de verão).

**Horários reais** (`listHealthSlots`): calculados no servidor a partir da agenda, com:
- antecedência mínima de 2 h e no máximo 90 dias à frente;
- dias bloqueados excluídos;
- consultas existentes não sobrepostas (a sobreposição parcial também bloqueia).

**Agendamento** (`bookHealthAppointment`), idempotente. Exige:
- profissional aprovado e ativo;
- especialidade da vertical Saúde, oferecida na agenda;
- modalidade oferecida;
- horário válido e livre;
- **consentimento** do termo de dados de saúde, versão `2026-10` (LGPD, art. 11).

Grava o registro completo: profissional, especialidade, data, início e fim, fuso, modalidade, valor da agenda e consentimento.

**Conflito:** cada reserva lê e atualiza `healthCalendars/{profissional}` dentro da transação, o que serializa as reservas do mesmo profissional. Teste: dois pacientes no mesmo horário ao mesmo tempo → **exatamente um** consegue.

**Cancelar / reagendar / concluir** (`healthAppointmentAction`):
- **paciente:** cancela ou reagenda até **2 h antes**, no máximo **2 reagendamentos**;
- **profissional:** cancela a qualquer momento **com motivo**;
- **concluir ou registrar falta:** só o profissional, depois do início;
- no reagendamento, o horário antigo é liberado e o novo é validado na mesma transação.

**Privacidade:**
- o motivo e os sintomas ficam em `appointments/{id}/private/clinical`, legível **só pelo paciente e pelo profissional** (nem o admin lê pelo app);
- as notificações usam texto genérico, sem especialidade nem motivo;
- o **Resolve recusa categorias de saúde**, que não viram oportunidade pública e são direcionadas ao agendamento em Saúde;
- o consentimento é registrado no agendamento e em `healthConsents/{uid}`.

**Atalhos:**
- "Emergência" orienta SAMU 192 / pronto-socorro (o app não faz urgência);
- "Agendar" orienta escolher um profissional;
- "Home Care" aplica o filtro domiciliar.

### Locação

**Cotação e reserva no servidor** (`quoteRentalBooking`, `createRentalBooking`):
- preço por **hora, diária, semana ou mês** vindo do anúncio, em centavos;
- quantidade limitada por período (72 h, 90 dias, 12 semanas, 12 meses);
- o fim de "mês" é calculado no calendário (31/01 + 1 mês = 28/02);
- início entre 1 h e 365 dias a partir de agora;
- não é possível reservar o próprio anúncio nem um anúncio pausado;
- total e valores enviados pelo app são **ignorados**;
- idempotente pelo `requestId`.

**Disponibilidade / sobreposição:**
- a transação lê e atualiza `rentals/{id}/meta/calendar`;
- reservas pendentes, confirmadas e em andamento bloqueiam o período; uma pendente cujo início já passou não bloqueia;
- períodos que apenas encostam são permitidos;
- teste: duas reservas simultâneas do mesmo período → exatamente uma.

**Períodos ocupados** (`rentalAvailability`): devolve só as datas, sem dados de quem reservou. A folha de reserva mostra esses períodos.

**Transições autorizadas** (`transitionRentalBooking`), com histórico:
| Ação | Quem | Regra |
|---|---|---|
| confirmar / recusar | anunciante | só pendente |
| cancelar | locatário | pendente a qualquer momento; confirmada até **24 h antes** do início |
| cancelar | anunciante | com **motivo** se já confirmada |
| iniciar | anunciante | a partir de 1 h antes do início |
| concluir | anunciante | só em andamento |

Reservas pendentes não confirmadas até o início são encerradas pela rotina `rentalMaintenance` (de hora em hora).

**Notificações por evento** (`onRentalBookingWrite`): nova solicitação, confirmação, cancelamento (com motivo), início e conclusão. O app não grava mais notificações.

## 3. Arquivos

**Backend:**
- `functions/healthCore.js` (novo)
- `functions/rentalCore.js` (novo)
- `functions/scheduleCore.test.js` (novo)
- `functions/schedule.js` (novo)
- `functions/index.js`
- `functions/resolve.js` (bloqueio de saúde)
- `functions/package.json`

**Regras e índices:**
- `firestore.rules`:
  - `appointments` e `bookings` sem escrita pelo app;
  - `appointments/*/private` só para os participantes;
  - `healthSchedules` gravado só pelo próprio profissional, com formato validado;
  - `healthCalendars` e `healthConsents` só pelo servidor.
- `firestore.indexes.json`: 5 índices novos:
  - `appointments`: `providerId + status + startMs`, `clientId + startMs`, `providerId + startMs`;
  - `bookings`: `rentalId + status`, `status + startMs`.

**App:**
- `lib/features/health/health_booking.dart` (novo): agendamento, seletor de horários e lista com cancelar/reagendar/concluir
- `lib/features/health/health_schedule_editor.dart` (novo)
- `lib/features/health/health_screen.dart`
- `lib/features/rental/rental_screen.dart`
- `lib/features/provider/provider_home_screen.dart`
- `lib/shared/services/firebase_service.dart`
- `lib/shared/models/models.dart`

**Testes:**
- `firebase-tests/functions/schedule.test.js` (novo)
- `firebase-tests/rules/schedule.rules.test.js` (novo)
- `firebase-tests/e2e/schedule.e2e.js` (novo)
- `test/health_rental_test.dart` (novo)
- `test_driver/e2e_schedule_main.dart` (novo)

**Migração / dados legados:** nenhuma migração.
- Agendamentos antigos (sem profissional nem data) continuam legíveis, mas não são exibidos na nova lista, que exige horário real, e não recebem notificações.
- Reservas antigas em reais seguem legíveis (`total`). As novas usam `totalCents` e `startMs`/`endMs`.
- Reservas antigas sem `startMs` **não entram na checagem de sobreposição**.

## 4. Testes

| Suíte | Resultado | Observação |
|---|---|---|
| Functions unitários (`npm test`) | **62/62** | +7: fuso, horários livres, prazos, preço, fim de período, sobreposição, transições |
| Emulador (regras + integração, Fases 1–5) | **99/99** | +7 de integração e +4 de regras da Fase 5 |
| Flutter (`flutter test`) | **90 aprovados, 1 ignorado** | O ignorado é o teste de login que só roda com emulador, já existente |
| E2E navegador (`schedule.e2e.js`) | **11/11** | Horário real → sem consentimento não agenda → agendado → reagendado; reserva com valor do servidor → confirmada pelo anunciante → notificação |
| `flutter analyze` | **0 erros** | Só avisos antigos de estilo e deprecação |
| Build web hml (release, `APP_ENV=hml`) | **OK** | Não publicado |

**Coberto na integração:**
- horários vindos da agenda;
- recusa de horário fora da grade ou do expediente, sem consentimento, modalidade não oferecida, profissional não aprovado e especialidade fora de Saúde;
- preço do app ignorado; idempotência;
- motivo só no subdocumento privado;
- sobreposição parcial bloqueada;
- **agendamento concorrente: um vence**;
- reagendar para horário ocupado recusado; reagendar libera o antigo; limite de 2;
- concluir antes do início recusado;
- profissional cancela só com motivo; paciente não cancela a menos de 2 h;
- notificação genérica;
- Resolve recusa saúde;
- locação: total do servidor, próprio anúncio, período sem preço, sobreposição, encostado permitido, ocupação sem dados pessoais;
- **reserva concorrente: uma vence**;
- transições por papel, prazo de 24 h e motivo do anunciante; histórico; notificações por evento.

**Evidências:** `docs/fase5/evidencias/` (horários reais e resumo, lista de agendamentos, reagendado, cotação da reserva, reserva confirmada).

**Ajuste depois das capturas:** no chip de data da agenda, o dia da semana aparecia cortado. Passei para uma linha ("qua 14/10"). As capturas do E2E são de antes desse ajuste.

## 5. Aplicar em homologação

1. `firebase deploy --project hml --only firestore:rules,firestore:indexes,functions` e aguardar os índices.
2. Publicar o app hml **junto**: versões antigas não conseguem mais criar agendamento nem reserva diretamente.
3. Os profissionais de saúde precisam publicar a "Agenda de Saúde". Sem agenda, o paciente vê "Este profissional ainda não publicou a agenda".

## 6. Limitações e pendências

- **Cobrança:** consultas e locações não são cobradas pelo app. O valor é registrado e o pagamento é combinado fora. Integrar ao fluxo de pagamento da Fase 3 é extensão direta (novo tipo de alvo), mas não foi feito nesta fase.
- **Vídeo:** consultas online não têm sala de vídeo integrada; o link deve ser combinado pelo chat.
- **Fuso:** fixo em America/Belem. Profissionais em outros fusos não são suportados.
- **Prontuário:** não há prontuário nem anexos clínicos. O dado clínico se limita ao motivo da consulta. Também não há tela para o paciente revogar o consentimento (está registrado e versionado, mas a revogação ainda é manual).
- **Calendário de locação:** não há bloqueio manual de datas pelo anunciante; ele usa "disponível/indisponível" ou recusa reservas. A reserva por hora começa às 08:00 do dia escolhido (a tela não tem seletor de hora).
- **Notificações:** sem lembrete agendado antes da consulta ou da retirada.
- **Builds Android/iOS:** não executados (sem SDKs neste ambiente).
