'use strict';

/**
 * Pruebas de firestore.rules: las reglas son la barrera real de seguridad
 * (el panel y algunas pantallas escriben directo en Firestore).
 *
 *   cd reglas && npm install && npm test
 *
 * Usa el emulador de Firestore (no toca la base real).
 */
const test = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp } = require('firebase/firestore');

let entorno;

const alumno = () => entorno.authenticatedContext('alumno').firestore();
const otro = () => entorno.authenticatedContext('otro').firestore();
const admin = () => entorno.authenticatedContext('jefe', { admin: true }).firestore();
const anonimo = () => entorno.unauthenticatedContext().firestore();

const perfil = {
  correo: 'a@b.pe',
  nombre: 'Ana',
  rol: 'estudiante',
  estado: 'activo',
  fechaCreacion: new Date('2026-10-01'),
  carreraPostulada: 'Derecho',
};

test.before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: 'demo-academiapp',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

test.after(async () => {
  await entorno.cleanup();
});

test.beforeEach(async () => {
  await entorno.clearFirestore();
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'usuarios/alumno'), perfil);
    await setDoc(doc(db, 'claves_preguntas/p1'), { opcionCorrectaId: 'a' });
    await setDoc(doc(db, 'claves_examen/e1__p001'), { opcionCorrectaId: 'b' });
    await setDoc(doc(db, 'preguntas_examen/e1__p001'), { examenId: 'e1', enunciado: '¿?' });
    await setDoc(doc(db, 'simulacros/s1'), { usuarioId: 'alumno', estado: 'en_curso' });
    await setDoc(doc(db, 'matriculas/m1'), { usuarioId: 'alumno', estado: 'activa' });
  });
});

test('perfil: crea el suyo como estudiante activo y nada más', async () => {
  await assertSucceeds(setDoc(doc(otro(), 'usuarios/otro'), { ...perfil, correo: 'o@b.pe' }));
  await assertFails(setDoc(doc(otro(), 'usuarios/otro'), { ...perfil, rol: 'admin' }));
  await assertFails(setDoc(doc(otro(), 'usuarios/otro'), { ...perfil, plan: 'premium' }));
  await assertFails(setDoc(doc(otro(), 'usuarios/alumno'), perfil));
});

test('perfil: cambia su nombre, pero no su plan, rol ni estado', async () => {
  await assertSucceeds(updateDoc(doc(alumno(), 'usuarios/alumno'), { nombre: 'Ana Q.' }));
  await assertFails(updateDoc(doc(alumno(), 'usuarios/alumno'), { plan: 'premium' }));
  await assertFails(updateDoc(doc(alumno(), 'usuarios/alumno'), { rol: 'admin' }));
  await assertFails(updateDoc(doc(alumno(), 'usuarios/alumno'), { estado: 'suspendido' }));
});

test('perfil: la última actividad solo con la hora del servidor', async () => {
  await assertSucceeds(updateDoc(doc(alumno(), 'usuarios/alumno'), { ultimaActividad: serverTimestamp() }));
  await assertFails(updateDoc(doc(alumno(), 'usuarios/alumno'), { ultimaActividad: new Date('2030-01-01') }));
});

test('perfil: nadie lee el de otro, salvo el administrador', async () => {
  await assertSucceeds(getDoc(doc(alumno(), 'usuarios/alumno')));
  await assertFails(getDoc(doc(otro(), 'usuarios/alumno')));
  await assertFails(getDoc(doc(anonimo(), 'usuarios/alumno')));
  await assertSucceeds(getDoc(doc(admin(), 'usuarios/alumno')));
});

test('claves: el estudiante nunca las lee', async () => {
  await assertFails(getDoc(doc(alumno(), 'claves_preguntas/p1')));
  await assertFails(getDoc(doc(alumno(), 'claves_examen/e1__p001')));
});

test('examenes: el estudiante lee preguntas; solo el admin edita preguntas y claves', async () => {
  await assertSucceeds(getDoc(doc(alumno(), 'preguntas_examen/e1__p001')));
  await assertFails(setDoc(doc(alumno(), 'preguntas_examen/e1__p001'), { enunciado: 'x' }));
  await assertFails(setDoc(doc(alumno(), 'claves_examen/e1__p001'), { opcionCorrectaId: 'a' }));
  await assertSucceeds(setDoc(doc(admin(), 'preguntas_examen/e1__p001'), { enunciado: 'x' }));
  await assertSucceeds(getDoc(doc(admin(), 'claves_examen/e1__p001')));
  await assertSucceeds(setDoc(doc(admin(), 'claves_examen/e1__p001'), { opcionCorrectaId: 'c' }));
});

