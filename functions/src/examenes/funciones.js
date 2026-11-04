'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { FieldValue, Timestamp } = require('firebase-admin/firestore');
const { verificarEstudiante } = require('../comun/estudiante');
const { leerConfiguracion, esPremium } = require('../comun/plan');
const {
  semanaDeExamen,
  cierreExamenMs,
  idExamenSemanal,
  idSimulacroSemanal,
  nombreCorto,
  ordenarRanking,
  calificarExamen,
} = require('./reglas');

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

/** ¿El intento sigue abierto (con el margen para el envío automático)? */
const sigueEnCurso = (d, ahora) => d.estado === 'en_curso'
  && d.venceEn.toMillis() + MARGEN_SEGUNDOS * 1000 > ahora;

/** Firestore: el documento ya existe (create() de dos llamadas a la vez). */
const yaExiste = (e) => e && (e.code === 6 || e.code === 'already-exists');

/** Las preguntas de un simulacro viejo (al azar) están en otra colección. */
const coleccionesDe = (datos) => (datos.examenSemanalId
  ? { preguntas: 'preguntas_semanales', claves: 'claves_semanales' }
  : { preguntas: 'preguntas_examen', claves: 'claves_examen' });

/**
 * Qué examen semanal le toca ahora al estudiante y en qué va: para la
 * tarjeta de Exámenes y el aviso del Inicio. No da preguntas.
 */
const estadoExamenSemanal = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const db = admin.firestore();
  const uid = request.auth.uid;
  const matricula = await verificarEstudiante(db, uid);
  const ahora = Date.now();
  const semana = semanaDeExamen(matricula.fechaInicioAcademico.toMillis(), ahora);
  if (semana < 1) return { semana: 0 };

  const examenId = idExamenSemanal(matricula.versionId, semana);
  const [examenSnap, previoSnap, usuarioSnap, configuracion] = await Promise.all([
    db.collection('examenes_semanales').doc(examenId).get(),
    db.collection('simulacros').doc(idSimulacroSemanal(uid, examenId)).get(),
    db.collection('usuarios').doc(uid).get(),
    leerConfiguracion(db),
  ]);
  const examen = examenSnap.data();
  const previo = previoSnap.exists ? previoSnap.data() : null;
  const enCurso = previo && sigueEnCurso(previo, ahora);

  return {
    semana,
    titulo: examen ? examen.titulo : `Semana ${semana}`,
    publicado: Boolean(examen && examen.estado === 'publicado'),
    totalPreguntas: examen ? examen.totalPreguntas || 0 : 0,
    estado: !previo ? 'pendiente' : (enCurso ? 'en_curso' : 'completado'),
    puntaje: previo && previo.estado === 'completado' ? previo.puntaje : null,
    cierraEnMs: cierreExamenMs(ahora),
    requierePremium: Boolean(configuracion.simulacroSoloPremium && !esPremium(usuarioSnap.data())),
  };
});

/**
 * Examen semanal: el de la última semana que el estudiante completó (según
 * su fecha de inicio). Se abre el sábado y queda abierto hasta el sábado
 * siguiente. Un solo intento. Si ya hay uno en curso, lo devuelve (así
 * recargar la app no lo pierde).
 */
