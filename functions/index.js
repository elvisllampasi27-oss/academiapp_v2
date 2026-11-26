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

const examenes = require('./src/examenes/funciones');

exports.revisarPreguntaExamen = examenes.revisarPreguntaExamen;
exports.iniciarSimulacro = examenes.iniciarSimulacro;
exports.enviarSimulacro = examenes.enviarSimulacro;
exports.rankingSemanal = examenes.rankingSemanal;
exports.estadoExamenSemanal = examenes.estadoExamenSemanal;

const { generarPreguntas } = require('./src/contenido/generar_preguntas');

exports.generarPreguntas = generarPreguntas;

const cuenta = require('./src/cuenta/eliminar_cuenta');

exports.eliminarMiCuenta = cuenta.eliminarMiCuenta;
exports.eliminarCuentaAlumno = cuenta.eliminarCuentaAlumno;

const { prepararCuenta } = require('./src/cuenta/preparar_cuenta');

exports.prepararCuenta = prepararCuenta;

const { verificarCompraPlay } = require('./src/premium/compra_play');

exports.verificarCompraPlay = verificarCompraPlay;

const culqi = require('./src/premium/cobro_culqi');

exports.cotizarPremiumWeb = culqi.cotizarPremiumWeb;
exports.cobrarPremiumWeb = culqi.cobrarPremiumWeb;

const { estadoSistema } = require('./src/sistema/estado');

exports.estadoSistema = estadoSistema;
