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
const { doc, getDoc, setDoc, updateDoc } = require('firebase/firestore');

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

test('perfil: nadie lee el de otro, salvo el administrador', async () => {
  await assertSucceeds(getDoc(doc(alumno(), 'usuarios/alumno')));
  await assertFails(getDoc(doc(otro(), 'usuarios/alumno')));
  await assertFails(getDoc(doc(anonimo(), 'usuarios/alumno')));
  await assertSucceeds(getDoc(doc(admin(), 'usuarios/alumno')));
});

test('claves: el estudiante nunca las lee', async () => {
  await assertFails(getDoc(doc(alumno(), 'claves_preguntas/p1')));
  await assertFails(getDoc(doc(alumno(), 'claves_examen/e1__p001')));
  await assertFails(getDoc(doc(admin(), 'claves_preguntas/p1')));
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
