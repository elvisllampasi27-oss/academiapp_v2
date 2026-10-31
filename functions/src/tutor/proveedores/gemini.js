'use strict';

/**
 * Proveedor Gemini (Google AI Studio). Llamada REST directa: sin SDK.
 * @param {{ clave: string, modelo?: string, instrucciones: string,
 *           mensajes: {rol: 'estudiante'|'tutor', texto: string}[] }} opciones
 * @returns {Promise<string>} texto de la respuesta
 */
async function generarConGemini({ clave, modelo, instrucciones, mensajes }) {
  const nombre = modelo || 'gemini-3.8-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${nombre}:generateContent`;

  const respuesta = await fetch(url, {
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
        maxOutputTokens: 1536,
        // Poco "pensamiento": respuestas rápidas y más baratas.
        thinkingConfig: { thinkingLevel: 'low' },
      },
    }),
  });

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

module.exports = { generarConGemini };
