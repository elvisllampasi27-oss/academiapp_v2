'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { prepararEvaluaciones } = require('../cargar_evaluaciones');

const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'curriculo_v1.json'), 'utf8'));
const temas = new Set(curriculo.temas.map((t) => t.id));

test('la plantilla de ejemplo es valida y separa las claves', () => {
  const archivo = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'preguntas.ejemplo.json'), 'utf8'));
  const plan = prepararEvaluaciones(archivo, temas);
  assert.deepStrictEqual(plan.errores, []);
  assert.strictEqual(plan.evaluaciones.length, 2);

  const p = plan.evaluaciones[0].preguntas[0];
  assert.strictEqual(p.id, 'version-1__aritmetica-02__practica-basica__p01');
  assert.strictEqual(p.clave.opcionCorrectaId, 'b');
  // El documento público no lleva la respuesta correcta ni la explicación.
  assert.ok(!('correcta' in p.datos) && !('explicacion' in p.datos));
  assert.ok(!JSON.stringify(p.datos.opciones).includes('esCorrecta'));
});

test('acepta el formato de V1', () => {
  const plan = prepararEvaluaciones({
    versionId: 'version-1',
    evaluaciones: [{
      temaId: 'fisica-01', nivel: 'basica',
      preguntas: [{ pregunta: '¿?', opciones: ['a', 'b', 'c', 'd'], respuestaCorrecta: 3 }],
    }],
  }, temas);
  assert.deepStrictEqual(plan.errores, []);
  assert.strictEqual(plan.evaluaciones[0].preguntas[0].clave.opcionCorrectaId, 'd');
});

test('rechaza datos invalidos', () => {
  const plan = prepararEvaluaciones({
    versionId: 'version-1',
    evaluaciones: [
      { temaId: 'no-existe', nivel: 'basica', preguntas: [] },
      { temaId: 'fisica-01', nivel: 'facil', preguntas: [] },
      { temaId: 'fisica-02', nivel: 'basica', preguntas: [{ enunciado: 'x', opciones: ['a', 'b'], correcta: 5 }] },
    ],
  }, temas);
  assert.strictEqual(plan.errores.length, 4);
  assert.strictEqual(plan.evaluaciones.length, 0);
});
