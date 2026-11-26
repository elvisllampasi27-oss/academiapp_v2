'use strict';

/**
 * Premium desde la web (hosting/premium/) con Culqi: Yape o tarjeta. Pago
 * único por los días de config/academia; no se renueva solo.
 *
 * - cotizarPremiumWeb: cuánto paga el alumno (con su cupón, si tiene).
 * - cobrarPremiumWeb: cobra con el token que da Culqi Checkout y da los
 *   días. Si la tarjeta pide 3DS, responde { estado: '3ds' } y la página
 *   vuelve a llamar con la autenticación. Una beca (cupón de Premium
 *   gratis) se canjea aquí mismo, sin cobro.
 *
 * La llave secreta de Culqi va como secreto de las funciones
 * (CULQI_LLAVE_SECRETA); nunca en la app, la página ni git.
 */
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');
const { leerConfiguracion } = require('../comun/plan');
const { aplicarPagoAprobado } = require('./dar_premium');
const { leerMatriculaActiva } = require('../comun/pausa');

const CULQI_LLAVE_SECRETA = defineSecret('CULQI_LLAVE_SECRETA');
const URL_CARGOS = 'https://api.culqi.com/v2/charges';

/** Culqi no cobra menos de S/ 3 (300 céntimos). */
const MONTO_MINIMO = 3;

/** Igual que normalizarCodigo en Dart: "beca 50 " → "BECA50". */
const normalizarCodigo = (codigo) => String(codigo || '').toUpperCase().replace(/[^A-Z0-9-]/g, '');

/** Igual que Cupon.vigente en Dart. */
function cuponVigente(cupon, ahoraMs) {
  if (!cupon || cupon.activo === false) return false;
  const vence = cupon.vence && typeof cupon.vence.toMillis === 'function' ? cupon.vence.toMillis() : null;
  if (vence != null && vence < ahoraMs) return false;
  if (cupon.usosMaximos != null && (cupon.usos || 0) >= cupon.usosMaximos) return false;
  return true;
}

/** Igual que Cupon.precioCon en Dart: lo que paga con el cupón, en soles. */
function precioConCupon(precio, cupon) {
  if (!cupon) return precio;
  const valor = Number(cupon.valor) || 0;
  switch (cupon.tipo) {
    case 'descuento':
      return Math.round((precio * (100 - Math.min(100, Math.max(0, valor)))) / 100);
    case 'precioFijo':
      return Math.min(precio, Math.max(0, valor));
    case 'premiumGratis':
      return 0;
    default:
      return precio;
  }
}

/** Token de Culqi Checkout: tarjeta (tkn_…) o Yape (ype_…). */
function tokenCulqiValido(token) {
  return typeof token === 'string' && /^[a-z]{3}_(live|test)_[A-Za-z0-9]{6,64}$/.test(token);
}

/** Los parámetros que devuelve Culqi3DS al autenticar. */
function autenticacionValida(a) {
  if (a == null) return true;
  if (typeof a !== 'object') return false;
  const campos = ['eci', 'xid', 'cavv', 'protocolVersion', 'directoryServerTransactionId'];
  return Object.keys(a).every((k) => campos.includes(k))
    && Object.values(a).every((v) => v == null || (typeof v === 'string' && v.length <= 200));
}

/**
 * Qué pasó con el cargo según lo que respondió Culqi.
 * @returns {{tipo: 'exito', cargo: object} | {tipo: '3ds'} | {tipo: 'error', mensaje: string}}
 */
function interpretarCargo(estadoHttp, cuerpo) {
  const ok = estadoHttp >= 200 && estadoHttp < 300;
  if (ok && cuerpo && cuerpo.object === 'charge'
      && (!cuerpo.outcome || cuerpo.outcome.type === 'venta_exitosa')) {
    return { tipo: 'exito', cargo: cuerpo };
  }
  if (ok && cuerpo && cuerpo.action_code === 'REVIEW') return { tipo: '3ds' };
  const mensaje = (cuerpo && (cuerpo.user_message || (cuerpo.outcome && cuerpo.outcome.user_message)))
    || 'No se pudo completar el pago. Inténtalo de nuevo.';
  return { tipo: 'error', mensaje };
}

