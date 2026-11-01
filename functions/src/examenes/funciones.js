'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { verificarEstudiante } = require('../comun/estudiante');
const { esFinDeSemanaLima, elegirPreguntas, calificarExamen } = require('./reglas');

const PREGUNTAS_SIMULACRO = () => Number(process.env.SIMULACRO_PREGUNTAS) || 20;
/** Como en la UNSCH: unos 2 minutos por pregunta. */
const SEGUNDOS_POR_PREGUNTA = 120;
/** Margen para el envío automático al acabarse el tiempo. */
const MARGEN_SEGUNDOS = 120;

const publica = (doc) => {
  const d = doc.data();
  return {
    id: doc.id,
    numero: d.numero,
    seccion: d.seccion,
    enunciado: d.enunciado,
    opciones: d.opciones,
    imagen: d.imagen || null,
  };
};

/**
 * Examen pasado (práctica): el estudiante responde una pregunta y recibe al
 * instante si acertó, la correcta y la solución. Las claves nunca salen
 * antes de responder.
 */
const revisarPreguntaExamen = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const { preguntaId, opcionId } = request.data || {};
  if (typeof preguntaId !== 'string' || !preguntaId || typeof opcionId !== 'string' || !opcionId) {
    throw new HttpsError('invalid-argument', 'Respuesta inválida.');
  }

  const db = admin.firestore();
  await verificarEstudiante(db, request.auth.uid);

  const [preguntaSnap, claveSnap] = await Promise.all([
    db.collection('preguntas_examen').doc(preguntaId).get(),
    db.collection('claves_examen').doc(preguntaId).get(),
  ]);
  if (!preguntaSnap.exists || preguntaSnap.data().activa !== true || !claveSnap.exists) {
    throw new HttpsError('not-found', 'Esta pregunta no está disponible.');
  }
  if (!preguntaSnap.data().opciones.some((o) => o.id === opcionId)) {
    throw new HttpsError('invalid-argument', 'Opción inválida.');
  }

  const clave = claveSnap.data();
  return {
    esCorrecta: opcionId === clave.opcionCorrectaId,
    opcionCorrectaId: clave.opcionCorrectaId,
    solucion: clave.solucion || null,
    imagenSolucion: clave.imagenSolucion || null,
  };
});

/**
 * Examen tipo admisión: solo sábado y domingo. Arma un examen con preguntas
 * de exámenes pasados repartidas por área. Si ya hay uno en curso, lo
 * devuelve (así recargar la app no lo pierde).
 */
const iniciarSimulacro = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const db = admin.firestore();
  const uid = request.auth.uid;
  await verificarEstudiante(db, uid);

  const ahora = Date.now();
  const enCurso = await db.collection('simulacros')
    .where('usuarioId', '==', uid)
    .where('estado', '==', 'en_curso')
    .get();
  const vigente = enCurso.docs.find((d) => d.data().venceEn.toMillis() + MARGEN_SEGUNDOS * 1000 > ahora);

  let simulacroRef;
  let datos;

  if (vigente) {
    simulacroRef = vigente.ref;
    datos = vigente.data();
  } else {
    if (!esFinDeSemanaLima() && process.env.SIMULACRO_CUALQUIER_DIA !== 'true') {
      throw new HttpsError('failed-precondition', 'El examen tipo admisión se da sábados y domingos.');
    }

    const indice = await db.collection('indices').doc('preguntas_examen').get();
    const banco = indice.exists ? indice.data().preguntas || [] : [];
    if (banco.length === 0) {
      throw new HttpsError('failed-precondition', 'Todavía no hay preguntas para el examen.');
    }

    const elegidas = elegirPreguntas(banco, PREGUNTAS_SIMULACRO());
    const duracionSegundos = elegidas.length * SEGUNDOS_POR_PREGUNTA;
    simulacroRef = db.collection('simulacros').doc();
    datos = {
      usuarioId: uid,
      preguntas: elegidas.map((p) => ({ id: p.id, seccion: p.seccion })),
      estado: 'en_curso',
      duracionSegundos,
      iniciadoEn: Timestamp.fromMillis(ahora),
      venceEn: Timestamp.fromMillis(ahora + duracionSegundos * 1000),
    };
    await simulacroRef.set(datos);
  }

  const snaps = await db.getAll(
    ...datos.preguntas.map((p) => db.collection('preguntas_examen').doc(p.id)),
  );

  return {
    simulacroId: simulacroRef.id,
    duracionSegundos: datos.duracionSegundos,
    venceEnMs: datos.venceEn.toMillis(),
    preguntas: snaps.filter((s) => s.exists).map(publica),
  };
});

/** Corrige el examen tipo admisión y guarda el resultado. */
const enviarSimulacro = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const { simulacroId, respuestas } = request.data || {};
  if (typeof simulacroId !== 'string' || !simulacroId || !respuestas || typeof respuestas !== 'object') {
    throw new HttpsError('invalid-argument', 'Envío inválido.');
  }

  const db = admin.firestore();
  const uid = request.auth.uid;
  const ref = db.collection('simulacros').doc(simulacroId);
  const snap = await ref.get();
  const datos = snap.data();

  if (!snap.exists || datos.usuarioId !== uid) {
    throw new HttpsError('not-found', 'No se encontró tu examen.');
  }
  if (datos.estado !== 'en_curso') {
    throw new HttpsError('failed-precondition', 'Este examen ya fue enviado.');
  }

  const clavesSnap = await db.getAll(
    ...datos.preguntas.map((p) => db.collection('claves_examen').doc(p.id)),
  );
  const claves = new Map(clavesSnap.filter((s) => s.exists).map((s) => [s.id, s.data()]));

  let resultado;
  try {
    resultado = calificarExamen(datos.preguntas, claves, respuestas);
  } catch (e) {
    throw new HttpsError('internal', 'El examen está mal configurado.');
  }

  const usados = Math.round((Date.now() - datos.iniciadoEn.toMillis()) / 1000);
  const tiempoUsadoSegundos = Math.min(usados, datos.duracionSegundos);

  await ref.update({
    estado: 'completado',
    respuestas: Object.fromEntries(resultado.detalle.map((d) => [d.preguntaId, d.opcionElegidaId])),
    correctas: resultado.correctas,
    total: resultado.total,
    puntaje: resultado.puntaje,
    porSeccion: resultado.porSeccion,
    tiempoUsadoSegundos,
    terminadoEn: FieldValue.serverTimestamp(),
  });

  return { ...resultado, tiempoUsadoSegundos };
});

module.exports = { revisarPreguntaExamen, iniciarSimulacro, enviarSimulacro };
