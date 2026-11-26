'use strict';

/**
 * Pausa del plan: cuando se acaba la prueba gratis o el Premium, el plan se
 * queda en la semana en que iba. Al pagar, se retoma desde el lunes de esa
 * semana: si hoy es lunes, hoy mismo; si no, el lunes que viene. Para eso
 * se corre el inicio del plan (fechaInicioAcademico) un número exacto de
 * semanas, así los temas de cada día y el examen del sábado no se mueven
 * de su día de la semana. Igual que lib/features/enrollment/domain/pausa_plan.dart.
 */
const { DIA_MS, DESFASE_LIMA_MS, diaLima, diaSemana, semanaAcademica } = require('../examenes/reglas');

const medianocheLima = (dia) => dia * DIA_MS + DESFASE_LIMA_MS;

/**
 * Si al pagar en [ahoraMs] hay que retomar un plan en pausa. null si no
 * estaba en pausa (sigue con Premium, nunca tuvo, o se pausó hoy lunes).
 * @returns {null | {semana: number, desplazamientoDias: number, retomaElMs: number}}
 */
function retomaDelPlan({ inicioMs, premiumHastaMs, ahoraMs }) {
  if (inicioMs == null || premiumHastaMs == null || premiumHastaMs > ahoraMs) return null;
  // Primer día sin Premium (nunca antes de que empiece el plan).
  const pausa = Math.max(diaLima(premiumHastaMs), diaLima(inicioMs));
  const lunesPausa = pausa - diaSemana(pausa);
  const hoy = diaLima(ahoraMs);
  const retoma = diaSemana(hoy) === 0 ? hoy : hoy + (7 - diaSemana(hoy));
  const desplazamientoDias = retoma - lunesPausa;
  if (desplazamientoDias <= 0) return null;
  return {
    semana: Math.max(1, semanaAcademica(inicioMs, medianocheLima(pausa))),
    desplazamientoDias,
    retomaElMs: medianocheLima(retoma),
  };
}

/** La matrícula activa del alumno, leída dentro de la transacción. */
async function leerMatriculaActiva(tx, db, uid) {
  const consulta = await tx.get(db.collection('matriculas')
    .where('usuarioId', '==', uid)
    .where('estado', '==', 'activa')
    .limit(1));
  return consulta.empty ? null : consulta.docs[0];
}

module.exports = { retomaDelPlan, leerMatriculaActiva };
