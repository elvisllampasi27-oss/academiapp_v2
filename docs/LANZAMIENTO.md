# Lanzamiento de Sinchi: lo que queda para el final

Orden acordado: **1)** terminar los parches de la app, **2)** preparar el
contenido (videos, ejercicios, exámenes, materiales), **3)** recién entonces
hacer lo de este documento. Todo el código que depende de Blaze ya queda
escrito y probado; solo falta activarlo aquí.

## 1. Proyecto de Firebase con el Gmail

El proyecto actual (`academiapp-v2-7b9ce`) está a nombre del correo
institucional. Sinchi es un emprendimiento propio: pasa a un proyecto nuevo
a nombre de **elbrayanllampasiespino@gmail.com**. Como todavía no hay
alumnos reales, se empieza limpio (no se migran datos).

En la consola de Firebase, con el Gmail:

1. Crear el proyecto **Sinchi**. Elegir bien el **ID** (no se puede
   cambiar): por ejemplo `sinchi-academia` → la web queda en
   `sinchi-academia.web.app`. Sin Google Analytics.
2. **Authentication**: activar *Correo/contraseña* y *Google*.
3. **Firestore**: ubicación **`nam5 (us-central)`** (la misma región de las
   funciones, `us-central1`; no se puede cambiar).
4. **Registrar apps**:
   - Android `pe.sinchi.academia` con las huellas SHA1 y SHA256 de
     `docs/PUBLICAR_ANDROID.md` (las de la PC sirven igual).
   - Web, apodo "Sinchi web".
5. **Storage** se crea al activar Blaze (sección 2).

En PowerShell:

```powershell
firebase logout
firebase login                # con el Gmail
flutterfire configure --project=<ID-NUEVO> --platforms=android,web --android-package-name=pe.sinchi.academia
git checkout -- firebase.json # flutterfire lo reescribe; ver abajo
```

Cambiar en el código el ID viejo por el nuevo (buscar `academiapp-v2-7b9ce`):

- `firebase.json` → los `appId` de Android y web (sección `flutter`).
- `lib/core/enlaces.dart` → enlace de la política de privacidad.
- `lib/admin/importar/importar_json.dart` y
  `lib/admin/examenes/editor_pregunta.dart` → dirección del hosting.
- `tool/cargar_examenes.js` (`URL_HOSTING`) y `tool/seed_academico_v2.js`
  (`PROYECTO_ESPERADO`).
- `docs/BLAZE.md`, `docs/ARQUITECTURA.md`, `docs/PUBLICAR_ANDROID.md`.
- Crear `.firebaserc` con `{"projects": {"default": "<ID-NUEVO>"}}`.

Después:

```powershell
firebase deploy --only firestore,hosting
```

- Registrarse en la app con el Gmail y volverse administrador:
  `node tool/hacer_admin.js` (con la clave de cuenta de servicio del
  proyecto nuevo: Configuración → Cuentas de servicio → Generar clave;
  **nunca subirla a git**).
- Cargar el temario y el contenido con los scripts de `tool/` (seed,
  material, evaluaciones, exámenes, seminarios), siempre primero sin
  `--apply` para revisar.
- Cuando todo funcione, dejar el proyecto viejo.

> Opcional: comprar un dominio (por ejemplo `sinchi.pe`) y conectarlo a
> Hosting. Así los enlaces (política, eliminar cuenta, pago web) no
> dependen del ID del proyecto.

## 2. Activar Blaze

Seguir `docs/BLAZE.md` en el proyecto nuevo. Con Blaze se activan las
funciones que ya están escritas y probadas:

| Función | Para qué |
|---|---|
| `prepararCuenta` | Matrícula automática y prueba gratis al registrarse |
| `eliminarMiCuenta`, `eliminarCuentaAlumno` | Eliminar la cuenta (Play Store lo exige) |
| `enviarIntentoEvaluacion` | Corregir las prácticas |
| `iniciarSimulacro`, `enviarSimulacro`, `rankingSemanal`, `estadoExamenSemanal`, `revisarPreguntaExamen` | Examen semanal, ranking y exámenes pasados |
| `generarPreguntas` | Generar preguntas con IA desde el panel |
| `preguntarTutor` | Tutor con IA |
| `verificarCompraPlay` | Confirmar la compra de Premium en Android y dar los días |
| Cobro con Culqi | Premium en la web (se agrega en el próximo parche) |

Antes de eso, la app responde "estará disponible pronto" donde haga falta,
y la matrícula se hace desde el panel.

## 3. Cuentas para cobrar (modelo mixto, pago único de 90 días)

- **App de Android**: solo Google Play Billing (la política de Play lo
  exige en Perú). Nada de Yape, enlaces ni precios de la web dentro de la
  app.
  - Play Console → crear el perfil de comerciante.
  - Subir al menos una versión a *Prueba interna* (Play no deja crear
    productos sin una versión subida).
  - **Monetizar → Productos → Productos integrados → Crear**: ID
    **`premium_90_dias`** (exacto: es el que usa la app y la función),
    nombre "Premium 90 días", precio en soles. Activarlo.
  - Google Cloud (proyecto nuevo) → **APIs y servicios** → activar
    **Google Play Android Developer API**.
  - Play Console → **Usuarios y permisos → Invitar** a la cuenta de
    servicio con la que corren las funciones (Google Cloud → IAM; la de
    las funciones v2 es `NÚMERO-compute@developer.gserviceaccount.com`).
    Permisos de la app: *Ver datos financieros* y *Gestionar pedidos*.
    Puede tardar hasta un día en valer.
  - Probar con **Configuración → Pruebas de licencias**: agregar el Gmail
    como probador. Esas compras no se cobran y en el panel salen como
    compra de prueba.
  - Reembolsos: se hacen en Play Console → Gestión de pedidos. Por ahora
    la app no quita el Premium cuando Google reembolsa. Pendiente para
    cuando haya ventas: leer los reembolsos con la API *Voided Purchases*.
- **Web** (página `/premium` y la versión web de Sinchi): **Culqi** con
  Yape y tarjetas.
  - Cuenta de Culqi con el RUC 10705212631 y una cuenta bancaria.
  - Las claves de Culqi van como *secretos* de las funciones; nunca en la
    app ni en git.
- El panel conserva "Dar Premium" para casos especiales.

## 4. Antes de publicar en Play Store

- Seguir `docs/PUBLICAR_ANDROID.md` (clave de firma, `.aab`, huellas de
  Play App Signing en Firebase).
- Enlaces que pide Play Console: política de privacidad y eliminar cuenta
  (`/privacidad/` y `/eliminar-cuenta/` del hosting nuevo).
- Que un abogado revise la política de privacidad y redactar términos y
  condiciones (Premium sin reembolso, prueba gratis una vez).
- Revisar la marca "Sinchi" en INDECOPI.
