'use strict';

/** ¿Es sábado o domingo en Perú? (el examen tipo admisión solo se da esos días) */
function esFinDeSemanaLima(fecha = new Date()) {
  const dia = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Lima', weekday: 'short' }).format(fecha);
  return dia === 'Sat' || dia === 'Sun';
}

/** Mezcla (Fisher-Yates) sin modificar la lista original. */
function mezclar(lista, aleatorio = Math.random) {
  const copia = [...lista];
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(aleatorio() * (i + 1));
    [copia[i], copia[j]] = [copia[j], copia[i]];
  }
  return copia;
}

/**
 * Elige [total] preguntas repartidas por sección en proporción al banco
 * (como el examen real) y las devuelve agrupadas por sección.
 * @param {{id: string, seccion: string}[]} banco
 */
function elegirPreguntas(banco, total, aleatorio = Math.random) {
  const grupos = new Map();
  for (const p of banco) {
    if (!grupos.has(p.seccion)) grupos.set(p.seccion, []);
    grupos.get(p.seccion).push(p);
  }

  const n = Math.min(total, banco.length);
  const secciones = [...grupos.keys()];
  // Cuotas por "mayor resto" para que sumen exactamente n.
  const exactas = secciones.map((s) => (grupos.get(s).length / banco.length) * n);
  const cuotas = exactas.map(Math.floor);
  const faltan = n - cuotas.reduce((a, b) => a + b, 0);
  secciones
    .map((s, i) => ({ i, resto: exactas[i] - cuotas[i] }))
    .sort((a, b) => b.resto - a.resto)
    .slice(0, faltan)
    .forEach(({ i }) => { cuotas[i] += 1; });

  return secciones.flatMap((s, i) => mezclar(grupos.get(s), aleatorio).slice(0, cuotas[i]));
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

module.exports = { esFinDeSemanaLima, mezclar, elegirPreguntas, calificarExamen };
