'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { esFinDeSemanaLima, elegirPreguntas, calificarExamen } = require('../src/examenes/reglas');

test('sabado y domingo segun la hora de Lima', () => {
  assert.strictEqual(esFinDeSemanaLima(new Date('2026-10-31T15:00:00Z')), true); // sábado
  assert.strictEqual(esFinDeSemanaLima(new Date('2026-11-01T15:00:00Z')), true); // domingo
  // Lunes 02:00 UTC todavía es domingo en Lima.
  assert.strictEqual(esFinDeSemanaLima(new Date('2026-11-02T02:00:00Z')), true);
  assert.strictEqual(esFinDeSemanaLima(new Date('2026-11-02T15:00:00Z')), false);
});

test('reparte las preguntas por seccion en proporcion al banco', () => {
  const banco = [
    ...Array.from({ length: 50 }, (_, i) => ({ id: `c${i}`, seccion: 'Comunicación' })),
    ...Array.from({ length: 30 }, (_, i) => ({ id: `m${i}`, seccion: 'Matemática' })),
    ...Array.from({ length: 20 }, (_, i) => ({ id: `s${i}`, seccion: 'Sociales' })),
  ];

  const elegidas = elegirPreguntas(banco, 20);
  const cuenta = (s) => elegidas.filter((p) => p.seccion === s).length;

  assert.strictEqual(elegidas.length, 20);
  assert.strictEqual(new Set(elegidas.map((p) => p.id)).size, 20);
  assert.deepStrictEqual([cuenta('Comunicación'), cuenta('Matemática'), cuenta('Sociales')], [10, 6, 4]);
  // Agrupadas por sección, como el examen real.
  assert.strictEqual(elegidas[0].seccion, 'Comunicación');
  assert.strictEqual(elegidas[19].seccion, 'Sociales');
});

test('con un banco pequeno devuelve lo que hay', () => {
  assert.strictEqual(elegirPreguntas([{ id: 'a', seccion: 'X' }], 20).length, 1);
});

test('califica, cuenta por seccion y trata las no respondidas como incorrectas', () => {
  const preguntas = [
    { id: 'p1', seccion: 'Comunicación' },
    { id: 'p2', seccion: 'Comunicación' },
    { id: 'p3', seccion: 'Matemática' },
  ];
  const claves = new Map([
    ['p1', { opcionCorrectaId: 'a', solucion: 'Porque sí.' }],
    ['p2', { opcionCorrectaId: 'b' }],
    ['p3', { opcionCorrectaId: 'c' }],
  ]);

  const r = calificarExamen(preguntas, claves, { p1: 'a', p3: 'd' });

  assert.strictEqual(r.correctas, 1);
  assert.strictEqual(r.total, 3);
  assert.strictEqual(r.puntaje, 33);
  assert.deepStrictEqual(r.porSeccion, [
    { nombre: 'Comunicación', correctas: 1, total: 2 },
    { nombre: 'Matemática', correctas: 0, total: 1 },
  ]);
  assert.strictEqual(r.detalle[1].opcionElegidaId, null);
  assert.strictEqual(r.detalle[0].solucion, 'Porque sí.');
});