const iniciarSimulacro = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const db = admin.firestore();
  const uid = request.auth.uid;
  const matricula = await verificarEstudiante(db, uid);

  const ahora = Date.now();
  const semana = semanaDeExamen(matricula.fechaInicioAcademico.toMillis(), ahora);
  if (semana < 1) {
    throw new HttpsError('failed-precondition', 'Tu primer examen semanal se abre el sábado de tu primera semana.');
  }
  const examenId = idExamenSemanal(matricula.versionId, semana);

  const simulacroRef = db.collection('simulacros').doc(idSimulacroSemanal(uid, examenId));
  const [examenSnap, previoSnap, usuarioSnap, configuracion] = await Promise.all([
    db.collection('examenes_semanales').doc(examenId).get(),
    simulacroRef.get(),
    db.collection('usuarios').doc(uid).get(),
    leerConfiguracion(db),
  ]);

  const yaLoDio = () => new HttpsError(
    'failed-precondition',
    `Ya diste el examen de la semana ${semana}. Mira tu puesto en el ranking.`,
  );
  let datos;

  if (previoSnap.exists) {
    datos = previoSnap.data();
    if (!sigueEnCurso(datos, ahora)) throw yaLoDio();
  } else {
    if (configuracion.simulacroSoloPremium && !esPremium(usuarioSnap.data())) {
      throw new HttpsError(
        'permission-denied',
        'El examen semanal es para Premium. Hazte Premium desde tu Perfil.',
      );
    }
    const examen = examenSnap.data();
    if (!examenSnap.exists || examen.estado !== 'publicado') {
      throw new HttpsError('failed-precondition', `El examen de tu semana ${semana} todavía no está listo. Vuelve más tarde.`);
    }

    const preguntasSnap = await db.collection('preguntas_semanales')
      .where('examenId', '==', examenId)
      .get();
    const preguntas = preguntasSnap.docs
      .filter((d) => d.data().activa === true)
      .sort((a, b) => a.data().numero - b.data().numero)
      .map((d) => ({ id: d.id, seccion: d.data().seccion }));
    if (preguntas.length === 0) {
      throw new HttpsError('failed-precondition', 'Este examen todavía no tiene preguntas.');
    }

    const duracionSegundos = preguntas.length * SEGUNDOS_POR_PREGUNTA;
    datos = {
      usuarioId: uid,
      nombre: (usuarioSnap.data() || {}).nombre || '',
      examenSemanalId: examenId,
      versionId: matricula.versionId,
      semana,
      titulo: examen.titulo || `Semana ${semana}`,
      preguntas,
      estado: 'en_curso',
      duracionSegundos,
      iniciadoEn: Timestamp.fromMillis(ahora),
      venceEn: Timestamp.fromMillis(ahora + duracionSegundos * 1000),
    };
    try {
      // create() falla si ya existe: de dos llamadas a la vez, solo una crea
      // el intento y la otra recibe ese mismo.
      await simulacroRef.create(datos);
    } catch (e) {
      if (!yaExiste(e)) throw e;
      datos = (await simulacroRef.get()).data();
      if (!sigueEnCurso(datos, ahora)) throw yaLoDio();
    }
  }

  const { preguntas: coleccion } = coleccionesDe(datos);
  const snaps = await db.getAll(
    ...datos.preguntas.map((p) => db.collection(coleccion).doc(p.id)),
  );

  return {
    simulacroId: simulacroRef.id,
    titulo: datos.titulo || 'Examen semanal',
    semana: datos.semana || null,
    duracionSegundos: datos.duracionSegundos,
    venceEnMs: datos.venceEn.toMillis(),
    preguntas: snaps.filter((s) => s.exists).map(publica),
  };
});

/**
 * Ranking de un examen semanal: los 10 primeros y el puesto del que
 * pregunta. Sin [examenId], el último examen semanal que dio.
 */
