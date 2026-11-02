'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { validarSolicitud, construirInstruccionesQuiz, leerPreguntasGeneradas } = require('../src/contenido/quiz');

test('valida la solicitud de quiz', () => {
  assert.strictEqual(validarSolicitud({ versionId: 'v', temaId: 't', nivel: 'basica', cantidad: 5 }), null);
  assert.ok(validarSolicitud({ versionId: 'v', temaId: 't', nivel: 'facil', cantidad: 5 }));
  assert.ok(validarSolicitud({ versionId: 'v', temaId: 't', nivel: 'basica', cantidad: 50 }));
  assert.ok(validarSolicitud(null));
});

test('las instrucciones llevan tema, nivel, cantidad y material', () => {
  const texto = construirInstruccionesQuiz({
    curso: 'Álgebra', tema: 'Polinomios', contenidos: ['Grado'], material: 'Un polinomio es…', nivel: 'avanzada', cantidad: 3,
  });
  assert.match(texto, /Polinomios/);
  assert.match(texto, /exactamente 3 preguntas/);
  assert.match(texto, /admisión/);
  assert.match(texto, /Un polinomio es/);
});

test('lee el JSON de la IA y descarta las preguntas mal formadas', () => {
  const texto = '```json\n' + JSON.stringify({
    preguntas: [
      { enunciado: '¿2+2?', opciones: ['3', '4', '5', '6', '7'], correcta: 1, explicacion: 'Suma.' },
      { enunciado: 'Sin opciones', opciones: [], correcta: 0 },
      { enunciado: 'Repetidas', opciones: ['a', 'a'], correcta: 0 },
      { enunciado: 'Índice malo', opciones: ['a', 'b'], correcta: 5 },
    ],
  }) + '\n```';
  const preguntas = leerPreguntasGeneradas(texto);
  assert.strictEqual(preguntas.length, 1);
  assert.deepStrictEqual(preguntas[0].opciones, ['3', '4', '5', '6', '7']);
  assert.throws(() => leerPreguntasGeneradas('no es json'), /JSON/);
  assert.throws(() => leerPreguntasGeneradas('{"preguntas": []}'), /válida/);
});
