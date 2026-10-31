#!/usr/bin/env node
/**
 * Carga contenidos y recursos (videos, PDF...) de tool/material.json en Firestore.
 *
 * - IDs determinísticos: volver a ejecutarlo actualiza, no duplica.
 * - Valida que cada temaId exista en el currículo (tool/curriculo_v1.json).
 * - Omite recursos cuya ubicación siga siendo un marcador "PEGA_AQUI...".
 * - Por defecto solo simula; escribe con --apply.
 *
 * Uso (desde la raíz del proyecto):
 *   node tool\cargar_material.js --key C:\ruta\clave.json
 *   node tool\cargar_material.js --key C:\ruta\clave.json --apply
 *
 * Formato de cada recurso en material.json:
 *   { "temaId": "geografia-01", "tipo": "video|pdf|teoria|ejemplo|ejercicio|grabacion",
 *     "titulo": "...", "ubicacion": "https://... (o ID de YouTube para video)",
 *     "reemplazaA": "id-de-recurso-anterior (opcional)" }
 */
'use strict';

const fs = require('fs');
const path = require('path');

const TIPOS = ['video', 'pdf', 'teoria', 'ejemplo', 'ejercicio', 'grabacion'];
const ID_YOUTUBE = /^[A-Za-z0-9_-]{11}$/;

function ubicacionValida(tipo, ubicacion) {
  if (tipo === 'video' && ID_YOUTUBE.test(ubicacion)) return true;
  try {
    const url = new URL(ubicacion);
    return url.protocol === 'https:' && url.hostname.length > 0;
  } catch {
    return false;
  }
}

/** Valida material.json y devuelve los documentos a escribir. Función pura. */
function prepararMaterial(material, idsTemas) {
  const errores = [];
  const omitidos = [];
  const versionId = material.versionId;
  if (!versionId) errores.push('Falta "versionId" en material.json.');

  const contenidos = [];
  const vistosContenido = new Set();
  for (const [i, c] of (material.contenidos || []).entries()) {
    const donde = `contenidos[${i}]`;
    if (!idsTemas.has(c.temaId)) { errores.push(`${donde}: tema "${c.temaId}" no existe.`); continue; }
    if (!Number.isInteger(c.orden) || c.orden < 1) { errores.push(`${donde}: "orden" debe ser entero >= 1.`); continue; }
    if (!c.nombre || !String(c.nombre).trim()) { errores.push(`${donde}: falta "nombre".`); continue; }
    const id = `${c.temaId}-c${String(c.orden).padStart(2, '0')}`;
    if (vistosContenido.has(id)) { errores.push(`${donde}: orden ${c.orden} repetido en ${c.temaId}.`); continue; }
    vistosContenido.add(id);
    contenidos.push({
      id,
      datos: {
        temaId: c.temaId,
        nombre: String(c.nombre).trim(),
        descripcion: c.descripcion ? String(c.descripcion).trim() : null,
        orden: c.orden,
        activo: true,
      },
    });
  }

  const recursos = [];
  const contador = new Map();
  for (const [i, r] of (material.recursos || []).entries()) {
    const donde = `recursos[${i}]`;
    if (!idsTemas.has(r.temaId)) { errores.push(`${donde}: tema "${r.temaId}" no existe.`); continue; }
    if (!TIPOS.includes(r.tipo)) { errores.push(`${donde}: tipo "${r.tipo}" inválido (${TIPOS.join(', ')}).`); continue; }
    if (!r.titulo || !String(r.titulo).trim()) { errores.push(`${donde}: falta "titulo".`); continue; }
    const ubicacion = String(r.ubicacion || '').trim();

    const clave = `${r.temaId}__${r.tipo}`;
    const n = (contador.get(clave) || 0) + 1;
    contador.set(clave, n);

    if (ubicacion.startsWith('PEGA_AQUI')) { omitidos.push(`${donde} (${r.temaId}, ${r.tipo}): sin enlace todavía.`); continue; }
    if (!ubicacionValida(r.tipo, ubicacion)) { errores.push(`${donde}: ubicación no es https ni ID de YouTube.`); continue; }

    recursos.push({
      id: `${versionId}__${clave}-${n}`,
      datos: {
        temaId: r.temaId,
        versionId,
        tipo: r.tipo,
        titulo: String(r.titulo).trim(),
        ubicacion,
        activo: true,
        reemplazaA: r.reemplazaA || null,
      },
    });
  }

  return { versionId, contenidos, recursos, omitidos, errores };
}

async function main() {
  const argv = process.argv.slice(2);
  const apply = argv.includes('--apply');
  const iKey = argv.indexOf('--key');
  const key = iKey >= 0 ? argv[iKey + 1] : undefined;

  const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, 'curriculo_v1.json'), 'utf8'));
  const material = JSON.parse(fs.readFileSync(path.join(__dirname, 'material.json'), 'utf8'));
  const plan = prepararMaterial(material, new Set(curriculo.temas.map((t) => t.id)));

  console.log(apply ? 'MODO: APLICAR (escribe en Firestore)' : 'MODO: SIMULACIÓN (no escribe nada)');
  console.log(`Versión: ${plan.versionId}`);
  console.log(`Contenidos válidos: ${plan.contenidos.length}`);
  console.log(`Recursos válidos: ${plan.recursos.length}`);
  for (const r of plan.recursos) console.log(`  - ${r.id}: ${r.datos.titulo}`);
  if (plan.omitidos.length) {
    console.log('Omitidos (completa el enlace en material.json):');
    for (const o of plan.omitidos) console.log(`  - ${o}`);
  }
  if (plan.errores.length) {
    console.error('\nErrores en material.json:');
    for (const e of plan.errores) console.error(`  - ${e}`);
    throw new Error('Corrige material.json. No se escribió nada.');
  }

  const { iniciarFirebase } = require('./seed_academico_v2');
  const db = iniciarFirebase(key);
  const version = await db.collection('versiones_academicas').doc(plan.versionId).get();
  if (!version.exists) throw new Error(`No existe versiones_academicas/${plan.versionId}.`);

  if (!apply) {
    console.log('\nSimulación terminada. Repite con --apply para escribir.');
    return;
  }

  const lote = db.batch();
  for (const c of plan.contenidos) lote.set(db.collection('contenidos').doc(c.id), c.datos);
  for (const r of plan.recursos) lote.set(db.collection('recursos').doc(r.id), r.datos);
  await lote.commit();
  console.log(`\nAPLICADO: ${plan.contenidos.length} contenidos y ${plan.recursos.length} recursos.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { prepararMaterial };
