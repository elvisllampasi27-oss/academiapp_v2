'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  versionVigente,
  inicioPlan,
  finPrueba,
  planDeCuenta,
} = require('../src/cuenta/preparar_cuenta');

/** Una hora de Lima (UTC-5) como ms: lima('2026-11-30 07:00'). */
const lima = (texto) => Date.parse(`${texto.replace(' ', 'T')}:00-05:00`);
/** Fecha de Lima (AAAA-MM-DD) de una medianoche de Lima en ms. */
const dia = (valorMs) => new Date(valorMs - 5 * 3600 * 1000).toISOString().slice(0, 10);
const marca = (valorMs) => ({ toMillis: () => valorMs });

// El 30 de noviembre de 2026 es lunes.
const aperturaPasada = lima('2026-11-01 00:00');

test('antes de las 6 a. m. empieza ese día; después, al día siguiente', () => {
  assert.equal(dia(inicioPlan(lima('2026-11-30 05:59'), aperturaPasada)), '2026-11-30');
  assert.equal(dia(inicioPlan(lima('2026-11-30 06:00'), aperturaPasada)), '2026-12-01');
  assert.equal(dia(inicioPlan(lima('2026-11-30 23:30'), aperturaPasada)), '2026-12-01');
  // El inicio es la medianoche de Lima (05:00 UTC).
  assert.equal(new Date(inicioPlan(lima('2026-11-30 05:00'), aperturaPasada)).toISOString(),
    '2026-11-30T05:00:00.000Z');
});

test('nunca empieza en domingo: pasa al lunes', () => {
  // Sábado 5 de diciembre a las 8 a. m. → domingo → lunes 7.
  assert.equal(dia(inicioPlan(lima('2026-12-05 08:00'), aperturaPasada)), '2026-12-07');
  // Domingo de madrugada → también lunes.
  assert.equal(dia(inicioPlan(lima('2026-12-06 03:00'), aperturaPasada)), '2026-12-07');
  // Sábado de madrugada sí empieza el sábado.
  assert.equal(dia(inicioPlan(lima('2026-12-05 05:00'), aperturaPasada)), '2026-12-05');
});

test('nunca empieza antes de que abra la versión', () => {
  const apertura = lima('2026-12-09 00:00');
  assert.equal(dia(inicioPlan(lima('2026-11-30 10:00'), apertura)), '2026-12-09');
});

test('la prueba dura hasta el lunes después de su primer examen semanal', () => {
  // Empieza lunes 30: examen el sábado 5, prueba hasta el domingo 6 (incl.).
  assert.equal(dia(finPrueba(lima('2026-11-30 00:00'))), '2026-12-07');
  // Empieza miércoles 2: misma semana, mismo examen.
  assert.equal(dia(finPrueba(lima('2026-12-02 00:00'))), '2026-12-07');
  // Empieza sábado 5: su semana 1 es la siguiente; examen el sábado 12.
  assert.equal(dia(finPrueba(lima('2026-12-05 00:00'))), '2026-12-14');
  // Empieza lunes 7.
  assert.equal(dia(finPrueba(lima('2026-12-07 00:00'))), '2026-12-14');
});

const version = (id, estado, apertura, corte = null) => ({
  id,
  nombre: id,
  estado,
  fechaAperturaMs: lima(apertura),
  fechaCorteMs: corte ? lima(corte) : null,
});

test('la versión vigente: abierta, sin pasar el corte, la más reciente', () => {
  const ahora = lima('2026-11-30 10:00');
  const versiones = [
    version('2026-II', 'activa', '2026-08-01 00:00'),
    version('2027-I', 'publicada', '2026-11-01 00:00'),
    version('2027-II', 'preparacion', '2026-12-01 00:00'),
  ];
  assert.equal(versionVigente(versiones, ahora).id, '2027-I');
  // El día del corte todavía acepta; al día siguiente ya no.
  assert.equal(versionVigente([version('a', 'activa', '2026-11-01 00:00', '2026-11-30 00:00')], ahora).id, 'a');
  assert.equal(versionVigente([version('a', 'activa', '2026-11-01 00:00', '2026-11-29 00:00')], ahora), null);
  assert.equal(versionVigente([version('a', 'finalizada', '2026-11-01 00:00')], ahora), null);
});

const versiones = [version('2027-I', 'activa', '2026-11-01 00:00')];
const ahora = lima('2026-11-30 10:00');

test('alumno nuevo: matrícula con prueba gratis', () => {
  const d = planDeCuenta({ usuario: {}, matriculas: [], versiones, ahoraMs: ahora });
  assert.equal(d.accion, 'crear');
  assert.equal(d.version.id, '2027-I');
  assert.equal(dia(d.inicioMs), '2026-12-01');
  assert.equal(dia(d.pruebaHastaMs), '2026-12-07');
});

test('la prueba gratis es una sola vez, y no hace falta si ya es Premium', () => {
  const yaProbo = planDeCuenta({
    usuario: { pruebaHasta: marca(lima('2026-10-10 00:00')) },
    matriculas: [{ estado: 'finalizada' }],
    versiones,
    ahoraMs: ahora,
  });
  assert.equal(yaProbo.accion, 'crear');
  assert.equal(yaProbo.pruebaHastaMs, null);

  const premium = planDeCuenta({
    usuario: { premiumHasta: marca(lima('2027-01-01 00:00')) },
    matriculas: [],
    versiones,
    ahoraMs: ahora,
  });
  assert.equal(premium.pruebaHastaMs, null);
});

test('si ya tiene matrícula activa no se crea otra', () => {
  const d = planDeCuenta({
    usuario: {},
    matriculas: [{ id: 'm1', estado: 'activa' }],
    versiones,
    ahoraMs: ahora,
  });
  assert.equal(d.accion, 'existente');
  assert.equal(d.matricula.id, 'm1');
});

test('una matrícula suspendida por el administrador no se reemplaza sola', () => {
  const d = planDeCuenta({
    usuario: {},
    matriculas: [{ estado: 'suspendida' }],
    versiones,
    ahoraMs: ahora,
  });
  assert.equal(d.accion, 'suspendida');
});

test('sin versiones abiertas, las matrículas están cerradas', () => {
  const d = planDeCuenta({ usuario: {}, matriculas: [], versiones: [], ahoraMs: ahora });
  assert.equal(d.accion, 'cerrado');
});
