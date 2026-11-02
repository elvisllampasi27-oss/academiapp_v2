# AcademiApp V2

App de preparación para el examen de admisión de la UNSCH: temas del día con
clase en video, prácticas con corrección en el servidor, ruta personalizada
(BKT), tutor con IA, exámenes pasados y examen tipo admisión. Incluye un panel
de control web para la academia.

- **App**: Flutter (Android y web) + Firebase (Auth, Firestore, Hosting).
- **Servidor**: Cloud Functions (Node 22).
- **Arquitectura y reglas del proyecto**: [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md).

## Ejecutar

```bash
flutter pub get
flutter run -d edge                          # app del estudiante
flutter run -d edge -t lib/main_admin.dart   # panel de control
```

Funciones en tu PC (necesitan `functions/.secret.local` con `GEMINI_API_KEY`):

```bash
firebase emulators:start --only functions
flutter run -d edge --dart-define=EMULADOR_FUNCTIONS=true
```

## Pruebas

```bash
dart format lib test && flutter analyze && flutter test
npm test --prefix tool
npm test --prefix functions
cd reglas && npm install && npm test   # reglas de Firestore (Java 11+)
```

## Scripts de administración (`tool/`)

Todos simulan primero y solo escriben con `--apply`:
`seed_academico_v2.js` (temario y calendario), `cargar_material.js`,
`cargar_evaluaciones.js`, `cargar_examenes.js`, `cargar_seminarios.js`,
`hacer_admin.js`.
