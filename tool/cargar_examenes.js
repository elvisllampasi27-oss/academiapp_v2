#!/usr/bin/env node
/**
 * Carga exámenes pasados (Ordinario / Exonerados) a Firestore, con el mismo
 * formato JSON que usaba el panel de control de la V1:
 *
 *   { "preguntas": [ { enunciado, opciones: [...], clave: "texto de la correcta",
 *                      solucion, imagen, imagenSolucion, latex, latexSolucion } ] }
 *
 * Carpeta esperada (la misma de la V1):
 *   <carpeta>/<ordinario|exonerados>/<dd-mm-aaaa>/<cualquier>.json + imágenes
 *
 * Escribe:
 *   examenes/{id}            -> datos públicos (tipo, fecha, secciones)
 *   preguntas_examen/{id}    -> enunciado, opciones e imagen (SIN la correcta)
 *   claves_examen/{id}       -> opción correcta y solución (solo el servidor)
 *   indices/preguntas_examen -> lista {id, seccion} para armar simulacros
 *
 * Las imágenes se copian a hosting/examenes/... y se publican con
 *   firebase deploy --only hosting      (funciona en el plan gratis)
 *
 * Los JSON tienen las respuestas: NO van a GitHub (la carpeta está fuera del repo
 * o en .gitignore).
 *
 * Uso:
 *   node tool\cargar_examenes.js --carpeta C:\ruta\examenes --key C:\...\academiapp-v2-admin.json [--apply]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const LETRAS = 'abcdefgh';
const TIPOS = ['ordinario', 'exonerados'];
const URL_HOSTING = 'https://academiapp-v2-7b9ce.web.app';
const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

const texto = (v) => (v === undefined || v === null ? '' : String(v).trim());

/** "16-11-2025" -> "2025-11-16" (o null si no es una fecha). */
function fechaIso(carpeta) {
  const m = /^(\d{2})-(\d{2})-(\d{4})$/.exec(carpeta);
  return m ? `${m[3]}-${m[2]}-${m[1]}` : null;
}

function tituloExamen(tipo, iso) {
  const [a, m, d] = iso.split('-').map(Number);
  const nombre = tipo === 'ordinario' ? 'Ordinario' : 'Exonerados';
  return `${nombre} · ${d} ${MESES[m - 1]} ${a}`;
}

function urlImagen(tipo, carpeta, archivo) {
  return `${URL_HOSTING}/examenes/${tipo}/${carpeta}/${encodeURIComponent(archivo)}`;
}

/**
 * Valida un examen y lo convierte en documentos. Función pura.
 * Las preguntas con problemas se omiten (con aviso) en vez de cargarse mal.
 */
