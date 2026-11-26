'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');
const {
  normalizarCodigo,
  cuponVigente,
  precioConCupon,
  tokenCulqiValido,
  autenticacionValida,
  interpretarCargo,
  cotizar,
  cobrar,
} = require('../src/premium/cobro_culqi');

const DIA = 24 * 60 * 60 * 1000;
const AHORA = Date.parse('2026-12-01T15:00:00Z');
const UID = 'alumnoUid1234567890';
const TOKEN = 'tkn_test_AbCdEf123456';

/** Firestore de mentira: get directo, transacciones e incrementos. */
function baseDeDatos(inicial = {}) {
  const datos = inicial;
  const ruta = (r) => r.path.split('/');
  let n = 0;
  const leer = (r) => {
    const [c, id] = ruta(r);
    const d = datos[c] && datos[c][id];
    return { exists: d != null, data: () => d };
  };
  const escribir = (r, d, opciones) => {
    const [c, id] = ruta(r);
    datos[c] = datos[c] || {};
    const previo = (opciones && opciones.merge && datos[c][id]) || {};
    const nuevo = { ...previo };
    for (const [k, v] of Object.entries(d)) {
      // FieldValue.increment(1) de firebase-admin.
      const suma = v && v.constructor && v.constructor.name === 'NumericIncrementTransform'
        ? v.operand
        : null;
      nuevo[k] = suma != null ? (previo[k] || 0) + suma : v;
    }
    datos[c][id] = nuevo;
  };
  return {
    datos,
    collection: (c) => ({ doc: (id) => ({ path: `${c}/${id ?? `auto${++n}`}`, get: async () => leer({ path: `${c}/${id}` }) }) }),
    async runTransaction(fn) {
      const escrituras = [];
      const tx = { get: async (r) => leer(r), set: (r, d, o) => escrituras.push([r, d, o]) };
      const resultado = await fn(tx);
      for (const [r, d, o] of escrituras) escribir(r, d, o);
      return resultado;
    },
  };
}

const pedido = (datos = {}, uid = UID) => ({
  auth: { uid, token: { name: 'Ana Quispe', email: 'ana@mail.pe' } },
  data: datos,
});

const cargoExitoso = (id = 'chr_test_AAA111') => ({
  estado: 201,
  cuerpo: { object: 'charge', id, outcome: { type: 'venta_exitosa' }, source: { object: 'token' } },
});

function entorno(inicial, { respuesta = cargoExitoso(), llave = 'sk_test_x' } = {}) {
  const db = baseDeDatos({ usuarios: { [UID]: { nombre: 'Ana' } }, ...inicial });
  const enviados = [];
  return {
    db,
    enviados,
    deps: {
      db,
      configuracion: async () => ({ precio: 35, diasPremium: 90 }),
      cargar: async (cuerpo, secreta) => {
        enviados.push({ cuerpo, secreta });
        return typeof respuesta === 'function' ? respuesta(cuerpo) : respuesta;
      },
      llaveSecreta: llave,
      ahoraMs: AHORA,
    },
  };
}

test('cupones: código, vigencia y precio igual que en la app', () => {
  assert.equal(normalizarCodigo(' beca 50 '), 'BECA50');
  assert.ok(cuponVigente({ tipo: 'descuento' }, AHORA));
  assert.ok(!cuponVigente({ activo: false }, AHORA));
  assert.ok(!cuponVigente({ vence: Timestamp.fromMillis(AHORA - 1) }, AHORA));
  assert.ok(!cuponVigente({ usosMaximos: 2, usos: 2 }, AHORA));
  assert.ok(!cuponVigente(null, AHORA));
  assert.equal(precioConCupon(35, { tipo: 'descuento', valor: 50 }), 18);
  assert.equal(precioConCupon(35, { tipo: 'precioFijo', valor: 20 }), 20);
  assert.equal(precioConCupon(35, { tipo: 'precioFijo', valor: 99 }), 35);
  assert.equal(precioConCupon(35, { tipo: 'premiumGratis' }), 0);
  assert.equal(precioConCupon(35, null), 35);
});

