#!/usr/bin/env node
/**
 * Carga el currículo real (tool/curriculo_v1.json) en Firestore de AcademiApp V2.
 *
 * Qué hace:
 *   1. Escribe areas/{id}, cursos/{id}, temas/{id} con IDs determinísticos.
 *   2. Elimina SOLO los datos manuales de prueba conocidos del bloque 12.11
 *      (curso matematica, 6 temas, 3 publicaciones), tras verificar su contenido.
 *      lenguaje y fisica no se borran: se sobrescriben con el currículo real.
 *   3. Publica los temas hasta el día académico de la matrícula activa más
 *      avanzada de la versión + un buffer (publicación progresiva).
 *   4. Todo en un único lote atómico: o se aplica todo o nada.
 *
 * Por defecto NO escribe (simulación). Para escribir hay que pasar --apply.
 *
 * Uso (desde la raíz del proyecto, Windows cmd):
 *   cd tool && npm install && cd ..
 *   node tool/seed_academico_v2.js --key C:\ruta\serviceAccountKey.json
 *   node tool/seed_academico_v2.js --key C:\ruta\serviceAccountKey.json --apply
 *
 * Opciones:
 *   --key <ruta>              credencial de cuenta de servicio (o GOOGLE_APPLICATION_CREDENTIALS)
 *   --apply                   escribe en Firestore (sin esto solo simula)
 *   --version <id>            versión académica (por defecto version-1)
 *   --buffer-dias <n>         días publicados por delante del alumno más avanzado (por defecto 2)
 *   --publicar-hasta-dia <n>  fija manualmente el último día académico a publicar
 *   --inicio <YYYY-MM-DD>     fecha de inicio de referencia (por defecto: la matrícula activa más antigua)
 *   --offline                no se conecta a Firebase; solo muestra el plan calculado
 */
'use strict';

const fs = require('fs');
const path = require('path');

const PROYECTO_ESPERADO = 'academiapp-v2-7b9ce';
const ZONA_HORARIA = 'America/Lima';
const LIMITE_LOTE = 500;

// Se carga junto con firebase-admin (los tests no lo necesitan).
let FieldValue;

// Datos manuales de prueba del bloque 12.11 (ver documentos 02/03).
const TEMPORALES = {
  cursos: ['matematica', 'fisica', 'lenguaje'],
  temas: ['matrices', 'algebra', 'cinematica', 'dinamica', 'comprension-lectora', 'oraciones'],
  publicaciones: ['publicacion-matrices', 'publicacion-cinematica', 'publicacion-comprension'],
};

// ---------------------------------------------------------------------------
// Lógica pura (replica SecuenciaAcademicaService y CalendarioAcademicoService
// de lib/features/academic/domain/services; el test Dart verifica que coincidan).
// ---------------------------------------------------------------------------

function generarSecuencia(cursos, temas) {
  const cursosOrdenados = [...cursos].sort((a, b) => a.orden - b.orden);
  const porCurso = new Map(
    cursosOrdenados.map((c) => [
      c.id,
      temas.filter((t) => t.cursoId === c.id).sort((a, b) => a.orden - b.orden),
    ]),
  );
  const maximo = Math.max(0, ...[...porCurso.values()].map((l) => l.length));
  const secuencia = [];
  for (let ronda = 0; ronda < maximo; ronda++) {
    for (const curso of cursosOrdenados) {
      const lista = porCurso.get(curso.id);
      if (ronda < lista.length) secuencia.push(lista[ronda]);
    }
  }
  return secuencia;
}

/** fechaInicio: 'YYYY-MM-DD'. Devuelve [{numero, fecha:'YYYY-MM-DD', temas:[...]}]. */
function generarCalendario(secuencia, fechaInicio) {
  const dias = [];
  let posicion = 0;
  let numero = 1;
  const fecha = new Date(`${fechaInicio}T00:00:00Z`);
  while (posicion < secuencia.length) {
    const diaSemana = fecha.getUTCDay(); // 0 domingo, 6 sábado
    if (diaSemana !== 0) {
      const cantidad = diaSemana === 6 ? 2 : 3;
      const fin = Math.min(posicion + cantidad, secuencia.length);
      dias.push({
        numero,
        fecha: fecha.toISOString().slice(0, 10),
        temas: secuencia.slice(posicion, fin),
      });
      posicion = fin;
      numero++;
    }
    fecha.setUTCDate(fecha.getUTCDate() + 1);
  }
  return dias;
}

