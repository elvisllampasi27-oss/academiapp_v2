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
const assert = require('node:assert');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, writeBatch, increment, Timestamp } = require('firebase/firestore');

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
  await assertFails(deleteDoc(doc(alumno(), 'cupones/BECA50')));
  await assertSucceeds(deleteDoc(doc(admin(), 'cupones/BECA50')));

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

test('narraciones: las agrega el administrador; las lee quien tiene sesión', async () => {
  const narracion = { versionId: 'v1', temaId: 'lit-03', titulo: 'Paco Yunque', tipo: 'Cuento', url: 'https://x.pe/a.mp3' };
  await assertSucceeds(setDoc(doc(admin(), 'narraciones/n1'), narracion));
  await assertFails(setDoc(doc(alumno(), 'narraciones/n2'), narracion));
  await assertSucceeds(getDoc(doc(alumno(), 'narraciones/n1')));
  await assertFails(getDoc(doc(anonimo(), 'narraciones/n1')));
  await assertFails(deleteDoc(doc(alumno(), 'narraciones/n1')));
  await assertSucceeds(deleteDoc(doc(admin(), 'narraciones/n1')));
});

test('docentes: cada uno pide su cuenta; el administrador decide', async () => {
  const solicitud = {
    uid: 'alumno',
    nombre: 'Ana',
    correo: 'a@b.pe',
    celular: '987654321',
    cursos: 'Historia del Perú',
    enlaces: ['https://youtube.com/@ana'],
    mensaje: 'Enseño historia hace cinco años en Huamanga.',
    estado: 'pendiente',
    creadaEn: serverTimestamp(),
  };
  // A nombre de otro, ya aprobada, sin enlaces o mensaje corto: no.
  await assertFails(setDoc(doc(otro(), 'solicitudes_docente/alumno'), solicitud));
  await assertFails(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), { ...solicitud, estado: 'aprobada' }));
  await assertFails(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), { ...solicitud, enlaces: [] }));
  await assertFails(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), { ...solicitud, mensaje: 'Hola' }));
  await assertFails(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), { ...solicitud, celular: '12345' }));
  await assertSucceeds(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), solicitud));
  await assertFails(getDoc(doc(otro(), 'solicitudes_docente/alumno')));

  // Mientras está en revisión no la cambia; tampoco se aprueba solo.
  await assertFails(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), solicitud));
  await assertFails(setDoc(doc(alumno(), 'docentes/alumno'), { activo: true }));

  // El administrador no la aprueba: el alumno corrige y la vuelve a enviar.
  await assertSucceeds(updateDoc(doc(admin(), 'solicitudes_docente/alumno'), { estado: 'rechazada', motivo: 'El enlace no abre.' }));
  await assertSucceeds(setDoc(doc(alumno(), 'solicitudes_docente/alumno'), solicitud));

  await assertSucceeds(setDoc(doc(admin(), 'docentes/alumno'), { uid: 'alumno', activo: true }));
  await assertSucceeds(getDoc(doc(otro(), 'docentes/alumno')));
});

