'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');
const { prepararSeminarios, idYoutube, fechaPeru } = require('../cargar_seminarios');

const cursos = new Map([['algebra', { nombre: 'Álgebra' }], ['aritmetica', { nombre: 'Aritmética' }]]);

test('la plantilla seminarios.json es valida', () => {
  const archivo = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'seminarios.json'), 'utf8'));
  const plan = prepararSeminarios(archivo, cursos);
  assert.deepStrictEqual(plan.errores, []);
  assert.ok(plan.seminarios.length > 0);
});

test('acepta enlaces de YouTube habituales, incluidos los de vivo', () => {
  assert.strictEqual(idYoutube('pRRaLT4H-9s'), 'pRRaLT4H-9s');
  assert.strictEqual(idYoutube('https://www.youtube.com/live/pRRaLT4H-9s?si=x'), 'pRRaLT4H-9s');
  assert.strictEqual(idYoutube('https://youtu.be/pRRaLT4H-9s'), 'pRRaLT4H-9s');
  assert.strictEqual(idYoutube('https://www.youtube.com/watch?v=pRRaLT4H-9s'), 'pRRaLT4H-9s');
  assert.strictEqual(idYoutube('https://vimeo.com/1'), null);
});

test('la fecha se interpreta en hora de Peru', () => {
  assert.strictEqual(fechaPeru('2026-11-07T19:00').toISOString(), '2026-11-08T00:00:00.000Z');
  assert.strictEqual(fechaPeru('7/11/2026'), null);
});

test('reporta errores y guarda el nombre del curso', () => {
  const plan = prepararSeminarios({
    seminarios: [
      { id: 'ok', titulo: 'A', cursoId: 'algebra', fecha: '2026-11-07T19:00', youtube: 'pRRaLT4H-9s' },
      { id: 'x', titulo: 'B', cursoId: 'quimica', fecha: '2026-11-07T19:00', youtube: 'pRRaLT4H-9s' },
      { id: 'y', titulo: 'C', fecha: '2026-11-07T19:00', youtube: 'PEGA_AQUI_EL_ENLACE' },
    ],
  }, cursos);

  assert.strictEqual(plan.seminarios[0].datos.cursoNombre, 'Álgebra');
  assert.strictEqual(plan.errores.length, 1);
  assert.strictEqual(plan.omitidos.length, 1);
});
