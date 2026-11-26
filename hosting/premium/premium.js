// Premium desde la web con Culqi (Yape o tarjeta). El cobro y los días de
// Premium los hace el servidor (cotizarPremiumWeb y cobrarPremiumWeb); aquí
// solo se inicia sesión, se muestra el precio y se abre Culqi Checkout.
// La configuración de Firebase la da el propio Hosting (/__/firebase/init.json),
// así esta página sirve igual en el proyecto nuevo sin tocarla.
import { initializeApp } from 'https://www.gstatic.com/firebasejs/13.3.0/firebase-app.js';
import {
  getAuth,
  onAuthStateChanged,
  signInWithPopup,
  signInWithEmailAndPassword,
  signOut,
  GoogleAuthProvider,
} from 'https://www.gstatic.com/firebasejs/13.3.0/firebase-auth.js';
import { getFirestore, doc, getDoc } from 'https://www.gstatic.com/firebasejs/13.3.0/firebase-firestore.js';
import { getFunctions, httpsCallable } from 'https://www.gstatic.com/firebasejs/13.3.0/firebase-functions.js';

const DIA_MS = 24 * 60 * 60 * 1000;
const $ = (id) => document.getElementById(id);
const SECCIONES = ['cargando', 'pronto', 'ingreso', 'cuenta', 'listo'];

function mostrar(seccion) {
  for (const s of SECCIONES) $(s).hidden = s !== seccion;
}

/** Pone un texto y lo muestra; sin texto, lo oculta. */
function texto(id, valor, clase) {
  const e = $(id);
  e.textContent = valor || '';
  e.hidden = !valor;
  if (clase) e.className = `${clase} chico`;
}

const fecha = (ms) => new Date(ms).toLocaleDateString('es-PE', {
  day: 'numeric', month: 'long', year: 'numeric', timeZone: 'America/Lima',
});

/** El mensaje del servidor si es para el alumno; si no, uno genérico. */
function mensajeDe(error) {
  const codigo = (error && error.code) || '';
  if (error && error.message && codigo.startsWith('functions/') && codigo !== 'functions/internal') {
    return error.message;
  }
  return 'Algo salió mal. Inténtalo de nuevo en un momento.';
}

let auth;
let db;
let cotizarPremium;
let cobrarPremium;
let llavePublica = '';
let cotizacion = null; // { precio, monto, dias, beca, cupon }
let dispositivo = null;

async function iniciar() {
  try {
    const respuesta = await fetch('/__/firebase/init.json');
    const app = initializeApp(await respuesta.json());
    auth = getAuth(app);
    db = getFirestore(app);
    const funciones = getFunctions(app, 'us-central1');
    cotizarPremium = httpsCallable(funciones, 'cotizarPremiumWeb');
    cobrarPremium = httpsCallable(funciones, 'cobrarPremiumWeb');
  } catch (_) {
    mostrar('pronto');
    return;
  }
  onAuthStateChanged(auth, (usuario) => {
    $('salir').hidden = !usuario;
    if (usuario) {
      cargarCuenta(usuario);
    } else {
      mostrar('ingreso');
    }
  });
}

// ------------------------------------------------------------ ingreso

$('google').addEventListener('click', async () => {
  texto('error-ingreso', '');
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    if (e && e.code !== 'auth/popup-closed-by-user' && e.code !== 'auth/cancelled-popup-request') {
      texto('error-ingreso', 'No se pudo iniciar sesión con Google.');
    }
  }
});

$('formulario-correo').addEventListener('submit', async (evento) => {
  evento.preventDefault();
  texto('error-ingreso', '');
  try {
    await signInWithEmailAndPassword(auth, $('correo').value.trim(), $('clave').value);
  } catch (_) {
    texto('error-ingreso', 'Correo o contraseña incorrectos.');
  }
});

$('salir').addEventListener('click', () => signOut(auth));

// ------------------------------------------------------------ cuenta

async function cargarCuenta(usuario) {
  mostrar('cargando');
  try {
    const [perfil, academia] = await Promise.all([
      getDoc(doc(db, 'usuarios', usuario.uid)),
      getDoc(doc(db, 'config', 'academia')),
    ]);
    llavePublica = String((academia.data() || {}).culqiLlavePublica || '').trim();
    if (!llavePublica) {
      mostrar('pronto');
      return;
    }
    const datos = perfil.exists() ? perfil.data() : null;
    $('nombre').textContent = (datos && datos.nombre) || usuario.displayName || '';
    $('correo-cuenta').textContent = `(${usuario.email || ''})`;
    if (!datos) {
      $('estado').textContent = 'Primero crea tu cuenta en la app Sinchi y vuelve aquí.';
      $('tarjeta-pago').hidden = true;
      mostrar('cuenta');
      return;
    }
    $('estado').textContent = estadoPlan(datos);
    $('tarjeta-pago').hidden = false;
    mostrar('cuenta');
    await cotizarCon('');
  } catch (e) {
    texto('error-pago', mensajeDe(e));
    mostrar('cuenta');
  }
}

function estadoPlan(datos) {
  const ms = (v) => (v && typeof v.toMillis === 'function' ? v.toMillis() : null);
  const hasta = ms(datos.premiumHasta);
  const prueba = ms(datos.pruebaHasta);
  if (hasta == null || hasta <= Date.now()) return 'Tienes el plan gratis.';
  if (prueba != null && hasta <= prueba) {
    return `Estás en tu prueba gratis hasta el ${fecha(prueba - DIA_MS)}.`;
  }
  return `Tienes Premium hasta el ${fecha(hasta)}.`;
}

