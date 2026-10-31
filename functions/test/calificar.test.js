'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { calificar, validarSolicitud, habilidadesDePregunta } = require('../src/assessment/calificar');

const preguntas = [
  { id: 'p1', dificultad: 'basica', opciones: [{ id: 'a' }, { id: 'b' }] },
  { id: 'p2', dificultad: 'basica', opciones: [{ id: 'a' }, { id: 'b' }] },
  { id: 'p3', dificultad: 'basica', opciones: [{ id: 'a' }, { id: 'b' }] },
  { id: 'p4', dificultad: 'basica', opciones: [{ id: 'a' }, { id: 'b' }] },
];
const claves = new Map([
  ['p1', { opcionCorrectaId: 'a', explicacion: 'Porque sí.' }],
  ['p2', { opcionCorrectaId: 'b' }],
  ['p3', { opcionCorrectaId: 'a' }],
  ['p4', { opcionCorrectaId: 'b' }],
]);

test('cuenta correctas y calcula puntaje de 0 a 100', () => {
  const r = calificar(preguntas, claves, { p1: 'a', p2: 'a', p3: 'a' });
  assert.strictEqual(r.total, 4);
  assert.strictEqual(r.correctas, 2);
  assert.strictEqual(r.incorrectas, 2);
  assert.strictEqual(r.puntaje, 50);
  assert.strictEqual(r.detalle[0].explicacion, 'Porque sí.');
});

test('una opcion ajena a la pregunta cuenta como no respondida', () => {
  const r = calificar(preguntas, claves, { p1: 'z' });
  assert.strictEqual(r.detalle[0].opcionElegidaId, null);
  assert.strictEqual(r.detalle[0].esCorrecta, false);
});

test('falla si una pregunta no tiene clave', () => {
  assert.throws(() => calificar(preguntas, new Map(), {}));
});

test('valida la forma de la solicitud', () => {
  assert.strictEqual(validarSolicitud({ evaluacionId: 'e', respuestas: { p1: 'a' } }), null);
  assert.ok(validarSolicitud(null));
  assert.ok(validarSolicitud({ respuestas: {} }));
  assert.ok(validarSolicitud({ evaluacionId: 'e', respuestas: ['a'] }));
  assert.ok(validarSolicitud({ evaluacionId: 'e', respuestas: { p1: 1 } }));
});

test('sin habilidades definidas usa la habilidad general del tema', () => {
  assert.deepStrictEqual(habilidadesDePregunta({}, 'algebra-02'), ['algebra-02__general']);
  assert.deepStrictEqual(
    habilidadesDePregunta({ habilidades: ['suma-matrices', 'suma-matrices', ''] }, 'x'),
    ['suma-matrices'],
  );
});
