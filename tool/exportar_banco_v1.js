#!/usr/bin/env node
/**
 * Exporta (SOLO LECTURA) el banco de preguntas de AcademiApp V1
 * (proyecto Firebase app-movil-ebc90) a tool/banco_v1.json.
 *
 * Lee:
 *   - cursos/{curso}/temas/{tema}/premium/contenido -> quiz_basico, quiz_intermedio,
 *     quiz_avanzado (solo los aprobados; los "_borrador" se cuentan pero no se exportan)
 *   - examenes/{id}
 *
 * Cada tema de V1 se enlaza con su ID de V2 por curso + orden (ver curriculo_v1.json).
 * No escribe nada en ningún Firebase.
 *
 * IMPORTANTE: banco_v1.json contiene las respuestas correctas. Está en .gitignore:
 * no lo subas al repositorio (es público).
 *
 * Uso:
 *   node tool\exportar_banco_v1.js --key C:\Users\elvis\claves\academiapp-v1-admin.json
 */
'use strict';

const fs = require('fs');
const path = require('path');

const PROYECTO_V1 = 'app-movil-ebc90';
const NIVELES = ['basico', 'intermedio', 'avanzado'];

/** Revisa una pregunta con el formato de V1. Devuelve la lista de problemas. */
function problemasDePregunta(p) {
  const problemas = [];
  if (!p || typeof p !== 'object') return ['no es un objeto'];
  if (typeof p.pregunta !== 'string' || !p.pregunta.trim()) problemas.push('sin enunciado');
  if (!Array.isArray(p.opciones) || p.opciones.length < 2) problemas.push('menos de 2 opciones');
  else if (p.opciones.some((o) => typeof o !== 'string' || !o.trim())) problemas.push('opción vacía');
  if (!Number.isInteger(p.respuestaCorrecta)) problemas.push('respuestaCorrecta no es entero');
  else if (Array.isArray(p.opciones) && (p.respuestaCorrecta < 0 || p.respuestaCorrecta >= p.opciones.length)) {
    problemas.push('respuestaCorrecta fuera de rango');
  }
  return problemas;
}

/** ID de V2 a partir del curso y el orden de V1. */
function idTemaV2(cursoId, orden) {
  return `${cursoId}-${String(orden).padStart(2, '0')}`;
}

function aJsonPlano(valor) {
  // Convierte Timestamps y otros tipos de Firestore en algo serializable.
  return JSON.parse(
    JSON.stringify(valor, (_, v) => (v && typeof v.toDate === 'function' ? v.toDate().toISOString() : v)),
  );
}

