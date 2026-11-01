#!/usr/bin/env node
/**
 * Carga seminarios (enlaces de YouTube) desde tool/seminarios.json.
 *
 *   seminarios/{id} -> { titulo, cursoId, cursoNombre, fecha, duracionMinutos, videoId, activo }
 *
 * Uso:
 *   node tool\cargar_seminarios.js --key C:\...\academiapp-v2-admin.json [--apply]
 */
'use strict';

const fs = require('fs');
const path = require('path');

const ID_YOUTUBE = /^[A-Za-z0-9_-]{11}$/;

/** ID de YouTube desde un ID suelto o un enlace (watch, youtu.be, live, shorts, embed). */
function idYoutube(valor) {
  const texto = String(valor || '').trim();
  if (ID_YOUTUBE.test(texto)) return texto;

  let url;
  try { url = new URL(texto); } catch { return null; }

  const host = url.hostname.replace(/^www\./, '').replace(/^m\./, '');
  const partes = url.pathname.split('/').filter(Boolean);
  let id = null;

  if (host === 'youtu.be') id = partes[0];
  else if (host === 'youtube.com') {
    if (partes[0] === 'watch') id = url.searchParams.get('v');
    else if (['live', 'shorts', 'embed'].includes(partes[0])) id = partes[1];
  }

  return id && ID_YOUTUBE.test(id) ? id : null;
}

/** "2026-11-07T19:00" en hora de Perú (UTC-5, sin horario de verano) -> Date. */
function fechaPeru(texto) {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(String(texto || ''))) return null;
  const fecha = new Date(`${texto}:00-05:00`);
  return Number.isNaN(fecha.getTime()) ? null : fecha;
}

/** Valida y convierte. Función pura. */
function prepararSeminarios(archivo, cursos) {
  const errores = [];
  const omitidos = [];
  const seminarios = [];
  const ids = new Set();

  for (const [i, s] of (archivo.seminarios || []).entries()) {
    const donde = `seminarios[${i}]`;
    if (String(s.youtube || '').startsWith('PEGA_AQUI')) { omitidos.push(`${donde}: sin enlace todavía.`); continue; }

    const id = String(s.id || '').trim();
    if (!/^[a-z0-9-]+$/.test(id)) { errores.push(`${donde}: "id" debe usar minúsculas, números y guiones.`); continue; }
    if (ids.has(id)) { errores.push(`${donde}: id repetido "${id}".`); continue; }
    ids.add(id);

    const titulo = String(s.titulo || '').trim();
    if (!titulo) { errores.push(`${donde}: falta "titulo".`); continue; }

    const curso = s.cursoId ? cursos.get(s.cursoId) : null;
    if (s.cursoId && !curso) { errores.push(`${donde}: el curso "${s.cursoId}" no existe.`); continue; }

    const fecha = fechaPeru(s.fecha);
    if (!fecha) { errores.push(`${donde}: "fecha" debe ser AAAA-MM-DDTHH:MM (hora de Perú).`); continue; }

    const videoId = idYoutube(s.youtube);
    if (!videoId) { errores.push(`${donde}: "youtube" no es un enlace o ID de YouTube válido.`); continue; }

    const duracion = Number(s.duracionMinutos || 90);
    if (!Number.isInteger(duracion) || duracion <= 0 || duracion > 600) {
      errores.push(`${donde}: "duracionMinutos" inválido.`); continue;
    }

    seminarios.push({
      id,
      datos: {
        titulo,
        cursoId: curso ? s.cursoId : null,
        cursoNombre: curso ? curso.nombre : null,
        fecha,
        duracionMinutos: duracion,
        videoId,
        activo: s.activo !== false,
      },
    });
  }

  return { seminarios, errores, omitidos };
}

async function main() {
  const argv = process.argv.slice(2);
  const valor = (op) => { const i = argv.indexOf(op); return i >= 0 ? argv[i + 1] : undefined; };
  const apply = argv.includes('--apply');

  const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, 'curriculo_v1.json'), 'utf8'));
  const archivo = JSON.parse(fs.readFileSync(valor('--archivo') || path.join(__dirname, 'seminarios.json'), 'utf8'));
  const plan = prepararSeminarios(archivo, new Map(curriculo.cursos.map((c) => [c.id, c])));

  console.log(apply ? 'MODO: APLICAR (escribe en Firestore)' : 'MODO: SIMULACIÓN (no escribe nada)');
  for (const s of plan.seminarios) {
    console.log(`  - ${s.id}: ${s.datos.titulo} (${s.datos.fecha.toISOString()})`);
  }
  for (const o of plan.omitidos) console.log(`  - ${o}`);
  if (plan.errores.length) {
    console.error('\nErrores:');
    for (const e of plan.errores) console.error(`  - ${e}`);
    throw new Error('Corrige el archivo. No se escribió nada.');
  }

  if (!apply) {
    console.log('\nSimulación terminada. Repite con --apply para escribir.');
    return;
  }

  const { iniciarFirebase } = require('./seed_academico_v2');
  const db = iniciarFirebase(valor('--key'));
  const lote = db.batch();
  for (const s of plan.seminarios) lote.set(db.collection('seminarios').doc(s.id), s.datos);
  await lote.commit();

  console.log(`\nAPLICADO: ${plan.seminarios.length} seminarios.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { prepararSeminarios, idYoutube, fechaPeru };