const rankingSemanal = onCall(async (request) => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');

  const db = admin.firestore();
  const uid = request.auth.uid;
  await verificarEstudiante(db, uid);

  let { examenId } = request.data || {};
  if (examenId !== undefined && (typeof examenId !== 'string' || !/^[\w-]+__s\d{2}$/.test(examenId))) {
    throw new HttpsError('invalid-argument', 'Examen inválido.');
  }
  if (!examenId) {
    const mios = await db.collection('simulacros')
      .where('usuarioId', '==', uid)
      .where('estado', '==', 'completado')
      .get();
    const ultimo = mios.docs
      .map((d) => d.data())
      .filter((d) => d.examenSemanalId)
      .sort((a, b) => b.terminadoEn.toMillis() - a.terminadoEn.toMillis())[0];
    if (!ultimo) return { examenId: null };
    examenId = ultimo.examenSemanalId;
  }

  const resultados = await db.collection('simulacros')
    .where('examenSemanalId', '==', examenId)
    .where('estado', '==', 'completado')
    .get();
  const filas = ordenarRanking(resultados.docs.map((d) => {
    const r = d.data();
    return {
      usuarioId: r.usuarioId,
      nombre: nombreCorto(r.nombre),
      titulo: r.titulo,
      semana: r.semana,
      puntaje: r.puntaje || 0,
      correctas: r.correctas || 0,
      total: r.total || 0,
      tiempoUsadoSegundos: r.tiempoUsadoSegundos || 0,
      terminadoMs: r.terminadoEn ? r.terminadoEn.toMillis() : 0,
    };
  }));
  const publicaFila = (f) => ({
    puesto: f.puesto,
    nombre: f.nombre,
    puntaje: f.puntaje,
    correctas: f.correctas,
    total: f.total,
    tiempoUsadoSegundos: f.tiempoUsadoSegundos,
    soyYo: f.usuarioId === uid,
  });
  const yo = filas.find((f) => f.usuarioId === uid);

  return {
    examenId,
    titulo: filas[0] ? filas[0].titulo : null,
    semana: filas[0] ? filas[0].semana : null,
    participantes: filas.length,
    top: filas.slice(0, 10).map(publicaFila),
    yo: yo ? publicaFila(yo) : null,
  };
});

/** Corrige el examen semanal y guarda el resultado. */
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
  if (!snap.exists || snap.data().usuarioId !== uid) {
    throw new HttpsError('not-found', 'No se encontró tu examen.');
  }

  const { claves: coleccionClaves } = coleccionesDe(snap.data());
  const clavesSnap = await db.getAll(
    ...snap.data().preguntas.map((p) => db.collection(coleccionClaves).doc(p.id)),
  );
  const claves = new Map(clavesSnap.filter((s) => s.exists).map((s) => [s.id, s.data()]));
  const corregir = (preguntas, r) => {
    try {
      return calificarExamen(preguntas, claves, r);
    } catch (e) {
      throw new HttpsError('internal', 'El examen está mal configurado.');
    }
  };

  // En una transacción: si llegan dos envíos a la vez (doble toque o el
  // envío automático al acabarse el tiempo), solo uno lo corrige.
  const hecho = await db.runTransaction(async (tx) => {
    const datos = (await tx.get(ref)).data();
    if (datos.estado !== 'en_curso') return { yaEnviado: datos };

    const resultado = corregir(datos.preguntas, respuestas);
    const usados = Math.round((Date.now() - datos.iniciadoEn.toMillis()) / 1000);
    const tiempoUsadoSegundos = Math.min(usados, datos.duracionSegundos);
    tx.update(ref, {
      estado: 'completado',
      respuestas: Object.fromEntries(resultado.detalle.map((d) => [d.preguntaId, d.opcionElegidaId])),
      correctas: resultado.correctas,
      total: resultado.total,
      puntaje: resultado.puntaje,
      porSeccion: resultado.porSeccion,
      tiempoUsadoSegundos,
      terminadoEn: FieldValue.serverTimestamp(),
    });
    return { resultado, tiempoUsadoSegundos };
  });

  // Ya estaba enviado: se devuelve lo guardado (la primera corrección).
  if (hecho.yaEnviado) {
    const d = hecho.yaEnviado;
    return {
      ...corregir(d.preguntas, d.respuestas || {}),
      tiempoUsadoSegundos: d.tiempoUsadoSegundos || 0,
    };
  }
  return { ...hecho.resultado, tiempoUsadoSegundos: hecho.tiempoUsadoSegundos };
});

module.exports = {
  revisarPreguntaExamen,
  iniciarSimulacro,
  enviarSimulacro,
  rankingSemanal,
  estadoExamenSemanal,
};
