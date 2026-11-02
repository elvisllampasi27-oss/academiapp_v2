'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { esPremium, limiteTutor, CONFIGURACION_POR_DEFECTO } = require('../src/comun/plan');

const fecha = (ms) => ({ toMillis: () => ms });

test('premium vigente solo si premiumHasta es futuro', () => {
  assert.strictEqual(esPremium({ premiumHasta: fecha(2000) }, 1000), true);
  assert.strictEqual(esPremium({ premiumHasta: fecha(500) }, 1000), false);
  assert.strictEqual(esPremium({}, 1000), false);
  assert.strictEqual(esPremium(null, 1000), false);
});

test('límite del tutor según el plan', () => {
  assert.strictEqual(limiteTutor(CONFIGURACION_POR_DEFECTO, false), 3);
  assert.strictEqual(limiteTutor(CONFIGURACION_POR_DEFECTO, true), 20);
  assert.strictEqual(limiteTutor({ tutorGratis: 'x' }, false), 0);
});
