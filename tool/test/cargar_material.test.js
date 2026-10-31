'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const { prepararMaterial } = require('../cargar_material');

const temas = new Set(['geografia-01', 'fisica-01']);

test('la plantilla material.json es valida', () => {
  const curriculo = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'curriculo_v1.json'), 'utf8'));
  const material = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'material.json'), 'utf8'));
  const plan = prepararMaterial(material, new Set(curriculo.temas.map((t) => t.id)));
  assert.deepStrictEqual(plan.errores, []);
  assert.strictEqual(plan.contenidos.length, 16);
});

test('omite marcadores PEGA_AQUI y acepta https e IDs de YouTube', () => {
  const plan = prepararMaterial({
    versionId: 'version-1',
    recursos: [
      { temaId: 'geografia-01', tipo: 'video', titulo: 'A', ubicacion: 'PEGA_AQUI_X' },
      { temaId: 'geografia-01', tipo: 'video', titulo: 'B', ubicacion: 'AbCdEfGhIjK' },
      { temaId: 'geografia-01', tipo: 'pdf', titulo: 'C', ubicacion: 'https://ejemplo.pe/a.pdf' },
    ],
  }, temas);
  assert.deepStrictEqual(plan.errores, []);
  assert.strictEqual(plan.omitidos.length, 1);
  assert.deepStrictEqual(plan.recursos.map((r) => r.id), [
    'version-1__geografia-01__video-2',
    'version-1__geografia-01__pdf-1',
  ]);
});

test('rechaza temas inexistentes, tipos invalidos y enlaces http', () => {
  const plan = prepararMaterial({
    versionId: 'version-1',
    recursos: [
      { temaId: 'no-existe', tipo: 'video', titulo: 'A', ubicacion: 'AbCdEfGhIjK' },
      { temaId: 'fisica-01', tipo: 'podcast', titulo: 'B', ubicacion: 'https://a.pe' },
      { temaId: 'fisica-01', tipo: 'pdf', titulo: 'C', ubicacion: 'http://a.pe/x.pdf' },
    ],
  }, temas);
  assert.strictEqual(plan.errores.length, 3);
  assert.strictEqual(plan.recursos.length, 0);
});

test('contenidos con ID determinista y sin ordenes repetidos', () => {
  const plan = prepararMaterial({
    versionId: 'version-1',
    contenidos: [
      { temaId: 'fisica-01', orden: 1, nombre: 'Magnitudes' },
      { temaId: 'fisica-01', orden: 1, nombre: 'Repetido' },
    ],
  }, temas);
  assert.strictEqual(plan.contenidos[0].id, 'fisica-01-c01');
  assert.strictEqual(plan.errores.length, 1);
});
