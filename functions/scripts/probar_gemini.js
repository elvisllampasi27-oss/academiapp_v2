'use strict';

/**
 * Diagnóstico rápido: ¿Gemini responde desde esta PC?
 * Prueba el modelo principal y el de respaldo con una pregunta corta y dice
 * cuánto tardó cada uno. Lee la clave de functions/.secret.local y NUNCA la
 * muestra.
 *
 * Uso (desde la carpeta del proyecto):  node functions/scripts/probar_gemini.js
 */
const fs = require('node:fs');
const path = require('node:path');
const { MODELO_PRINCIPAL, MODELO_RESPALDO } = require('../src/tutor/proveedores/gemini');

function leerClave() {
  const archivo = path.join(__dirname, '..', '.secret.local');
  if (!fs.existsSync(archivo)) return null;
  const linea = fs.readFileSync(archivo, 'utf8')
    .split(/\r?\n/)
    .find((l) => l.startsWith('GEMINI_API_KEY='));
  return linea ? linea.slice('GEMINI_API_KEY='.length).trim().replace(/^"|"$/g, '') : null;
}

async function probar(modelo, clave) {
  const inicio = Date.now();
  try {
    const respuesta = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`,
      {
        method: 'POST',
        signal: AbortSignal.timeout(40000),
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': clave },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: 'Responde solo: hola' }] }],
          generationConfig: { maxOutputTokens: 256, thinkingConfig: { thinkingLevel: 'low' } },
        }),
      },
    );
    const ms = Date.now() - inicio;
    const cuerpo = await respuesta.text();
    if (!respuesta.ok) {
      let mensaje = cuerpo;
      try { mensaje = JSON.parse(cuerpo).error.message; } catch (_) { /* texto tal cual */ }
      return `✗ ${modelo}: ${respuesta.status} en ${ms} ms → ${String(mensaje).slice(0, 160)}`;
    }
    const texto = JSON.parse(cuerpo).candidates?.[0]?.content?.parts
      ?.filter((p) => !p.thought).map((p) => p.text).join('').trim();
    return `✓ ${modelo}: respondió en ${ms} ms → "${(texto || '').slice(0, 60)}"`;
  } catch (e) {
    const ms = Date.now() - inicio;
    const causa = (e.cause && (e.cause.code || e.cause.message)) || e.name || e.message;
    return `✗ ${modelo}: sin respuesta tras ${ms} ms → ${causa}`;
  }
}

(async () => {
  const clave = leerClave();
  if (!clave) {
    console.log('No encontré GEMINI_API_KEY en functions/.secret.local.');
    process.exitCode = 1;
    return;
  }
  console.log(`Clave encontrada (termina en …${clave.slice(-4)}). Probando…`);
  for (const modelo of [process.env.GEMINI_MODELO || MODELO_PRINCIPAL, MODELO_RESPALDO]) {
    console.log(await probar(modelo, clave));
  }
})();
