'use strict';

/**
 * Relógio do servidor. Em produção/homologação é sempre Date.now().
 * Só no emulador com TEST_CLOCK=true (functions/.env.demo-carajas360) os
 * testes podem avançar o tempo gravando `_testClock/current.offsetMs`
 * (coleção sem acesso pelo app). Usado por prazos e tarefas agendadas
 * (retenção de reservas, confirmação em 72 h, liberação em 7 dias).
 */
const enabled = () => process.env.FUNCTIONS_EMULATOR === 'true' && process.env.TEST_CLOCK === 'true';

let cache = { at: 0, offset: 0 };

/** Atualiza o deslocamento (no máximo 1 leitura por segundo) e devolve "agora". */
async function nowMs(db) {
  if (!enabled()) return Date.now();
  if (Date.now() - cache.at > 1000) {
    const s = await db.collection('_testClock').doc('current').get();
    cache = { at: Date.now(), offset: s.exists ? Number(s.data().offsetMs) || 0 : 0 };
  }
  return Date.now() + cache.offset;
}

/** "Agora" síncrono com o último deslocamento lido (sempre Date.now() fora do emulador). */
function nowSync() {
  return enabled() ? Date.now() + cache.offset : Date.now();
}

module.exports = { nowMs, nowSync, enabled };
