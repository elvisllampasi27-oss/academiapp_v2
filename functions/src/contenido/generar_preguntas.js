'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { generarConGemini } = require('../tutor/proveedores/gemini');
const { validarSolicitud, construirInstruccionesQuiz, leerPreguntasGeneradas } = require('./quiz');

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Solo para el administrador: genera BORRADORES de preguntas de práctica
 * con el material del tema. No guarda nada: el panel las muestra para
 * revisarlas y el administrador decide qué publicar.
 */
const generarPreguntas = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 120 },
  async (request) => {
    if (request.auth?.token?.admin !== true) {
      throw new HttpsError('permission-denied', 'Solo el administrador puede generar quizzes.');
    }
    const error = validarSolicitud(request.data);
    if (error) throw new HttpsError('invalid-argument', error);

    const { versionId, temaId, nivel, cantidad } = request.data;
    const db = admin.firestore();
    const [curriculoSnap, contenidosSnap, materialSnap] = await Promise.all([
      db.collection('curriculos').doc(versionId).get(),
      db.collection('contenidos').where('temaId', '==', temaId).where('activo', '==', true).get(),
      db.collection('material_tutor').doc(`${versionId}__${temaId}`).get(),
    ]);

    const curriculo = curriculoSnap.data() || {};
    const tema = (curriculo.temas || []).find((t) => t.id === temaId);
    if (!tema) throw new HttpsError('not-found', 'No se encontró el tema.');
    const curso = (curriculo.cursos || []).find((c) => c.id === tema.cursoId);

    const clave = GEMINI_API_KEY.value();
    if (!clave) {
      throw new HttpsError('failed-precondition', 'Falta GEMINI_API_KEY en functions/.secret.local.');
    }

    const instrucciones = construirInstruccionesQuiz({
      curso: curso ? curso.nombre : tema.cursoId,
      tema: tema.titulo,
      contenidos: contenidosSnap.docs
        .map((d) => d.data())
        .sort((a, b) => (a.orden || 0) - (b.orden || 0))
        .map((c) => c.nombre),
      material: materialSnap.exists ? String(materialSnap.data().texto || '') : '',
      nivel,
      cantidad,
    });

    try {
      const texto = await generarConGemini({
        clave,
        modelo: process.env.GEMINI_MODELO,
        instrucciones,
        mensajes: [{ rol: 'estudiante', texto: `Genera las ${cantidad} preguntas.` }],
        json: true,
        maxTokens: 8192,
        // Generar varias preguntas toma más; la función tiene 120 s.
        tiempoMaximoMs: 100000,
      });
      return { preguntas: leerPreguntasGeneradas(texto).slice(0, cantidad) };
    } catch (e) {
      logger.error('No se pudo generar el quiz', { estado: e.estado, detalle: e.detalle, mensaje: e.message });
      throw new HttpsError(
        e.estado === 429 ? 'resource-exhausted' : 'internal',
        e.estado === 429
          ? 'La IA está ocupada. Inténtalo en un minuto.'
          : `No se pudo generar: ${e.message}`,
      );
    }
  },
);

module.exports = { generarPreguntas };
