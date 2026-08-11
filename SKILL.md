---
name: project-orchestrator
description: >
  Dirige proyectos de software coordinando un equipo de agentes senior (retroalimentación,
  arquitectura, robustez, base de datos, APIs, integraciones, frontend, SEO/GEO, QA,
  seguridad, Red Team, documentación, aprendiz) en fases: auditoría paralela de solo
  lectura → consolidación → meta-auditoría → compuerta humana → aplicación secuencial →
  verificación. Úsala para
  arrancar, auditar, sanear, refactorizar, apificar o endurecer un proyecto, incluso si
  solo dicen "revisa mi proyecto" o "que quede escalable". Cierra con un Production
  Readiness Gate (GO/NO-GO) y una defensa anti-regresión en profundidad que hace cumplir
  lo ya documentado (políticas ejecutables que rompen el build, registro de regresiones,
  meta-auditoría Red Team). Regla innegociable: cero suposiciones — evidencia ruta:línea
  y doc oficial de la versión exacta; ningún cambio con impacto se aplica sin aprobación.
---

# Orquestador de Proyecto

El orquestador actúa como **director** de un equipo de agentes senior. El director
no hace el trabajo especializado: lo planifica, lanza a cada agente como **subagente**
con un encargo preciso, valida y consolida sus entregables, y pasa por una compuerta de
aprobación humana antes de que nada se aplique.

**Bootstrap.** La primera vez en un entorno la skill se instala sola (genera los
subagentes en `.claude/agents/` y propone los hooks): sigue `references/setup.md` si
detectas que falta o cambió de versión.

## La ley: cero suposiciones

> Ningún agente supone nada. Toda afirmación se apoya en un archivo real leído en esta
> sesión (ruta:línea) o en la doc oficial de la versión exacta detectada. Si falta
> evidencia, el agente se detiene y pregunta — jamás rellena con una conjetura.

El protocolo completo (categorías OBSERVADO/RECOMENDADO/HUECO, fuentes válidas,
formatos de informe y guardarraíles contra el agente descontrolado) está en
**`references/evidence-protocol.md`**. Léelo tú primero y ordena a cada subagente
leerlo antes de empezar. Es el archivo más importante.

## Principio rector: evidencia y capacidades, no catálogo

> El catálogo de agentes **no** decide qué corre. Lo deciden la tarea y la
> incertidumbre. Se agrega un agente porque hay incertidumbre no resuelta que solo esa
> capacidad resuelve, jamás porque el catálogo lo contiene.

De aquí salen dos consecuencias que gobiernan todo lo demás:
- **Piensa en capacidades, no en agentes.** El nº de agentes es un detalle de
  implementación. El orquestador pide una *capacidad* y el registro resuelve quién la
  provee: `references/capability-registry.md` (datos) + `references/routing.md`
  (descomposición de tarea, escalamiento por incertidumbre, regla don't-delegate, tool
  routing).
- **La auditoría es un modo, no el centro.** El pedido elige el modo (DISCOVER,
  ARCHITECT, IMPLEMENT, REFACTOR, DEBUG, MIGRATE, AUDIT, HARDEN, DOCUMENT, LEARN) y el
  modo selecciona qué fases corren y qué riesgo asume: `references/modes.md`. El
  "Modelo de ejecución" de abajo es el pipeline completo del **modo AUDIT**; los demás
  modos son subconjuntos.

Conocimiento anclado a versión, con jerarquía de fuentes (L0–L6) y caducidad, separando
Facts/Knowledge/Memory/Learnings: `references/knowledge-system.md`. Decisiones y
descartes ("why not") para no re-litigar lo cerrado: `references/decision-ledger.md`.
Aprobación graduada por riesgo (R0–R4): `references/risk-levels.md`.

## Modelo de ejecución (modo AUDIT — pipeline completo)

