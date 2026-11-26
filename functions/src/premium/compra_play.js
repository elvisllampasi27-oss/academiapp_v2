'use strict';

/**
 * Compra de Premium con Google Play (Android).
 *
 * La app compra el producto "premium_90_dias" (producto único, no una
 * suscripción) y manda aquí el token de la compra. Esta función lo
 * confirma con la API de Google Play, da los días de Premium una sola vez
 * por token y consume la compra para que el alumno pueda volver a comprar
 * cuando se le acabe.
 *
 * Necesita el plan Blaze, la API "Google Play Android Developer" activada
 * y la cuenta de servicio de las funciones invitada en Play Console
 * (ver docs/LANZAMIENTO.md).
 */
const crypto = require('node:crypto');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const { Timestamp, FieldValue } = require('firebase-admin/firestore');
const { leerConfiguracion } = require('../comun/plan');

const PAQUETE = 'pe.sinchi.academia';
const PRODUCTO_PREMIUM = 'premium_90_dias';
const DIA_MS = 24 * 60 * 60 * 1000;
const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';
const ALCANCE = 'https://www.googleapis.com/auth/androidpublisher';

// purchaseState de purchases.products.get.
const COMPRADA = 0;
const PENDIENTE = 2;
// consumptionState.
const SIN_CONSUMIR = 0;
// purchaseType: 0 = compra de prueba (cuentas de prueba de Play Console).
const DE_PRUEBA = 0;

const sha256 = (texto) => crypto.createHash('sha256').update(texto).digest('hex');

/** Id del pago: uno por token, así la misma compra no da Premium dos veces. */
const idPagoPlay = (token) => `googlePlay__${sha256(token).slice(0, 40)}`;

/**
 * Cuenta ofuscada que la app manda a Google Play al comprar
 * (applicationUserName). Debe coincidir con cuentaOfuscadaPlay en Dart.
 */
const cuentaOfuscada = (uid) => sha256(`sinchi:${uid}`);

/** Igual que premiumNuevoHasta en Dart: suma a lo que le queda. */
function premiumNuevoHasta(actualMs, ahoraMs, dias) {
  const base = actualMs != null && actualMs > ahoraMs ? actualMs : ahoraMs;
  return base + dias * DIA_MS;
}

/** El token que manda la app: texto no vacío y de tamaño razonable. */
function tokenValido(token) {
  return typeof token === 'string' && token.length >= 10 && token.length <= 1000;
}

/**
 * Qué hacer con la compra que devolvió Google Play.
 * @returns {'valida'|'pendiente'|'otraCuenta'|'noPagada'}
 */
function revisarCompra(compra, uid) {
  if (compra.purchaseState === PENDIENTE) return 'pendiente';
  if (compra.purchaseState !== COMPRADA) return 'noPagada';
  const cuenta = compra.obfuscatedExternalAccountId;
  if (cuenta && cuenta !== cuentaOfuscada(uid)) return 'otraCuenta';
  return 'valida';
}

/**
 * Da Premium por la compra [token] dentro de una transacción. Si ese token
 * ya dio Premium a este alumno, no vuelve a sumar días.
 * @returns {Promise<{nueva: boolean, premiumHastaMs: number}>}
 */
async function activarCompraPlay({
  db, uid, nombre, correo, token, compra, dias, precio, ahoraMs,
}) {
  return db.runTransaction(async (tx) => {
    const pagoRef = db.collection('pagos').doc(idPagoPlay(token));
    const usuarioRef = db.collection('usuarios').doc(uid);
    const [pago, usuario] = await Promise.all([tx.get(pagoRef), tx.get(usuarioRef)]);

    if (pago.exists) {
      if (pago.data().usuarioId !== uid) {
        throw new HttpsError('permission-denied', 'Esta compra es de otra cuenta.');
      }
      const hasta = pago.data().premiumHasta;
      return { nueva: false, premiumHastaMs: hasta ? hasta.toMillis() : 0 };
    }

    const anterior = usuario.exists ? usuario.data().premiumHasta : null;
    const anteriorMs = anterior && typeof anterior.toMillis === 'function'
      ? anterior.toMillis()
      : null;
    const nuevoMs = premiumNuevoHasta(anteriorMs, ahoraMs, dias);
    const nuevo = Timestamp.fromMillis(nuevoMs);

    tx.set(usuarioRef, { premiumHasta: nuevo }, { merge: true });
    tx.set(pagoRef, {
      usuarioId: uid,
      nombre,
      correo,
      // Precio de lista (config/academia), para los ingresos del panel. Lo
      // que llega de verdad, sin la comisión de Google, está en Play Console.
      monto: Math.max(0, Math.round(Number(precio) || 0)),
      metodo: 'googlePlay',
      operacion: compra.orderId || '',
      estado: 'aprobado',
      dePrueba: compra.purchaseType === DE_PRUEBA,
      creadoEn: FieldValue.serverTimestamp(),
      revisadoEn: FieldValue.serverTimestamp(),
      revisadoPor: 'Google Play',
      premiumHasta: nuevo,
      premiumAnterior: anteriorMs == null ? null : Timestamp.fromMillis(anteriorMs),
    });
    const fecha = new Date(nuevoMs - 5 * 60 * 60 * 1000).toISOString().slice(0, 10);
    tx.set(db.collection('registro_admin').doc(), {
      tipo: 'pago',
      usuarioId: uid,
      descripcion: `Compró Premium en Google Play (${compra.orderId || 'sin N.º de pedido'}`
        + `${compra.purchaseType === DE_PRUEBA ? ', compra de prueba' : ''}): `
        + `hasta el ${fecha}.`,
      adminUid: 'sistema',
      adminCorreo: 'Google Play',
      fecha: FieldValue.serverTimestamp(),
    });
    return { nueva: true, premiumHastaMs: nuevoMs };
  });
}

