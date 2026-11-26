'use strict';

/**
 * Firestore de mentira para las pruebas de cobro: documentos, consultas con
 * where/limit, transacciones (leen y escriben al final), merge e
 * incrementos. No trae pruebas propias.
 */
function firestoreFalso(inicial = {}) {
  const datos = inicial;
  let n = 0;

  const leerDoc = (c, id) => {
    const d = datos[c] && datos[c][id];
    return { exists: d != null, id, data: () => d, ref: referencia(c, id) };
  };

  function referencia(c, id) {
    return { path: `${c}/${id}`, coleccion: c, id, get: async () => leerDoc(c, id) };
  }

  function consulta(c, filtros = [], limite = null) {
    return {
      esConsulta: true,
      where: (campo, op, valor) => consulta(c, [...filtros, [campo, valor]], limite),
      limit: (k) => consulta(c, filtros, k),
      async get() {
        return leerConsulta(this);
      },
      c,
      filtros,
      limite,
    };
  }

  function leerConsulta(q) {
    let docs = Object.keys(datos[q.c] || {})
      .filter((id) => q.filtros.every(([campo, valor]) => datos[q.c][id][campo] === valor))
      .map((id) => leerDoc(q.c, id));
    if (q.limite != null) docs = docs.slice(0, q.limite);
    return { empty: docs.length === 0, size: docs.length, docs };
  }

  function escribir(r, d, opciones) {
    datos[r.coleccion] = datos[r.coleccion] || {};
    const previo = (opciones && opciones.merge && datos[r.coleccion][r.id]) || {};
    const nuevo = { ...previo };
    for (const [k, v] of Object.entries(d)) {
      // FieldValue.increment(n) de firebase-admin.
      const suma = v && v.constructor && v.constructor.name === 'NumericIncrementTransform'
        ? v.operand
        : null;
      nuevo[k] = suma != null ? (previo[k] || 0) + suma : v;
    }
    datos[r.coleccion][r.id] = nuevo;
  }

  return {
    datos,
    collection: (c) => ({
      doc: (id) => referencia(c, id ?? `auto${++n}`),
      where: (campo, op, valor) => consulta(c).where(campo, op, valor),
    }),
    async runTransaction(fn) {
      const escrituras = [];
      const tx = {
        get: async (r) => (r.esConsulta ? leerConsulta(r) : leerDoc(r.coleccion, r.id)),
        set: (r, d, o) => escrituras.push([r, d, o]),
      };
      const resultado = await fn(tx);
      for (const [r, d, o] of escrituras) escribir(r, d, o);
      return resultado;
    },
  };
}

module.exports = { firestoreFalso };
