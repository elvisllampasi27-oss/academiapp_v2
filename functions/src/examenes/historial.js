'use strict';

/**
 * Historial de exámenes semanales del alumno, con su promedio. Un examen
 * que no dio cuenta como 0 cuando ya se cerró (el sábado siguiente), si
 * pudo darlo: el examen estaba publicado y en esa semana tenía Premium (o
 * el examen no era solo para Premium). Ese 0 no se guarda ni entra al
 * ranking: solo se muestra aquí y pesa en el promedio.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { verificarEstudiante } = require('../comun/estudiante');
const { leerConfiguracion } = require('../comun/plan');
const {
  DIA_MS,
  DESFASE_LIMA_MS,
  diaLima,
  semanaAcademica,
  semanaDeExamen,
  idExamenSemanal,
  idSimulacroSemanal,
} = require('./reglas');

/**
 * Hasta qué semana un examen no dado cuenta como 0. Los de semanas
 * anteriores al examen abierto ya cerraron; si el plan está en pausa, solo
 * cuentan los de antes de la pausa; si nunca tuvo Premium y el examen es
 * solo para Premium, ninguno.
 */
function limiteNoDados({ inicioMs, ahoraMs, premiumHastaMs, soloPremium }) {
  let limite = semanaDeExamen(inicioMs, ahoraMs) - 1;
  if (soloPremium) {
    if (premiumHastaMs == null) return 0;
    if (premiumHastaMs <= ahoraMs) {
      const pausa = Math.max(diaLima(premiumHastaMs), diaLima(inicioMs));
      const semanaPausa = semanaAcademica(inicioMs, pausa * DIA_MS + DESFASE_LIMA_MS);
      limite = Math.min(limite, Math.max(1, semanaPausa) - 1);
    }
  }
  return Math.max(0, limite);
}

/**
 * Arma las filas (de la más reciente a la más antigua) y el promedio.
 * @param {{semana: number, examen: object|null, simulacro: object|null}[]} semanas
 */
function armarHistorial(semanas, limite) {
  const filas = [];
  for (const { semana, examen, simulacro } of semanas) {
    const titulo = (examen && examen.titulo) || (simulacro && simulacro.titulo) || `Semana ${semana}`;
    if (simulacro && simulacro.estado === 'completado') {
      filas.push({ semana, titulo, puntaje: Number(simulacro.puntaje) || 0, dado: true });
    } else if (semana <= limite && examen && examen.estado === 'publicado') {
      filas.push({ semana, titulo, puntaje: 0, dado: false });
    }
  }
  filas.sort((a, b) => b.semana - a.semana);
  const promedio = filas.length
    ? Math.round(filas.reduce((t, f) => t + f.puntaje, 0) / filas.length)
    : null;
  return { semanas: filas, promedio };
}

async function historialDe(db, uid, ahoraMs) {
  const matricula = await verificarEstudiante(db, uid);
  const inicioMs = matricula.fechaInicioAcademico.toMillis();
  const actual = semanaDeExamen(inicioMs, ahoraMs);
  if (actual < 1) return { semanas: [], promedio: null };

  const numeros = Array.from({ length: actual }, (_, i) => i + 1);
  const ids = numeros.map((s) => idExamenSemanal(matricula.versionId, s));
  const [usuario, configuracion, examenes, simulacros] = await Promise.all([
    db.collection('usuarios').doc(uid).get(),
    leerConfiguracion(db),
    db.getAll(...ids.map((id) => db.collection('examenes_semanales').doc(id))),
    db.getAll(...ids.map((id) => db.collection('simulacros').doc(idSimulacroSemanal(uid, id)))),
  ]);
  const hasta = usuario.data() && usuario.data().premiumHasta;
  const limite = limiteNoDados({
    inicioMs,
    ahoraMs,
    premiumHastaMs: hasta && typeof hasta.toMillis === 'function' ? hasta.toMillis() : null,
    soloPremium: Boolean(configuracion.simulacroSoloPremium),
  });
  return armarHistorial(numeros.map((semana, i) => ({
    semana,
    examen: examenes[i].exists ? examenes[i].data() : null,
    simulacro: simulacros[i].exists ? simulacros[i].data() : null,
  })), limite);
}

const historialExamenesSemanales = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  return historialDe(admin.firestore(), request.auth.uid, Date.now());
});

module.exports = { limiteNoDados, armarHistorial, historialExamenesSemanales };
