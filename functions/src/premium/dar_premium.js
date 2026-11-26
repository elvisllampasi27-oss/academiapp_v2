'use strict';

/**
 * Dar Premium por un pago ya confirmado (Google Play o Culqi). Lo comparten
 * las funciones de cobro para que todas sumen los días igual que el panel.
 */
const { Timestamp, FieldValue } = require('firebase-admin/firestore');

const DIA_MS = 24 * 60 * 60 * 1000;
const DESFASE_LIMA_MS = 5 * 60 * 60 * 1000;

/** Igual que premiumNuevoHasta en Dart: suma a lo que le queda. */
function premiumNuevoHasta(actualMs, ahoraMs, dias) {
  const base = actualMs != null && actualMs > ahoraMs ? actualMs : ahoraMs;
  return base + dias * DIA_MS;
}

/** "2026-12-31" en hora de Lima. */
const fechaLima = (ms) => new Date(ms - DESFASE_LIMA_MS).toISOString().slice(0, 10);

/**
 * Dentro de una transacción (con [usuario] ya leído): suma [dias] de
 * Premium, guarda el pago como aprobado y lo anota en el registro del
 * panel. [descripcion] recibe la fecha de fin ("2026-12-31").
 * @returns {number} el nuevo premiumHasta en ms.
 */
function aplicarPagoAprobado(tx, {
  db, uid, usuario, pagoRef, pago, dias, ahoraMs, revisadoPor, descripcion,
}) {
  const anterior = usuario && usuario.exists ? usuario.data().premiumHasta : null;
  const anteriorMs = anterior && typeof anterior.toMillis === 'function'
    ? anterior.toMillis()
    : null;
  const nuevoMs = premiumNuevoHasta(anteriorMs, ahoraMs, dias);
  const nuevo = Timestamp.fromMillis(nuevoMs);

  tx.set(db.collection('usuarios').doc(uid), { premiumHasta: nuevo }, { merge: true });
  tx.set(pagoRef, {
    ...pago,
    usuarioId: uid,
    estado: 'aprobado',
    creadoEn: FieldValue.serverTimestamp(),
    revisadoEn: FieldValue.serverTimestamp(),
    revisadoPor,
    premiumHasta: nuevo,
    premiumAnterior: anteriorMs == null ? null : Timestamp.fromMillis(anteriorMs),
  });
  tx.set(db.collection('registro_admin').doc(), {
    tipo: 'pago',
    usuarioId: uid,
    descripcion: descripcion(fechaLima(nuevoMs)),
    adminUid: 'sistema',
    adminCorreo: revisadoPor,
    fecha: FieldValue.serverTimestamp(),
  });
  return nuevoMs;
}

module.exports = { DIA_MS, premiumNuevoHasta, fechaLima, aplicarPagoAprobado };
