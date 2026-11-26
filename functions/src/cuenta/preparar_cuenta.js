'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { DIA_MS, DESFASE_LIMA_MS, diaLima, diaSemana } = require('../examenes/reglas');
const { esPremium } = require('../comun/plan');

/**
 * Hora de Perú desde la que el plan empieza al día siguiente: quien se
 * matricula de madrugada empieza ese mismo día; después, mañana. Es la
 * misma regla del panel (configuracionInicioPanel).
 */
const HORA_CORTE = 6;
const HORA_MS = 60 * 60 * 1000;
const DOMINGO = 6;
const ESTADOS_ABIERTOS = ['publicada', 'activa'];

/** Medianoche de Lima del día [dia] (número de día desde 1970), en ms. */
const medianocheLima = (dia) => dia * DIA_MS + DESFASE_LIMA_MS;

/**
 * Versión que acepta matrículas en [ahoraMs]: publicada o activa y sin
 * pasar su fecha de corte (el mismo día del corte todavía vale). Si hay
 * varias, la que abrió más recientemente. null si no hay ninguna.
 * @param {{id: string, estado: string, fechaAperturaMs: number,
 *          fechaCorteMs: number|null}[]} versiones
 */
function versionVigente(versiones, ahoraMs) {
  const hoy = diaLima(ahoraMs);
  const abiertas = versiones.filter((v) => ESTADOS_ABIERTOS.includes(v.estado)
    && (v.fechaCorteMs == null || diaLima(v.fechaCorteMs) >= hoy));
  if (abiertas.length === 0) return null;
  return abiertas.reduce((a, b) => (b.fechaAperturaMs > a.fechaAperturaMs ? b : a));
}

/**
 * Día 1 del plan: hoy si se matricula antes de las 6 a. m. (hora de Perú),
 * si no mañana; nunca antes de que abra la versión y nunca en domingo.
 * Devuelve la medianoche de Lima de ese día, en ms.
 */
function inicioPlan(ahoraMs, aperturaMs) {
  const hoy = diaLima(ahoraMs);
  const horaLima = Math.floor((ahoraMs - DESFASE_LIMA_MS - hoy * DIA_MS) / HORA_MS);
  let dia = horaLima < HORA_CORTE ? hoy : hoy + 1;
  dia = Math.max(dia, diaLima(aperturaMs));
  if (diaSemana(dia) === DOMINGO) dia += 1;
  return medianocheLima(dia);
}

/**
 * Fin de la prueba gratis: el lunes (00:00 de Lima) después del fin de
 * semana en que se abre su primer examen semanal. Así tiene sábado y
 * domingo para rendirlo. Si empieza sábado o domingo, su semana 1 es la
 * siguiente (como en semanaAcademica).
 */
function finPrueba(inicioMs) {
  const inicio = diaLima(inicioMs);
  let lunesSemana1 = inicio - diaSemana(inicio);
  if (diaSemana(inicio) >= 5) lunesSemana1 += 7;
  return medianocheLima(lunesSemana1 + 7);
}

/**
 * Qué hacer con la cuenta. No toca nada: decide.
 * - 'existente': ya tiene una matrícula activa.
 * - 'suspendida': el administrador la suspendió; no se matricula solo.
 * - 'cerrado': no hay versiones abiertas a matrículas.
 * - 'crear': matrícula nueva (con prueba gratis si nunca la tuvo y no es
 *   Premium).
 */
function planDeCuenta({ usuario, matriculas, versiones, ahoraMs }) {
  const activa = matriculas.find((m) => m.estado === 'activa');
  if (activa) return { accion: 'existente', matricula: activa };
  if (matriculas.some((m) => m.estado === 'suspendida')) return { accion: 'suspendida' };

  const version = versionVigente(versiones, ahoraMs);
  if (!version) return { accion: 'cerrado' };

  const inicioMs = inicioPlan(ahoraMs, version.fechaAperturaMs);
  const darPrueba = usuario.pruebaHasta == null && !esPremium(usuario, ahoraMs);
  return {
    accion: 'crear',
    version,
    inicioMs,
    pruebaHastaMs: darPrueba ? finPrueba(inicioMs) : null,
  };
}

