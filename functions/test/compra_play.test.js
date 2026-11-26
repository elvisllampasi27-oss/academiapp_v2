'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('firebase-admin/firestore');
const {
  idPagoPlay,
  cuentaOfuscada,
  premiumNuevoHasta,
  tokenValido,
  revisarCompra,
  verificarCompra,
} = require('../src/premium/compra_play');

const DIA = 24 * 60 * 60 * 1000;
const AHORA = Date.parse('2026-12-01T15:00:00Z');
const UID = 'alumnoUid1234567890';
const TOKEN = 'token-de-compra-de-prueba-123';

/** Firestore de mentira con transacciones (lee, escribe al final). */
function baseDeDatos(inicial = {}) {
  const datos = JSON.parse(JSON.stringify(inicial));
  const ruta = (r) => r.path.split('/');
  let n = 0;
  const db = {
    datos,
    collection: (c) => ({ doc: (id) => ({ path: `${c}/${id ?? `auto${++n}`}` }) }),
    async runTransaction(fn) {
      const escrituras = [];
      const tx = {
        async get(r) {
          const [c, id] = ruta(r);
          const d = datos[c] && datos[c][id];
          return { exists: d != null, data: () => d };
        },
        set(r, d, opciones) {
          escrituras.push([r, d, opciones]);
        },
      };
      const resultado = await fn(tx);
      for (const [r, d, opciones] of escrituras) {
        const [c, id] = ruta(r);
        datos[c] = datos[c] || {};
        datos[c][id] = opciones && opciones.merge ? { ...datos[c][id], ...d } : d;
      }
      return resultado;
    },
  };
  return db;
}

const pedido = (uid = UID) => ({
  auth: { uid, token: { name: 'Ana Quispe', email: 'ana@mail.pe' } },
  data: { productoId: 'sinchi_premium', token: TOKEN },
});

function dependencias(db, compra, extra = {}) {
  const consumidas = [];
  return {
    consumidas,
    deps: {
      db,
      consultar: async () => compra,
      consumir: async (t) => consumidas.push(t),
      configuracion: async () => ({ diasPremium: 90, precio: 35 }),
      ahoraMs: AHORA,
      ...extra,
    },
  };
}

const compraPagada = {
  purchaseState: 0,
  consumptionState: 0,
  orderId: 'GPA.1234-5678-9012-34567',
  purchaseType: 0,
  obfuscatedExternalAccountId: cuentaOfuscada(UID),
};

test('id y cuenta ofuscada: fijos y sin datos personales', () => {
  assert.equal(idPagoPlay(TOKEN), idPagoPlay(TOKEN));
  assert.match(idPagoPlay(TOKEN), /^googlePlay__[0-9a-f]{40}$/);
  // El mismo valor que prueba cuentaOfuscadaPlay en Dart.
  assert.equal(cuentaOfuscada(UID),
    '393f34bd9e5f9e8a857aa8d8399524b84cc896ae48594ef43eda032d9ede1559');
  assert.ok(!cuentaOfuscada(UID).includes(UID));
});

test('Premium se suma a lo que le queda', () => {
  assert.equal(premiumNuevoHasta(null, AHORA, 90), AHORA + 90 * DIA);
  assert.equal(premiumNuevoHasta(AHORA - DIA, AHORA, 90), AHORA + 90 * DIA);
  assert.equal(premiumNuevoHasta(AHORA + 10 * DIA, AHORA, 90), AHORA + 100 * DIA);
});

test('token: texto de tamaño razonable', () => {
  assert.ok(tokenValido(TOKEN));
  assert.ok(!tokenValido(''));
  assert.ok(!tokenValido(123));
  assert.ok(!tokenValido('x'.repeat(1001)));
});

test('revisa estado y cuenta de la compra', () => {
  assert.equal(revisarCompra(compraPagada, UID), 'valida');
  assert.equal(revisarCompra({ ...compraPagada, purchaseState: 2 }, UID), 'pendiente');
  assert.equal(revisarCompra({ ...compraPagada, purchaseState: 1 }, UID), 'noPagada');
  assert.equal(revisarCompra(compraPagada, 'otroUid1234567890'), 'otraCuenta');
  // Sin cuenta ofuscada (compra antigua) se acepta.
  const { obfuscatedExternalAccountId, ...sinCuenta } = compraPagada;
  assert.equal(revisarCompra(sinCuenta, 'otroUid1234567890'), 'valida');
});