test('token y 3DS: solo lo que da Culqi', () => {
  assert.ok(tokenCulqiValido(TOKEN));
  assert.ok(tokenCulqiValido('ype_live_123456abcdef'));
  assert.ok(!tokenCulqiValido('sk_live_123456'));
  assert.ok(!tokenCulqiValido('tkn_test_../x'));
  assert.ok(autenticacionValida(undefined));
  assert.ok(autenticacionValida({ eci: '05', xid: 'x', cavv: 'c', protocolVersion: '2.1.0' }));
  assert.ok(!autenticacionValida({ eci: '05', otro: 'x' }));
  assert.ok(!autenticacionValida('texto'));
});

test('lee la respuesta de Culqi: éxito, 3DS o error', () => {
  assert.equal(interpretarCargo(201, cargoExitoso().cuerpo).tipo, 'exito');
  assert.deepEqual(interpretarCargo(200, { action_code: 'REVIEW' }), { tipo: '3ds' });
  assert.deepEqual(interpretarCargo(402, { object: 'error', user_message: 'Tu tarjeta fue rechazada.' }), {
    tipo: 'error',
    mensaje: 'Tu tarjeta fue rechazada.',
  });
  assert.equal(interpretarCargo(500, null).tipo, 'error');
});

test('cotiza con y sin cupón', async () => {
  const { deps } = entorno({
    cupones: { BECA50: { tipo: 'descuento', valor: 50 }, GRATIS: { tipo: 'premiumGratis' } },
  });
  assert.deepEqual(await cotizar(pedido(), deps), {
    precio: 35, monto: 35, dias: 90, beca: false, cupon: null,
  });
  assert.equal((await cotizar(pedido({ cupon: 'beca50' }), deps)).monto, 18);
  assert.equal((await cotizar(pedido({ cupon: 'GRATIS' }), deps)).beca, true);
  await assertRechaza(cotizar(pedido({ cupon: 'NOEXISTE' }), deps), 'not-found');
});

async function assertRechaza(promesa, code) {
  await assert.rejects(promesa, (e) => e.code === code);
}

test('sin cuenta en la app no se cobra', async () => {
  const { deps, enviados } = entorno();
  await assertRechaza(cobrar(pedido({ token: TOKEN }, 'otroUid1234567890'), deps), 'failed-precondition');
  assert.equal(enviados.length, 0);
});

test('cobra en soles a céntimos y da los 90 días una vez', async () => {
  const { db, deps, enviados } = entorno();
  const r = await cobrar(pedido({ token: TOKEN, dispositivo: 'disp-1' }), deps);

  assert.deepEqual(r, { estado: 'activada', premiumHasta: AHORA + 90 * DIA, monto: 35 });
  assert.equal(enviados[0].secreta, 'sk_test_x');
  assert.equal(enviados[0].cuerpo.amount, 3500);
  assert.equal(enviados[0].cuerpo.currency_code, 'PEN');
  assert.equal(enviados[0].cuerpo.email, 'ana@mail.pe');
  assert.equal(enviados[0].cuerpo.source_id, TOKEN);
  assert.deepEqual(enviados[0].cuerpo.antifraud_details, { device_finger_print_id: 'disp-1' });
  assert.equal(enviados[0].cuerpo.authentication_3DS, undefined);

  const pago = db.datos.pagos.culqi__chr_test_AAA111;
  assert.equal(pago.metodo, 'culqi');
  assert.equal(pago.monto, 35);
  assert.equal(pago.estado, 'aprobado');
  assert.equal(pago.operacion, 'chr_test_AAA111');
  assert.equal(pago.dePrueba, true);
  assert.equal(db.datos.usuarios[UID].premiumHasta.toMillis(), AHORA + 90 * DIA);
  assert.equal(db.datos.usuarios[UID].nombre, 'Ana');

  // El mismo cargo otra vez (doble clic que llega igual): no suma días.
  const otra = await cobrar(pedido({ token: TOKEN }), deps);
  assert.equal(otra.premiumHasta, AHORA + 90 * DIA);
  assert.equal(Object.keys(db.datos.registro_admin).length, 1);
});

