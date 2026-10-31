/**
 * Punto de entrada de Cloud Functions de AcademiApp V2.
 * Cada módulo vive en src/<modulo>/ (no repetir el "god file" de V1).
 */
'use strict';

const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

// Límite de instancias: protege el presupuesto ante abuso o bucles.
setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

const { enviarIntentoEvaluacion } = require('./src/assessment/enviar_intento_evaluacion');

exports.enviarIntentoEvaluacion = enviarIntentoEvaluacion;

const { preguntarTutor } = require('./src/tutor/preguntar_tutor');

exports.preguntarTutor = preguntarTutor;