test('una compra válida da 90 días, la registra y la consume', async () => {
  const db = baseDeDatos({ usuarios: { [UID]: { nombre: 'Ana' } } });
  const { deps, consumidas } = dependencias(db, compraPagada);
  const r = await verificarCompra(pedido(), deps);

  assert.deepEqual(r, {
    estado: 'activada',
    nueva: true,
    premiumHasta: AHORA + 90 * DIA,
    consumida: true,
  });
  assert.equal(db.datos.usuarios[UID].premiumHasta.toMillis(), AHORA + 90 * DIA);
  assert.equal(db.datos.usuarios[UID].nombre, 'Ana');
  const pago = db.datos.pagos[idPagoPlay(TOKEN)];
  assert.equal(pago.metodo, 'googlePlay');
  assert.equal(pago.estado, 'aprobado');
  assert.equal(pago.monto, 35);
  assert.equal(pago.usuarioId, UID);
  assert.equal(pago.operacion, 'GPA.1234-5678-9012-34567');
  assert.equal(pago.dePrueba, true);
  assert.equal(pago.premiumAnterior, null);
  assert.deepEqual(consumidas, [TOKEN]);
  assert.equal(Object.keys(db.datos.registro_admin).length, 1);
});

test('en la prueba gratis, los 90 días empiezan cuando termina', async () => {
  const finPrueba = AHORA + 5 * DIA;
  const db = baseDeDatos();
  db.datos.usuarios = { [UID]: { premiumHasta: Timestamp.fromMillis(finPrueba) } };
  const { deps } = dependencias(db, compraPagada);
  const r = await verificarCompra(pedido(), deps);
  assert.equal(r.premiumHasta, finPrueba + 90 * DIA);
});

test('la misma compra dos veces no suma días de nuevo', async () => {
  const db = baseDeDatos({ usuarios: { [UID]: {} } });
  const { deps } = dependencias(db, compraPagada);
  await verificarCompra(pedido(), deps);
  const otra = dependencias(db, { ...compraPagada, consumptionState: 1 });
  const r = await verificarCompra(pedido(), otra.deps);

  assert.equal(r.nueva, false);
  assert.equal(r.premiumHasta, AHORA + 90 * DIA);
  assert.equal(r.consumida, true);
  assert.deepEqual(otra.consumidas, []);
  assert.equal(Object.keys(db.datos.registro_admin).length, 1);
});

test('el token de otra cuenta no sirve', async () => {
  const db = baseDeDatos({ usuarios: { [UID]: {} } });
  await verificarCompra(pedido(), dependencias(db, compraPagada).deps);
  const ajena = { ...compraPagada, obfuscatedExternalAccountId: undefined };
  await assert.rejects(
    verificarCompra(pedido('otroUid1234567890'), dependencias(db, ajena).deps),
    { code: 'permission-denied' },
  );
});

test('pendiente: no da Premium todavía', async () => {
  const db = baseDeDatos({ usuarios: { [UID]: {} } });
  const { deps, consumidas } = dependencias(db, { ...compraPagada, purchaseState: 2 });
  assert.deepEqual(await verificarCompra(pedido(), deps), { estado: 'pendiente' });
  assert.equal(db.datos.pagos, undefined);
  assert.deepEqual(consumidas, []);
});

test('pedidos inválidos y errores de Google Play', async () => {
  const db = baseDeDatos();
  const { deps } = dependencias(db, compraPagada);
  await assert.rejects(verificarCompra({ data: {} }, deps), { code: 'unauthenticated' });
  await assert.rejects(
    verificarCompra({ ...pedido(), data: { productoId: 'otro', token: TOKEN } }, deps),
    { code: 'invalid-argument' },
  );
  await assert.rejects(
    verificarCompra(pedido(), dependencias(db, { ...compraPagada, purchaseState: 1 }).deps),
    { code: 'failed-precondition' },
  );
  const noExiste = dependencias(db, null, {
    consultar: async () => {
      throw Object.assign(new Error('x'), { response: { status: 410 } });
    },
  });
  await assert.rejects(verificarCompra(pedido(), noExiste.deps), { code: 'not-found' });
  const caida = dependencias(db, null, {
    consultar: async () => {
      throw Object.assign(new Error('x'), { response: { status: 503 } });
    },
  });
  await assert.rejects(verificarCompra(pedido(), caida.deps), { code: 'unavailable' });
});

test('si no se puede consumir, igual da Premium y avisa', async () => {
  const db = baseDeDatos({ usuarios: { [UID]: {} } });
  const { deps } = dependencias(db, compraPagada, {
    consumir: async () => {
      throw new Error('sin conexión');
    },
  });
  const r = await verificarCompra(pedido(), deps);
  assert.equal(r.estado, 'activada');
  assert.equal(r.consumida, false);
});