/** Fecha local de Lima en formato 'YYYY-MM-DD' (igual que ve la app). */
function fechaLima(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: ZONA_HORARIA,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/** Último día académico alcanzado en `hoy` (0 si aún no empieza). */
function diaAcademicoEn(calendario, hoy) {
  let ultimo = 0;
  for (const dia of calendario) {
    if (dia.fecha <= hoy) ultimo = dia.numero;
  }
  return ultimo;
}

function calcularTemasAPublicar(secuencia, fechaInicio, hastaDia) {
  const calendario = generarCalendario(secuencia, fechaInicio);
  return calendario.filter((d) => d.numero <= hastaDia);
}

/**
 * Todo el temario de una versión en UN documento: la app lo lee con una sola
 * lectura en vez de ~220 (17 cursos + 205 temas).
 */
function documentoCurriculo(curriculo, versionId) {
  return {
    versionId,
    areas: curriculo.areas.map((a) => ({ id: a.id, nombre: a.nombre, orden: a.orden })),
    cursos: curriculo.cursos.map((c) => ({
      id: c.id, areaId: c.areaId, nombre: c.nombre, orden: c.orden, icono: c.icono ?? null,
    })),
    temas: curriculo.temas.map((t) => ({
      id: t.id, cursoId: t.cursoId, titulo: t.titulo, orden: t.orden, descripcion: t.descripcion ?? null,
    })),
  };
}

/** Lista de temas publicados de una versión en UN documento (sin duplicados, ordenada). */
function documentoPublicaciones(versionId, temaIds) {
  return { versionId, temas: [...new Set(temaIds)].sort() };
}

// ---------------------------------------------------------------------------
// Utilidades de línea de comandos
// ---------------------------------------------------------------------------

function leerArgumentos(argv) {
  const args = { apply: false, offline: false, version: 'version-1', bufferDias: 2 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--apply') args.apply = true;
    else if (a === '--offline') args.offline = true;
    else if (a === '--key') args.key = argv[++i];
    else if (a === '--version') args.version = argv[++i];
    else if (a === '--buffer-dias') args.bufferDias = Number(argv[++i]);
    else if (a === '--publicar-hasta-dia') args.hastaDia = Number(argv[++i]);
    else if (a === '--inicio') args.inicio = argv[++i];
    else throw new Error(`Opción desconocida: ${a}`);
  }
  return args;
}

function cargarCurriculo() {
  const ruta = path.join(__dirname, 'curriculo_v1.json');
  const curriculo = JSON.parse(fs.readFileSync(ruta, 'utf8'));
  const { validar } = require('./extraer_curriculo_v1');
  validar(curriculo);
  return curriculo;
}

function imprimirDias(dias) {
  for (const d of dias) {
    console.log(`  Día ${d.numero} (${d.fecha}):`);
    for (const t of d.temas) console.log(`    - [${t.cursoId}] ${t.titulo}`);
  }
}

// ---------------------------------------------------------------------------
// Firebase
// ---------------------------------------------------------------------------

function iniciarFirebase(rutaKey) {
  const ruta = rutaKey || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!ruta) {
    throw new Error('Falta la credencial: usa --key <ruta> o GOOGLE_APPLICATION_CREDENTIALS.');
  }
  const credencial = JSON.parse(fs.readFileSync(ruta, 'utf8'));
  if (credencial.project_id !== PROYECTO_ESPERADO) {
    throw new Error(
      `La credencial es del proyecto "${credencial.project_id}", se esperaba "${PROYECTO_ESPERADO}". Abortado.`,
    );
  }
  const admin = require('firebase-admin');
  FieldValue = require('firebase-admin/firestore').FieldValue;
  admin.initializeApp({ credential: admin.credential.cert(credencial), projectId: PROYECTO_ESPERADO });
  return admin.firestore();
}

async function leerEstado(db, versionId) {
  const [cursos, temas, publicaciones, version, planes, matriculas] = await Promise.all([
    db.collection('cursos').get(),
    db.collection('temas').get(),
    db.collection('publicaciones_temas').where('versionId', '==', versionId).get(),
    db.collection('versiones_academicas').doc(versionId).get(),
    db.collection('planes_academicos').where('versionId', '==', versionId).where('activo', '==', true).get(),
    db.collection('matriculas').where('versionId', '==', versionId).where('estado', '==', 'activa').get(),
  ]);
  const mapa = (snap) => new Map(snap.docs.map((d) => [d.id, d.data()]));
  return {
    cursos: mapa(cursos),
    temas: mapa(temas),
    publicaciones: mapa(publicaciones),
    versionExiste: version.exists,
    planesActivos: planes.size,
    matriculas: matriculas.docs.map((d) => ({ id: d.id, ...d.data() })),
  };
}

