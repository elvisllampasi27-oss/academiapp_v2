'use strict';

/**
 * Plan del estudiante (gratis o Premium) y las reglas de la academia que
 * edita el administrador en el panel (documento config/academia).
 */
const CONFIGURACION_POR_DEFECTO = Object.freeze({
  precio: 29,
  diasPremium: 90,
  tutorGratis: 3,
  tutorPremium: 20,
  simulacroSoloPremium: true,
});

async function leerConfiguracion(db) {
  const snap = await db.collection('config').doc('academia').get();
  return { ...CONFIGURACION_POR_DEFECTO, ...(snap.exists ? snap.data() : {}) };
}

/** Premium vigente según usuarios/{uid}.premiumHasta. */
function esPremium(usuario, ahoraMs = Date.now()) {
  const hasta = usuario && usuario.premiumHasta;
  return Boolean(hasta && typeof hasta.toMillis === 'function' && hasta.toMillis() > ahoraMs);
}

/** Dudas al tutor por día según el plan. */
function limiteTutor(configuracion, premium) {
  const valor = premium ? configuracion.tutorPremium : configuracion.tutorGratis;
  return Math.max(0, Number(valor) || 0);
}

module.exports = { CONFIGURACION_POR_DEFECTO, leerConfiguracion, esPremium, limiteTutor };
