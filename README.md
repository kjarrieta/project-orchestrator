# project-orchestrator

Skill de orquestación que dirige un proyecto de software de inicio a fin coordinando un
**equipo de agentes senior** especializados, bajo una regla
innegociable: **no supone nada** y **nada con impacto se aplica sin aprobación humana**.
Cierra con un **Production Readiness Gate** (GO/NO-GO) y una **defensa anti-regresión en
profundidad** que hace cumplir lo ya documentado.

---

## Qué hace

El orquestador actúa como **director** de un equipo de agentes. El director no hace el
trabajo especializado: detecta el contexto real del proyecto, lanza a cada agente como
subagente con un encargo preciso, consolida sus hallazgos, y te presenta un plan para
que apruebes antes de tocar nada. Sirve para arrancar, auditar, sanear, refactorizar,
apificar o endurecer un proyecto, nuevo o existente.

La idea de fondo: **la calidad de un sistema multiagente no está en cuántos agentes
corren, sino en cuánta evidencia y coordinación los gobiernan.** Por eso cada
afirmación se apoya en código real (ruta:línea) y cada recomendación en documentación
oficial de la versión exacta detectada; si falta evidencia, el agente pregunta en vez
de inventar.

## El equipo de agentes

| Agente | Rol |
|---|---|
| **Retroalimentación** | Corre primero. Ingiere memorias previas del equipo y el registro de regresiones para aprovechar lo ya sabido y hacerlo cumplir. |
| **Arquitecto** | Arquitectura, huecos de flujo, redundancia, clean code, SOLID, servicios escalables y concurrencia. |
| **Revisor de Convenciones** | Convención de capas del stack e idioms del framework; anti-patrones de capa sin caer en over-engineering. |
| **Arquitecto de Desarrollo** | Robustez de ejecución: manejo de errores, transacciones con rollback, idempotencia, solapamiento de reglas/notificaciones. |
| **Base de Datos** | Integridad, optimización, relaciones, flujo de datos, aislamiento multi-tenant. |
| **APIs** | Consistencia de contratos en producción, errores RFC 9457, seguridad OWASP API, y apificación de apps nuevas. |
| **Integraciones y archivos** | S3, Drive, FTP/SFTP, terceros: resiliencia (backoff, timeouts, idempotencia), credenciales y archivos seguros. |
| **Frontend** | Flujo y diseño, políticas de UI, réplica de validación de BD en la vista, UX/UI y accesibilidad. |
| **SEO/GEO** | Solo web pública. URLs, SEO técnico y SEO para IA (crawlers, llms.txt, datos estructurados, contenido citable). |
| **Performance** | N+1, consumo de memoria sobre datasets grandes, jobs (timeout/idempotencia/batching). Mide antes y después. |
| **Observabilidad/SRE** | "¿Cómo sabemos que esto falló?": logs con contexto sin PII, métricas, alertas accionables, health checks. |
| **Production/DevOps** | "¿Puedo desplegar un viernes?": migraciones backward-compatible, expand-contract, rollback, jobs viejos en el nuevo deploy. |
| **Business Rules Auditor** | Matriz regla→fuente→implementación→test; detecta reglas de negocio no implementadas; matriz de cobertura. |
| **QA Senior** | Sin autocomplacencia: pruebas de lógica, caja negra y blanca contra políticas y reglas de negocio; detecta conflictos de reglas. |
| **Seguridad** | Inyecciones, OWASP, pentest defensivo del propio proyecto, dueño del veredicto de aislamiento de tenants y de los hard_gates. |
| **Red Team / Audit Lead** | Meta-audita la auditoría: reconcilia contradicciones, caza PASS sin evidencia y puede anular un PASS antes del gate. |
| **Documentación** | Automático. Doc viva módulo por módulo, registro de reglas de negocio y mapa de impacto, cierre documentado de cada desarrollo. |
| **Aprendiz** | Automático. Destila aprendizajes en políticas y memoria global; promueve regresiones al registro y las materializa (lint/test). |

## Flujo de ejecución