/** Decide qué borrar y detecta documentos desconocidos que contaminarían la secuencia. */
function analizarExistentes(estado, curriculo) {
  const idsCursos = new Set(curriculo.cursos.map((c) => c.id));
  const idsTemas = new Set(curriculo.temas.map((t) => t.id));
  const borrar = { cursos: [], temas: [], publicaciones: [] };
  const desconocidos = [];

  for (const [id, datos] of estado.cursos) {
    if (idsCursos.has(id)) continue; // se sobrescribe
    if (TEMPORALES.cursos.includes(id)) borrar.cursos.push(id);
    else if (datos.activo === true) desconocidos.push(`cursos/${id}`);
  }
  for (const [id, datos] of estado.temas) {
    if (idsTemas.has(id)) continue;
    if (TEMPORALES.temas.includes(id) && TEMPORALES.cursos.includes(datos.cursoId)) {
      borrar.temas.push(id);
    } else if (datos.activo === true) desconocidos.push(`temas/${id}`);
  }
  for (const [id, datos] of estado.publicaciones) {
    if (TEMPORALES.publicaciones.includes(id) || TEMPORALES.temas.includes(datos.temaId)) {
      if (!idsTemas.has(datos.temaId)) borrar.publicaciones.push(id);
    }
  }
  return { borrar, desconocidos };
}

