#!/usr/bin/env node
/**
 * Carga evaluaciones de práctica a Firestore desde un JSON local.
 *
 *   evaluaciones/{id}      -> datos públicos de la práctica
 *   preguntas/{id}         -> enunciado y opciones (SIN la correcta)
 *   claves_preguntas/{id}  -> opción correcta + explicación (solo el servidor las lee)
 *
 * Por defecto lee tool/preguntas.json (NO se sube a GitHub: tiene las respuestas).
 * Para probar puedes usar la plantilla: --archivo tool\preguntas.ejemplo.json
 *
 * Acepta también el formato de V1: { pregunta, opciones, respuestaCorrecta, explicacion }.
 * Cada pregunta puede declarar "habilidades": ["id-habilidad", ...] (opcional).
 * Si vuelves a cargar una evaluación con menos preguntas, las sobrantes se desactivan.
 *
 * Uso:
 *   node tool\cargar_evaluaciones.js --key C:\...\academiapp-v2-admin.json [--archivo ruta] [--apply]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const NIVELES = ['basica', 'intermedia', 'avanzada'];
const LETRAS = 'abcdefgh';

function normalizarPregunta(p) {
  return {
    enunciado: String(p.enunciado ?? p.pregunta ?? '').trim(),
    opciones: Array.isArray(p.opciones) ? p.opciones.map((o) => String(o).trim()) : [],
    correcta: p.correcta ?? p.respuestaCorrecta,
    explicacion: p.explicacion ? String(p.explicacion).trim() : null,
    habilidades: Array.isArray(p.habilidades)
      ? p.habilidades.map((h) => String(h).trim()).filter(Boolean)
      : [],
  };
}

/** Valida y convierte el JSON en documentos de Firestore. Función pura. */
function prepararEvaluaciones(archivo, idsTemas) {
  const errores = [];
  const versionId = archivo.versionId;
  if (!versionId) errores.push('Falta "versionId".');

  const evaluaciones = [];
  const vistas = new Set();

  for (const [i, ev] of (archivo.evaluaciones || []).entries()) {
    const donde = `evaluaciones[${i}]`;
    if (!idsTemas.has(ev.temaId)) { errores.push(`${donde}: tema "${ev.temaId}" no existe.`); continue; }
    if (!NIVELES.includes(ev.nivel)) { errores.push(`${donde}: nivel debe ser ${NIVELES.join('|')}.`); continue; }

    const id = `${versionId}__${ev.temaId}__practica-${ev.nivel}`;
    if (vistas.has(id)) { errores.push(`${donde}: evaluación repetida (${ev.temaId}, ${ev.nivel}).`); continue; }
    vistas.add(id);

    const preguntas = [];
    for (const [j, bruta] of (ev.preguntas || []).entries()) {
      const p = normalizarPregunta(bruta);
      const dondeP = `${donde}.preguntas[${j}]`;
      if (!p.enunciado) { errores.push(`${dondeP}: falta enunciado.`); continue; }
      if (p.opciones.length < 2 || p.opciones.length > LETRAS.length || p.opciones.some((o) => !o)) {
        errores.push(`${dondeP}: necesita entre 2 y ${LETRAS.length} opciones no vacías.`); continue;
      }
      if (!Number.isInteger(p.correcta) || p.correcta < 0 || p.correcta >= p.opciones.length) {
        errores.push(`${dondeP}: "correcta" debe ser el índice (0..${p.opciones.length - 1}).`); continue;
      }
      const preguntaId = `${id}__p${String(j + 1).padStart(2, '0')}`;
      preguntas.push({
        id: preguntaId,
        datos: {
          evaluacionId: id,
          enunciado: p.enunciado,
          dificultad: ev.nivel,
          orden: j + 1,
          activa: true,
          opciones: p.opciones.map((texto, k) => ({ id: LETRAS[k], texto })),
          // Habilidades que mide (opcional). Vacío = habilidad general del tema.
          habilidades: p.habilidades,
        },
        clave: { opcionCorrectaId: LETRAS[p.correcta], explicacion: p.explicacion },
      });
    }
    if (preguntas.length === 0) { errores.push(`${donde}: no tiene preguntas válidas.`); continue; }

    evaluaciones.push({
      id,
      datos: { temaId: ev.temaId, versionId, tipo: 'practica', nivel: ev.nivel, estado: 'publicada' },
      preguntas,
    });
  }

  return { versionId, evaluaciones, errores };
}

async function main() {
  const argv = process.argv.slice(2);
  const valor = (op) => { const i = argv.indexOf(op); return i >= 0 ? argv[i + 1] : undefined; };
  const apply = argv.includes('--apply');
  const rutaArchivo = valor('--archivo') || path.join(__dirname, 'preguntas.json');

  if (!fs.existsSync(rutaArchivo)) {
    throw new Error(`No existe ${rutaArchivo}. Copia tool\\preguntas.ejemplo.json como tool\\preguntas.json o usa --archivo.`);
  }

  const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, 'curriculo_v1.json'), 'utf8'));
  const archivo = JSON.parse(fs.readFileSync(rutaArchivo, 'utf8'));
  const plan = prepararEvaluaciones(archivo, new Set(curriculo.temas.map((t) => t.id)));

  console.log(apply ? 'MODO: APLICAR (escribe en Firestore)' : 'MODO: SIMULACIÓN (no escribe nada)');
  console.log(`Archivo: ${rutaArchivo}`);
  for (const ev of plan.evaluaciones) console.log(`  - ${ev.id}: ${ev.preguntas.length} preguntas`);
  if (plan.errores.length) {
    console.error('\nErrores:');
    for (const e of plan.errores) console.error(`  - ${e}`);
    throw new Error('Corrige el archivo. No se escribió nada.');
  }

  const { iniciarFirebase } = require('./seed_academico_v2');
  const db = iniciarFirebase(valor('--key'));

  // Preguntas existentes que ya no están en el archivo -> se desactivan.
  const desactivar = [];
  for (const ev of plan.evaluaciones) {
    const actuales = await db.collection('preguntas').where('evaluacionId', '==', ev.id).get();
    const nuevas = new Set(ev.preguntas.map((p) => p.id));
    for (const d of actuales.docs) if (!nuevas.has(d.id)) desactivar.push(d.ref);
  }
  if (desactivar.length) console.log(`Preguntas a desactivar: ${desactivar.length}`);

  const operaciones = plan.evaluaciones.reduce((n, ev) => n + 1 + ev.preguntas.length * 2, 0) + desactivar.length;
  if (operaciones > 500) throw new Error(`Demasiadas operaciones (${operaciones}); divide el archivo.`);

  if (!apply) {
    console.log('\nSimulación terminada. Repite con --apply para escribir.');
    return;
  }

  const lote = db.batch();
  for (const ev of plan.evaluaciones) {
    lote.set(db.collection('evaluaciones').doc(ev.id), ev.datos);
    for (const p of ev.preguntas) {
      lote.set(db.collection('preguntas').doc(p.id), p.datos);
      lote.set(db.collection('claves_preguntas').doc(p.id), p.clave);
    }
  }
  for (const ref of desactivar) lote.update(ref, { activa: false });
  await lote.commit();

  console.log(`\nAPLICADO: ${plan.evaluaciones.length} evaluaciones.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { prepararEvaluaciones, normalizarPregunta };