```
Fase R  Retroalimentación  → ingerir memorias previas + registro de regresiones (solo lectura)
Fase 0  Intake             → detectar stack, versiones, multi-tenant, estado Capa A; poblar memoria
Fase 1  Auditoría          → agentes en paralelo, SOLO LECTURA (3 ejes por hallazgo)
Fase 2  Consolidación      → unificar hallazgos y detectar conflictos
Fase 2.5 Cross/Meta-Audit  → Red Team reconcilia y puede anular un PASS
Fase 3  Compuerta          → emitir Production Gate GO/NO-GO; aprobar el plan (nada se aplica sin esto)
Fase 4  Aplicación         → en secuencia, sobre una rama, commits atómicos; checklist de política por ruta
Fase 5  Verificación       → QA y Seguridad validan + exigen el test/lint de cada regresión tocada
```

Cada fase tiene un **bucle de validación**: si la salida de un agente no trae
evidencia o se sale de su alcance, se reintenta una vez y, si sigue mal, se registra
como hueco en vez de avanzar a ciegas.

## Instalación

1. Copia la carpeta de la skill a `~/.claude/skills/project-orchestrator/` (para todos
   tus proyectos) o a `<repo>/.claude/skills/project-orchestrator/` (solo ese repo).
2. La primera vez que corras, la skill **se instala sola** (bootstrap): genera los
   subagentes en `.claude/agents/` desde sus briefs y **propone** los hooks de
   automatización para que los apruebes. No hay que crearlos a mano. Detalle en
   `references/setup.md`.

## Cómo usarla

El punto de entrada recomendado es el comando `/orchestrator` (incluido en
`commands/orchestrator.md`; cópialo a `~/.claude/commands/`). El mapa completo de
modos está en `COMMANDS.md`:

```
/orchestrator                    flujo completo hasta la compuerta
/orchestrator auditar <alcance>  auditoría acotada, solo lectura
/orchestrator aplicar            aplica el plan aprobado (Fases 4-5)
/orchestrator nuevo              entrevista greenfield + propuesta de stack
/orchestrator verificar          solo Fase 5
/orchestrator estado             resume .orchestrator/ sin lanzar agentes
/orchestrator setup              solo bootstrap
/orchestrator cerrar             Documentación + Aprendiz
```

Comandos compañeros: `/setup-project` (config inicial de plugins por proyecto) y
`/sync-capabilities` (auditar plugins nuevos y actualizar el mapa de capacidades).

También funciona en lenguaje natural:

- **Proyecto existente:** «Corre el orquestador de proyecto en modo auditoría sobre
  este repo». Ingiere memorias, detecta contexto, audita en paralelo y te presenta el
  plan en la compuerta.
- **Proyecto nuevo:** «Quiero arrancar un proyecto nuevo con el orquestador». Dispara
  una entrevista de arquitecto senior antes de proponer stack y diseño.

Empieza siempre por una **corrida de solo auditoría**: no toca nada y te devuelve
informes con evidencia para que veas cómo razona antes de darle permiso de escritura.

## Sistema de memoria

- **Memoria de proyecto** (`.orchestrator/project-memory/`, versionada con el repo):
  arquitectura, módulos, reglas de negocio, contratos. Se puebla en la Fase 0 y se lee
  en corridas siguientes para no redescubrir todo.
- **Corridas incrementales**: `.orchestrator/state.json` guarda el commit y los hashes
  de la última corrida; si existe, la documentación NO se regenera — solo se
  actualizan las secciones afectadas por el delta de git. Cero re-trabajo, cero
  tokens re-gastados.
- **Memoria global por lenguaje** (`~/.claude/project-orchestrator/memory/<lenguaje>/`):
  patrones, footguns y buenas prácticas del lenguaje/framework, por dominio, que
  escalan a los próximos proyectos. Ver `references/language-memory.md`.
- **Retroalimentación** ingiere al inicio lo que ya existe; **Aprendiz** destila al
  final lo nuevo. Nada se vuelve canónico sin la compuerta.

## Salida

Todo el trabajo vive en `.orchestrator/` (ficha de hechos, memoria de proyecto,
informes de auditoría, plan consolidado, bitácoras de aplicación, contratos de API,
verificación con la prueba de aislamiento de tenants, aprendizajes, y corridas
anteriores archivadas).

