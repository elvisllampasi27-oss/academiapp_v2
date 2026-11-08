'use strict';

/**
 * Proveedor Gemini (Google AI Studio). Llamada REST directa: sin SDK.
 * @param {{ clave: string, modelo?: string, instrucciones: string,
 *           mensajes: {rol: 'estudiante'|'tutor', texto: string}[],
 *           json?: boolean, maxTokens?: number, tiempoMaximoMs?: number }} opciones
 *   json: pide la respuesta como JSON (para generar quizzes).
 *   tiempoMaximoMs: si Gemini (o la red) no responde en ese tiempo, se corta
 *   con un error claro en vez de quedarse colgada hasta el límite de la función.
 * @returns {Promise<string>} texto de la respuesta
 */
async function generarConGemini({
  clave, modelo, instrucciones, mensajes, json = false, maxTokens = 1536, tiempoMaximoMs = 30000,
}) {
  const nombre = modelo || 'gemini-3.8-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${nombre}:generateContent`;

  let respuesta;
  try {
    respuesta = await llamar(url, clave, {
      instrucciones, mensajes, json, maxTokens, tiempoMaximoMs,
    });
  } catch (e) {
    const agotado = e && (e.name === 'TimeoutError' || e.name === 'AbortError');
    const error = new Error(agotado
      ? `Gemini no respondió en ${Math.round(tiempoMaximoMs / 1000)} s`
      : 'No se pudo conectar con Gemini');
    // 504: se agotó el tiempo; 503: falló la red (DNS, conexión cortada...).
    error.estado = agotado ? 504 : 503;
    error.detalle = String((e && e.cause && (e.cause.code || e.cause.message)) || (e && e.message) || '');
    throw error;
  }

  if (!respuesta.ok) {
    const error = new Error(`Gemini respondió ${respuesta.status}`);
    error.estado = respuesta.status;
    error.detalle = await respuesta.text().catch(() => '');
    throw error;
  }

  const datos = await respuesta.json();
  const texto = (datos.candidates?.[0]?.content?.parts || [])
    .filter((p) => !p.thought)
    .map((p) => p.text || '')
    .join('')
    .trim();

  if (!texto) {
    const error = new Error('Gemini no devolvió texto');
    error.estado = 0;
    error.detalle = JSON.stringify(datos.promptFeedback || datos.candidates?.[0]?.finishReason || '');
    throw error;
  }

  return texto;
}

function llamar(url, clave, { instrucciones, mensajes, json, maxTokens, tiempoMaximoMs }) {
  return fetch(url, {
    signal: AbortSignal.timeout(tiempoMaximoMs),
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': clave },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: instrucciones }] },
      contents: mensajes.map((m) => ({
        role: m.rol === 'tutor' ? 'model' : 'user',
        parts: [{ text: m.texto }],
      })),
      generationConfig: {
        temperature: 0.4,
        // Incluye el razonamiento interno del modelo, no solo la respuesta.
        maxOutputTokens: maxTokens,
        // Poco "pensamiento": respuestas rápidas y más baratas.
        thinkingConfig: { thinkingLevel: 'low' },
        ...(json ? { responseMimeType: 'application/json' } : {}),
      },
    }),
  });
}

module.exports = { generarConGemini };
