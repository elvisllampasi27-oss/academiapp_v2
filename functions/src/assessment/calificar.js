'use strict';

/**
 * Califica un intento. Función pura (sin Firebase) para poder probarla.
 *
 * @param {Array<{id:string, dificultad:string, opciones:Array<{id:string}>}>} preguntas
 * @param {Map<string,{opcionCorrectaId:string, explicacion?:string|null}>} claves
 * @param {Object<string,string>} respuestas  preguntaId -> opcionId elegida
 */
function calificar(preguntas, claves, respuestas) {
  const detalle = preguntas.map((pregunta) => {
    const clave = claves.get(pregunta.id);
    if (!clave) {
      throw new Error(`La pregunta ${pregunta.id} no tiene clave de respuesta.`);
    }

    const elegida = respuestas[pregunta.id];
    // Una opción que no pertenece a la pregunta cuenta como no respondida.
    const opcionValida = pregunta.opciones.some((o) => o.id === elegida);
    const opcionElegidaId = opcionValida ? elegida : null;

    return {
      preguntaId: pregunta.id,
      dificultad: pregunta.dificultad,
      opcionElegidaId,
      opcionCorrectaId: clave.opcionCorrectaId,
      esCorrecta: opcionElegidaId !== null && opcionElegidaId === clave.opcionCorrectaId,
      explicacion: clave.explicacion || null,
    };
  });

  const total = detalle.length;
  const correctas = detalle.filter((d) => d.esCorrecta).length;
  const puntaje = total === 0 ? 0 : (correctas / total) * 100;

  return { total, correctas, incorrectas: total - correctas, puntaje, detalle };
}

/**
 * Habilidades que mide una pregunta. Si el docente no definió ninguna,
 * se usa la habilidad general del tema.
 */
function habilidadesDePregunta(pregunta, temaId) {
  const definidas = Array.isArray(pregunta.habilidades)
    ? pregunta.habilidades.filter((h) => typeof h === 'string' && h.trim())
    : [];
  return definidas.length ? [...new Set(definidas)] : [`${temaId}__general`];
}

/** Valida la forma de los datos que envía la app. Devuelve un mensaje de error o null. */
function validarSolicitud(data) {
  if (!data || typeof data !== 'object') return 'Solicitud vacía.';
  if (typeof data.evaluacionId !== 'string' || !data.evaluacionId) return 'Falta evaluacionId.';
  const r = data.respuestas;
  if (!r || typeof r !== 'object' || Array.isArray(r)) return 'respuestas debe ser un objeto.';
  const entradas = Object.entries(r);
  if (entradas.length > 100) return 'Demasiadas respuestas.';
  if (entradas.some(([k, v]) => typeof k !== 'string' || typeof v !== 'string')) {
    return 'Cada respuesta debe ser texto.';
  }
  return null;
}

module.exports = { calificar, validarSolicitud, habilidadesDePregunta };