test('clases de docentes: solo un docente aprobado envía; un corazón por alumno', async () => {
  const profe = () => entorno.authenticatedContext('profe').firestore();
  const clase = {
    docenteUid: 'profe',
    docenteNombre: 'Ana',
    temaId: 'his-03',
    temaTitulo: 'Los incas',
    cursoNombre: 'Historia del Perú',
    titulo: 'El Tahuantinsuyo en 10 minutos',
    videoId: 'pRRaLT4H-9s',
    estado: 'pendiente',
    corazones: 0,
    creadaEn: serverTimestamp(),
  };

  // Sin cuenta de docente, no.
  await assertFails(setDoc(doc(profe(), 'clases_docente/c1'), clase));
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'docentes/profe'), { uid: 'profe', activo: true });
  });
  // Ya publicada, con corazones o con un video raro, tampoco.
  await assertFails(setDoc(doc(profe(), 'clases_docente/c1'), { ...clase, estado: 'aprobada' }));
  await assertFails(setDoc(doc(profe(), 'clases_docente/c1'), { ...clase, corazones: 99 }));
  await assertFails(setDoc(doc(profe(), 'clases_docente/c1'), { ...clase, videoId: 'x' }));
  await assertSucceeds(setDoc(doc(profe(), 'clases_docente/c1'), clase));

  // Sin publicar: la ve el docente, no los alumnos.
  await assertSucceeds(getDoc(doc(profe(), 'clases_docente/c1')));
  await assertFails(getDoc(doc(alumno(), 'clases_docente/c1')));
  await assertFails(updateDoc(doc(profe(), 'clases_docente/c1'), { estado: 'aprobada' }));
  await assertSucceeds(updateDoc(doc(admin(), 'clases_docente/c1'), { estado: 'aprobada' }));
  await assertSucceeds(getDoc(doc(alumno(), 'clases_docente/c1')));

  const corazon = (db, uid, n) => {
    const lote = writeBatch(db);
    lote.update(doc(db, 'clases_docente/c1'), { corazones: increment(n) });
    if (n > 0) {
      lote.set(doc(db, `clases_docente/c1/corazones/${uid}`), { creadoEn: serverTimestamp() });
    } else {
      lote.delete(doc(db, `clases_docente/c1/corazones/${uid}`));
    }
    return lote.commit();
  };

  await assertSucceeds(corazon(alumno(), 'alumno', 1));
  // Otra vez el mismo alumno, o subir de a 5: no.
  await assertFails(corazon(alumno(), 'alumno', 1));
  await assertFails(corazon(otro(), 'otro', 5));
  // Solo el contador, sin su corazón: no. Cambiar el título: no.
  await assertFails(updateDoc(doc(otro(), 'clases_docente/c1'), { corazones: increment(1) }));
  await assertFails(updateDoc(doc(otro(), 'clases_docente/c1'), { titulo: 'Otra cosa' }));
  // El corazón de otro no se toca.
  await assertFails(deleteDoc(doc(otro(), 'clases_docente/c1/corazones/alumno')));
  await assertSucceeds(corazon(alumno(), 'alumno', -1));
  const despues = await entorno.withSecurityRulesDisabled(async (ctx) =>
    (await getDoc(doc(ctx.firestore(), 'clases_docente/c1'))).data().corazones);
  assert.equal(despues, 0);
});

test('en vivos: solo un docente aprobado programa; los alumnos ven los aprobados', async () => {
  const profe = () => entorno.authenticatedContext('profe').firestore();
  const inicio = new Date(Date.now() + 2 * 60 * 60 * 1000);
  inicio.setSeconds(0, 0);
  const minutos = (n) => Timestamp.fromDate(new Date(inicio.getTime() + n * 60 * 1000));
  const enVivo = {
    docenteUid: 'profe',
    docenteNombre: 'Ana',
    titulo: 'Repaso de los incas',
    plataforma: 'meet',
    enlace: 'https://meet.google.com/abc-defg-hij',
    inicio: Timestamp.fromDate(inicio),
    fin: minutos(60),
    duracionMinutos: 60,
    cursoNombre: 'Historia del Perú',
    estado: 'pendiente',
    creadoEn: serverTimestamp(),
  };

  // Sin cuenta de docente, no.
  await assertFails(setDoc(doc(profe(), 'en_vivos/v1'), enVivo));
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'docentes/profe'), { uid: 'profe', activo: true });
  });
  // Ya aprobado, con un fin que no cuadra, en el pasado o sin https: no.
  await assertFails(setDoc(doc(profe(), 'en_vivos/v1'), { ...enVivo, estado: 'aprobado' }));
  await assertFails(setDoc(doc(profe(), 'en_vivos/v1'), { ...enVivo, fin: minutos(600) }));
  await assertFails(setDoc(doc(profe(), 'en_vivos/v1'), {
    ...enVivo,
    inicio: Timestamp.fromDate(new Date(Date.now() - 60 * 60 * 1000)),
    fin: Timestamp.fromDate(new Date(Date.now())),
  }));
  await assertFails(setDoc(doc(profe(), 'en_vivos/v1'), { ...enVivo, enlace: 'http://meet.google.com/x' }));
  await assertSucceeds(setDoc(doc(profe(), 'en_vivos/v1'), enVivo));

  // Sin aprobar no lo ven los alumnos; el docente no se lo aprueba solo.
  await assertFails(getDoc(doc(alumno(), 'en_vivos/v1')));
  await assertFails(updateDoc(doc(profe(), 'en_vivos/v1'), { estado: 'aprobado' }));
  await assertSucceeds(updateDoc(doc(admin(), 'en_vivos/v1'), { estado: 'aprobado' }));
  await assertSucceeds(getDoc(doc(alumno(), 'en_vivos/v1')));

  await assertFails(deleteDoc(doc(alumno(), 'en_vivos/v1')));
  await assertSucceeds(deleteDoc(doc(profe(), 'en_vivos/v1')));
});

