'use strict';

const { HttpsError } = require('firebase-functions/v2/https');

/** Exige un estudiante activo con matrícula activa. Devuelve la matrícula. */
async function verificarEstudiante(db, uid) {
  const [usuarioSnap, matriculas] = await Promise.all([
    db.collection('usuarios').doc(uid).get(),
    db.collection('matriculas')
      .where('usuarioId', '==', uid)
      .where('estado', '==', 'activa')
      .limit(1)
      .get(),
  ]);

  const usuario = usuarioSnap.data();
  if (!usuario || usuario.rol !== 'estudiante' || usuario.estado !== 'activo') {
    throw new HttpsError('permission-denied', 'Tu cuenta no puede usar esta función.');
  }
  if (matriculas.empty) {
    throw new HttpsError('permission-denied', 'No tienes una matrícula activa.');
  }

  return { id: matriculas.docs[0].id, ...matriculas.docs[0].data() };
}

module.exports = { verificarEstudiante };