## Seguridad y buenas prácticas

- **Compuerta humana**: ningún cambio con impacto se aplica sin tu aprobación.
- **Agentes de auditoría sin escritura**: nacen con `Read, Grep, Glob`; solo reciben
  escritura en la fase de aplicación y acotada a su alcance.
- **Hooks = código**: se ejecutan con tus privilegios, así que se proponen y se
  escriben solo con tu visto bueno; revísalos como cualquier código.
- **Aplicación sobre rama** con commits atómicos y plan de reversa; los cambios
  irreversibles (migraciones destructivas) se separan y se aprueban aparte.
- **Selección de equipo**: no se lanza todo el equipo por defecto; el director escoge los
  agentes que el pedido necesita y justifica los que omite.
- **Capacidades por tarea**: los plugins y skills del entorno se activan solo por
  proyecto y con tarea que lo justifique (`references/capabilities.md`); un agente
  delega en la herramienta instalada en vez de reinventarla.
- **Nada sensible** cruza a la memoria global (ni secretos, ni datos de cliente).

## Guardarraíles

La skill está diseñada **contra** los antipatrones del multiagente descontrolado: no
se refactoriza por estética, no se hace pasar un test falseándolo, no se actualiza una
dependencia por moda, y no se despliega solo. La regla completa está en
`references/evidence-protocol.md`, que todos los agentes leen antes de trabajar.

## Estructura de la skill

```
project-orchestrator/
├── SKILL.md                    (el orquestador / director)
├── README.md                   (este archivo)
├── COMMANDS.md                 (mapa de comandos y flujos típicos)
├── commands/
│   └── orchestrator.md         (comando /orchestrator — copiar a ~/.claude/commands/)
└── references/
    ├── evidence-protocol.md    (la ley común: evidencia, 3 ejes, guardarraíles, concisión)
    ├── modes.md                (modos de operación: DISCOVER/ARCHITECT/IMPLEMENT/.../AUDIT/HARDEN)
    ├── routing.md              (enrutamiento: descomposición, incertidumbre, don't-delegate, tools)
    ├── capability-registry.md  (registro capacidad→agente: núcleo/condicional/meta)
    ├── knowledge-system.md     (Facts/Knowledge/Memory/Learnings, jerarquía L0–L6, versión, caducidad)
    ├── decision-ledger.md      (ADR + "why not": decisiones y descartes que no se re-litigan)
    ├── risk-levels.md          (aprobación graduada R0–R4)
    ├── setup.md                (instalación automática)
    ├── capabilities.md         (selección de plugins/skills del entorno por tarea)
    ├── anti-regression.md      (defensa anti-regresión en 4 capas — solución de raíz)
    ├── regression-ledger.md    (registro de regresiones e invariantes: backbone)
    ├── production-gate.md      (Production Readiness Gate GO/NO-GO: criterio de decisión)
    ├── feedback.md             (Retroalimentación)
    ├── architect.md            (Arquitecto)
    ├── conventions-reviewer.md (Revisor de Convenciones del Stack)
    ├── robustness.md           (Arquitecto de Desarrollo)
    ├── database.md             (Base de Datos)
    ├── api.md                  (APIs)
    ├── integrations.md         (Integraciones y archivos)
    ├── frontend.md             (Frontend)
    ├── seo.md                  (SEO/GEO)
    ├── performance.md          (Performance Engineer)
    ├── sre.md                  (Observabilidad/SRE del proyecto)
    ├── devops.md               (Production/DevOps)
    ├── business-rules.md       (Business Rules Auditor + matriz de cobertura)
    ├── qa.md                   (QA Senior)
    ├── security.md             (Seguridad)
    ├── red-team.md             (Red Team / Audit Lead — meta-auditoría)
    ├── documentation.md        (Documentación)
    ├── learner.md              (Aprendiz)
    ├── language-memory.md      (memoria global por lenguaje)
    ├── automation-hooks.md     (hooks y subagentes)
    └── observability.md        (trazabilidad y sensores del flujo agéntico)
```
