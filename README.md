# AcademiApp v2

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart_3-0175C2?logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-en_integración-FFCA28?logo=firebase&logoColor=black)
![Arquitectura](https://img.shields.io/badge/arquitectura-Clean_Architecture-6f42c1)
![Estado](https://img.shields.io/badge/estado-en_desarrollo-orange)

Aplicación móvil en **Flutter** para el acompañamiento académico personalizado de estudiantes. Combina un **modelo del estudiante** basado en *Bayesian Knowledge Tracing* (BKT), un **motor adaptativo** que genera recomendaciones según el nivel de dominio y un **tutor con RAG** (*Retrieval-Augmented Generation*) que responde usando solo conocimiento validado.

> Proyecto desarrollado como parte de una tesis de pregrado — Universidad Nacional de San Cristóbal de Huamanga (UNSCH).

---

## Tabla de contenidos

- [Arquitectura](#arquitectura)
- [Módulos](#módulos)
- [Flujo del tutor RAG](#flujo-del-tutor-rag)
- [Decisiones de diseño](#decisiones-de-diseño)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Configuración de Firebase](#configuración-de-firebase)
- [Pruebas y calidad](#pruebas-y-calidad)
- [Convención de commits](#convención-de-commits)
- [Estado del proyecto](#estado-del-proyecto)

---

## Arquitectura

El proyecto sigue **Clean Architecture** organizada por *features*. Cada módulo separa:

| Capa | Responsabilidad |
|---|---|
| `domain/entities` | Modelos del negocio, sin dependencias externas. |
| `domain/repositories` | Contratos (clases abstractas) que el dominio necesita. |
| `domain/services` | Reglas de negocio puras y testeables. |
| `infrastructure` | Implementaciones concretas de los contratos (memoria, Firebase…). |
| `presentation` | Páginas y widgets de Flutter. |

**Regla principal:** el dominio no conoce la infraestructura. Las dependencias siempre apuntan hacia el dominio.

### Diagrama de módulos

```mermaid
flowchart LR
    subgraph Planificacion["Planificación"]
        ENR[enrollment<br/>Matrícula]
        ACA[academic<br/>Plan y calendario]
    end

    subgraph Personalizacion["Personalización"]
        ASM[assessment<br/>Evaluación]
        STM[student_model<br/>BKT]
        ADE[adaptive_engine<br/>Recomendaciones]
    end

    subgraph Tutor["Tutor inteligente"]
        RAG[tutor_rag<br/>RAG]
    end

    ENR --> ACA
    ASM -->|respuestas| STM
    STM -->|EstadoDominio| ADE
    STM -->|EstadoDominio| RAG
    ADE -->|Recomendacion| RAG
```

### Dominio e infraestructura

```mermaid
flowchart TB
    subgraph Dominio
        RC[[RepositorioConocimiento<br/>contrato]]
    end

    subgraph Infraestructura
        MEM[RepositorioConocimientoEnMemoria<br/>actual]
        FB[RepositorioConocimientoFirebase<br/>planificado]
    end

    MEM -.implementa.-> RC
    FB -.implementa.-> RC

    style FB stroke-dasharray: 5 5
```

---

## Módulos

### `academic` — Planificación académica
Entidades: `Area`, `Curso`, `Tema`, `Contenido`, `Recurso`, `PlanAcademico`, `VersionAcademica`, `DiaAcademico`, `ActividadProgramada`.

- `SecuenciaAcademicaService`: ordena los temas de los cursos en una secuencia de estudio.
- `CalendarioAcademicoService`: genera los días académicos del plan.
- `ActividadesDelDiaService`: obtiene las actividades programadas para un día.

### `enrollment` — Matrícula
- `CalcularInicioAcademicoService`: calcula la fecha de inicio académico a partir de la matrícula y su configuración.

### `assessment` — Evaluación
Entidades: `Evaluacion`, `Pregunta`, `Opcion`, `Respuesta`, `IntentoEvaluacion`, `ResultadoEvaluacion`.

- `CalcularResultadoEvaluacionService`: calcula el resultado de un intento a partir de las respuestas.

### `student_model` — Modelo del estudiante (BKT)
Entidades: `Habilidad`, `PreguntaHabilidad`, `Evidencia`, `ParametrosBkt`, `EstadoDominio`.

- `GenerarEvidenciasService`: convierte respuestas en evidencias por habilidad.
- `ModeloBktService`: actualiza la probabilidad de dominio con BKT.
- `CalcularEstadoDominioService`: recorre las evidencias en orden cronológico y devuelve el `EstadoDominio`.

**Parámetros BKT** (todos entre 0 y 1): conocimiento inicial *P(L₀)*, aprendizaje *P(T)*, adivinanza *P(G)* y desliz *P(S)*.

Actualización tras cada evidencia:

$$
P(L \mid \text{correcta}) = \frac{P(L)\,(1-S)}{P(L)\,(1-S) + (1-P(L))\,G}
\qquad
P(L \mid \text{incorrecta}) = \frac{P(L)\,S}{P(L)\,S + (1-P(L))\,(1-G)}
$$

$$
P(L_{t+1}) = P(L \mid \text{obs}) + \bigl(1 - P(L \mid \text{obs})\bigr)\,T
$$

```mermaid
flowchart LR
    L0(["P(L₀)<br/>conocimiento inicial"]) --> OBS{Evidencia}
    OBS -- correcta --> C["Bayes<br/>acierto: usa 1−S y G"]
    OBS -- incorrecta --> I["Bayes<br/>error: usa S y 1−G"]
    C --> T["Aprendizaje<br/>+ (1 − P)·T"]
    I --> T
    T -- siguiente evidencia --> OBS
    T --> N["EstadoDominio<br/>bajo · medio · alto"]
```

**Clasificación del nivel de dominio:**

| Valor | Nivel |
|---|---|
| `< 0.50` | `bajo` |
| `0.50 – 0.79` | `medio` |
| `≥ 0.80` | `alto` |

### `adaptive_engine` — Motor adaptativo
- `AdaptiveEngineService.generarRecomendacion()`: transforma un `EstadoDominio` en una `Recomendacion`.
- `AdaptiveEngineService.construirMiRuta()`: genera recomendaciones para varias habilidades ordenadas por prioridad.

| Nivel de dominio | Recomendación | Prioridad |
|---|---|---|
| `bajo` | `reforzar` | 3 |
| `medio` | `practicar` | 2 |
| `alto` | `profundizar` | 1 |

### `tutor_rag` — Tutor con RAG
Entidades: `DocumentoConocimiento`, `ChunkConocimiento`, `EmbeddingChunk`, `ConsultaTutor`, `ContextoTutor`.

Contratos (`domain/repositories`):

| Contrato | Responsabilidad |
|---|---|
| `RepositorioConocimiento` | Acceso a chunks y embeddings almacenados. |
| `RecuperadorConocimiento` | Recuperar los chunks relevantes para una consulta. |
| `GeneradorEmbedding` | Convertir texto en vector. |
| `GeneradorRespuestaTutor` | Generar la respuesta final a partir del contexto. |

Servicios:

- `RecuperadorPorTextoService`: recuperación por coincidencia de palabras.
- `RecuperadorVectorialService`: recuperación por similitud coseno, con umbral configurable `similitudMinima` (por defecto `0.5`, rango `[-1, 1]`).
- `SimilitudCosenoService`: calcula la similitud coseno entre dos vectores.
- `TutorService`: orquesta la recuperación y la generación. **Si no recupera conocimiento relevante, lanza `ConocimientoNoEncontradoException` y no llama al generador**, para evitar respuestas inventadas.

---

## Flujo del tutor RAG

### Vista general

```mermaid
flowchart LR
    subgraph Personalizacion["1 · Personalización"]
        direction TB
        EV[Evidencias] --> BKT[ModeloBktService]
        BKT --> ED[EstadoDominio]
        ED --> AE[AdaptiveEngineService]
        AE --> REC[Recomendacion]
    end

    subgraph Recuperacion["2 · Recuperación"]
        direction TB
        RCON{{RecuperadorConocimiento}}
        RCON --> RT[Por texto]
        RCON --> RV["Vectorial<br/>similitud ≥ similitudMinima"]
        RT --> REPO[(RepositorioConocimiento)]
        RV --> REPO
    end

    subgraph Generacion["3 · Generación"]
        direction TB
        Q{¿Chunks<br/>relevantes?}
        Q -- Sí --> CTX[ContextoTutor] --> GEN[GeneradorRespuestaTutor] --> RESP[Respuesta]
        Q -- No --> EX[ConocimientoNoEncontradoException]
    end

    CT[ConsultaTutor] --> TS[TutorService]
    ED --> TS
    REC --> TS
    TS --> RCON
    REPO --> Q

    style EX fill:#fdd,stroke:#c33
    style RESP fill:#dfd,stroke:#3a3
```

### Secuencia de `TutorService.responder()`

```mermaid
sequenceDiagram
    autonumber
    actor E as Estudiante
    participant T as TutorService
    participant R as RecuperadorVectorialService
    participant G as GeneradorEmbedding
    participant Repo as RepositorioConocimiento
    participant S as SimilitudCosenoService
    participant LLM as GeneradorRespuestaTutor

    E->>T: responder(consulta, estadoDominio, recomendacion)
    T->>R: recuperar(consulta, limite)
    R->>Repo: obtenerChunks() / obtenerEmbeddings()
    R->>G: generar(texto: consulta)
    G-->>R: vector de la consulta
    loop por cada embedding
        R->>S: calcular(vectorA, vectorB)
        S-->>R: similitud
        Note over R: se descarta si similitud < similitudMinima
    end
    R-->>T: chunks ordenados por similitud (máx. limite)

    alt sin chunks relevantes
        T-->>E: ConocimientoNoEncontradoException
        Note over T,LLM: el generador NO se invoca
    else con chunks relevantes
        T->>LLM: generar(ContextoTutor)
        LLM-->>T: respuesta
        T-->>E: respuesta personalizada
    end
```

---

## Decisiones de diseño

| Decisión | Motivo |
|---|---|
| **Contratos en el dominio** (`RepositorioConocimiento`, `GeneradorEmbedding`, `GeneradorRespuestaTutor`) | El dominio no depende de Firebase ni de un proveedor de IA concreto; se pueden reemplazar sin tocar las reglas de negocio. |
| **`AlmacenVectorial` → `RepositorioConocimiento`** | El recuperador por texto también lo usa; el nombre debía describir *qué* guarda, no *cómo* se busca. |
| **Umbral `similitudMinima`** | Evita que el recuperador vectorial devuelva siempre "lo menos malo" aunque no tenga relación con la consulta. |
| **El tutor no responde sin conocimiento** | Si la recuperación está vacía se lanza `ConocimientoNoEncontradoException` y no se llama al generador: se priorizan respuestas fundamentadas sobre respuestas inventadas. |
| **El contexto incluye `EstadoDominio` y `Recomendacion`** | La respuesta del tutor se adapta al nivel del estudiante (reforzar, practicar o profundizar). |
| **Dobles de prueba en lugar de servicios reales** | Las pruebas son deterministas, rápidas y no requieren red ni credenciales. |

---

## Estructura del proyecto

```text
lib/
├── main.dart
├── app/
│   └── app.dart
└── features/
    ├── academic/
    │   ├── domain/{entities,services}
    │   └── presentation/pages
    ├── adaptive_engine/domain/{entities,services}
    ├── assessment/domain/{entities,services}
    ├── enrollment/domain/{entities,services}
    ├── student_model/domain/{entities,services}
    └── tutor_rag/
        ├── domain/{entities,exceptions,repositories,services}
        └── infrastructure/repositories

test/
├── widget_test.dart
└── features/
    ├── academic/ …
    ├── adaptive_engine/ …
    ├── assessment/ …
    ├── enrollment/ …
    ├── student_model/ …
    └── tutor_rag/
        ├── domain/{entities,repositories,services}
        ├── infrastructure/repositories
        └── integration/tutor_rag_integration_test.dart
```

---

## Requisitos

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal estable) y Dart 3
- Git
- Node.js LTS (para Firebase CLI)
- Firebase CLI y FlutterFire CLI (para la integración con Firebase)

---

## Instalación

```powershell
git clone <url-del-repositorio>
cd academiapp_v2
flutter pub get
flutter run
```

---

## Configuración de Firebase

> La integración con Firebase está en proceso. El dominio ya está desacoplado mediante `RepositorioConocimiento`, por lo que Firebase entrará como una implementación más en `infrastructure`.

```powershell
# 1. Firebase CLI
npm install -g firebase-tools
firebase login

# 2. FlutterFire CLI
dart pub global activate flutterfire_cli

# 3. Desde la raíz del proyecto (donde está pubspec.yaml)
flutterfire configure
```

En Windows, si `flutterfire` no se reconoce, agrega `C:\Users\<usuario>\AppData\Local\Pub\Cache\bin` al `PATH` y reinicia VS Code.
Si PowerShell bloquea `firebase`, ejecuta una vez: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

---

## Pruebas y calidad

Antes de cada commit:

```powershell
dart format lib test
flutter analyze
flutter test
```

Criterio de aceptación: **`flutter analyze` sin problemas y todas las pruebas en verde.**

Las pruebas usan **dobles de prueba** (implementaciones falsas de los contratos) para verificar el dominio sin depender de servicios externos. La prueba de integración `tutor_rag_integration_test.dart` valida el flujo completo del tutor con el repositorio en memoria, incluido el caso en que no hay conocimiento relevante.

---

## Convención de commits

Se usa [Conventional Commits](https://www.conventionalcommits.org/es/):

```text
feat(tutor_rag): agregar similitud minima al recuperador vectorial
test(tutor_rag): verificar que el tutor no responde sin conocimiento relevante
refactor(tutor_rag): renombrar AlmacenVectorial a RepositorioConocimiento
fix(student_model): corregir orden de evidencias en BKT
```

Usa siempre `git commit -m "mensaje"` para evitar que se abra el editor (Vim). Si se abre, sal con `Esc` → `:q!` → `Enter`.

---

## Estado del proyecto

- [x] Planificación académica, matrícula y evaluación
- [x] Modelo del estudiante con BKT
- [x] Motor adaptativo de recomendaciones
- [x] Tutor RAG: recuperación textual y vectorial con umbral de similitud
- [x] Abstracción `RepositorioConocimiento` y repositorio en memoria
- [x] Prueba de integración del tutor RAG
- [ ] Repositorio de conocimiento en Firebase
- [ ] Generador de embeddings real
- [ ] Generador de respuestas con LLM
- [ ] Interfaz del tutor y de "Mi ruta"

---

## Autor

**Elvis Llampasi** — Universidad Nacional de San Cristóbal de Huamanga
