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

test('si Gemini no responde a tiempo, corta con un error claro (504)', async (t) => {
  t.mock.method(globalThis, 'fetch', (url, opciones) => new Promise((_, rechazar) => {
    // Un Gemini que nunca contesta. (El temporizador mantiene viva la prueba:
    // el del corte no lo hace por sí solo.)
    const colgado = setTimeout(() => {}, 5000);
    opciones.signal.addEventListener('abort', () => {
      clearTimeout(colgado);
      rechazar(opciones.signal.reason);
    });
  }));

  await assert.rejects(
    generarConGemini({
      clave: 'x',
      instrucciones: 'i',
      mensajes: [{ rol: 'estudiante', texto: 'a' }],
      tiempoMaximoMs: 20,
    }),
    (e) => e.estado === 504 && /no respondió/.test(e.message),
  );
});

test('si falla la red, avisa el motivo (503)', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => {
    const error = new TypeError('fetch failed');
    error.cause = { code: 'ENOTFOUND' };
    throw error;
  });

  await assert.rejects(
    generarConGemini({ clave: 'x', instrucciones: 'i', mensajes: [{ rol: 'estudiante', texto: 'a' }] }),
    // También prueba el respaldo; el detalle conserva la causa.
    (e) => e.estado === 503 && /ENOTFOUND/.test(e.detalle),
  );
});

test('si el modelo principal está saturado, responde el de respaldo', async (t) => {
  const pedidos = [];
  t.mock.method(globalThis, 'fetch', async (url) => {
    pedidos.push(url);
    if (pedidos.length === 1) {
      return { ok: false, status: 503, text: async () => 'high demand' };
    }
    return {
      ok: true,
      json: async () => ({ candidates: [{ content: { parts: [{ text: 'desde el respaldo' }] } }] }),
    };
  });

  const texto = await generarConGemini({
    clave: 'x', instrucciones: 'i', mensajes: [{ rol: 'estudiante', texto: 'a' }],
  });

  assert.strictEqual(texto, 'desde el respaldo');
  assert.match(pedidos[0], /gemini-3\.8-flash:/);
  assert.match(pedidos[1], /gemini-3\.1-flash-lite:/);
});

test('un error que no es de saturación (400) no prueba el respaldo', async (t) => {
  let llamadas = 0;
  t.mock.method(globalThis, 'fetch', async () => {
    llamadas += 1;
    return { ok: false, status: 400, text: async () => 'mal' };
  });

  await assert.rejects(
    generarConGemini({ clave: 'x', instrucciones: 'i', mensajes: [{ rol: 'estudiante', texto: 'a' }] }),
    (e) => e.estado === 400,
  );
  assert.strictEqual(llamadas, 1);
});

test('si los dos están saturados, avisa de ambos', async (t) => {
  t.mock.method(globalThis, 'fetch', async () => ({ ok: false, status: 503, text: async () => 'ocupado' }));

  await assert.rejects(
    generarConGemini({ clave: 'x', instrucciones: 'i', mensajes: [{ rol: 'estudiante', texto: 'a' }] }),
    (e) => e.estado === 503 && /principal .*503 .*respaldo .*503/.test(e.detalle),
  );
});