test('progreso de la clase: cada uno el suyo y con su id', async () => {
  const datos = (usuarioId) => ({
    usuarioId, versionId: 'version-1', temaId: 'algebra-02',
    tramos: [0, 30], duracion: 100, completada: false,
  });
  await assertSucceeds(setDoc(doc(alumno(), 'progreso_clases/alumno__version-1__algebra-02'), datos('alumno')));
  await assertFails(setDoc(doc(alumno(), 'progreso_clases/otro__version-1__algebra-02'), datos('otro')));
  await assertFails(setDoc(doc(alumno(), 'progreso_clases/alumno__version-1__fisica-01'), datos('alumno')));
  await assertSucceeds(getDoc(doc(alumno(), 'progreso_clases/alumno__version-1__algebra-02')));
  await assertFails(getDoc(doc(otro(), 'progreso_clases/alumno__version-1__algebra-02')));
});

test('lo que escribe el servidor no lo escribe el estudiante', async () => {
  const db = alumno();
  await assertFails(setDoc(doc(db, 'matriculas/m2'), { usuarioId: 'alumno', estado: 'activa' }));
  await assertFails(setDoc(doc(db, 'evidencias/x'), { usuarioId: 'alumno' }));
  await assertFails(setDoc(doc(db, 'intentos_evaluacion/x'), { usuarioId: 'alumno' }));
  await assertFails(setDoc(doc(db, 'uso_tutor/alumno__2026-11-01'), { consultas: 0 }));
  await assertFails(updateDoc(doc(db, 'simulacros/s1'), { estado: 'completado' }));
});

test('simulacros y matriculas: cada uno lee solo los suyos', async () => {
  await assertSucceeds(getDoc(doc(alumno(), 'simulacros/s1')));
  await assertFails(getDoc(doc(otro(), 'simulacros/s1')));
  await assertSucceeds(getDoc(doc(alumno(), 'matriculas/m1')));
  await assertFails(getDoc(doc(otro(), 'matriculas/m1')));
});

test('colecciones no declaradas quedan cerradas', async () => {
  await assertFails(getDoc(doc(alumno(), 'cualquier_cosa/x')));
  await assertFails(setDoc(doc(admin(), 'cualquier_cosa/x'), { a: 1 }));
});

test('matriculas: solo el administrador las crea y cambia; nadie las borra', async () => {
  const nueva = { usuarioId: 'alumno', versionId: 'v1', estado: 'activa' };
  await assertSucceeds(setDoc(doc(admin(), 'matriculas/m2'), nueva));
  await assertSucceeds(updateDoc(doc(admin(), 'matriculas/m1'), { estado: 'suspendida' }));
  await assertSucceeds(getDoc(doc(admin(), 'matriculas/m1')));
  await assertFails(deleteDoc(doc(admin(), 'matriculas/m1')));
});

test('registro del panel: solo se agrega, con el admin y la hora reales', async () => {
  const accion = { tipo: 'matricula', descripcion: 'Matriculó a Ana', adminUid: 'jefe', fecha: serverTimestamp() };
  await assertSucceeds(setDoc(doc(admin(), 'registro_admin/r1'), accion));
  await assertFails(setDoc(doc(admin(), 'registro_admin/r2'), { ...accion, adminUid: 'otro' }));
  await assertFails(setDoc(doc(admin(), 'registro_admin/r3'), { ...accion, fecha: new Date('2020-01-01') }));
  await assertFails(updateDoc(doc(admin(), 'registro_admin/r1'), { descripcion: 'x' }));
  await assertFails(getDoc(doc(alumno(), 'registro_admin/r1')));
});

test('el administrador lee el avance de cualquier estudiante', async () => {
  await assertSucceeds(getDoc(doc(admin(), 'simulacros/s1')));
  await assertSucceeds(getDoc(doc(admin(), 'progreso_clases/alumno__version-1__algebra-02')));
});

const pagoYape = {
  usuarioId: 'alumno', nombre: 'Ana', correo: 'a@b.pe', monto: 29,
  metodo: 'yape', operacion: '0045812', estado: 'pendiente',
};

