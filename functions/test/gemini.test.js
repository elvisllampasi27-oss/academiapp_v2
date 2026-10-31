'use strict';

const test = require('node:test');
const assert = require('node:assert');
const { generarConGemini } = require('../src/tutor/proveedores/gemini');

test('envia instrucciones e historial y devuelve el texto', async (t) => {
  let enviado;
  t.mock.method(globalThis, 'fetch', async (url, opciones) => {
    enviado = { url, cuerpo: JSON.parse(opciones.body), clave: opciones.headers['x-goog-api-key'] };
    return {
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: ' P(1) = 7 ' }] } }] }),
    };
  });

  const texto = await generarConGemini({
    clave: 'clave-prueba',
    instrucciones: 'Eres el tutor',
    mensajes: [
      { rol: 'estudiante', texto: 'hola' },
      { rol: 'tutor', texto: 'hola, ¿qué duda tienes?' },
      { rol: 'estudiante', texto: '¿Cuánto es P(1)?' },
    ],
  });

  assert.strictEqual(texto, 'P(1) = 7');
  assert.match(enviado.url, /gemini-3\.8-flash:generateContent$/);
  assert.strictEqual(enviado.clave, 'clave-prueba');
  assert.deepStrictEqual(enviado.cuerpo.contents.map((c) => c.role), ['user', 'model', 'user']);
  assert.strictEqual(enviado.cuerpo.systemInstruction.parts[0].text, 'Eres el tutor');
});

test('un error HTTP conserva el estado (429 = ocupado)', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => ({ ok: false, status: 429, text: async () => 'cuota' }));

  await assert.rejects(
    generarConGemini({ clave: 'x', instrucciones: 'i', mensajes: [{ rol: 'estudiante', texto: 'a' }] }),
    (e) => e.estado === 429,
  );
});