function prepararExamen({ tipo, carpeta, preguntas, secciones, archivos }) {
  const avisos = [];
  const iso = fechaIso(carpeta);
  if (!TIPOS.includes(tipo)) throw new Error(`Tipo desconocido: ${tipo}`);
  if (!iso) throw new Error(`La carpeta "${carpeta}" no es una fecha dd-mm-aaaa.`);

  const id = `${tipo}-${iso}`;
  const seccionDe = (n) => (secciones || []).find((s) => n >= s.desde && n <= s.hasta)?.nombre || 'General';
  if (!secciones) avisos.push(`${id}: sin secciones en examenes_secciones.json (todo irá como "General").`);

  const docsPreguntas = [];
  const claves = [];
  const imagenes = new Set();

  preguntas.forEach((bruta, i) => {
    const numero = i + 1;
    const donde = `${id} #${numero}`;
    const enunciado = texto(bruta.enunciado) || texto(bruta.latex);
    const opciones = Array.isArray(bruta.opciones) ? bruta.opciones.map(texto) : [];
    const clave = texto(bruta.clave);

    if (!enunciado) { avisos.push(`${donde}: sin enunciado, se omite.`); return; }
    if (opciones.length < 2 || opciones.length > LETRAS.length || opciones.some((o) => !o)) {
      avisos.push(`${donde}: opciones inválidas, se omite.`); return;
    }
    const indice = opciones.indexOf(clave);
    if (indice < 0) { avisos.push(`${donde}: la clave "${clave}" no está entre las opciones, se omite.`); return; }

    const imagen = texto(bruta.imagen);
    if (imagen && !archivos.has(imagen)) { avisos.push(`${donde}: falta la imagen ${imagen}, se omite.`); return; }
    const imagenSolucion = texto(bruta.imagenSolucion);
    const conImagenSolucion = imagenSolucion && archivos.has(imagenSolucion);
    if (imagenSolucion && !conImagenSolucion) avisos.push(`${donde}: falta la imagen de solución ${imagenSolucion} (se carga sin ella).`);

    if (imagen) imagenes.add(imagen);
    if (conImagenSolucion) imagenes.add(imagenSolucion);

    const preguntaId = `${id}__p${String(numero).padStart(3, '0')}`;
    docsPreguntas.push({
      id: preguntaId,
      datos: {
        examenId: id,
        numero,
        seccion: seccionDe(numero),
        enunciado,
        opciones: opciones.map((t, k) => ({ id: LETRAS[k], texto: t })),
        imagen: imagen ? urlImagen(tipo, carpeta, imagen) : null,
        activa: true,
      },
    });
    claves.push({
      id: preguntaId,
      datos: {
        examenId: id,
        opcionCorrectaId: LETRAS[indice],
        solucion: texto(bruta.solucion) || texto(bruta.latexSolucion) || null,
        imagenSolucion: conImagenSolucion ? urlImagen(tipo, carpeta, imagenSolucion) : null,
      },
    });
  });

  const totales = new Map();
  for (const p of docsPreguntas) totales.set(p.datos.seccion, (totales.get(p.datos.seccion) || 0) + 1);

  return {
    id,
    examen: {
      tipo,
      fecha: iso,
      titulo: tituloExamen(tipo, iso),
      totalPreguntas: docsPreguntas.length,
      secciones: [...totales].map(([nombre, total]) => ({ nombre, total })),
      estado: 'publicado',
    },
    preguntas: docsPreguntas,
    claves,
    imagenes: [...imagenes],
    avisos,
  };
}

/** Recorre la carpeta y prepara todos los exámenes que tengan JSON. */
function leerCarpeta(raiz, secciones) {
  const planes = [];
  const sinJson = [];

  for (const tipo of TIPOS) {
    const dirTipo = path.join(raiz, tipo);
    if (!fs.existsSync(dirTipo)) continue;

    for (const carpeta of fs.readdirSync(dirTipo).sort()) {
      const dir = path.join(dirTipo, carpeta);
      if (!fs.statSync(dir).isDirectory()) continue;

      const archivos = fs.readdirSync(dir);
      const json = archivos.find((a) => a.toLowerCase().endsWith('.json'));
      if (!json) { sinJson.push(`${tipo}/${carpeta}`); continue; }

      const contenido = JSON.parse(fs.readFileSync(path.join(dir, json), 'utf8'));
      const plan = prepararExamen({
        tipo,
        carpeta,
        preguntas: contenido.preguntas || [],
        secciones: secciones[`${tipo}/${carpeta}`],
        archivos: new Set(archivos),
      });
      plan.dir = dir;
      plan.tipo = tipo;
      plan.carpeta = carpeta;
      planes.push(plan);
    }
  }

  return { planes, sinJson };
}

