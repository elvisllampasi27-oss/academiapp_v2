'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { limiteNoDados, armarHistorial } = require('../src/examenes/historial');

const lima = (texto) => Date.parse(`${texto.replace(' ', 'T')}:00-05:00`);
// Plan desde el lunes 2 de noviembre de 2026.
const inicioMs = lima('2026-11-02 00:00');

test('cuentan como 0 los exámenes ya cerrados', () => {
  // Martes de la semana 4: el examen abierto es el 3; cerraron el 1 y el 2.
  assert.equal(limiteNoDados({
    inicioMs, ahoraMs: lima('2026-11-24 10:00'), premiumHastaMs: lima('2027-01-01 00:00'), soloPremium: true,
  }), 2);
  // Sábado de la semana 4: se abre el 4 y cierra el 3.
  assert.equal(limiteNoDados({
    inicioMs, ahoraMs: lima('2026-11-28 10:00'), premiumHastaMs: lima('2027-01-01 00:00'), soloPremium: true,
  }), 3);
});

test('en pausa solo cuentan los de antes de la pausa', () => {
  // La prueba acabó el lunes 9 (semana 2): solo cuenta el examen 1.
  assert.equal(limiteNoDados({
    inicioMs, ahoraMs: lima('2026-12-20 10:00'), premiumHastaMs: lima('2026-11-09 00:00'), soloPremium: true,
  }), 1);
  // Sin Premium nunca y examen solo para Premium: ninguno.
  assert.equal(limiteNoDados({
    inicioMs, ahoraMs: lima('2026-12-20 10:00'), premiumHastaMs: null, soloPremium: true,
  }), 0);
  // Si el examen es para todos, la pausa no importa.
  assert.equal(limiteNoDados({
    inicioMs, ahoraMs: lima('2026-11-24 10:00'), premiumHastaMs: null, soloPremium: false,
  }), 2);
});

test('historial: dados, no dados en 0 y promedio; lo abierto no cuenta', () => {
  const publicado = (titulo) => ({ estado: 'publicado', titulo });
  const h = armarHistorial([
    { semana: 1, examen: publicado('Semana 1'), simulacro: { estado: 'completado', puntaje: 80 } },
    { semana: 2, examen: publicado('Semana 2'), simulacro: null },
    { semana: 3, examen: { estado: 'borrador' }, simulacro: null },
    { semana: 4, examen: publicado('Semana 4'), simulacro: { estado: 'en_curso' } },
    { semana: 5, examen: publicado('Semana 5'), simulacro: null },
  ], 4);
  assert.deepEqual(h.semanas, [
    { semana: 4, titulo: 'Semana 4', puntaje: 0, dado: false },
    { semana: 2, titulo: 'Semana 2', puntaje: 0, dado: false },
    { semana: 1, titulo: 'Semana 1', puntaje: 80, dado: true },
  ]);
  assert.equal(h.promedio, 27);
  assert.deepEqual(armarHistorial([], 3), { semanas: [], promedio: null });
});
