'use strict';

/**
 * Modo manutenção (config/platform.maintenanceMode). Enquanto ligado, as
 * operações que criam ou alteram pedidos, pagamentos e reservas recusam
 * usuários comuns; administradores continuam operando. Webhooks e tarefas
 * agendadas não passam por aqui (pagamentos já iniciados se concluem).
 */
module.exports = function maintenanceGuard({ db, isAdmin, httpsError }) {
  let cache = { at: 0, on: false, message: null };
  async function state() {
    if (Date.now() - cache.at > 30000) {
      const s = await db.collection('config').doc('platform').get();
      const d = s.exists ? s.data() : {};
      cache = { at: Date.now(), on: d.maintenanceMode === true, message: d.maintenanceMessage || null };
    }
    return cache;
  }
  return async function guard(auth) {
    const st = await state();
    if (!st.on) return;
    if (auth && (await isAdmin(auth))) return;
    throw httpsError('unavailable', st.message || 'O Carajás 360 está em manutenção. Tente novamente em alguns minutos.');
  };
};
