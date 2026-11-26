'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { retomaDelPlan } = require('../src/comun/pausa');

/** Una hora de Lima (UTC-5) como ms: lima('2026-11-30 07:00'). */
const lima = (texto) => Date.parse(`${texto.replace(' ', 'T')}:00-05:00`);
const dia = (ms) => new Date(ms - 5 * 3600 * 1000).toISOString().slice(0, 10);

// El plan empezó el lunes 2 de noviembre de 2026.
const inicioMs = lima('2026-11-02 00:00');

test('sin pausa: Premium vigente o nunca tuvo', () => {
  assert.equal(retomaDelPlan({ inicioMs, premiumHastaMs: lima('2026-12-20 10:00'), ahoraMs: lima('2026-12-01 10:00') }), null);
  assert.equal(retomaDelPlan({ inicioMs, premiumHastaMs: null, ahoraMs: lima('2026-12-01 10:00') }), null);
});

test('prueba que terminó el lunes de la semana 2: paga ese lunes y sigue igual', () => {
  const finPrueba = lima('2026-11-09 00:00');
  assert.equal(retomaDelPlan({ inicioMs, premiumHastaMs: finPrueba, ahoraMs: lima('2026-11-09 18:00') }), null);
});

test('paga días después: retoma el lunes que viene en la semana en que se quedó', () => {
  const finPrueba = lima('2026-11-09 00:00');
  // Paga el miércoles 18 (semana 3 del calendario): retoma el lunes 23.
  const r = retomaDelPlan({ inicioMs, premiumHastaMs: finPrueba, ahoraMs: lima('2026-11-18 20:00') });
  assert.equal(r.semana, 2);
  assert.equal(r.desplazamientoDias, 14);
  assert.equal(dia(r.retomaElMs), '2026-11-23');
  // Con el inicio corrido 14 días, el lunes 23 es el lunes de su semana 2.
  assert.equal(dia(inicioMs + r.desplazamientoDias * 24 * 3600 * 1000), '2026-11-16');
});

test('si paga un lunes, retoma ese mismo día', () => {
  const r = retomaDelPlan({ inicioMs, premiumHastaMs: lima('2026-11-09 00:00'), ahoraMs: lima('2026-11-30 09:00') });
  assert.equal(dia(r.retomaElMs), '2026-11-30');
  assert.equal(r.desplazamientoDias, 21);
});

test('Premium que acabó a mitad de semana: retoma desde el lunes de esa semana', () => {
  // Acabó el jueves 3 de diciembre (semana 5); paga el sábado 5.
  const r = retomaDelPlan({ inicioMs, premiumHastaMs: lima('2026-12-03 15:30'), ahoraMs: lima('2026-12-05 11:00') });
  assert.equal(r.semana, 5);
  assert.equal(dia(r.retomaElMs), '2026-12-07');
  assert.equal(r.desplazamientoDias, 7);
});