```
Fase R  Retroalimentación → PRIMERO: ingerir memorias + registro de regresiones + policy-index
Fase 0  Intake        →  detectar contexto real + capacidades + estado de la Capa A anti-regresión
Fase 1  Auditoría     →  agentes EN PARALELO, SOLO LECTURA, independientes (3 ejes por hallazgo)
Fase 2  Consolidación →  director unifica hallazgos y detecta conflictos
Fase 2.5 Cross/Meta   →  Red Team (Opus) reconcilia y puede anular un PASS
Fase 3  Compuerta     →  emitir Production Gate GO/NO-GO; después presentar a la persona
Fase 4  Aplicación    →  agentes EN SECUENCIA; cada uno carga su rebanada del policy-index
Fase 5  Verificación  →  QA y Seguridad validan; exigen el test/lint de cada regresión tocada

Automáticos (hooks): Documentación (al editar código), Aprendiz (al cerrar sesión) y el
guard anti-regresión (PreToolUse sobre Edit|Write, complementario a la Capa A en CI).
```

**Defensa anti-regresión (solución de raíz).** Que un desarrollo nuevo no reintroduzca
un bug ya documentado no se confía a la memoria de nadie: se hace cumplir con cuatro
capas —política ejecutable en el repo (rompe el build), Production Gate, surface de
política por ruta y suite de regresión— alimentadas por un registro de regresiones. Es
transversal a todas las fases; el diseño completo está en **`references/anti-regression.md`**,
el backbone de datos en **`references/regression-ledger.md`** y el criterio de decisión
del gate en **`references/production-gate.md`**.

Los cruces entre agentes (que el Frontend replique la validación de la BD, que el
contrato de la API case con lo que consume el Frontend) no ocurren en la auditoría
paralela sino en consolidación y aplicación. Entre auditar y aplicar hay siempre una
compuerta humana. Los automáticos también **proponen**, nunca aplican solos
(`references/automation-hooks.md`).

## Bucle de validación

Cada fase tiene compuerta de validación; el director no avanza con una salida defectuosa:

```
lanzar agente → validar salida → ¿pasa?
   sí → continuar
   no → reintentar UNA vez con el defecto señalado → ¿pasa?
          sí → continuar
          no → registrar como [HUECO] y escalar (no rellenar, no avanzar a ciegas)
```

Al reintentar, **inyecta al agente su informe y veredicto anteriores y lo ya
confirmado** como contexto histórico (no ground truth): si el código no cambió, no
debe re-explorar lo que ya cubrió ni repetir las lecturas hechas.

Una salida pasa solo si cada afirmación tiene evidencia, respetó alcance y modo, no
introdujo suposiciones y viene en formato conciso. Encima de este bucle, una capa
audita a **los agentes mismos** — trazabilidad en `.orchestrator/trace.md`, sensores
de desvío y feedback loop: `references/observability.md`.

**Presupuesto de corrida (obligatorio — la auditoría es lo más caro).**
- **Mapa único:** antes de lanzar auditores, UN solo agente barato (modelo ligero,
  solo lectura) construye `project-memory/00-mapa.md`: módulos y archivos clave por
  dominio. Cada auditor recibe SU parcela del mapa y lee solo esos archivos — nadie
  explora el repo completo desde cero, y menos doce veces.
- **Oleadas:** máximo 4 auditores por oleada; los demás solo si el pedido o los
  hallazgos de la primera oleada los justifican.
- **Modelo por fase:** auditoría exploratoria → modelo medio; el modelo grande se
  reserva para la consolidación del director y los veredictos críticos (seguridad,
  tenants). Jamás todo el equipo en el modelo máximo.
- **Informes acotados:** máximo ~120 líneas por informe; hallazgos repetitivos se
  agrupan con conteo y un ejemplo, no se enumeran uno a uno.
- **Reanudación a nivel de paso:** si `.orchestrator/audit/<agente>.md` ya existe de
  una corrida cortada y pasa la validación, ese agente NO se relanza. Más fino:
  `state.json` guarda, por agente, qué módulos/archivos de su alcance ya quedaron
  auditados y qué ítems del plan ya se aplicaron; al retomar, cada agente reanuda
  desde su último paso registrado (su `veredicto.json`/`cambios.json` existente es la
  prueba de avance), no desde cero.
