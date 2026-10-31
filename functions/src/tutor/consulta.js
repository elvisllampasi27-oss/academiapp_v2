'use strict';

/** Límites de una consulta al tutor (cuidan el costo y el abuso). */
const MAXIMO_PREGUNTA = 600;
const MAXIMO_TURNO = 2000;
const MAXIMO_HISTORIAL = 6;

/** Devuelve un mensaje de error para el estudiante, o null si es válida. */
function validarConsulta(data) {
  if (!data || typeof data !== 'object') return 'Consulta inválida.';

  const { versionId, temaId, pregunta, historial } = data;

  if (typeof versionId !== 'string' || !versionId) return 'Falta la versión.';
  if (typeof temaId !== 'string' || !temaId) return 'Falta el tema.';
  if (typeof pregunta !== 'string' || !pregunta.trim()) return 'Escribe tu duda.';
  if (pregunta.length > MAXIMO_PREGUNTA) {
    return `Tu duda es muy larga (máximo ${MAXIMO_PREGUNTA} caracteres).`;
  }

  if (historial !== undefined) {
    if (!Array.isArray(historial) || historial.length > MAXIMO_HISTORIAL) {
      return 'Historial inválido.';
    }
    for (const turno of historial) {
      if (!turno || !['estudiante', 'tutor'].includes(turno.rol)
        || typeof turno.texto !== 'string' || turno.texto.length > MAXIMO_TURNO) {
        return 'Historial inválido.';
      }
    }
  }

  return null;
}

/** Fecha (AAAA-MM-DD) en Perú: el límite diario se reinicia a medianoche de Lima. */
function fechaLima(fecha = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'America/Lima', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(fecha);
}

/** Instrucciones del tutor, con el material del tema como contexto. */
function construirInstrucciones({ curso, tema, contenidos, material }) {
  const lineas = [
    'Eres el tutor de AcademiApp, una academia preuniversitaria que prepara a',
    'postulantes a la Universidad Nacional San Cristóbal de Huamanga (UNSCH, Ayacucho, Perú).',
    `El estudiante está en el tema «${tema}» del curso ${curso}.`,
  ];

  if (contenidos.length) {
    lineas.push('', 'Contenidos del tema:', ...contenidos.map((c) => `- ${c}`));
  }

  if (material) {
    lineas.push('', 'Material del tema (úsalo como fuente principal):', material);
  }

  lineas.push(
    '',
    'Cómo responder:',
    '- En español claro y cercano, como un buen profesor de academia.',
    '- Breve: lo necesario para resolver la duda (unas 150 palabras), salvo que pida más detalle.',
    '- Si es un ejercicio, explica paso a paso y verifica el resultado.',
    '- Escribe las fórmulas en LaTeX entre signos de dólar, por ejemplo $x^2 + 1$.',
    '- Si la duda no es de este tema ni de la preparación preuniversitaria, dilo con amabilidad y vuelve al tema.',
    '- No inventes datos. Si no estás seguro, dilo.',
  );

  return lineas.join('\n');
}

module.exports = {
  MAXIMO_HISTORIAL,
  validarConsulta,
  fechaLima,
  construirInstrucciones,
};
