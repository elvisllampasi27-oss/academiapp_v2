'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {
  semanaAcademica,
  semanaDeExamen,
  cierreExamenMs,
  idExamenSemanal,
  nombreCorto,
  ordenarRanking,
  calificarExamen,
} = require('../src/examenes/reglas');

test('semana academica: de lunes a domingo, en hora de Lima', () => {
  // Empezó el miércoles 21 oct 2026 (medianoche de Lima = 05:00 UTC).
  const inicio = Date.parse('2026-10-21T05:00:00Z');
  assert.strictEqual(semanaAcademica(inicio, Date.parse('2026-10-20T15:00:00Z')), 0);
  assert.strictEqual(semanaAcademica(inicio, Date.parse('2026-10-24T15:00:00Z')), 1); // sáb 24
  assert.strictEqual(semanaAcademica(inicio, Date.parse('2026-10-26T04:00:00Z')), 1); // dom 25 en Lima
  assert.strictEqual(semanaAcademica(inicio, Date.parse('2026-10-31T15:00:00Z')), 2); // sáb 31
  assert.strictEqual(semanaAcademica(inicio, Date.parse('2026-11-08T15:00:00Z')), 3); // dom 8 nov
  // Si empezó un sábado, su semana 1 es la siguiente.
  const sabado = Date.parse('2026-10-24T05:00:00Z');
  assert.strictEqual(semanaAcademica(sabado, Date.parse('2026-10-24T15:00:00Z')), 0);
  assert.strictEqual(semanaAcademica(sabado, Date.parse('2026-10-31T15:00:00Z')), 1);
});

test('el examen de la semana se abre el sabado y dura hasta el siguiente', () => {
  const inicio = Date.parse('2026-10-21T05:00:00Z'); // miércoles 21 oct
  const viernes23 = Date.parse('2026-10-23T15:00:00Z');
  const sabado24 = Date.parse('2026-10-24T15:00:00Z');
  const martes27 = Date.parse('2026-10-27T15:00:00Z');
  const sabado31 = Date.parse('2026-10-31T15:00:00Z');
  assert.strictEqual(semanaDeExamen(inicio, viernes23), 0);
  assert.strictEqual(semanaDeExamen(inicio, sabado24), 1);
  assert.strictEqual(semanaDeExamen(inicio, martes27), 1); // sigue abierto
  assert.strictEqual(semanaDeExamen(inicio, sabado31), 2);
  // Cierra el próximo sábado a las 00:00 de Lima (05:00 UTC).
  assert.strictEqual(new Date(cierreExamenMs(martes27)).toISOString(), '2026-10-31T05:00:00.000Z');
  assert.strictEqual(new Date(cierreExamenMs(sabado24)).toISOString(), '2026-10-31T05:00:00.000Z');
});

test('id del examen semanal y nombre corto para el ranking', () => {
  assert.strictEqual(idExamenSemanal('v1', 3), 'v1__s03');
  assert.strictEqual(nombreCorto('Ana María Quispe Rojas'), 'Ana Q.');
  assert.strictEqual(nombreCorto('Luis Paredes'), 'Luis P.');
  assert.strictEqual(nombreCorto('  '), 'Estudiante');
});

test('ranking: puntaje, luego tiempo, luego quien termino antes', () => {
  const r = ordenarRanking([
    { usuarioId: 'a', puntaje: 80, tiempoUsadoSegundos: 900, terminadoMs: 3 },
    { usuarioId: 'b', puntaje: 90, tiempoUsadoSegundos: 1200, terminadoMs: 2 },
    { usuarioId: 'c', puntaje: 80, tiempoUsadoSegundos: 700, terminadoMs: 5 },
    { usuarioId: 'd', puntaje: 80, tiempoUsadoSegundos: 700, terminadoMs: 1 },
  ]);
  assert.deepStrictEqual(r.map((x) => `${x.puesto}${x.usuarioId}`), ['1b', '2d', '3c', '4a']);
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