/** Cobro en Culqi con la llave secreta. */
async function cargarEnCulqi(cuerpo, llaveSecreta) {
  const respuesta = await fetch(URL_CARGOS, {
    method: 'POST',
    headers: { Authorization: `Bearer ${llaveSecreta}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(cuerpo),
  });
  let datos = null;
  try {
    datos = await respuesta.json();
  } catch (_) {
    datos = null;
  }
  return { estado: respuesta.status, cuerpo: datos };
}

/** Lee lo necesario para cotizar: alumno, configuración y cupón. */
async function prepararCobro({ db, uid, codigo, configuracion, ahoraMs }) {
  const usuario = await db.collection('usuarios').doc(uid).get();
  if (!usuario.exists) {
    throw new HttpsError('failed-precondition',
      'Primero crea tu cuenta en la app Sinchi y vuelve aquí.');
  }
  const config = await configuracion();
  const precio = Math.max(0, Math.round(Number(config.precio) || 0));
  const dias = Number(config.diasPremium) || 90;

  let cupon = null;
  if (codigo) {
    const snap = await db.collection('cupones').doc(codigo).get();
    cupon = snap.exists ? snap.data() : null;
    if (!cuponVigente(cupon, ahoraMs)) {
      throw new HttpsError('not-found', 'Ese cupón no existe o ya no está vigente.');
    }
  }
  return { precio, dias, cupon, monto: precioConCupon(precio, cupon) };
}

function leerPedido(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }
  const datos = request.data || {};
  const codigo = datos.cupon ? normalizarCodigo(datos.cupon) : '';
  if (datos.cupon && (codigo.length === 0 || codigo.length > 40)) {
    throw new HttpsError('not-found', 'Ese cupón no existe o ya no está vigente.');
  }
  return { uid: request.auth.uid, codigo, datos };
}

async function cotizar(request, { db, configuracion, ahoraMs }) {
  const { uid, codigo } = leerPedido(request);
  const { precio, dias, cupon, monto } = await prepararCobro({ db, uid, codigo, configuracion, ahoraMs });
  return {
    precio,
    monto,
    dias,
    beca: Boolean(cupon) && monto === 0,
    cupon: cupon ? codigo : null,
  };
}

/** Canje de una beca (o cupón que deja el precio en 0): sin cobro. */
async function canjearBeca({ db, uid, codigo, dias, ahoraMs, nombre, correo }) {
  return db.runTransaction(async (tx) => {
    const pagoRef = db.collection('pagos').doc(`beca__${uid}__${codigo}`);
    const cuponRef = db.collection('cupones').doc(codigo);
    const usuarioRef = db.collection('usuarios').doc(uid);
    const [pago, cupon, usuario, matricula] = await Promise.all([
      tx.get(pagoRef), tx.get(cuponRef), tx.get(usuarioRef), leerMatriculaActiva(tx, db, uid),
    ]);
    if (pago.exists && pago.data().estado !== 'rechazado') {
      throw new HttpsError('already-exists', 'Ya usaste este cupón.');
    }
    // Se vuelve a revisar aquí: dos canjes a la vez no pasan el límite.
    if (!cuponVigente(cupon.exists ? cupon.data() : null, ahoraMs)) {
      throw new HttpsError('not-found', 'Ese cupón no existe o ya no está vigente.');
    }
    const nuevoMs = aplicarPagoAprobado(tx, {
      db,
      uid,
      usuario,
      matricula,
      pagoRef,
      pago: { nombre, correo, monto: 0, metodo: 'beca', operacion: '', cupon: codigo },
      dias,
      ahoraMs,
      revisadoPor: 'canje en la web',
      descripcion: (fin) => `Canjeó la beca ${codigo} en la web: Premium hasta el ${fin}.`,
    });
    tx.set(cuponRef, { usos: FieldValue.increment(1) }, { merge: true });
    return nuevoMs;
  });
}

/** Guarda el cargo exitoso y da los días (una sola vez por cargo). */
async function registrarCargo({ db, uid, cargo, codigo, monto, dias, ahoraMs, nombre, correo }) {
  return db.runTransaction(async (tx) => {
    const pagoRef = db.collection('pagos').doc(`culqi__${cargo.id}`);
    const usuarioRef = db.collection('usuarios').doc(uid);
    const [pago, usuario, matricula] = await Promise.all([
      tx.get(pagoRef), tx.get(usuarioRef), leerMatriculaActiva(tx, db, uid),
    ]);
    if (pago.exists) {
      const hasta = pago.data().premiumHasta;
      return hasta ? hasta.toMillis() : 0;
    }
    const metodoCulqi = cargo.source && cargo.source.object === 'yape' ? 'Yape' : 'tarjeta';
    const nuevoMs = aplicarPagoAprobado(tx, {
      db,
      uid,
      usuario,
      matricula,
      pagoRef,
      pago: {
        nombre,
        correo,
        monto,
        metodo: 'culqi',
        operacion: cargo.id,
        ...(codigo ? { cupon: codigo } : {}),
        dePrueba: String(cargo.id).includes('_test_'),
      },
      dias,
      ahoraMs,
      revisadoPor: 'Culqi',
      descripcion: (fin) => `Pagó S/ ${monto} con ${metodoCulqi} en la web (${cargo.id}`
        + `${codigo ? `, cupón ${codigo}` : ''}): Premium hasta el ${fin}.`,
    });
    if (codigo) {
      tx.set(db.collection('cupones').doc(codigo), { usos: FieldValue.increment(1) }, { merge: true });
    }
    return nuevoMs;
  });
}

async function cobrar(request, { db, configuracion, cargar, llaveSecreta, ahoraMs }) {
  const { uid, codigo, datos } = leerPedido(request);
  const nombre = request.auth.token.name || '';
  const correo = request.auth.token.email || '';
  const { dias, cupon, monto } = await prepararCobro({ db, uid, codigo, configuracion, ahoraMs });

  if (cupon && monto === 0) {
    const hasta = await canjearBeca({ db, uid, codigo, dias, ahoraMs, nombre, correo });
    return { estado: 'activada', premiumHasta: hasta, monto: 0 };
  }
  if (monto < MONTO_MINIMO) {
    throw new HttpsError('failed-precondition', `El pago mínimo en línea es S/ ${MONTO_MINIMO}.`);
  }
  if (!tokenCulqiValido(datos.token) || !autenticacionValida(datos.autenticacion3DS)) {
    throw new HttpsError('invalid-argument', 'Pago no válido.');
  }
  if (!correo) {
    throw new HttpsError('failed-precondition', 'Tu cuenta no tiene correo.');
  }
  if (!llaveSecreta) {
    throw new HttpsError('unavailable', 'El pago en línea estará disponible pronto.');
  }

  const dispositivo = typeof datos.dispositivo === 'string' && datos.dispositivo.length <= 100
    ? datos.dispositivo
    : null;
  const cuerpo = {
    amount: monto * 100,
    currency_code: 'PEN',
    email: correo,
    source_id: datos.token,
    description: `Sinchi Premium ${dias} días`,
    metadata: { uid, ...(codigo ? { cupon: codigo } : {}) },
    ...(dispositivo ? { antifraud_details: { device_finger_print_id: dispositivo } } : {}),
    ...(datos.autenticacion3DS ? { authentication_3DS: datos.autenticacion3DS } : {}),
  };

  let respuesta;
  try {
    respuesta = await cargar(cuerpo, llaveSecreta);
  } catch (e) {
    logger.error('No se pudo llamar a Culqi', { uid, mensaje: e && e.message });
    throw new HttpsError('unavailable', 'No pudimos conectar con el medio de pago. Inténtalo en un rato.');
  }

  const resultado = interpretarCargo(respuesta.estado, respuesta.cuerpo);
  if (resultado.tipo === '3ds') return { estado: '3ds', monto };
  if (resultado.tipo === 'error') {
    logger.warn('Culqi rechazó el cargo', {
      uid,
      estado: respuesta.estado,
      codigo: respuesta.cuerpo && respuesta.cuerpo.code,
    });
    throw new HttpsError('failed-precondition', resultado.mensaje);
  }

  const hasta = await registrarCargo({
    db, uid, cargo: resultado.cargo, codigo, monto, dias, ahoraMs, nombre, correo,
  });
  return { estado: 'activada', premiumHasta: hasta, monto };
}

const cotizarPremiumWeb = onCall((request) => {
  const db = admin.firestore();
  return cotizar(request, { db, configuracion: () => leerConfiguracion(db), ahoraMs: Date.now() });
});

const cobrarPremiumWeb = onCall({ secrets: [CULQI_LLAVE_SECRETA] }, (request) => {
  const db = admin.firestore();
  return cobrar(request, {
    db,
    configuracion: () => leerConfiguracion(db),
    cargar: cargarEnCulqi,
    llaveSecreta: CULQI_LLAVE_SECRETA.value(),
    ahoraMs: Date.now(),
  });
});

module.exports = {
  MONTO_MINIMO,
  normalizarCodigo,
  cuponVigente,
  precioConCupon,
  tokenCulqiValido,
  autenticacionValida,
  interpretarCargo,
  cotizar,
  cobrar,
  cotizarPremiumWeb,
  cobrarPremiumWeb,
};