test('reportes: el estudiante manda el suyo como nuevo; el admin responde', async () => {
  const reporte = {
    usuarioId: 'alumno',
    nombre: 'Ana',
    correo: 'a@b.pe',
    tipo: 'preguntaExamen',
    mensaje: 'La clave no coincide con la solución.',
    contexto: { titulo: 'Exonerados 2025 · pregunta 3', examenId: 'e1', preguntaId: 'e1__p003' },
    estado: 'nuevo',
    creadoEn: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(alumno(), 'reportes/r1'), reporte));
  // Otro estado, otro dueño, mensaje vacío, campo extra o tipo inventado: no.
  await assertFails(setDoc(doc(alumno(), 'reportes/r2'), { ...reporte, estado: 'resuelto' }));
  await assertFails(setDoc(doc(otro(), 'reportes/r3'), reporte));
  await assertFails(setDoc(doc(alumno(), 'reportes/r4'), { ...reporte, mensaje: 'x' }));
  await assertFails(setDoc(doc(alumno(), 'reportes/r5'), { ...reporte, respuesta: 'listo' }));
  await assertFails(setDoc(doc(alumno(), 'reportes/r6'), { ...reporte, tipo: 'spam' }));
  await assertFails(setDoc(doc(anonimo(), 'reportes/r7'), reporte));
  // Lo lee él y el admin; nadie más.
  await assertSucceeds(getDoc(doc(alumno(), 'reportes/r1')));
  await assertFails(getDoc(doc(otro(), 'reportes/r1')));
  await assertSucceeds(getDoc(doc(admin(), 'reportes/r1')));
  // El estudiante no se responde a sí mismo; el admin sí. Nadie borra.
  await assertFails(updateDoc(doc(alumno(), 'reportes/r1'), { estado: 'resuelto' }));
  await assertSucceeds(updateDoc(doc(admin(), 'reportes/r1'), { estado: 'resuelto', respuesta: 'Corregida.' }));
  await assertFails(deleteDoc(doc(admin(), 'reportes/r1')));
});

test('avisos: el estudiante lee solo los activos; el admin los maneja', async () => {
  const aviso = {
    titulo: 'El lunes no hay clase',
    mensaje: 'Feriado.',
    versionId: null,
    importante: false,
    activo: true,
    hasta: new Date('2026-11-10'),
    creadoEn: serverTimestamp(),
  };
  await assertSucceeds(setDoc(doc(admin(), 'avisos/a1'), aviso));
  await assertSucceeds(setDoc(doc(admin(), 'avisos/a2'), { ...aviso, activo: false }));
  // Campos de más o título vacío: no.
  await assertFails(setDoc(doc(admin(), 'avisos/a3'), { ...aviso, enlace: 'x' }));
  await assertFails(setDoc(doc(admin(), 'avisos/a4'), { ...aviso, titulo: '' }));
  // El estudiante no publica ni borra; lee el activo y no el pausado.
  await assertFails(setDoc(doc(alumno(), 'avisos/a5'), aviso));
  await assertSucceeds(getDoc(doc(alumno(), 'avisos/a1')));
  await assertFails(getDoc(doc(alumno(), 'avisos/a2')));
  await assertFails(getDoc(doc(anonimo(), 'avisos/a1')));
  await assertFails(deleteDoc(doc(alumno(), 'avisos/a1')));
  await assertSucceeds(deleteDoc(doc(admin(), 'avisos/a1')));
});

test('examen semanal: el estudiante no ve preguntas ni claves antes de tiempo', async () => {
  await assertSucceeds(setDoc(doc(admin(), 'examenes_semanales/v1__s01'), { titulo: 'Semana 1', estado: 'publicado' }));
  await assertSucceeds(setDoc(doc(admin(), 'preguntas_semanales/v1__s01__p001'), { examenId: 'v1__s01', enunciado: '¿?' }));
  await assertSucceeds(setDoc(doc(admin(), 'claves_semanales/v1__s01__p001'), { opcionCorrectaId: 'a' }));
  await assertFails(getDoc(doc(alumno(), 'examenes_semanales/v1__s01')));
  await assertFails(getDoc(doc(alumno(), 'preguntas_semanales/v1__s01__p001')));
  await assertFails(getDoc(doc(alumno(), 'claves_semanales/v1__s01__p001')));
  await assertFails(setDoc(doc(alumno(), 'preguntas_semanales/x'), { examenId: 'v1__s01' }));
});
