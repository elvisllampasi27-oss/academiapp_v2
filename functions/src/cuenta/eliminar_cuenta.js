'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

/**
 * Para borrar su cuenta, el alumno tiene que haber ingresado (o vuelto a
 * ingresar) hace poco: así nadie la borra desde un celular que quedó con la
 * sesión abierta.
 */
const MAX_SEGUNDOS_DESDE_INGRESO = 5 * 60;

/** Colecciones donde un campo dice de quién es el documento: se borran. */
const POR_CAMPO = [
  ['matriculas', 'usuarioId'],
  ['simulacros', 'usuarioId'],
  ['intentos_evaluacion', 'usuarioId'],
  ['respuestas', 'usuarioId'],
  ['evidencias', 'usuarioId'],
  ['progreso_clases', 'usuarioId'],
  ['uso_tutor', 'usuarioId'],
  ['reportes', 'usuarioId'],
  ['en_vivos', 'docenteUid'],
];

/** Clases de un docente: se borran con sus corazones (subcolección). */
const CLASES_DOCENTE = ['clases_docente', 'docenteUid'];

/** Documentos cuyo id es el uid. */
const POR_ID = ['usuarios', 'solicitudes_docente', 'docentes'];

/** ¿El ingreso (auth_time, en segundos) fue hace poco? */
function ingresoReciente(authTimeSegundos, ahoraMs) {
  const segundos = Number(authTimeSegundos);
  if (!Number.isFinite(segundos)) return false;
  return ahoraMs / 1000 - segundos <= MAX_SEGUNDOS_DESDE_INGRESO;
}

/** Un uid de Firebase Auth: letras y números, sin barras. */
function uidValido(uid) {
  return typeof uid === 'string' && /^[A-Za-z0-9]{10,128}$/.test(uid);
}

/**
 * Lo que queda de un pago: monto, fecha, método y número de operación (para
 * la contabilidad); sin nombre, correo ni foto del comprobante.
 * [borrar] es el marcador de Firestore para quitar un campo.
 */
function pagoSinDatosPersonales(borrar) {
  return {
    nombre: 'Cuenta eliminada',
    correo: '',
    fotoUrl: borrar,
    cuentaEliminada: true,
  };
}

/**
 * Borra todo lo de [uid]. Primero los datos y al final el acceso: si algo
 * falla a mitad, el alumno todavía puede entrar y volver a intentarlo.
 * Devuelve cuántos documentos se borraron y cuántos pagos se anonimizaron.
 */
async function eliminarDatosDeCuenta({ db, bucket, auth, borrarCampo, uid, quien }) {
  const escritor = db.bulkWriter();
  // Cada escritura avisa si falla; se revisan todas antes de borrar el acceso.
  const operaciones = [];
  const anotar = (promesa) => operaciones.push(promesa.then(() => null, (e) => e));
  let borrados = 0;

  for (const [coleccion, campo] of POR_CAMPO) {
    const snap = await db.collection(coleccion).where(campo, '==', uid).select().get();
    for (const doc of snap.docs) {
      anotar(escritor.delete(doc.ref));
      borrados += 1;
    }
  }

  const [coleccionClases, campoClases] = CLASES_DOCENTE;
  const clases = await db.collection(coleccionClases)
    .where(campoClases, '==', uid).select().get();
  for (const doc of clases.docs) {
    await db.recursiveDelete(doc.ref, escritor);
    borrados += 1;
  }

  for (const coleccion of POR_ID) {
    anotar(escritor.delete(db.collection(coleccion).doc(uid)));
    borrados += 1;
  }

  const pagos = await db.collection('pagos').where('usuarioId', '==', uid).select().get();
  for (const doc of pagos.docs) {
    anotar(escritor.update(doc.ref, pagoSinDatosPersonales(borrarCampo)));
  }

  // El registro del panel puede nombrar al alumno: queda la acción, sin él.
  const registro = await db.collection('registro_admin')
    .where('usuarioId', '==', uid).select().get();
  for (const doc of registro.docs) {
    anotar(escritor.update(doc.ref, {
      usuarioId: borrarCampo,
      descripcion: 'Acción sobre una cuenta que fue eliminada.',
    }));
  }

  anotar(escritor.create(db.collection('registro_admin').doc(), {
    tipo: 'cuenta_eliminada',
    descripcion: quien.esAdmin
      ? 'El administrador eliminó una cuenta y sus datos.'
      : 'Un alumno eliminó su cuenta y sus datos desde la app.',
    adminUid: quien.uid,
    adminCorreo: quien.esAdmin ? quien.correo || 'admin' : 'el propio alumno',
    fecha: new Date(),
  }));

  await escritor.close();
  const errores = (await Promise.all(operaciones)).filter(Boolean);
  if (errores.length > 0) throw errores[0];

  await bucket.deleteFiles({ prefix: `comprobantes/${uid}/` });

  try {
    await auth.deleteUser(uid);
  } catch (e) {
    if (e?.code !== 'auth/user-not-found') throw e;
  }

  return { borrados, pagosAnonimizados: pagos.size };
}

function dependencias() {
  return {
    db: admin.firestore(),
    bucket: admin.storage().bucket(),
    auth: admin.auth(),
    borrarCampo: FieldValue.delete(),
  };
}

/** El alumno borra su propia cuenta (Perfil → Eliminar mi cuenta). */
const eliminarMiCuenta = onCall({ timeoutSeconds: 300 }, async (request) => {
  const token = request.auth?.token;
  if (!request.auth || !token) {
    throw new HttpsError('unauthenticated', 'Inicia sesión para continuar.');
  }
  if (token.admin === true) {
    throw new HttpsError(
      'failed-precondition',
      'La cuenta del administrador no se elimina desde la app.',
    );
  }
  if (!ingresoReciente(token.auth_time, Date.now())) {
    throw new HttpsError(
      'unauthenticated',
      'Por seguridad, vuelve a ingresar y repite la eliminación.',
    );
  }

  const uid = request.auth.uid;
  const resultado = await eliminarDatosDeCuenta({
    ...dependencias(), uid, quien: { uid, esAdmin: false },
  });
  return { ok: true, ...resultado };
});

/** El administrador borra la cuenta de alguien que lo pidió por correo. */
const eliminarCuentaAlumno = onCall({ timeoutSeconds: 300 }, async (request) => {
  const token = request.auth?.token;
  if (token?.admin !== true) {
    throw new HttpsError('permission-denied', 'Solo el administrador puede hacer esto.');
  }
  const uid = request.data?.uid;
  if (!uidValido(uid)) {
    throw new HttpsError('invalid-argument', 'El identificador del alumno no es válido.');
  }
  if (uid === request.auth.uid) {
    throw new HttpsError('failed-precondition', 'No puedes eliminar tu propia cuenta de administrador.');
  }

  const resultado = await eliminarDatosDeCuenta({
    ...dependencias(),
    uid,
    quien: { uid: request.auth.uid, esAdmin: true, correo: token.email },
  });
  return { ok: true, ...resultado };
});

module.exports = {
  MAX_SEGUNDOS_DESDE_INGRESO,
  POR_CAMPO,
  POR_ID,
  ingresoReciente,
  uidValido,
  pagoSinDatosPersonales,
  eliminarDatosDeCuenta,
  eliminarMiCuenta,
  eliminarCuentaAlumno,
};
