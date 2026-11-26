'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  ingresoReciente,
  uidValido,
  pagoSinDatosPersonales,
  eliminarDatosDeCuenta,
  MAX_SEGUNDOS_DESDE_INGRESO,
} = require('../src/cuenta/eliminar_cuenta');

const UID = 'alumnoUid1234567890';
const OTRO = 'otroUid12345678901';
const BORRAR = Symbol('borrar');

/** Una base de datos de mentira que anota todo lo que se le pide. */
function entorno(datos, { fallaAlBorrar = false } = {}) {
  const orden = [];
  const hechos = { borrados: [], actualizados: {}, creados: [], recursivos: [], orden };
  const ref = (coleccion, id) => ({ path: `${coleccion}/${id}`, coleccion });
  const db = {
    collection(coleccion) {
      return {
        doc: (id) => ref(coleccion, id ?? 'nuevo'),
        where: (campo, op, valor) => ({
          select: () => ({
            async get() {
              const docs = Object.entries(datos[coleccion] || {})
                .filter(([, d]) => d[campo] === valor)
                .map(([id]) => ({ ref: ref(coleccion, id) }));
              return { docs, size: docs.length };
            },
          }),
        }),
      };
    },
    bulkWriter() {
      return {
        delete(r) {
          if (fallaAlBorrar) return Promise.reject(new Error('sin conexión'));
          hechos.borrados.push(r.path);
          return Promise.resolve();
        },
        update(r, d) {
          hechos.actualizados[r.path] = d;
          return Promise.resolve();
        },
        create(r, d) {
          hechos.creados.push({ coleccion: r.coleccion, ...d });
          return Promise.resolve();
        },
        async close() {
          orden.push('datos');
        },
      };
    },
    async recursiveDelete(r) {
      hechos.recursivos.push(r.path);
    },
  };
  const bucket = {
    async deleteFiles({ prefix }) {
      orden.push(`storage:${prefix}`);
    },
  };
  const auth = {
    async deleteUser(uid) {
      orden.push(`acceso:${uid}`);
    },
  };
  return { db, bucket, auth, borrarCampo: BORRAR, hechos };
}

const datosEjemplo = () => ({
  matriculas: { m1: { usuarioId: UID }, m2: { usuarioId: OTRO } },
  respuestas: { r1: { usuarioId: UID }, r2: { usuarioId: UID }, r3: { usuarioId: OTRO } },
  evidencias: { e1: { usuarioId: UID } },
  uso_tutor: { [`${UID}__2026-11-25`]: { usuarioId: UID } },
  simulacros: { s1: { usuarioId: UID, nombre: 'Ana Q.' } },
  reportes: { rep1: { usuarioId: UID } },
  clases_docente: { c1: { docenteUid: UID }, c2: { docenteUid: OTRO } },
  en_vivos: { v1: { docenteUid: UID } },
  pagos: { 'yape__123456': { usuarioId: UID, nombre: 'Ana Quispe' }, 'yape__999999': { usuarioId: OTRO } },
  registro_admin: { a1: { usuarioId: UID, descripcion: 'Aprobó el pago de Ana Quispe' } },
});

test('el ingreso vale para borrar la cuenta solo si fue hace poco', () => {
  const ahora = Date.parse('2026-11-25T23:00:00Z');
  const hace = (s) => ahora / 1000 - s;
  assert.equal(ingresoReciente(hace(60), ahora), true);
  assert.equal(ingresoReciente(hace(MAX_SEGUNDOS_DESDE_INGRESO), ahora), true);
  assert.equal(ingresoReciente(hace(MAX_SEGUNDOS_DESDE_INGRESO + 1), ahora), false);
  assert.equal(ingresoReciente(undefined, ahora), false);
});

test('el uid del alumno no puede traer barras ni estar vacío', () => {
  assert.equal(uidValido(UID), true);
  assert.equal(uidValido(''), false);
  assert.equal(uidValido('../usuarios/x'), false);
  assert.equal(uidValido(42), false);
});