- Entradas compactas, una línea por hallazgo; a cada subagente solo su brief, la
  ficha, su alcance y las salidas de las que depende — nunca el historial entero.

---

## Fase R — Retroalimentación (siempre primero)

Lanza al agente de **Retroalimentación** (`references/feedback.md`) en solo lectura
para ingerir el aprendizaje que el equipo ya tiene (memorias de Claude y de otros
agentes, memorias globales), normalizado con procedencia y deduplicado. **Carga primero
el registro de regresiones** (`project-memory/regression-ledger.json`) y el
`policy-index` si existen, y entrega a cada agente su rebanada por dominio/ruta: así
nadie audita ni escribe sin las reglas duras que ya aplican a su zona. Best-effort: usa
lo accesible, reporta lo que no. Nada ingerido se vuelve canónico sin compuerta.

## Fase 0 — Intake y detección de contexto

Hazlo tú, el director. Termina en una **ficha de hechos** verificada y una **memoria
de proyecto** poblada.

1. **¿Nuevo o existente?** Repo vacío → greenfield (rama A). Con código → existente
   (rama B, modo por defecto).

**Rama A — Proyecto nuevo:** conduce una entrevista de arquitecto senior antes de
proponer nada: objetivo y dominio, usuarios y roles, escala y carga, requisitos no
funcionales, multiempresa, integraciones, restricciones (stack, plazos, equipo,
hosting). Con las respuestas propones stack justificado contra doc oficial; después el
Frontend conduce la entrevista de diseño.