async function main() {
  const argv = process.argv.slice(2);
  const valor = (op) => { const i = argv.indexOf(op); return i >= 0 ? argv[i + 1] : undefined; };
  const apply = argv.includes('--apply');
  const raiz = valor('--carpeta');
  if (!raiz || !fs.existsSync(raiz)) throw new Error('Indica la carpeta de exámenes con --carpeta <ruta>.');

  const secciones = JSON.parse(fs.readFileSync(path.join(__dirname, 'examenes_secciones.json'), 'utf8'));
  const { planes, sinJson } = leerCarpeta(raiz, secciones);

  console.log(apply ? 'MODO: APLICAR (escribe en Firestore)' : 'MODO: SIMULACIÓN (no escribe nada)');
  for (const p of planes) {
    console.log(`  - ${p.id}: ${p.preguntas.length} preguntas, ${p.imagenes.length} imágenes`);
  }
  for (const s of sinJson) console.log(`  - ${s}: sin JSON (solo imágenes), se omite.`);
  const avisos = planes.flatMap((p) => p.avisos);
  if (avisos.length) {
    console.log('\nAvisos:');
    for (const a of avisos) console.log(`  - ${a}`);
  }

  // Copia de imágenes a hosting/ (se publica con firebase deploy --only hosting).
  const destinoRaiz = path.join(__dirname, '..', 'hosting', 'examenes');
  if (apply) {
    for (const p of planes) {
      const destino = path.join(destinoRaiz, p.tipo, p.carpeta);
      fs.mkdirSync(destino, { recursive: true });
      for (const img of p.imagenes) fs.copyFileSync(path.join(p.dir, img), path.join(destino, img));
    }
  }

  if (!apply) {
    console.log('\nSimulación terminada. Repite con --apply para escribir.');
    return;
  }

  const { iniciarFirebase } = require('./seed_academico_v2');
  const db = iniciarFirebase(valor('--key'));
  const { FieldValue } = require('firebase-admin/firestore');

  const operaciones = [];
  for (const p of planes) {
    operaciones.push((l) => l.set(db.collection('examenes').doc(p.id), {
      ...p.examen, actualizadoEn: FieldValue.serverTimestamp(),
    }));
    for (const q of p.preguntas) operaciones.push((l) => l.set(db.collection('preguntas_examen').doc(q.id), q.datos));
    for (const c of p.claves) operaciones.push((l) => l.set(db.collection('claves_examen').doc(c.id), c.datos));

    // Preguntas de una carga anterior que ya no están -> se desactivan.
    const nuevas = new Set(p.preguntas.map((q) => q.id));
    const actuales = await db.collection('preguntas_examen').where('examenId', '==', p.id).get();
    for (const d of actuales.docs) if (!nuevas.has(d.id)) operaciones.push((l) => l.update(d.ref, { activa: false }));
  }

  // Índice para armar simulacros con 1 lectura (en vez de leer todo el banco).
  const indice = [];
  for (const p of planes) for (const q of p.preguntas) indice.push({ id: q.id, seccion: q.datos.seccion });
  const otros = await db.collection('examenes').get();
  const cargados = new Set(planes.map((p) => p.id));
  for (const d of otros.docs) {
    if (cargados.has(d.id)) continue;
    // Exámenes cargados antes desde otra carpeta: se conservan en el índice.
    const qs = await db.collection('preguntas_examen').where('examenId', '==', d.id).where('activa', '==', true).get();
    for (const q of qs.docs) indice.push({ id: q.id, seccion: q.data().seccion });
  }
  operaciones.push((l) => l.set(db.collection('indices').doc('preguntas_examen'), {
    preguntas: indice, actualizadoEn: FieldValue.serverTimestamp(),
  }));

  // Firestore admite 500 escrituras por lote.
  for (let i = 0; i < operaciones.length; i += 400) {
    const lote = db.batch();
    for (const op of operaciones.slice(i, i + 400)) op(lote);
    await lote.commit();
  }

  console.log(`\nAPLICADO: ${planes.length} exámenes (${operaciones.length} escrituras).`);
  console.log('Imágenes copiadas a hosting/examenes. Publícalas con: firebase deploy --only hosting');
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { prepararExamen, leerCarpeta, fechaIso, tituloExamen };