test('pagos: el estudiante registra el suyo como pendiente', async () => {
  const db = alumno();
  await assertSucceeds(setDoc(doc(db, 'pagos/yape__0045812'), { ...pagoYape, creadoEn: serverTimestamp() }));
  // Otro no puede reclamar la misma operación.
  await assertFails(setDoc(doc(otro(), 'pagos/yape__0045812'), { ...pagoYape, usuarioId: 'otro', creadoEn: serverTimestamp() }));
  // Ni aprobarse solo, ni cambiar el id, ni a nombre de otro.
  await assertFails(setDoc(doc(db, 'pagos/yape__111111'), { ...pagoYape, operacion: '111111', estado: 'aprobado', creadoEn: serverTimestamp() }));
  await assertFails(setDoc(doc(db, 'pagos/yape__999999'), { ...pagoYape, operacion: '111111', creadoEn: serverTimestamp() }));
  await assertFails(setDoc(doc(db, 'pagos/yape__222222'), { ...pagoYape, operacion: '222222', usuarioId: 'otro', creadoEn: serverTimestamp() }));
  // Y no lo puede editar después.
  await assertFails(updateDoc(doc(db, 'pagos/yape__0045812'), { monto: 1 }));
  await assertFails(getDoc(doc(otro(), 'pagos/yape__0045812')));
});

test('pagos: una beca es de monto 0 y una por cupón', async () => {
  const beca = { usuarioId: 'alumno', nombre: 'Ana', correo: 'a@b.pe', monto: 0, metodo: 'beca', operacion: '', cupon: 'BECA-UNSCH', estado: 'pendiente', creadoEn: serverTimestamp() };
  await assertSucceeds(setDoc(doc(alumno(), 'pagos/beca__alumno__BECA-UNSCH'), beca));
  await assertFails(setDoc(doc(alumno(), 'pagos/beca__alumno__OTRA'), { ...beca, cupon: 'OTRA', monto: 5 }));
});

test('premium, cupones y configuración: solo el administrador los cambia', async () => {
  await assertSucceeds(updateDoc(doc(admin(), 'usuarios/alumno'), { premiumHasta: new Date('2027-01-30') }));
  await assertFails(updateDoc(doc(admin(), 'usuarios/alumno'), { rol: 'admin' }));
  await assertFails(updateDoc(doc(alumno(), 'usuarios/alumno'), { premiumHasta: new Date('2030-01-01') }));

  await assertSucceeds(setDoc(doc(admin(), 'cupones/BECA50'), { tipo: 'descuento', valor: 50, usos: 0, activo: true }));
  await assertSucceeds(getDoc(doc(alumno(), 'cupones/BECA50')));
  await assertFails(setDoc(doc(alumno(), 'cupones/GRATIS'), { tipo: 'premiumGratis', activo: true }));

  await assertSucceeds(setDoc(doc(admin(), 'config/academia'), { precio: 29 }));
  await assertSucceeds(getDoc(doc(alumno(), 'config/academia')));
  await assertFails(setDoc(doc(alumno(), 'config/academia'), { precio: 1 }));
});

test('versiones y temario: solo el administrador los crea y publica', async () => {
  const version = { codigo: 'c27', nombre: 'Ciclo 2027-I', estado: 'preparacion', fechaApertura: new Date('2027-03-01') };
  await assertSucceeds(setDoc(doc(admin(), 'versiones_academicas/c27'), version));
  await assertFails(setDoc(doc(alumno(), 'versiones_academicas/c28'), version));
  await assertFails(deleteDoc(doc(admin(), 'versiones_academicas/c27')));

  await assertSucceeds(setDoc(doc(admin(), 'publicaciones_version/c27'), { versionId: 'c27', temas: ['a1'] }));
  await assertSucceeds(setDoc(doc(admin(), 'publicaciones_temas/c27__a1'), { versionId: 'c27', temaId: 'a1', publicada: true }));
  await assertFails(setDoc(doc(alumno(), 'publicaciones_temas/c27__a2'), { versionId: 'c27', temaId: 'a2', publicada: true }));
  await assertSucceeds(setDoc(doc(admin(), 'curriculos/c27'), { versionId: 'c27', temas: [] }));
  await assertFails(setDoc(doc(alumno(), 'curriculos/c27'), { versionId: 'c27', temas: [] }));

  // Las claves de las prácticas: el administrador sí, el estudiante nunca.
  await assertSucceeds(getDoc(doc(admin(), 'claves_preguntas/p1')));
  await assertFails(getDoc(doc(alumno(), 'claves_preguntas/p1')));
});

test('material del tutor y material de los temas: solo el administrador', async () => {
  await assertSucceeds(setDoc(doc(admin(), 'material_tutor/v1__algebra-02'), { texto: 'Un polinomio…' }));
  await assertFails(getDoc(doc(alumno(), 'material_tutor/v1__algebra-02')));
  await assertSucceeds(setDoc(doc(admin(), 'recursos/v1__algebra-02__video-1'), { temaId: 'algebra-02', activo: true }));
  await assertFails(setDoc(doc(alumno(), 'recursos/v1__algebra-02__video-2'), { temaId: 'algebra-02', activo: true }));
  await assertSucceeds(setDoc(doc(admin(), 'claves_preguntas/v1__q__p01'), { opcionCorrectaId: 'a' }));
});
