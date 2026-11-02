# Arquitectura de AcademiApp V2

Guía corta para entender dónde va cada cosa y por qué. Si un cambio no encaja
en estas reglas, primero se discute y se anota aquí.

## Piezas

| Pieza | Qué es | Dónde |
|---|---|---|
| App del estudiante | Flutter (Android y web) | `lib/main.dart`, `lib/app/`, `lib/features/` |
| Panel de control | Flutter web, otra entrada del mismo proyecto | `lib/main_admin.dart`, `lib/admin/` |
| Servidor | Cloud Functions (Node 22) | `functions/` |
| Reglas de seguridad | Firestore | `firestore.rules`, pruebas en `reglas/` |
| Scripts de carga | Node, se ejecutan desde la PC del admin | `tool/` |
| Archivos públicos | Firebase Hosting (panel compilado, figuras de exámenes) | `hosting/` |

## Capas de cada módulo (`lib/features/<módulo>/`)

```
domain/          reglas del negocio en Dart puro: entidades, interfaces de
                 repositorios, servicios (BKT, calendario, seguimiento de la clase…)
infrastructure/  implementaciones con Firebase (Firestore, Functions)
presentation/    pantallas y widgets
```

- `domain` no importa Flutter ni Firebase. Por eso se prueba sin emulador.
- `presentation` recibe interfaces por constructor, nunca crea repositorios.
- Un módulo no importa la `presentation` de otro. Si una pantalla necesita algo
  de otro módulo, se lo pasa quien la abre (ver `seccionExtra`/`practica`/`dudas`
  en `TemaPage`).

Módulos: `identity` (cuentas), `enrollment` (matrícula), `academic` (temario,
calendario, clase), `assessment` (prácticas), `student_model` (evidencias),
`adaptive_engine` (BKT y ruta), `exams` (exámenes pasados y tipo admisión),
`tutor` (dudas con IA), `seminars`.

## Composición (`lib/app/`)

- `dependencias.dart` es el **único** lugar donde se eligen las implementaciones
  (`Dependencias.firebase()`). Las pruebas arman las suyas con datos falsos.
- `puerta_sesion_page.dart` decide entre bienvenida, login e inicio.
- `home_estudiante.dart` arma las pestañas y la navegación entre módulos.
- `inicio/contexto_academico.dart` es el caso de uso que carga matrícula, día,
  ruta y temario al abrir la app.

Sin contenedor de inyección, sin `go_router`, sin Bloc/Riverpod: con este tamaño
el constructor y `setState` alcanzan. Se reconsidera si una pantalla necesita
compartir estado vivo con otra.

## Seguridad

1. **Las respuestas correctas nunca llegan al celular** antes de responder:
   viven en `claves_preguntas` y `claves_examen` (reglas: lectura cerrada) y
   corrige el servidor.
2. **Las reglas niegan todo lo no declarado.** Cada colección nueva se declara
   en `firestore.rules` **y** se prueba en `reglas/reglas.test.js`.
3. **El estudiante no puede cambiar su plan, rol ni estado**: solo `nombre` y
   `carreraPostulada` de su perfil.
4. **Administrador = permiso `admin` en el token** (`tool/hacer_admin.js`). El
   panel escribe directo en Firestore y las reglas lo exigen.
5. **Secretos fuera de git**: claves de servicio (`*-admin.json`), claves de IA
   (`functions/.secret.local`), exámenes con claves (`/examenes/`).
6. Lo que necesita el servidor y no puede esperar (corregir, IA) va en Cloud
   Functions. Lo que puede hacer un admin con reglas (aprobar pagos, editar
   contenido) funciona sin Functions, para no depender del plan Blaze.

## Datos (Firestore)

| Colección | Quién escribe | Notas |
|---|---|---|
| `usuarios` | estudiante (perfil) / admin | plan y estado solo admin |
| `matriculas`, `versiones_academicas`, `planes_academicos` | admin / scripts | |
| `curriculos/{version}`, `publicaciones_version/{version}` | scripts | temario en 1 lectura |
| `contenidos`, `recursos` | admin / scripts | material de cada tema |
| `progreso_clases` | estudiante (el suyo) | id `{uid}__{version}__{tema}` |
| `evaluaciones`, `preguntas` / `claves_preguntas` | admin / scripts | prácticas por tema |
| `intentos_evaluacion`, `respuestas`, `evidencias` | servidor | entrada del BKT |
| `examenes`, `preguntas_examen` / `claves_examen`, `indices` | admin / scripts | exámenes pasados |
| `simulacros` | servidor | examen tipo admisión |
| `uso_tutor` | servidor | límite diario |
| `seminarios` | admin / scripts | |

## Pruebas

| Qué | Cómo |
|---|---|
| App y panel | `flutter test` |
| Scripts | `npm test --prefix tool` |
| Funciones | `npm test --prefix functions` |
| Reglas | `cd reglas && npm install && npm test` (emulador, necesita Java 11+) |

GitHub Actions (`.github/workflows/ci.yml`) corre todo en cada push.

## Entornos

Hoy el desarrollo usa la base real (`academiapp-v2-7b9ce`) y las funciones en el
emulador. **Antes de matricular alumnos reales**: crear un proyecto de
desarrollo aparte (o usar también el emulador de Firestore) y dejar
`academiapp-v2-7b9ce` solo como producción.
