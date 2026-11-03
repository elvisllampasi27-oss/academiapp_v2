'use strict';

const DIA_MS = 24 * 60 * 60 * 1000;
/** Perú no cambia de hora: siempre UTC-5. */
const DESFASE_LIMA_MS = 5 * 60 * 60 * 1000;

/** Número de día (desde 1970) de la fecha en Lima. */
function diaLima(ms) {
  return Math.floor((ms - DESFASE_LIMA_MS) / DIA_MS);
}

/** 0 = lunes … 6 = domingo, para un número de día. */
function diaSemana(dia) {
  // El 1 de enero de 1970 fue jueves (3).
  return (dia + 3) % 7;
}

/**
 * Semana académica del estudiante (1, 2, 3…) en la fecha [ahoraMs]. La
 * semana va de lunes a domingo; si empezó un sábado o domingo, su semana 1
 * es la siguiente. 0 si todavía no le toca ninguna.
 */
function semanaAcademica(inicioMs, ahoraMs) {
  const inicio = diaLima(inicioMs);
  let lunesInicio = inicio - diaSemana(inicio);
  if (diaSemana(inicio) >= 5) lunesInicio += 7;
  const hoy = diaLima(ahoraMs);
  if (hoy < inicio || hoy < lunesInicio) return 0;
  return Math.floor((hoy - lunesInicio) / 7) + 1;
}

/**
 * Qué examen semanal le toca: el de la semana N se abre el sábado de esa
 * semana y queda abierto hasta que el sábado siguiente se abre el N+1.
 * 0 si todavía no le toca ninguno.
 */
function semanaDeExamen(inicioMs, ahoraMs) {
  const semana = semanaAcademica(inicioMs, ahoraMs);
  const finDeSemana = diaSemana(diaLima(ahoraMs)) >= 5;
  return finDeSemana ? semana : Math.max(semana - 1, 0);
}

/** Cuándo cierra el examen abierto ahora: el próximo sábado 00:00 de Lima. */
function cierreExamenMs(ahoraMs) {
  const hoy = diaLima(ahoraMs);
  const faltan = ((5 - diaSemana(hoy) + 7) % 7) || 7;
  return (hoy + faltan) * DIA_MS + DESFASE_LIMA_MS;
}

/** Id del examen semanal: `{version}__s03`. */
function idExamenSemanal(versionId, semana) {
  return `${versionId}__s${String(semana).padStart(2, '0')}`;
}

/** "Ana María Quispe Rojas" -> "Ana Q." (el ranking no muestra el nombre completo). */
function nombreCorto(nombre) {
  const partes = String(nombre || '').trim().split(/\s+/).filter(Boolean);
  if (partes.length === 0) return 'Estudiante';
  if (partes.length === 1) return partes[0];
  const apellido = partes.length >= 3 ? partes[partes.length - 2] : partes[1];
  return `${partes[0]} ${apellido[0].toUpperCase()}.`;
}

/**
 * Ordena los resultados para el ranking: más puntaje, luego menos tiempo,
 * luego quién terminó antes. Devuelve copias con su puesto.
 * @param {{usuarioId: string, puntaje: number, tiempoUsadoSegundos: number, terminadoMs: number}[]} resultados
 */
function ordenarRanking(resultados) {
  return [...resultados]
    .sort((a, b) => b.puntaje - a.puntaje
      || a.tiempoUsadoSegundos - b.tiempoUsadoSegundos
      || a.terminadoMs - b.terminadoMs)
    .map((r, i) => ({ ...r, puesto: i + 1 }));
}

/**
 * Corrige un examen completo.
 * @param {{id: string, seccion: string}[]} preguntas en el orden en que se dieron
 * @param {Map<string, {opcionCorrectaId: string, solucion?: string, imagenSolucion?: string}>} claves
 * @param {Record<string, string>} respuestas preguntaId -> opcionId (puede faltar)
 */
function calificarExamen(preguntas, claves, respuestas) {
  const porSeccion = new Map();
  const detalle = preguntas.map((p) => {
    const clave = claves.get(p.id);
    if (!clave) throw new Error(`Falta la clave de ${p.id}`);

    const elegida = typeof respuestas[p.id] === 'string' ? respuestas[p.id] : null;
    const esCorrecta = elegida === clave.opcionCorrectaId;

    const s = porSeccion.get(p.seccion) || { nombre: p.seccion, correctas: 0, total: 0 };
    s.total += 1;
    if (esCorrecta) s.correctas += 1;
    porSeccion.set(p.seccion, s);

    return {
      preguntaId: p.id,
      opcionElegidaId: elegida,
      opcionCorrectaId: clave.opcionCorrectaId,
      esCorrecta,
      solucion: clave.solucion || null,
      imagenSolucion: clave.imagenSolucion || null,
    };
  });

  const correctas = detalle.filter((d) => d.esCorrecta).length;
  return {
    correctas,
    total: detalle.length,
    puntaje: detalle.length ? Math.round((correctas / detalle.length) * 100) : 0,
    porSeccion: [...porSeccion.values()],
    detalle,
  };
}

module.exports = {
  semanaAcademica,
  semanaDeExamen,
  cierreExamenMs,
  idExamenSemanal,
  nombreCorto,
  ordenarRanking,
  calificarExamen,
};
