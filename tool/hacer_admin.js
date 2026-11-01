#!/usr/bin/env node
/**
 * Da (o quita) el permiso de administrador del panel a una cuenta.
 * Reutiliza la idea de la V1 (functions/scripts/hacer_admin.js), pero por
 * correo en vez de UID.
 *
 * Uso:
 *   node tool\hacer_admin.js --key C:\...\academiapp-v2-admin.json --correo tu@correo.com [--quitar]
 *
 * Después, cierra sesión en el panel y vuelve a entrar para que el permiso
 * llegue a tu sesión.
 */
'use strict';

async function main() {
  const argv = process.argv.slice(2);
  const valor = (op) => { const i = argv.indexOf(op); return i >= 0 ? argv[i + 1] : undefined; };
  const correo = valor('--correo');
  const quitar = argv.includes('--quitar');
  if (!correo) throw new Error('Indica la cuenta con --correo <correo>.');

  const { iniciarFirebase } = require('./seed_academico_v2');
  iniciarFirebase(valor('--key'));
  const { getAuth } = require('firebase-admin/auth');
  const auth = getAuth();

  const usuario = await auth.getUserByEmail(correo);
  const claims = { ...(usuario.customClaims || {}) };
  if (quitar) delete claims.admin;
  else claims.admin = true;

  await auth.setCustomUserClaims(usuario.uid, claims);
  console.log(`${correo}: ${quitar ? 'ya no es' : 'ahora es'} administrador.`);
  console.log('Cierra sesión en el panel y vuelve a entrar para que se aplique.');
}

main().catch((error) => {
  console.error(`\nERROR: ${error.message}`);
  process.exit(1);
});
