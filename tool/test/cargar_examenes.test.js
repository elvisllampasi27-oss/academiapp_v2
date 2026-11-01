'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { prepararExamen, fechaIso, tituloExamen } = require('../cargar_examenes');

const base = {
  tipo: 'exonerados',
  carpeta: '16-11-2025',
  secciones: [
    { nombre: 'Comunicación', desde: 1, hasta: 1 },
    { nombre: 'Matemática', desde: 2, hasta: 9 },
  ],
  archivos: new Set(['pregunta_2.jpg']),
};

const pregunta = (extra = {}) => ({
  enunciado: '¿Cuánto es $2+2$?',
  opciones: ['3', '4', '5', '6', '7'],
  clave: '4',
  solucion: 'Suma directa.',
  imagen: '',
  imagenSolucion: '',
  ...extra,
});

test('convierte el formato de la V1: clave por texto -> letra, sin clave en la pregunta', () => {
  const plan = prepararExamen({ ...base, preguntas: [pregunta(), pregunta({ imagen: 'pregunta_2.jpg' })] });

  assert.strictEqual(plan.id, 'exonerados-2025-11-16');
  assert.strictEqual(plan.examen.titulo, 'Exonerados · 16 nov 2025');
  assert.strictEqual(plan.preguntas.length, 2);
  assert.strictEqual(plan.claves[0].datos.opcionCorrectaId, 'b');
  assert.strictEqual(plan.preguntas[0].datos.seccion, 'Comunicación');
  assert.strictEqual(plan.preguntas[1].datos.seccion, 'Matemática');
  assert.match(plan.preguntas[1].datos.imagen, /\/examenes\/exonerados\/16-11-2025\/pregunta_2\.jpg$/);
  // La pregunta pública no lleva la respuesta.
  assert.ok(!('opcionCorrectaId' in plan.preguntas[0].datos));
  assert.ok(!JSON.stringify(plan.preguntas).includes('Suma directa'));
  assert.deepStrictEqual(plan.examen.secciones, [
    { nombre: 'Comunicación', total: 1 },
    { nombre: 'Matemática', total: 1 },
  ]);
});

test('omite con aviso las preguntas con clave inexistente o imagen faltante', () => {
  const plan = prepararExamen({
    ...base,
    preguntas: [pregunta({ clave: '80' }), pregunta({ imagen: 'no_existe.jpg' }), pregunta()],
  });

  assert.strictEqual(plan.preguntas.length, 1);
  assert.strictEqual(plan.preguntas[0].datos.numero, 3);
  assert.strictEqual(plan.avisos.length, 2);
});

test('fechas y titulos', () => {
  assert.strictEqual(fechaIso('08-06-2025'), '2025-06-08');
  assert.strictEqual(fechaIso('2025'), null);
  assert.strictEqual(tituloExamen('ordinario', '2024-11-24'), 'Ordinario · 24 nov 2024');
});