async function main() {
  const args = leerArgumentos(process.argv.slice(2));
  const curriculo = cargarCurriculo();
  const secuencia = generarSecuencia(curriculo.cursos, curriculo.temas);
  const totalDias = generarCalendario(secuencia, '2026-01-05').length;

  console.log(`Currículo: ${curriculo.areas.length} áreas, ${curriculo.cursos.length} cursos, ${curriculo.temas.length} temas.`);
  console.log(`Recorrido completo: ${totalDias} días académicos.`);
  console.log(args.apply ? 'MODO: APLICAR (escribe en Firestore)' : 'MODO: SIMULACIÓN (no escribe nada)');

  if (args.offline) {
    const inicio = args.inicio || fechaLima(new Date());
    const hasta = args.hastaDia ?? 1;
    console.log(`\n[offline] Inicio ${inicio}, días 1..${hasta}:`);
    imprimirDias(calcularTemasAPublicar(secuencia, inicio, hasta));
    return;
  }

  const db = iniciarFirebase(args.key);
  const estado = await leerEstado(db, args.version);

  console.log(`\nFirestore actual: ${estado.cursos.size} cursos, ${estado.temas.size} temas, ${estado.publicaciones.size} publicaciones de ${args.version}.`);
  if (!estado.versionExiste) throw new Error(`No existe versiones_academicas/${args.version}. Abortado.`);
  if (estado.planesActivos !== 1) {
    console.warn(`AVISO: ${estado.planesActivos} planes activos para ${args.version} (se esperaba 1).`);
  }

  // Publicación progresiva: alumno más avanzado (inicio más antiguo) + buffer.
  const hoy = fechaLima(new Date());
  let inicioReferencia = args.inicio;
  if (!inicioReferencia) {
    const inicios = estado.matriculas
      .filter((m) => m.fechaInicioAcademico && m.fechaInicioAcademico.toDate)
      .map((m) => fechaLima(m.fechaInicioAcademico.toDate()))
      .sort();
    inicioReferencia = inicios[0];
  }
  let hastaDia = args.hastaDia;
  if (hastaDia === undefined) {
    if (!inicioReferencia) {
      hastaDia = 1 + args.bufferDias;
      inicioReferencia = hoy;
      console.warn('AVISO: no hay matrículas activas; se publica desde hoy como Día 1.');
    } else {
      const diaHoy = diaAcademicoEn(generarCalendario(secuencia, inicioReferencia), hoy);
      hastaDia = Math.max(diaHoy, 1) + args.bufferDias;
    }
  }
  hastaDia = Math.min(hastaDia, totalDias);
  const diasPublicados = calcularTemasAPublicar(secuencia, inicioReferencia, hastaDia);
  const temasPublicados = diasPublicados.flatMap((d) => d.temas);

  console.log(`\nMatrículas activas: ${estado.matriculas.length}. Inicio de referencia: ${inicioReferencia}. Hoy (Lima): ${hoy}.`);
  console.log(`Se publicarán los días 1..${hastaDia} (${temasPublicados.length} temas):`);
  imprimirDias(diasPublicados);

  const { borrar, desconocidos } = analizarExistentes(estado, curriculo);
  console.log('\nDatos temporales a eliminar:');
  console.log(`  cursos: ${borrar.cursos.join(', ') || '(ninguno)'}`);
  console.log(`  temas: ${borrar.temas.join(', ') || '(ninguno)'}`);
  console.log(`  publicaciones: ${borrar.publicaciones.join(', ') || '(ninguna)'}`);

  if (desconocidos.length > 0) {
    console.error('\nDocumentos activos que NO son del currículo ni temporales conocidos:');
    for (const d of desconocidos) console.error(`  - ${d}`);
    throw new Error('Revisa esos documentos en la consola antes de continuar. No se escribió nada.');
  }

  const operaciones =
    curriculo.areas.length + curriculo.cursos.length + curriculo.temas.length +
    temasPublicados.length + borrar.cursos.length + borrar.temas.length + borrar.publicaciones.length + 2;
  if (operaciones > LIMITE_LOTE) throw new Error(`Demasiadas operaciones (${operaciones}) para un lote.`);

  console.log(`\nOperaciones en el lote: ${operaciones}.`);
  if (!args.apply) {
    console.log('\nSimulación terminada. Si todo se ve bien, repite el comando con --apply.');
    return;
  }

  const lote = db.batch();
  for (const id of borrar.publicaciones) lote.delete(db.collection('publicaciones_temas').doc(id));
  for (const id of borrar.temas) lote.delete(db.collection('temas').doc(id));
  for (const id of borrar.cursos) lote.delete(db.collection('cursos').doc(id));

  for (const a of curriculo.areas) {
    lote.set(db.collection('areas').doc(a.id), { nombre: a.nombre, orden: a.orden, activa: true });
  }
  for (const c of curriculo.cursos) {
    lote.set(db.collection('cursos').doc(c.id), {
      areaId: c.areaId, nombre: c.nombre, orden: c.orden, icono: c.icono, activo: true,
    });
  }
  for (const t of curriculo.temas) {
    lote.set(db.collection('temas').doc(t.id), {
      cursoId: t.cursoId, titulo: t.titulo, orden: t.orden, descripcion: null, activo: true,
    });
  }
  for (const t of temasPublicados) {
    lote.set(db.collection('publicaciones_temas').doc(`${args.version}__${t.id}`), {
      versionId: args.version, temaId: t.id, publicada: true,
    });
  }

  // Documentos resumen que lee la app (1 lectura cada uno).
  const yaPublicados = [...estado.publicaciones.entries()]
    .filter(([id, d]) => d.publicada === true && !borrar.publicaciones.includes(id))
    .map(([, d]) => d.temaId);
  const resumen = documentoPublicaciones(args.version, [...yaPublicados, ...temasPublicados.map((t) => t.id)]);
  lote.set(db.collection('curriculos').doc(args.version), {
    ...documentoCurriculo(curriculo, args.version),
    actualizadoEn: FieldValue.serverTimestamp(),
  });
  lote.set(db.collection('publicaciones_version').doc(args.version), {
    ...resumen,
    actualizadoEn: FieldValue.serverTimestamp(),
  });

  await lote.commit();
  console.log(`  curriculos/${args.version}: ${curriculo.temas.length} temas en un documento`);
  console.log(`  publicaciones_version/${args.version}: ${resumen.temas.length} temas publicados`);

  // Verificación posterior.
  const [areas, cursos, temas, pubs] = await Promise.all([
    db.collection('areas').get(),
    db.collection('cursos').where('activo', '==', true).get(),
    db.collection('temas').where('activo', '==', true).get(),
    db.collection('publicaciones_temas').where('versionId', '==', args.version).where('publicada', '==', true).get(),
  ]);
  console.log('\nAPLICADO. Estado final en Firestore:');
  console.log(`  áreas: ${areas.size}`);
  console.log(`  cursos activos: ${cursos.size}`);
  console.log(`  temas activos: ${temas.size}`);
  console.log(`  publicaciones de ${args.version}: ${pubs.size}`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = {
  iniciarFirebase,
  documentoCurriculo,
  documentoPublicaciones,
  generarSecuencia,
  generarCalendario,
  calcularTemasAPublicar,
  diaAcademicoEn,
  fechaLima,
  analizarExistentes,
  TEMPORALES,
};