test('con cupón cobra menos y cuenta el uso', async () => {
  const { db, deps, enviados } = entorno({ cupones: { BECA50: { tipo: 'descuento', valor: 50, usos: 1 } } });
  const r = await cobrar(pedido({ token: TOKEN, cupon: 'BECA50' }), deps);
  assert.equal(r.monto, 18);
  assert.equal(enviados[0].cuerpo.amount, 1800);
  assert.equal(db.datos.pagos.culqi__chr_test_AAA111.cupon, 'BECA50');
  assert.equal(db.datos.cupones.BECA50.usos, 2);
});

test('si Premium sigue vigente, se suma', async () => {
  const { deps } = entorno({
    usuarios: { [UID]: { premiumHasta: Timestamp.fromMillis(AHORA + 10 * DIA) } },
  });
  const r = await cobrar(pedido({ token: TOKEN }), deps);
  assert.equal(r.premiumHasta, AHORA + 100 * DIA);
});

test('tarjeta con 3DS: primero pide autenticar, luego cobra', async () => {
  const { deps, enviados } = entorno({}, {
    respuesta: (cuerpo) => (cuerpo.authentication_3DS
      ? cargoExitoso('chr_test_3DS')
      : { estado: 200, cuerpo: { action_code: 'REVIEW' } }),
  });
  assert.deepEqual(await cobrar(pedido({ token: TOKEN }), deps), { estado: '3ds', monto: 35 });
  const autenticacion = { eci: '05', xid: 'x', cavv: 'c', protocolVersion: '2.1.0' };
  const r = await cobrar(pedido({ token: TOKEN, autenticacion3DS: autenticacion }), deps);
  assert.equal(r.estado, 'activada');
  assert.deepEqual(enviados[1].cuerpo.authentication_3DS, autenticacion);
});

test('rechazo de Culqi: su mensaje para el alumno, sin Premium', async () => {
  const { db, deps } = entorno({}, {
    respuesta: { estado: 402, cuerpo: { object: 'error', user_message: 'Tu tarjeta no tiene fondos.' } },
  });
  await assert.rejects(cobrar(pedido({ token: TOKEN }), deps), {
    code: 'failed-precondition',
    message: 'Tu tarjeta no tiene fondos.',
  });
  assert.equal(db.datos.pagos, undefined);
  assert.equal(db.datos.usuarios[UID].premiumHasta, undefined);
});

test('beca: se canjea sin cobro, una vez por alumno y respetando el límite', async () => {
  const { db, deps, enviados } = entorno({
    cupones: { BECA: { tipo: 'premiumGratis', usosMaximos: 1 } },
  });
  const r = await cobrar(pedido({ cupon: 'beca' }), deps);
  assert.deepEqual(r, { estado: 'activada', premiumHasta: AHORA + 90 * DIA, monto: 0 });
  assert.equal(enviados.length, 0);
  assert.equal(db.datos.pagos[`beca__${UID}__BECA`].metodo, 'beca');
  assert.equal(db.datos.cupones.BECA.usos, 1);

  await assertRechaza(cobrar(pedido({ cupon: 'BECA' }), deps), 'not-found');
  db.datos.cupones.BECA.usosMaximos = 5;
  await assertRechaza(cobrar(pedido({ cupon: 'BECA' }), deps), 'already-exists');
});

test('pedidos inválidos y sin llave de Culqi', async () => {
  const { deps } = entorno();
  await assertRechaza(cobrar({ data: {} }, deps), 'unauthenticated');
  await assertRechaza(cobrar(pedido({ token: 'nada' }), deps), 'invalid-argument');
  await assertRechaza(cobrar(pedido({ token: TOKEN, autenticacion3DS: { malo: 1 } }), deps), 'invalid-argument');
  const sinLlave = entorno({}, { llave: '' });
  await assertRechaza(cobrar(pedido({ token: TOKEN }), sinLlave.deps), 'unavailable');
  const caido = entorno({}, {
    respuesta: () => {
      throw new Error('sin red');
    },
  });
  await assertRechaza(cobrar(pedido({ token: TOKEN }), caido.deps), 'unavailable');
});