async function main() {
  const argv = process.argv.slice(2);
  const iKey = argv.indexOf('--key');
  const rutaKey = iKey >= 0 ? argv[iKey + 1] : undefined;
  if (!rutaKey) throw new Error('Uso: node tool\\exportar_banco_v1.js --key <clave del proyecto V1>');

  const credencial = JSON.parse(fs.readFileSync(rutaKey, 'utf8'));
  if (credencial.project_id !== PROYECTO_V1) {
    throw new Error(`La clave es de "${credencial.project_id}"; se esperaba la de V1 (${PROYECTO_V1}).`);
  }

  const admin = require('firebase-admin');
  const app = admin.initializeApp({ credential: admin.credential.cert(credencial), projectId: PROYECTO_V1 }, 'v1');
  const db = app.firestore();

  const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, 'curriculo_v1.json'), 'utf8'));
  const temasV2 = new Map(curriculo.temas.map((t) => [t.id, t]));

  const quizzes = [];
  const avisos = [];
  const conteo = { temasV1: 0, temasConQuiz: 0, borradores: 0, preguntas: 0, invalidas: 0 };
  const porNivel = { basico: 0, intermedio: 0, avanzado: 0 };

  const cursos = await db.collection('cursos').get();
  for (const curso of cursos.docs) {
    const temas = await curso.ref.collection('temas').get();
    for (const tema of temas.docs) {
      conteo.temasV1++;
      const datosTema = tema.data();
      const temaId = idTemaV2(curso.id, datosTema.orden);
      const temaV2 = temasV2.get(temaId);

      if (!temaV2) {
        avisos.push(`Tema V1 ${curso.id}/${tema.id} (orden ${datosTema.orden}) no tiene equivalente en V2.`);
      } else if ((temaV2.titulo || '').trim() !== (datosTema.titulo || '').trim()) {
        avisos.push(`Título distinto en ${temaId}: V1="${datosTema.titulo}" / V2="${temaV2.titulo}".`);
      }

      const premium = await tema.ref.collection('premium').doc('contenido').get();
      if (!premium.exists) continue;
      const datos = premium.data();

      let tieneQuiz = false;
      for (const nivel of NIVELES) {
        if (Array.isArray(datos[`quiz_${nivel}_borrador`])) conteo.borradores++;
        const preguntas = datos[`quiz_${nivel}`];
        if (!Array.isArray(preguntas) || preguntas.length === 0) continue;
        tieneQuiz = true;

        const validas = [];
        preguntas.forEach((p, i) => {
          const problemas = problemasDePregunta(p);
          if (problemas.length) {
            conteo.invalidas++;
            avisos.push(`${temaId} ${nivel} #${i + 1}: ${problemas.join(', ')}.`);
          } else {
            validas.push(aJsonPlano(p));
          }
        });

        conteo.preguntas += validas.length;
        porNivel[nivel] += validas.length;
        quizzes.push({ temaId, temaIdV1: `${curso.id}/${tema.id}`, nivel, preguntas: validas });
      }
      if (tieneQuiz) conteo.temasConQuiz++;
    }
  }

  const examenesSnap = await db.collection('examenes').get();
  const examenes = examenesSnap.docs.map((d) => ({ id: d.id, ...aJsonPlano(d.data()) }));
  let preguntasExamen = 0;
  for (const ex of examenes) {
    (ex.preguntas || []).forEach((p, i) => {
      const problemas = problemasDePregunta(p);
      if (problemas.length) avisos.push(`examen ${ex.id} #${i + 1}: ${problemas.join(', ')}.`);
      else preguntasExamen++;
    });
  }

  const salida = {
    fuente: `Firebase ${PROYECTO_V1}`,
    exportadoEn: new Date().toISOString(),
    quizzes,
    examenes,
  };
  const destino = path.join(__dirname, 'banco_v1.json');
  fs.writeFileSync(destino, JSON.stringify(salida, null, 2) + '\n', 'utf8');

  console.log('EXPORTACIÓN V1 (solo lectura)');
  console.log(`  Temas en V1: ${conteo.temasV1}`);
  console.log(`  Temas con quiz aprobado: ${conteo.temasConQuiz}`);
  console.log(`  Preguntas de quiz válidas: ${conteo.preguntas} (básico ${porNivel.basico}, intermedio ${porNivel.intermedio}, avanzado ${porNivel.avanzado})`);
  console.log(`  Preguntas inválidas descartadas: ${conteo.invalidas}`);
  console.log(`  Quizzes en borrador (no exportados): ${conteo.borradores}`);
  console.log(`  Exámenes: ${examenes.length} (${preguntasExamen} preguntas válidas)`);
  const categorias = [...new Set(examenes.map((e) => e.categoria || '(sin categoría)'))];
  console.log(`  Categorías de examen: ${categorias.join(', ') || '-'}`);
  if (avisos.length) {
    console.log(`\nAvisos (${avisos.length}), primeros 30:`);
    for (const a of avisos.slice(0, 30)) console.log(`  - ${a}`);
  }
  console.log(`\nArchivo: ${destino}  (NO lo subas a GitHub)`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(`\nERROR: ${error.message}`);
    process.exit(1);
  });
}

module.exports = { problemasDePregunta, idTemaV2 };
