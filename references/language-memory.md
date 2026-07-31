# Memoria de aprendizaje por lenguaje

El aprendizaje sirve de verdad cuando **escala**: lo que un proyecto enseña sobre un
lenguaje debe estar disponible para el siguiente. Para eso hay dos niveles de
memoria, y una frontera estricta entre ellos. Léelo junto con `evidence-protocol.md`.

## Tres niveles

- **Memoria de proyecto** — vive con el repositorio (`CLAUDE.md`, reglas en
  `.claude/`, `docs/adr/`). Contiene lo específico de *este* proyecto: sus reglas de
  negocio, sus convenciones, sus decisiones. No viaja a otros proyectos.
- **Memoria global por lenguaje y versión** — vive en el ámbito de usuario, fuera de
  cualquier repositorio: `~/.claude/project-orchestrator/memory/<lenguaje>/`.
  Contiene lo que es cierto del **lenguaje o framework en sí**, siempre acotado a
  versión: lo que vale en Laravel 12 puede ser un error en Laravel 10.
- **Memoria universal** — `~/.claude/project-orchestrator/memory/global/practices.md`.
  Buenas prácticas de desarrollo **independientes del lenguaje**: disciplina de
  pruebas, principios de seguridad, manejo de procesos/flujos, optimización de
  trabajo agéntico y de tokens. Solo entra lo que sería igual de cierto en PHP, Java
  o TypeScript; si mencionar el lenguaje cambia la entrada, no es universal — va al
  nivel de lenguaje.

La memoria global **respeta la misma decomposición en dominios que los agentes**: una
carpeta por lenguaje, y dentro un archivo por dominio, no un archivo plano. Así un
footgun de concurrencia no se mezcla con un patrón de UI, y cada agente lee y alimenta
solo su parcela:

```
~/.claude/project-orchestrator/memory/
├── global/
│   └── practices.md         (universal: prácticas independientes del lenguaje)
├── php/
│   ├── architecture.md      (alimenta y lee el Arquitecto)
│   ├── database.md          (Base de Datos)
│   ├── api.md               (APIs)
│   ├── integrations.md      (Integraciones)
│   └── security.md          (Seguridad)
├── java/
│   └── ... (mismos dominios)
└── typescript/
    ├── frontend.md          (Frontend)
    └── ...
```

Crea solo los archivos de dominio que tengan aprendizajes. Dentro de cada archivo,
**secciones por framework y rango de versión explícito** (`## Laravel 12`, `## PHP
8.2–8.4`, `## Spring Boot 3.x`) — nunca una sección "Laravel" a secas. Una entrada
que cambia entre versiones se duplica por sección con su diferencia, y la superada
se marca enlazando a la vigente.

## La frontera: qué se promueve a global y qué no

Esta es la regla que protege la escalabilidad. Un aprendizaje sube a la memoria
global **solo si generaliza más allá de este proyecto**:

- **Sí sube**: un idiom del lenguaje/framework, un footgun conocido, una buena
  práctica confirmada contra **documentación oficial**, un patrón de bug reproducible
  cuya causa está en el lenguaje/framework (no en el negocio) con su forma correcta de
  evitarlo.
- **No sube (se queda en el proyecto)**: reglas de negocio, nombres de dominio,
  decisiones propias de esta arquitectura, cualquier cosa atada a *este* cliente o
  *este* esquema. Si la lección solo tiene sentido dentro del proyecto, es memoria de
  proyecto, no global.

Regla práctica: si no puedes respaldar la entrada con una cita a la doc oficial del
lenguaje/framework **o** con un patrón de bug reproducible fuera de este proyecto, no
es global todavía.

## Formato de una entrada global

Cada entrada es autocontenida y trazable:

```
### <título corto del patrón o footgun>
- Categoría: buena-práctica | footgun | patrón-de-bug | seguridad | idiom
- Aplica a: <lenguaje/framework> <rango de versiones> (p. ej. Laravel 10–11)
- Qué: <la práctica o el patrón, en una o dos líneas>
- Por qué: <cita a doc oficial (URL + versión) | causa raíz del bug>
- Cómo se detectó: <procedencia: "surgió en un proyecto <stack>", SIN nombres de
  cliente, SIN secretos, SIN datos del proyecto>
```

## Reglas de escritura (no negociables)

- **Nada sensible.** La memoria global cruza proyectos y clientes: jamás incluye
  secretos, credenciales, datos de negocio, nombres de cliente ni fragmentos
  identificables de código propietario. Solo el patrón, en abstracto.
- **Versiona el contexto.** Una práctica correcta en una versión puede ser errónea en
  otra. Cada entrada dice a qué versiones aplica. Nunca escribas una entrada "para el
  lenguaje" sin acotar versión.
- **Deduplica y reemplaza, no acumules.** Antes de anexar, busca si el patrón ya
  existe. Si un aprendizaje nuevo **contradice** uno viejo (una práctica se deprecó en
  una versión nueva), no dejes los dos: marca el viejo como superado, enlaza al nuevo
  y deja el porqué. La memoria es un log curado, no un vertedero.
- **Conservador por diseño.** Ante la duda, se queda en el proyecto. Una entrada
  global mala se replica a todos los proyectos futuros: el costo de un falso positivo
  es alto, así que el umbral para promover es alto.

## Cómo se consume (cierra el ciclo)

- **Al escribir (fin de sesión):** el agente Aprendiz coordina, pero **cada agente
  especialista propone las entradas de su propio dominio** (el Arquitecto las de
  `architecture.md`, BD las de `database.md`, etc.), según la frontera de arriba. No
  se escribe sin aprobación: una lección global es demasiado influyente para colarse
  sin compuerta.
- **Al leer (orquestador, Fase 0):** tras detectar el stack y las versiones, carga los
  archivos de dominio relevantes de los lenguajes detectados y se los entrega a cada
  agente, **revalidados contra la versión exacta del proyecto actual** — un idiom de
  una versión anterior no se aplica a ciegas. Así cada proyecto arranca ya primado con
  el criterio acumulado, y ese criterio crece con cada proyecto.