test('de un pago queda el monto y la operación, sin datos personales', () => {
  const p = pagoSinDatosPersonales(BORRAR);
  assert.equal(p.nombre, 'Cuenta eliminada');
  assert.equal(p.correo, '');
  assert.equal(p.fotoUrl, BORRAR);
  assert.ok(!('monto' in p) && !('operacion' in p));
});

test('borra todo lo del alumno y nada de otros', async () => {
  const e = entorno(datosEjemplo());
  const r = await eliminarDatosDeCuenta({ ...e, uid: UID, quien: { uid: UID, esAdmin: false } });

  for (const path of [
    'matriculas/m1', 'respuestas/r1', 'respuestas/r2', 'evidencias/e1',
    `uso_tutor/${UID}__2026-11-25`, 'simulacros/s1', 'reportes/rep1', 'en_vivos/v1',
    `usuarios/${UID}`, `solicitudes_docente/${UID}`, `docentes/${UID}`,
  ]) {
    assert.ok(e.hechos.borrados.includes(path), `debió borrar ${path}`);
  }
  for (const path of ['matriculas/m2', 'respuestas/r3', 'clases_docente/c2']) {
    assert.ok(!e.hechos.borrados.includes(path), `no debió borrar ${path}`);
  }
  // Las clases del docente se borran con sus corazones.
  assert.deepEqual(e.hechos.recursivos, ['clases_docente/c1']);
  assert.equal(r.pagosAnonimizados, 1);
});

test('los pagos y el registro del panel quedan sin el nombre del alumno', async () => {
  const e = entorno(datosEjemplo());
  await eliminarDatosDeCuenta({ ...e, uid: UID, quien: { uid: UID, esAdmin: false } });

  assert.equal(e.hechos.actualizados['pagos/yape__123456'].nombre, 'Cuenta eliminada');
  assert.equal(e.hechos.actualizados['pagos/yape__123456'].fotoUrl, BORRAR);
  assert.equal(e.hechos.actualizados['pagos/yape__999999'], undefined);

  const registro = e.hechos.actualizados['registro_admin/a1'];
  assert.equal(registro.usuarioId, BORRAR);
  assert.ok(!registro.descripcion.includes('Ana'));

  // Queda constancia de que se eliminó una cuenta, sin decir de quién.
  const [constancia] = e.hechos.creados;
  assert.equal(constancia.tipo, 'cuenta_eliminada');
  assert.ok(!('usuarioId' in constancia));
  assert.equal(constancia.adminCorreo, 'el propio alumno');
});

test('el acceso se borra al final, después de los datos y los comprobantes', async () => {
  const e = entorno(datosEjemplo());
  await eliminarDatosDeCuenta({ ...e, uid: UID, quien: { uid: UID, esAdmin: false } });
  assert.deepEqual(e.hechos.orden, ['datos', `storage:comprobantes/${UID}/`, `acceso:${UID}`]);
});

test('si falla el borrado de datos, el acceso no se toca y se puede reintentar', async () => {
  const e = entorno(datosEjemplo(), { fallaAlBorrar: true });
  await assert.rejects(
    eliminarDatosDeCuenta({ ...e, uid: UID, quien: { uid: UID, esAdmin: false } }),
    /sin conexión/,
  );
  assert.ok(!e.hechos.orden.some((paso) => paso.startsWith('acceso:')));
});

test('si el acceso ya no existía, igual termina bien', async () => {
  const e = entorno(datosEjemplo());
  e.auth.deleteUser = async () => {
    throw Object.assign(new Error('no existe'), { code: 'auth/user-not-found' });
  };
  const r = await eliminarDatosDeCuenta({
    ...e, uid: UID, quien: { uid: 'adminUid123456', esAdmin: true, correo: 'a@b.pe' },
  });
  assert.ok(r.borrados > 0);
  assert.equal(e.hechos.creados[0].adminCorreo, 'a@b.pe');
});
