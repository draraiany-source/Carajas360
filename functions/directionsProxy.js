'use strict';

/**
 * Directions via Function — só com GOOGLE_MAPS_SERVER_KEY no Secret Manager.
 * Sem key: recusa. Não inventamos secret e não deixamos a rota aberta.
 */
function directionsDecision({ serverKey, origin, destination }) {
  const key = String(serverKey || '');
  if (!key || /COLE_SUA|changeme|placeholder/i.test(key)) {
    return {
      ok: false,
      reason: 'maps_server_key_not_configured',
      charged: false,
    };
  }
  const o = String(origin || '').trim();
  const d = String(destination || '').trim();
  if (!o || !d) {
    return { ok: false, reason: 'invalid_origin_destination', charged: false };
  }
  return { ok: true, reason: 'ready', charged: false };
}

module.exports = { directionsDecision };
