# Registro de capacidades → agentes

Este registro es **datos**, no algoritmo. El algoritmo (cómo se decide qué capacidad se
necesita) vive en `routing.md`; aquí solo está el mapa de qué capacidad provee qué
agente, y en qué nivel vive. Piensa en capacidades primero, en agentes después: así el
roster puede crecer sin que la lógica de orquestación cambie.

> No confundir con `capabilities.md`: ese gobierna las **capacidades del entorno**
> (plugins, skills nativas, comandos externos). Este gobierna las **capacidades de los
> agentes** del equipo. Un agente puede, además, delegar en una capacidad del entorno
> (p. ej. BD delega en el plugin `claude-db`).

## Por qué capacidades y no "N agentes"

No debe importar cuántos agentes existen en el catálogo. Debe importar qué capacidades
requiere la tarea. Con 14 agentes hoy o 50 mañana, el orquestador pide una capacidad y
el registro resuelve quién la provee. Esto elimina el anti-patrón de "doce agentes" como
concepto central: el número de agentes es un detalle de implementación, no una promesa
de la skill.

## Tres niveles

```
Agent Registry
├── Núcleo        → capacidades que casi toda corrida no trivial toca
├── Condicional   → capacidades que solo entran si una subtarea las pide
└── Meta          → capacidades que auditan a los demás agentes
```

### Núcleo (pequeño por diseño)

El verdadero core es reducido. Todo lo demás es dinámico.

| Capacidad | Agente que la provee | Brief |
|---|---|---|
| `orchestration` | Orquestador (el director) | `SKILL.md` |
| `architecture` | Arquitecto | `architect.md` |
| `verification` / `qa` | QA Senior | `qa.md` |
| `security` | Seguridad | `security.md` |
| `knowledge` / `evidence` | Retroalimentación + protocolo | `feedback.md`, `evidence-protocol.md`, `knowledge-system.md` |

### Condicional (entra solo bajo demanda)

Ninguna se activa "por si acaso". Se activa cuando una subtarea de la corrida la
requiere (ver `routing.md`, resolución de capacidades).

| Capacidad | Agente | Brief | Se activa cuando |
|---|---|---|---|
| `conventions` | Revisor de Convenciones | `conventions-reviewer.md` | hay código que aplicar/revisar |
| `database` | Base de Datos | `database.md` | el pedido toca esquema, datos o consultas |
| `robustness` | Arquitecto de Desarrollo | `robustness.md` | hay transacciones, errores, idempotencia en juego |
| `api` | APIs | `api.md` | hay contratos de API o apificación |
| `integration` | Integraciones | `integrations.md` | hay terceros, archivos, colas externas |
| `frontend` | Frontend | `frontend.md` | hay UI (web/móvil/desktop/CLI con vista) |
| `systems-architecture` | Arquitecto (capacidad extendida) | `architect.md` | microservicios, event-driven, distribuido, colas, consistencia, multi-región |
| `performance` | Performance | `performance.md` | hay N+1, datasets grandes, jobs, latencia medida |
| `observability` / `sre` | Observabilidad/SRE | `sre.md` | operabilidad, logs, métricas, alertas |
| `devops` / `migration-safety` | Production/DevOps | `devops.md` | migraciones, deploy, reversa |
| `business-rules` | Business Rules Auditor | `business-rules.md` | hay reglas de negocio que trazar a implementación |
| `public-web` → `seo` → `geo` | SEO/GEO | `seo.md` | y **solo si** el proyecto tiene web pública indexable |

### Meta

| Capacidad | Agente | Brief |
|---|---|---|
| `meta-audit` / `red-team` | Red Team / Audit Lead | `red-team.md` |

### Automáticos (alrededor del ciclo)

| Capacidad | Agente | Brief | Disparo |
|---|---|---|---|
| `documentation` | Documentación | `documentation.md` | hook al editar código |
| `learning` | Aprendiz | `learner.md` | hook al cerrar sesión |

## Capacidades de dominio (fuera del core)

Algunas capacidades son demasiado específicas para vivir en el núcleo y se modelan como
**capacidades de dominio** anidadas, que solo se resuelven si el proyecto entra en ese
dominio:

```
public_web
  └── seo
        └── geo

ui
  ├── frontend (web)
  ├── mobile
  ├── desktop
  ├── embedded
  └── cli
```

No todo proyecto tiene UI, y no toda UI es web. SEO/GEO no es del core: es una hoja del
dominio `public_web`. Modelarlo así evita que la skill "se sienta construida alrededor
de un proyecto concreto".

## Cómo lo usa el orquestador

1. `routing.md` descompone la tarea y produce la lista de capacidades requeridas.
2. Para cada capacidad, este registro resuelve el agente y su brief.
3. El director activa **solo** esos agentes; el resto se omite con justificación en
   `00-ficha-de-hechos.md`.
4. La capacidad `systems-architecture` no agrega un agente permanente: el Arquitecto la
   activa cuando el problema es distribuido. Misma idea para toda capacidad extendida —
   preferimos extender un agente del core a crear uno nuevo permanente.

## Regla final

Añadir una capacidad al registro es barato; añadir un agente permanente al core es caro
(descripciones que se cargan siempre, un rol más que justificar). Ante la duda, modela
lo nuevo como capacidad condicional o como extensión de un agente del core, no como un
agente permanente más.
