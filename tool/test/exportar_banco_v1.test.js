'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { problemasDePregunta, idTemaV2 } = require('../exportar_banco_v1');

test('acepta una pregunta con el formato de V1', () => {
  assert.deepStrictEqual(
    problemasDePregunta({ pregunta: '¿2+2?', opciones: ['3', '4', '5', '6'], respuestaCorrecta: 1, explicacion: 'Suma.' }),
    [],
  );
});

test('detecta preguntas mal formadas', () => {
  assert.ok(problemasDePregunta({ opciones: ['a', 'b'], respuestaCorrecta: 0 }).includes('sin enunciado'));
  assert.ok(problemasDePregunta({ pregunta: 'x', opciones: ['a'], respuestaCorrecta: 0 }).includes('menos de 2 opciones'));
  assert.ok(problemasDePregunta({ pregunta: 'x', opciones: ['a', 'b'], respuestaCorrecta: 2 }).includes('respuestaCorrecta fuera de rango'));
  assert.ok(problemasDePregunta({ pregunta: 'x', opciones: ['a', 'b'], respuestaCorrecta: '1' }).includes('respuestaCorrecta no es entero'));
});

test('enlaza tema V1 con ID V2 por curso y orden', () => {
  assert.strictEqual(idTemaV2('fisica', 3), 'fisica-03');
  assert.strictEqual(idTemaV2('anatomia', 13), 'anatomia-13');
});
