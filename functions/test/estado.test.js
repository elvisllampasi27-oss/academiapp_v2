'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { respuestaEstado } = require('../src/sistema/estado');

const ahora = new Date('2026-11-02T10:00:00Z');

test('estado: solo para el administrador', () => {
  assert.equal(respuestaEstado({ esAdmin: false, clave: 'x', ahora }), null);
});

test('estado: dice si hay clave de Gemini, sin devolverla', () => {
  const r = respuestaEstado({ esAdmin: true, clave: 'secreta', ahora });
  assert.equal(r.ok, true);
  assert.equal(r.gemini, true);
  assert.equal(r.hora, '2026-11-02T10:00:00.000Z');
  assert.ok(!JSON.stringify(r).includes('secreta'));
  assert.equal(respuestaEstado({ esAdmin: true, clave: ' ', ahora }).gemini, false);
});
