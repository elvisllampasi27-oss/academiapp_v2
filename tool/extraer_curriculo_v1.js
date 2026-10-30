#!/usr/bin/env node
/**
 * Extrae el currículo real de AcademiApp V1 (lib/seed_firestore.dart)
 * y lo convierte al esquema académico de V2 en tool/curriculo_v1.json.
 *
 * Uso:
 *   node tool/extraer_curriculo_v1.js <ruta a seed_firestore.dart de V1>
 *
 * No toca Firebase. Solo lee el archivo Dart y escribe el JSON.
 * Falla si no encuentra exactamente 17 cursos y 205 temas.
 */
'use strict';

const fs = require('fs');
const path = require('path');

// Las áreas en V1 son texto libre; V2 necesita IDs estables.
const AREAS = {
  'Comunicación': 'comunicacion',
  'Matemática': 'matematica',
  'Ciencias y Tecnología': 'ciencias_tecnologia',
  'Ciencias Sociales': 'ciencias_sociales',
  'Desarrollo Personal, Ciudadanía y Cívica': 'dpcc',
  'Razonamiento Matemático': 'razonamiento_matematico',
};

const CURSOS_ESPERADOS = 17;
const TEMAS_ESPERADOS = 205;

function extraer(textoDart) {
  const inicio = textoDart.indexOf('final cursos = [');
  const fin = textoDart.indexOf('];', inicio);
  if (inicio < 0 || fin < 0) {
    throw new Error('No se encontró la lista "final cursos = [...]" en el archivo.');
  }
  const cuerpo = textoDart.slice(inicio, fin);

  const patronCurso =
    /'id':\s*'([^']+)',\s*'nombre':\s*'([^']+)',\s*'area':\s*'([^']+)',\s*'orden':\s*(\d+),\s*'icono':\s*'([^']+)',\s*'temas':\s*\[([\s\S]*?)\],/g;

  const areas = [];
  const cursos = [];
  const temas = [];

  let m;
  while ((m = patronCurso.exec(cuerpo)) !== null) {
    const [, cursoId, nombre, areaNombre, orden, icono, bloqueTemas] = m;

    const areaId = AREAS[areaNombre];
    if (!areaId) {
      throw new Error(`Área sin ID asignado: "${areaNombre}". Agrégala al mapa AREAS.`);
    }
    if (!areas.some((a) => a.id === areaId)) {
      areas.push({ id: areaId, nombre: areaNombre, orden: areas.length + 1 });
    }

    cursos.push({ id: cursoId, areaId, nombre, orden: Number(orden), icono });

    const titulos = [...bloqueTemas.matchAll(/^\s*'(.*)',\s*$/gm)].map((t) => t[1]);
    titulos.forEach((titulo, i) => {
      temas.push({
        id: `${cursoId}-${String(i + 1).padStart(2, '0')}`,
        cursoId,
        titulo,
        orden: i + 1,
      });
    });
  }

  validar({ areas, cursos, temas });
  return { areas, cursos, temas };
}

function validar({ areas, cursos, temas }) {
  if (cursos.length !== CURSOS_ESPERADOS) {
    throw new Error(`Se esperaban ${CURSOS_ESPERADOS} cursos y se extrajeron ${cursos.length}.`);
  }
  if (temas.length !== TEMAS_ESPERADOS) {
    throw new Error(`Se esperaban ${TEMAS_ESPERADOS} temas y se extrajeron ${temas.length}.`);
  }
  const unico = (lista, nombre) => {
    const ids = new Set(lista.map((x) => x.id));
    if (ids.size !== lista.length) throw new Error(`IDs duplicados en ${nombre}.`);
  };
  unico(areas, 'areas');
  unico(cursos, 'cursos');
  unico(temas, 'temas');
  const ordenes = new Set(cursos.map((c) => c.orden));
  if (ordenes.size !== cursos.length) throw new Error('Hay cursos con el mismo orden.');
}

function main() {
  const rutaDart = process.argv[2];
  if (!rutaDart) {
    console.error('Uso: node tool/extraer_curriculo_v1.js <ruta a seed_firestore.dart de V1>');
    process.exit(1);
  }
  const datos = extraer(fs.readFileSync(rutaDart, 'utf8'));
  const salida = {
    fuente: 'AcademiApp V1 - lib/seed_firestore.dart',
    ...datos,
  };
  const destino = path.join(__dirname, 'curriculo_v1.json');
  fs.writeFileSync(destino, JSON.stringify(salida, null, 2) + '\n', 'utf8');
  console.log(
    `OK: ${datos.areas.length} áreas, ${datos.cursos.length} cursos, ${datos.temas.length} temas -> ${destino}`,
  );
}

if (require.main === module) main();

module.exports = { extraer, validar, AREAS };