async function cotizarCon(codigo) {
  $('pagar').disabled = true;
  try {
    const { data } = await cotizarPremium(codigo ? { cupon: codigo } : {});
    cotizacion = data;
    $('dias').textContent = data.dias;
    $('monto').textContent = data.beca ? 'Gratis' : `S/ ${data.monto}`;
    texto('precio-normal', data.monto < data.precio ? `S/ ${data.precio}` : '');
    $('precio-normal').className = 'tachado';
    $('pagar').textContent = data.beca ? 'Canjear beca' : 'Pagar con Yape o tarjeta';
    texto('aviso-cupon', data.cupon ? `Cupón ${data.cupon} aplicado.` : '', 'ok');
  } catch (e) {
    if (codigo) {
      texto('aviso-cupon', mensajeDe(e), 'error');
    } else {
      texto('error-pago', mensajeDe(e));
    }
  } finally {
    $('pagar').disabled = cotizacion == null;
  }
}

$('aplicar').addEventListener('click', () => cotizarCon($('cupon').value.trim()));

// ------------------------------------------------------------ pago

function ocupado(si) {
  $('pagar').disabled = si || cotizacion == null;
  $('aplicar').disabled = si;
  $('pagar').textContent = si
    ? 'Procesando…'
    : (cotizacion && cotizacion.beca ? 'Canjear beca' : 'Pagar con Yape o tarjeta');
}

$('pagar').addEventListener('click', async () => {
  if (!cotizacion) return;
  texto('error-pago', '');
  const cupon = cotizacion.cupon || undefined;
  if (cotizacion.beca) {
    await enviar({ cupon });
    return;
  }
  await prepararDispositivo();
  abrirCulqi(cupon);
});

/** Huella del dispositivo para el antifraude de Culqi (opcional). */
async function prepararDispositivo() {
  dispositivo = null;
  try {
    if (window.Culqi3DS) {
      window.Culqi3DS.reset();
      window.Culqi3DS.publicKey = llavePublica;
      dispositivo = await window.Culqi3DS.generateDevice();
    }
  } catch (_) {
    dispositivo = null;
  }
}

function abrirCulqi(cupon) {
  if (!window.CulqiCheckout) {
    texto('error-pago', 'No se pudo cargar el medio de pago. Recarga la página.');
    return;
  }
  const culqi = new window.CulqiCheckout(llavePublica, {
    settings: { title: 'Sinchi Premium', currency: 'PEN', amount: cotizacion.monto * 100 },
    client: { email: auth.currentUser.email || '' },
    options: {
      lang: 'auto',
      installments: false,
      modal: true,
      paymentMethods: {
        tarjeta: true, yape: true, billetera: false, bancaMovil: false, agente: false, cuotealo: false,
      },
      paymentMethodsSort: ['yape', 'tarjeta'],
    },
    appearance: { theme: 'default', menuType: 'sidebar' },
  });
  culqi.culqi = async () => {
    if (culqi.token) {
      const token = culqi.token.id;
      culqi.close();
      await enviar({ token, cupon });
    } else if (culqi.error) {
      texto('error-pago', culqi.error.user_message || 'No se pudo procesar el pago.');
    }
  };
  culqi.open();
}

async function enviar(datos, autenticacion3DS) {
  ocupado(true);
  try {
    const { data } = await cobrarPremium({
      ...datos,
      ...(dispositivo ? { dispositivo } : {}),
      ...(autenticacion3DS ? { autenticacion3DS } : {}),
    });
    if (data.estado === 'activada') {
      $('listo-hasta').textContent = `Premium hasta el ${fecha(data.premiumHasta)}.`;
      mostrar('listo');
    } else if (data.estado === '3ds' && datos.token && !autenticacion3DS) {
      const parametros = await autenticar3DS(datos.token);
      await enviar(datos, parametros);
    } else {
      texto('error-pago', 'No se pudo completar el pago. Inténtalo de nuevo.');
    }
  } catch (e) {
    texto('error-pago', e instanceof ErrorTresDS ? e.message : mensajeDe(e));
  } finally {
    ocupado(false);
  }
}

class ErrorTresDS extends Error {}

/** Verificación del banco (3DS). Devuelve los parámetros para el cobro. */
function autenticar3DS(token) {
  const tresDS = window.Culqi3DS;
  if (!tresDS) return Promise.reject(new ErrorTresDS('Tu banco pide verificar la compra. Recarga la página e inténtalo de nuevo.'));
  tresDS.publicKey = llavePublica;
  tresDS.settings = {
    charge: { totalAmount: cotizacion.monto * 100, returnUrl: window.location.href, currency: 'PEN' },
    card: { email: auth.currentUser.email || '' },
  };
  tresDS.options = {
    showModal: true,
    showLoading: true,
    showIcon: true,
    style: { btnColor: '#FBBF24', btnTextColor: '#111111' },
  };
  return new Promise((resolver, rechazar) => {
    function escuchar(evento) {
      if (evento.origin !== window.location.origin) return;
      const d = evento.data || {};
      if (d.parameters3DS) {
        window.removeEventListener('message', escuchar);
        // Solo los campos que espera el servidor.
        const campos = ['eci', 'xid', 'cavv', 'protocolVersion', 'directoryServerTransactionId'];
        const p = d.parameters3DS;
        resolver(Object.fromEntries(campos.filter((k) => p[k] != null).map((k) => [k, String(p[k])])));
      } else if (d.error) {
        window.removeEventListener('message', escuchar);
        rechazar(new ErrorTresDS(typeof d.error === 'string' ? d.error : 'No se pudo verificar la compra.'));
      }
    }
    window.addEventListener('message', escuchar);
    tresDS.initAuthentication(token);
  });
}

iniciar();
