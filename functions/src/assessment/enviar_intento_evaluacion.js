'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const { calificar, validarSolicitud, habilidadesDePregunta } = require('./calificar');

/**
 * Recibe las respuestas del estudiante, corrige en el servidor (las claves
 * nunca llegan al celular), guarda el intento y sus respuestas, y devuelve
 * la corrección con explicaciones.
 */
const enviarIntentoEvaluacion = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
  }

  const error = validarSolicitud(request.data);
  if (error) throw new HttpsError('invalid-argument', error);

  const db = admin.firestore();
  const uid = request.auth.uid;
  const { evaluacionId, respuestas } = request.data;
  const tiemposMs = request.data.tiemposMs && typeof request.data.tiemposMs === 'object'
    ? request.data.tiemposMs
    : {};

  const [evaluacionSnap, usuarioSnap] = await Promise.all([
    db.collection('evaluaciones').doc(evaluacionId).get(),
    db.collection('usuarios').doc(uid).get(),
  ]);

  const evaluacion = evaluacionSnap.data();
  if (!evaluacionSnap.exists || evaluacion.estado !== 'publicada') {
    throw new HttpsError('not-found', 'Esta práctica no está disponible.');
  }

  const usuario = usuarioSnap.data();
  if (!usuario || usuario.rol !== 'estudiante' || usuario.estado !== 'activo') {
    throw new HttpsError('permission-denied', 'Tu cuenta no puede rendir evaluaciones.');
  }

  const matriculas = await db.collection('matriculas')
    .where('usuarioId', '==', uid)
    .where('estado', '==', 'activa')
    .limit(1)
    .get();
  const matricula = matriculas.empty ? null : matriculas.docs[0];
  if (!matricula || matricula.data().versionId !== evaluacion.versionId) {
    throw new HttpsError('permission-denied', 'No tienes una matrícula activa para esta versión.');
  }

  const publicacion = await db.collection('publicaciones_temas')
    .doc(`${evaluacion.versionId}__${evaluacion.temaId}`)
    .get();
  if (!publicacion.exists || publicacion.data().publicada !== true) {
    throw new HttpsError('failed-precondition', 'Este tema todavía no está publicado.');
  }

  const preguntasSnap = await db.collection('preguntas')
    .where('evaluacionId', '==', evaluacionId)
    .where('activa', '==', true)
    .get();
  if (preguntasSnap.empty) {
    throw new HttpsError('failed-precondition', 'Esta práctica no tiene preguntas.');
  }

  const preguntas = preguntasSnap.docs.map((d) => ({ id: d.id, ...d.data() }));
  const clavesSnap = await db.getAll(
    ...preguntas.map((p) => db.collection('claves_preguntas').doc(p.id)),
  );
  const claves = new Map(clavesSnap.filter((s) => s.exists).map((s) => [s.id, s.data()]));

  let resultado;
  try {
    resultado = calificar(preguntas, claves, respuestas);
  } catch (e) {
    throw new HttpsError('internal', 'La práctica está mal configurada.');
  }

  // Número de intento del estudiante en esta evaluación (para la evidencia).
  const previos = await db.collection('intentos_evaluacion')
    .where('usuarioId', '==', uid)
    .where('evaluacionId', '==', evaluacionId)
    .count()
    .get();
  const numeroIntento = previos.data().count + 1;
  const porPregunta = new Map(preguntas.map((p) => [p.id, p]));

  const ahora = FieldValue.serverTimestamp();
  const intentoRef = db.collection('intentos_evaluacion').doc();
  const lote = db.batch();

  lote.set(intentoRef, {
    usuarioId: uid,
    matriculaId: matricula.id,
    evaluacionId,
    temaId: evaluacion.temaId,
    versionId: evaluacion.versionId,
    tipo: evaluacion.tipo || 'practica',
    estado: 'completado',
    numeroIntento,
    correctas: resultado.correctas,
    total: resultado.total,
    puntaje: resultado.puntaje,
    fechaFin: ahora,
  });

  for (const d of resultado.detalle) {
    const tiempo = Number(tiemposMs[d.preguntaId]);
    lote.set(db.collection('respuestas').doc(`${intentoRef.id}__${d.preguntaId}`), {
      intentoId: intentoRef.id,
      usuarioId: uid,
      matriculaId: matricula.id,
      evaluacionId,
      temaId: evaluacion.temaId,
      preguntaId: d.preguntaId,
      opcionId: d.opcionElegidaId,
      esCorrecta: d.esCorrecta,
      dificultad: d.dificultad || 'basica',
      tiempoRespuestaMs: Number.isFinite(tiempo) && tiempo >= 0 ? Math.round(tiempo) : null,
      fecha: ahora,
    });

    // Evidencia: una por habilidad que mide la pregunta. Es la entrada del
    // modelo del estudiante (BKT). Solo el servidor puede escribirla.
    const respuestaId = `${intentoRef.id}__${d.preguntaId}`;
    for (const habilidadId of habilidadesDePregunta(porPregunta.get(d.preguntaId), evaluacion.temaId)) {
      lote.set(db.collection('evidencias').doc(`${respuestaId}-${habilidadId}`), {
        usuarioId: uid,
        matriculaId: matricula.id,
        respuestaId,
        habilidadId,
        temaId: evaluacion.temaId,
        origen: evaluacion.tipo === 'simulacro' ? 'simulacro' : 'practica',
        resultado: d.esCorrecta ? 'correcta' : 'incorrecta',
        dificultad: d.dificultad || 'basica',
        numeroIntento,
        ayudaUtilizada: false,
        fecha: ahora,
      });
    }
  }

  await lote.commit();

  return {
    intentoId: intentoRef.id,
    total: resultado.total,
    correctas: resultado.correctas,
    incorrectas: resultado.incorrectas,
    puntaje: resultado.puntaje,
    detalle: resultado.detalle.map(({ dificultad, ...resto }) => resto),
  };
});

module.exports = { enviarIntentoEvaluacion };