/**
 * Cliente de la API de Google Play con la cuenta de servicio de las
 * funciones. Se crea al primer uso.
 */
let clientePlay;
async function pedirAPlay(token, sufijo = '', metodo = 'GET') {
  if (!clientePlay) {
    const { GoogleAuth } = require('google-auth-library');
    clientePlay = await new GoogleAuth({ scopes: [ALCANCE] }).getClient();
  }
  const url = `${API}/${PAQUETE}/purchases/products/${PRODUCTO_PREMIUM}`
    + `/tokens/${encodeURIComponent(token)}${sufijo}`;
  const respuesta = await clientePlay.request({ url, method: metodo });
  return respuesta.data;
}

const consultarPlay = (token) => pedirAPlay(token);
const consumirPlay = (token) => pedirAPlay(token, ':consume', 'POST');

/** Lo que hace la función, con sus dependencias a la vista para probarla. */
async function verificarCompra(request, { db, consultar, consumir, configuracion, ahoraMs }) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }
  const { productoId, token } = request.data || {};
  if (productoId !== PRODUCTO_PREMIUM || !tokenValido(token)) {
    throw new HttpsError('invalid-argument', 'Compra no válida.');
  }
  const uid = request.auth.uid;

  let compra;
  try {
    compra = await consultar(token);
  } catch (e) {
    const estado = e && e.response && e.response.status;
    if (estado === 400 || estado === 404 || estado === 410) {
      throw new HttpsError('not-found', 'Google Play no reconoce esta compra.');
    }
    logger.error('No se pudo consultar Google Play', { uid, estado, mensaje: e && e.message });
    throw new HttpsError('unavailable', 'No pudimos confirmar tu compra. Inténtalo en un rato.');
  }

  switch (revisarCompra(compra, uid)) {
    case 'pendiente':
      return { estado: 'pendiente' };
    case 'noPagada':
      throw new HttpsError('failed-precondition', 'Esta compra fue cancelada o no se pagó.');
    case 'otraCuenta':
      throw new HttpsError('permission-denied', 'Esta compra es de otra cuenta.');
    default:
      break;
  }

  const { diasPremium, precio } = await configuracion();
  const resultado = await activarCompraPlay({
    db,
    uid,
    nombre: request.auth.token.name || '',
    correo: request.auth.token.email || '',
    token,
    compra,
    dias: Number(diasPremium) || 90,
    precio,
    ahoraMs,
  });

  // Consumir deja volver a comprar y vale como confirmación ante Google
  // (si no, Google la reembolsa a los 3 días). Si falla, la app la vuelve
  // a mandar al abrir y se intenta otra vez sin sumar días.
  let consumida = compra.consumptionState !== SIN_CONSUMIR;
  if (!consumida) {
    try {
      await consumir(token);
      consumida = true;
    } catch (e) {
      logger.warn('No se pudo consumir la compra de Google Play', { uid, mensaje: e && e.message });
    }
  }

  return {
    estado: 'activada',
    nueva: resultado.nueva,
    premiumHasta: resultado.premiumHastaMs,
    consumida,
  };
}

const verificarCompraPlay = onCall((request) => {
  const db = admin.firestore();
  return verificarCompra(request, {
    db,
    consultar: consultarPlay,
    consumir: consumirPlay,
    configuracion: () => leerConfiguracion(db),
    ahoraMs: Date.now(),
  });
});

module.exports = {
  PAQUETE,
  PRODUCTO_PREMIUM,
  idPagoPlay,
  cuentaOfuscada,
  premiumNuevoHasta,
  tokenValido,
  revisarCompra,
  activarCompraPlay,
  verificarCompra,
  verificarCompraPlay,
};
