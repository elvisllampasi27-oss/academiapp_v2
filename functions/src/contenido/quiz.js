'use strict';

/** Lógica pura para generar quizzes con IA (sin Firebase: se prueba sola). */

const NIVELES = {
  basica: 'básico: definiciones y aplicación directa de una fórmula',
  intermedia: 'intermedio: dos pasos o combinar dos ideas del tema',
  avanzada: 'avanzado: tipo examen de admisión de la UNSCH, con trampa típica',
};
const MAXIMO_PREGUNTAS = 10;
const OPCIONES = 5;

function validarSolicitud(datos) {
  if (!datos || typeof datos !== 'object') return 'Solicitud vacía.';
  const { versionId, temaId, nivel, cantidad } = datos;
  if (typeof versionId !== 'string' || !versionId) return 'Falta la versión.';
  if (typeof temaId !== 'string' || !temaId) return 'Falta el tema.';
  if (!Object.prototype.hasOwnProperty.call(NIVELES, nivel)) return 'Nivel inválido.';
  if (!Number.isInteger(cantidad) || cantidad < 1 || cantidad > MAXIMO_PREGUNTAS) {
    return `Pide entre 1 y ${MAXIMO_PREGUNTAS} preguntas.`;
  }
  return null;
}

function construirInstruccionesQuiz({ curso, tema, contenidos, material, nivel, cantidad }) {
  return [
    'Eres profesor de una academia preuniversitaria en Ayacucho (Perú) y',
    `preparas preguntas de práctica de ${curso}, tema "${tema}".`,
    contenidos.length ? `El tema abarca: ${contenidos.join('; ')}.` : '',
    `Nivel ${NIVELES[nivel]}.`,
    `Escribe exactamente ${cantidad} preguntas de opción múltiple, cada una con`,
    `${OPCIONES} opciones y una sola correcta. Las incorrectas deben ser errores`,
    'comunes de los estudiantes, no absurdas. Usa español claro y LaTeX entre $',
    'para las fórmulas. La explicación resuelve el ejercicio en 2 a 4 pasos.',
    'Responde SOLO con JSON: {"preguntas": [{"enunciado": "...", "opciones":',
    '["...", "...", "...", "...", "..."], "correcta": 0, "explicacion": "..."}]}',
    'donde "correcta" es el índice (0 a 4) de la opción correcta.',
    material
      ? `\nUsa este material de la clase como base:\n"""\n${material.slice(0, 12000)}\n"""`
      : '',
  ].filter(Boolean).join(' ');
}

/**
 * Lee la respuesta de la IA y devuelve solo las preguntas bien formadas
 * (las demás se descartan). Lanza si no queda ninguna.
 */
function leerPreguntasGeneradas(texto) {
  let datos;
  try {
    const limpio = String(texto).trim().replace(/^```(?:json)?\s*|\s*```$/g, '');
    datos = JSON.parse(limpio);
  } catch {
    throw new Error('La IA no devolvió JSON válido.');
  }
  const lista = Array.isArray(datos) ? datos : datos && datos.preguntas;
  if (!Array.isArray(lista)) throw new Error('La IA no devolvió una lista de preguntas.');

  const preguntas = [];
  for (const p of lista) {
    if (!p || typeof p.enunciado !== 'string' || !p.enunciado.trim()) continue;
    if (!Array.isArray(p.opciones)) continue;
    const opciones = p.opciones.map((o) => String(o ?? '').trim());
    if (opciones.length < 2 || opciones.length > 8 || opciones.some((o) => !o)) continue;
    if (new Set(opciones).size !== opciones.length) continue;
    if (!Number.isInteger(p.correcta) || p.correcta < 0 || p.correcta >= opciones.length) continue;
    preguntas.push({
      enunciado: p.enunciado.trim(),
      opciones,
      correcta: p.correcta,
      explicacion: typeof p.explicacion === 'string' ? p.explicacion.trim() : '',
    });
  }
  if (preguntas.length === 0) throw new Error('Ninguna pregunta generada era válida.');
  return preguntas;
}

module.exports = { validarSolicitud, construirInstruccionesQuiz, leerPreguntasGeneradas, MAXIMO_PREGUNTAS };
