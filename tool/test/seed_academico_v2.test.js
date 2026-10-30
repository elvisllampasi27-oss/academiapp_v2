'use strict';

const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const path = require('path');

const {
  generarSecuencia,
  generarCalendario,
  calcularTemasAPublicar,
  diaAcademicoEn,
  analizarExistentes,
} = require('../seed_academico_v2');

const curriculo = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'curriculo_v1.json'), 'utf8'),
);
const secuencia = generarSecuencia(curriculo.cursos, curriculo.temas);

test('el curriculo tiene 6 areas, 17 cursos y 205 temas', () => {
  assert.strictEqual(curriculo.areas.length, 6);
  assert.strictEqual(curriculo.cursos.length, 17);
  assert.strictEqual(curriculo.temas.length, 205);
  assert.strictEqual(secuencia.length, 205);
});

test('todo tema apunta a un curso y todo curso a un area', () => {
  const cursos = new Set(curriculo.cursos.map((c) => c.id));
  const areas = new Set(curriculo.areas.map((a) => a.id));
  for (const t of curriculo.temas) assert.ok(cursos.has(t.cursoId), t.id);
  for (const c of curriculo.cursos) assert.ok(areas.has(c.areaId), c.id);
});

test('la secuencia va por rondas', () => {
  assert.deepStrictEqual(
    secuencia.slice(0, 3).map((t) => t.id),
    ['razonamiento_verbal-01', 'lenguaje-01', 'literatura-01'],
  );
  assert.strictEqual(secuencia[16].id, 'razonamiento_matematico-01');
  assert.strictEqual(secuencia[17].id, 'razonamiento_verbal-02');
  // Ronda 13: solo Anatomia tiene tema 13.
  assert.strictEqual(secuencia[204].id, 'anatomia-13');
});

test('inicio viernes 23/10/2026: domingo no consume dia; jueves 29 es Dia 6', () => {
  const calendario = generarCalendario(secuencia, '2026-10-23');
  assert.strictEqual(calendario.length, 73);
  assert.strictEqual(calendario[0].fecha, '2026-10-23');
  assert.strictEqual(calendario[1].fecha, '2026-10-24');
  assert.strictEqual(calendario[1].temas.length, 2);
  assert.strictEqual(calendario[2].fecha, '2026-10-26');
  assert.strictEqual(diaAcademicoEn(calendario, '2026-10-29'), 6);
  assert.deepStrictEqual(
    calendario[5].temas.map((t) => t.id),
    ['geografia-01', 'formacion_civica-01', 'razonamiento_matematico-01'],
  );
  assert.strictEqual(diaAcademicoEn(calendario, '2026-10-22'), 0);
});

test('publicar hasta el dia 8 desde 23/10 son 22 temas', () => {
  const dias = calcularTemasAPublicar(secuencia, '2026-10-23', 8);
  assert.strictEqual(dias.length, 8);
  assert.strictEqual(dias.flatMap((d) => d.temas).length, 22);
});

test('borra solo temporales conocidos y respeta lenguaje/fisica', () => {
  const estado = {
    cursos: new Map([
      ['matematica', { activo: true }],
      ['fisica', { activo: true }],
      ['lenguaje', { activo: true }],
    ]),
    temas: new Map([
      ['matrices', { cursoId: 'matematica', activo: true }],
      ['cinematica', { cursoId: 'fisica', activo: true }],
      ['oraciones', { cursoId: 'lenguaje', activo: true }],
    ]),
    publicaciones: new Map([
      ['publicacion-matrices', { temaId: 'matrices' }],
      ['version-1__lenguaje-01', { temaId: 'lenguaje-01' }],
    ]),
  };
  const { borrar, desconocidos } = analizarExistentes(estado, curriculo);
  assert.deepStrictEqual(borrar.cursos, ['matematica']);
  assert.deepStrictEqual(borrar.temas.sort(), ['cinematica', 'matrices', 'oraciones']);
  assert.deepStrictEqual(borrar.publicaciones, ['publicacion-matrices']);
  assert.deepStrictEqual(desconocidos, []);
});

test('detecta documentos activos desconocidos y no los borra', () => {
  const estado = {
    cursos: new Map([['quimica_extra', { activo: true }]]),
    temas: new Map([['tema-nuevo', { cursoId: 'quimica', activo: true }]]),
    publicaciones: new Map(),
  };
  const { borrar, desconocidos } = analizarExistentes(estado, curriculo);
  assert.deepStrictEqual(borrar.cursos, []);
  assert.deepStrictEqual(borrar.temas, []);
  assert.deepStrictEqual(desconocidos, ['cursos/quimica_extra', 'temas/tema-nuevo']);
});
