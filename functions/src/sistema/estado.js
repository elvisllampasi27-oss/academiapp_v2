'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Lo que responde la función de estado. Nunca devuelve la clave: solo si
 * está puesta.
 */
function respuestaEstado({ esAdmin, clave, ahora }) {
  if (!esAdmin) return null;
  return {
    ok: true,
    hora: ahora.toISOString(),
    gemini: typeof clave === 'string' && clave.trim().length > 0,
    region: 'us-central1',
  };
}

/** Solo el administrador: el panel la llama para ver si Functions responde. */
const estadoSistema = onCall({ secrets: [GEMINI_API_KEY] }, async (request) => {
  const respuesta = respuestaEstado({
    esAdmin: request.auth?.token?.admin === true,
    clave: GEMINI_API_KEY.value(),
    ahora: new Date(),
  });
  if (!respuesta) {
    throw new HttpsError('permission-denied', 'Solo el administrador.');
  }
  return respuesta;
});

module.exports = { estadoSistema, respuestaEstado };