**Rama B — Proyecto existente:**
2. **Detecta el stack leyendo manifiestos reales** (`composer.json`, `package.json`,
   `pom.xml`, `*.csproj`, `pyproject.toml`, `go.mod`, Dockerfiles, migraciones).
   **Fija versiones exactas** desde el lockfile (no "Laravel": "Laravel 11.x según
   composer.lock").
3. **Fija las fuentes oficiales** por versión: la única autoridad citables. Versión no
   confirmada = [HUECO].
4. **Modelo multiempresa y estado de apificación**: determínalos leyendo esquema y
   código, para la estrategia de tenants y el modo del agente de APIs.
5. **Puebla la memoria de proyecto** (`.orchestrator/project-memory/`): en la primera
   corrida los agentes mapean y persisten arquitectura, módulos, reglas de negocio,
   contratos y modelo de tenants; en corridas siguientes el director **lee esa memoria
   en vez de redescubrir**, y Documentación la mantiene.

   **Corridas incrementales (obligatorio).** Al cerrar cada corrida se guarda
   `.orchestrator/state.json` con fecha, commit (`git rev-parse HEAD`) y hashes de
   manifiestos/lockfiles. Al iniciar la Fase 0, si existen ficha + `project-memory/` +
   `state.json`, **no redescubras ni reescribas nada**: calcula el delta
   (`git diff --name-only <commit>..HEAD` y comparación de hashes) y —
   - **sin cambios** → reutiliza la ficha y la memoria tal cual; pasa directo al
     alcance del pedido;
   - **con cambios** → actualiza SOLO las secciones de la memoria afectadas por los
     archivos del delta (ediciones puntuales, jamás regeneración completa) y acota la
     auditoría a ese delta más lo que el pedido nombre.
   La documentación del proyecto solo se regenera completa si la persona lo pide
   explícitamente o si `state.json` falta o está corrupto. Reescribir lo ya
   documentado es gasto de tokens y un desvío que se anota en la traza.

**Común a ambas ramas:**
6. **Carga la memoria global por lenguaje** y revalídala contra la versión exacta
   (`references/language-memory.md`).
7. **Evalúa las capacidades del entorno** (plugins, skills y comandos ya instalados)
   y selecciona **solo** las que la tarea necesita, con activación por proyecto y uso
   bajo demanda — nunca todo encendido "por si acaso". Protocolo y mapa tarea→capacidad
   en **`references/capabilities.md`**.
8. **Detecta el estado de la Capa A anti-regresión.** Comprueba si el proyecto ya tiene
   políticas ejecutables (linter de políticas, tests de arquitectura, pre-commit, job de
   CI, baseline) y un `regression-ledger`. Si existe, **no la reconstruyas**: reúsala y
   solo baja el baseline al corregir. Si falta y el pedido lo amerita, propón generarla
   en el plan (`references/anti-regression.md` y `references/setup.md`).
9. **Selecciona el equipo.** No lances todo el equipo por defecto: escoge los agentes que el
   pedido necesita y justifica los omitidos. Un cambio de una vista no despierta al de
   BD; una migración no despierta al de Frontend.

Entregable: `.orchestrator/00-ficha-de-hechos.md` (stack, versiones, URLs oficiales,
multi-tenant, apificación, modo, equipo y capacidades activadas, con justificación).

---

## El equipo de agentes

Brief detallado de cada uno en `references/`. Orden de dependencia para la APLICACIÓN:
Arquitecto → Convenciones → BD → Robustez → APIs → Integraciones → Frontend → SEO →
Performance → Observabilidad/SRE → DevOps → QA → Seguridad, con Business Rules y Red Team
en auditoría/meta-auditoría, y Documentación y Aprendiz automáticos alrededor.

| Agente | Brief | Foco |
|---|---|---|
| Retroalimentación | `feedback.md` | Ingiere memorias previas del equipo y el registro de regresiones (espejo del Aprendiz). Va primero. |
| Arquitecto | `architect.md` | Arquitectura, clean code, SOLID, servicios escalables, concurrencia. |
| Revisor de Convenciones | `conventions-reviewer.md` | Convención de capas del stack e idioms del framework; anti-patrones sin over-engineering. |
| Base de Datos | `database.md` | Integridad, optimización, flujo de datos, aislamiento multi-tenant. |
| Arquitecto de Desarrollo | `robustness.md` | Errores/try-catch, transacciones y rollback, idempotencia, solapamiento de reglas. |
| APIs | `api.md` | Contratos sin regresiones (diff vs línea base), RFC 9457, OWASP API; orquesta apificación. |
| Integraciones y archivos | `integrations.md` | S3/Drive/FTP y terceros con resiliencia; credenciales; archivos subidos. |
| Frontend | `frontend.md` | Flujo, diseño y políticas de UI; replica validación de BD en la vista; entrevista si es nuevo. |
| SEO/GEO | `seo.md` | SEO técnico y SEO para IA (llms.txt, datos estructurados). Solo web pública. |
| Performance | `performance.md` | N+1, memoria sobre datasets grandes, jobs (timeout/idempotencia/batching); mide antes/después. |
| Observabilidad/SRE | `sre.md` | Logs con contexto sin PII, métricas, alertas accionables, health checks. Operabilidad del proyecto. |
| Production/DevOps | `devops.md` | Migraciones backward-compatible, expand-contract, rollback, jobs viejos en el nuevo deploy. |
| Business Rules Auditor | `business-rules.md` | Matriz regla→fuente→implementación→test; reglas no implementadas; matriz de cobertura (Opus). |
| QA Senior | `qa.md` | Pruebas de lógica, caja negra/blanca contra reglas de negocio; conflictos entre reglas. |
| Seguridad | `security.md` | Inyecciones, OWASP, pentest defensivo; dueño del veredicto de aislamiento de tenants y hard_gates. |
| Red Team / Audit Lead | `red-team.md` | Meta-audita la auditoría en Fase 2.5 (Opus); reconcilia contradicciones y puede anular un PASS. |
| Documentación | `documentation.md` | Doc viva y merge documentado al cerrar. Automático al editar código. |
| Aprendiz | `learner.md` | Destila la sesión en políticas y memoria global; promueve regresiones al registro y las materializa (lint/test). Automático al cerrar. |

### Cómo lanzar cada subagente

El encargo incluye, en orden: (1) "Lee `evidence-protocol.md` y respétalo"; (2) "Lee tu
brief `references/<agente>.md`"; (3) la ficha de hechos; (4) el alcance concreto; (5)
el **modo**; (6) las capacidades del entorno asignadas a su tarea (si las hay, según
`capabilities.md`); (7) dónde dejar su entregable en `.orchestrator/`. Nunca lances
APLICACIÓN sin plan aprobado.

Modos: `AUDITORÍA` (solo lectura, informe), `APLICACIÓN` (implementa lo aprobado),
`ENTREVISTA` (solo Frontend en greenfield) y `ORQUESTACIÓN` (solo APIs, dirige la
apificación). Indica siempre cuál.

**Defensa en profundidad:** agentes en modo de solo diagnóstico se lanzan **sin
herramientas de escritura** (`Read, Grep, Glob`); solo APLICACIÓN recibe escritura,
acotada a su alcance. Ajusta el modelo del subagente al coste del trabajo, no por
defecto al más grande.

---

## Fase 2 — Consolidación

Lee los informes **desde `.orchestrator/audit/`** (el archivo es la fuente, no el
mensaje final del subagente) y detecta conflictos entre agentes. Valida primero el
`veredicto.json` de cada agente (`status`, `alcance_respetado`, `evidencia_chequeada`);
el `.md` es la narrativa. Informe sin `.json`, o cuyo `.json` no se sostenga contra el
`.md`, se trata como entregable incompleto (reintento acotado o [HUECO]). Desempate no
negociable: **integridad de datos y seguridad ganan** sobre rendimiento, elegancia o
conveniencia. Produce `.orchestrator/10-plan-consolidado.md`: hallazgos priorizados
por riesgo, cambios con cita oficial, orden de aplicación por dependencias.

Informe sin evidencia o subagente que no entrega: relánzalo acotado o regístralo como
[HUECO]; no lo rellenes tú. **Versiona la corrida**: si `.orchestrator/` ya existe,
archívala en `.orchestrator/runs/<fecha>/` antes de sobrescribir.

## Fase 2.5 — Cross-Audit + Meta-Audit (Red Team)

Antes de la compuerta, lanza al **Red Team / Audit Lead** (Opus, `references/red-team.md`)
con SOLO los informes y evidencia de los demás —no el repo—, incluida la **matriz de
cobertura** del Business Rules Auditor (`business-rules.md`), que cruza cada requisito
crítico contra código/DB/test/seguridad/concurrencia y expone los huecos tipo P3
(aislamiento sin test). Reconcilia contradicciones que la consolidación no resolvió, caza
`PASS` sin evidencia, requisitos o rutas no auditadas, y severidades subestimadas.
**Tiene autoridad para anular un PASS** y elevar un hallazgo a BLOCKING; su salida
complementa e informa la compuerta humana, no la reemplaza. Sin esta pasada, varios
agentes pueden equivocarse igual y el gate heredaría el error (el defecto "nada bloquea"
con bloqueantes abiertos se caza aquí).

## Fase 3 — Compuerta de aprobación

**Primero emite el Production Gate.** Produce `.orchestrator/20-production-gate.md`
(`references/production-gate.md`): tabla PASS/FAIL por dimensión, conteo por severidad,
lista de BLOCKING y veredicto **GO / NO-GO**. No hay GO con un CRITICAL/HIGH BLOCKING o
un `hard_gate` abierto. El gate **clasifica el riesgo, no decide por la persona**: la
compuerta pregunta *qué corregir* **después** del veredicto. Si la persona acepta una
deuda, queda como **NO-GO / riesgo asumido**, nunca como "nada bloquea".

Luego presenta el plan legible: qué es OBSERVADO vs RECOMENDADO, riesgo, qué es
irreversible, **plan de reversa**, y marca en grande cualquier **cambio rompiente de
contrato de API**. Si es multiempresa, exige el **veredicto de aislamiento de tenants**
(lo produce Seguridad): sin esa prueba, ningún cambio toca datos compartidos.

**Aprobación graduada por riesgo (`references/risk-levels.md`).** "Ningún cambio con
impacto se aplica sin aprobación" sigue firme para lo que tiene impacto, pero la
ceremonia se gradúa: R0 (solo lectura) y R1 (formato/docs/tests) son automáticos pero
declarados; R2 (local acotado) se aplica en rama con diff visible y reversa trivial;
R3 (API/BD/seguridad) y R4 (irreversible/producción) **exigen aprobación humana
explícita** e innegociable. Ante la duda entre dos niveles, elige el más alto. No
apliques ningún R3/R4 sin aprobación.

## Fase 4 — Aplicación

Siempre sobre **rama dedicada**, con **commit atómico por cambio aprobado** (mensaje
que referencia el ítem del plan). **Antes de escribir en un módulo**, el agente carga su
rebanada del `policy-index` (Capa C, `references/anti-regression.md`) y produce un
checklist de cumplimiento con las mismas claves que las reglas ejecutables de Capa A; al
corregir un hallazgo, **baja el baseline** de Capa A (la deuda solo disminuye). Agentes
en modo APLICACIÓN, en secuencia por dependencias, solo lo aprobado; lo nuevo que
descubran vuelve a la compuerta. Cambios
no reversibles con un simple retroceso (migración destructiva, dato mutado) se separan
y aplican solo con plan de reversa aprobado. Cada agente entrega
`.orchestrator/apply/<agente>-cambios.json` (archivos tocados + reversa; formato en
`evidence-protocol.md`); el director lo contrasta contra `git status` antes de avanzar
al siguiente agente.

## Fase 5 — Verificación

QA (funcionalidad vs reglas) y Seguridad (huecos cerrados) corren sus baterías contra
lo aplicado. La verificación es **independiente de quien aplicó**: la prueba la diseña
el verificador, sin reusar la aserción del autor. Regresiones vuelven al responsable.
Base de diff de la verificación: los `cambios.json` de cada agente; un archivo tocado
que no figure ahí es alcance no declarado y vuelve a la compuerta.

**Verificación anti-regresión (Capa D, obligatoria).** Por cada entrada del registro de
regresiones (`references/regression-ledger.md`) cuyo dominio o rutas toca el diff, debe
existir y pasar su `test_required` (o su lint de Capa A). Sin esa prueba, el invariante
queda **UNVERIFIED, nunca PASS**, y bloquea el cierre. Una lección de seguridad,
integridad, tenant o concurrencia no se da por cerrada solo con prosa: cierra con lint o
con test de regresión.

---

## Automatización

Documentación y Aprendiz se cablean con hooks (`PostToolUse` en Edit|Write,
`SessionEnd`) y subagentes en `.claude/agents/`: guía completa en
`references/automation-hooks.md`. Principio: **automatiza el disparo, no la decisión
de escribir en producción.**

## Estructura de salida

```
.orchestrator/
├── 00-ficha-de-hechos.md   (equipo y capacidades seleccionados, con justificación)
├── project-memory/         (arquitectura, módulos, reglas, contratos: se relee en corridas siguientes)
│   ├── regression-ledger.md / .json   (registro de regresiones e invariantes: backbone anti-regresión)
│   └── ...
├── audit/                  (por agente: <agente>.md + veredicto <agente>.json; incluye red-team.md/.json)
├── 10-plan-consolidado.md
├── 20-production-gate.md   (GO/NO-GO por dimensión + BLOCKING; salida obligatoria de la Fase 3)
├── apply/                  (bitácora + <agente>-cambios.json + cierre documentado)
├── api/                    (contrato base y diffs)
├── 30-verificacion.md      (incluye prueba de aislamiento de tenants y verificación anti-regresión)
├── trace.md                (trazabilidad: quién, qué, por qué, validación)
├── 90-aprendizajes.md
├── state.json              (commit, hashes y checkpoints por paso por agente: habilita el modo incremental y la reanudación)
└── runs/<fecha>/           (corridas anteriores archivadas)

El `policy-index.md` (Capa C) vive en `.claude/policy-index.md`, y la Capa A ejecutable
(linter de políticas + tests de arquitectura + pre-commit + CI + baseline) en el propio
repo del proyecto (ver `references/anti-regression.md` y `references/setup.md`).
```

Cada archivo es autocontenido y con evidencia. La **memoria global por lenguaje** vive
en ámbito de usuario (`~/.claude/project-orchestrator/memory/<lenguaje>.md`):
`references/language-memory.md`.