const ms = (valor) => (valor && typeof valor.toMillis === 'function' ? valor.toMillis() : null);

/** Lee, decide y escribe en una sola transacción (sin duplicados). */
async function prepararCuentaDe(db, uid, ahoraMs) {
  return db.runTransaction(async (tx) => {
    const usuarioRef = db.collection('usuarios').doc(uid);
    const [usuarioSnap, matriculasSnap, versionesSnap] = await Promise.all([
      tx.get(usuarioRef),
      tx.get(db.collection('matriculas').where('usuarioId', '==', uid)),
      tx.get(db.collection('versiones_academicas').where('estado', 'in', ESTADOS_ABIERTOS)),
    ]);

    const usuario = usuarioSnap.data();
    if (!usuario || usuario.rol !== 'estudiante' || usuario.estado !== 'activo') {
      throw new HttpsError('failed-precondition', 'Primero completa tu perfil de estudiante.');
    }

    const decision = planDeCuenta({
      usuario,
      matriculas: matriculasSnap.docs.map((d) => ({ id: d.id, ...d.data() })),
      versiones: versionesSnap.docs.map((d) => ({
        id: d.id,
        nombre: d.data().nombre,
        estado: d.data().estado,
        fechaAperturaMs: ms(d.data().fechaApertura) ?? 0,
        fechaCorteMs: ms(d.data().fechaCorte),
      })),
      ahoraMs,
    });

    if (decision.accion === 'existente') {
      return { nueva: false, inicioMs: ms(decision.matricula.fechaInicioAcademico) };
    }
    if (decision.accion === 'suspendida') {
      throw new HttpsError(
        'failed-precondition',
        'Tu plan está suspendido. Escríbenos para revisarlo.',
      );
    }
    if (decision.accion === 'cerrado') {
      throw new HttpsError('failed-precondition', 'Las matrículas están cerradas por ahora.');
    }

    const { version, inicioMs, pruebaHastaMs } = decision;
    tx.set(db.collection('matriculas').doc(), {
      usuarioId: uid,
      versionId: version.id,
      fechaMatricula: Timestamp.fromMillis(ahoraMs),
      fechaInicioAcademico: Timestamp.fromMillis(inicioMs),
      estado: 'activa',
      creadaPor: 'automática',
    });
    if (pruebaHastaMs != null) {
      tx.update(usuarioRef, {
        premiumHasta: Timestamp.fromMillis(pruebaHastaMs),
        pruebaHasta: Timestamp.fromMillis(pruebaHastaMs),
      });
    }
    const fecha = (valor) => new Date(valor - DESFASE_LIMA_MS).toISOString().slice(0, 10);
    tx.set(db.collection('registro_admin').doc(), {
      tipo: 'matricula',
      usuarioId: uid,
      descripcion: `Se matriculó solo en ${version.nombre || version.id} `
        + `(inicia el ${fecha(inicioMs)}`
        + `${pruebaHastaMs != null ? `, prueba gratis hasta el ${fecha(pruebaHastaMs - DIA_MS)}` : ''}).`,
      adminUid: 'sistema',
      adminCorreo: 'matrícula automática',
      fecha: FieldValue.serverTimestamp(),
    });

    return {
      nueva: true,
      versionNombre: version.nombre || version.id,
      inicioMs,
      pruebaHastaMs,
    };
  });
}

/**
 * Justo después de crear el perfil: matricula al alumno en la versión
 * vigente y le da su prueba gratis. Si ya tenía matrícula, no hace nada.
 */
const prepararCuenta = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }
  return prepararCuentaDe(admin.firestore(), request.auth.uid, Date.now());
});

module.exports = {
  HORA_CORTE,
  versionVigente,
  inicioPlan,
  finPrueba,
  planDeCuenta,
  prepararCuenta,
};
