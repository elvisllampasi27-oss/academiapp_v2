'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const {
  MAXIMO_HISTORIAL, validarConsulta, fechaLima, construirInstrucciones,
} = require('./consulta');
const { generarConGemini } = require('./proveedores/gemini');
const { leerConfiguracion, esPremium, limiteTutor } = require('../comun/plan');

// En el emulador se lee de functions/.secret.local (nunca se sube a git).
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

/**
 * Responde una duda del estudiante sobre un tema publicado, con el material
 * del tema como contexto. El proveedor de IA vive aquí (servidor): se puede
 * cambiar (p. ej. a Anthropic) sin tocar la app.
 */
const preguntarTutor = onCall(
  { secrets: [GEMINI_API_KEY], timeoutSeconds: 90 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }

    const error = validarConsulta(request.data);
    if (error) throw new HttpsError('invalid-argument', error);

    const db = admin.firestore();
    const uid = request.auth.uid;
    const { versionId, temaId } = request.data;
    const pregunta = request.data.pregunta.trim();
    const historial = (request.data.historial || []).slice(-MAXIMO_HISTORIAL);

    const [usuarioSnap, matriculas, publicacion, curriculoSnap, contenidosSnap, materialSnap,
      configuracion] =
      await Promise.all([
        db.collection('usuarios').doc(uid).get(),
        db.collection('matriculas')
          .where('usuarioId', '==', uid)
          .where('estado', '==', 'activa')
          .limit(1)
          .get(),
        db.collection('publicaciones_temas').doc(`${versionId}__${temaId}`).get(),
        db.collection('curriculos').doc(versionId).get(),
        db.collection('contenidos')
          .where('temaId', '==', temaId)
          .where('activo', '==', true)
          .get(),
        // Texto de la separata (opcional), cargado por el equipo académico.
        db.collection('material_tutor').doc(`${versionId}__${temaId}`).get(),
        leerConfiguracion(db),
      ]);

    const usuario = usuarioSnap.data();
    if (!usuario || usuario.rol !== 'estudiante' || usuario.estado !== 'activo') {
      throw new HttpsError('permission-denied', 'Tu cuenta no puede usar el tutor.');
    }

    const matricula = matriculas.empty ? null : matriculas.docs[0].data();
    if (!matricula || matricula.versionId !== versionId) {
      throw new HttpsError('permission-denied', 'No tienes una matrícula activa para esta versión.');
    }

    if (!publicacion.exists || publicacion.data().publicada !== true) {
      throw new HttpsError('failed-precondition', 'Este tema todavía no está publicado.');
    }

    const curriculo = curriculoSnap.data() || {};
    const tema = (curriculo.temas || []).find((t) => t.id === temaId);
    const curso = tema && (curriculo.cursos || []).find((c) => c.id === tema.cursoId);
    if (!tema) {
      throw new HttpsError('failed-precondition', 'No se encontró el tema.');
    }

    // Solo en el emulador y si se pide (functions/.env.local con
    // TUTOR_SIMULADO=true): una respuesta de prueba al instante, para poder
    // trabajar la app (puma, voz, chat) sin depender de que Gemini responda.
    // No descuenta dudas del día.
    if (process.env.FUNCTIONS_EMULATOR === 'true' && process.env.TUTOR_SIMULADO === 'true') {
      return { respuesta: respuestaSimulada(tema.titulo, pregunta), restantesHoy: null, limiteDiario: null };
    }

    const clave = GEMINI_API_KEY.value();
    if (!clave) {
      throw new HttpsError(
        'failed-precondition',
        'El tutor no está configurado (falta GEMINI_API_KEY en functions/.secret.local).',
      );
    }

    // Límite diario según el plan (panel → Configuración). Se descuenta
    // antes de llamar a la IA y se devuelve si falla.
    const premium = esPremium(usuario);
    const limite = limiteTutor(configuracion, premium);
    const usoRef = db.collection('uso_tutor').doc(`${uid}__${fechaLima()}`);
    const usadas = await db.runTransaction(async (tx) => {
      const uso = await tx.get(usoRef);
      const previas = uso.exists ? uso.data().consultas || 0 : 0;
      if (previas >= limite) return null;
      tx.set(usoRef, {
        usuarioId: uid,
        fecha: fechaLima(),
        consultas: previas + 1,
        actualizadoEn: FieldValue.serverTimestamp(),
      }, { merge: true });
      return previas + 1;
    });

    if (usadas === null) {
      const mas = !premium && configuracion.tutorPremium > limite
        ? ` Con Premium tienes ${configuracion.tutorPremium} al día.`
        : '';
      throw new HttpsError(
        'resource-exhausted',
        `Ya usaste tus ${limite} dudas de hoy. Vuelve mañana.${mas}`,
      );
    }

    const contenidos = contenidosSnap.docs
      .map((d) => d.data())
      .sort((a, b) => (a.orden || 0) - (b.orden || 0))
      .map((c) => c.nombre);

    const instrucciones = construirInstrucciones({
      curso: curso ? curso.nombre : tema.cursoId,
      tema: tema.titulo,
      contenidos,
      material: materialSnap.exists ? String(materialSnap.data().texto || '').slice(0, 12000) : '',
    });

    let respuesta;
    try {
      respuesta = await generarConGemini({
        clave,
        modelo: process.env.GEMINI_MODELO,
        instrucciones,
        mensajes: [...historial, { rol: 'estudiante', texto: pregunta }],
        // Por intento: si el principal no responde se prueba el respaldo, y
        // los dos juntos quedan por debajo del límite de la función (90 s)
        // y del de la app (60 s).
        tiempoMaximoMs: 25000,
      });
    } catch (e) {
      await usoRef.update({ consultas: FieldValue.increment(-1) }).catch(() => {});
      logger.error('Fallo del proveedor de IA', { estado: e.estado, detalle: e.detalle, mensaje: e.message });

      // En el emulador se muestra la causa real para poder corregirla.
      if (process.env.FUNCTIONS_EMULATOR === 'true') {
        throw new HttpsError(
          'failed-precondition',
          `Tutor (desarrollo): ${e.estado || ''} ${e.message} ${String(e.detalle || '').slice(0, 300)}`,
        );
      }

      if (e.estado === 429) {
        throw new HttpsError('resource-exhausted', 'El tutor está muy ocupado. Inténtalo en un minuto.');
      }
      if (e.estado === 504 || e.estado === 503) {
        throw new HttpsError('unavailable', 'El tutor tardó demasiado en responder. Inténtalo de nuevo.');
      }
      throw new HttpsError('internal', 'El tutor no pudo responder.');
    }

    return {
      respuesta,
      restantesHoy: Math.max(0, limite - usadas),
      limiteDiario: limite,
    };
  },
);

/** Respuesta de prueba del modo simulado (con una fórmula, para la voz). */
function respuestaSimulada(tema, pregunta) {
  return `(Respuesta de prueba, sin Gemini) Preguntaste: «${pregunta}». `
    + `En ${tema}, por ejemplo: si $P(x) = x^2 + 3$, entonces $P(1) = 4$, `
    + 'y $\\frac{12}{4} = 3$. Cuando Gemini responda, aquí verás la explicación real.';
}

module.exports = { preguntarTutor, respuestaSimulada };
