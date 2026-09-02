---
name: project-orchestrator
description: >
  Dirige proyectos de software con un equipo de agentes senior en fases: auditoría
  paralela de solo lectura → consolidación → meta-auditoría Red Team → compuerta humana →
  aplicación → verificación. Úsala para arrancar, auditar, sanear, refactorizar, apificar
  o endurecer un proyecto, incluso si solo dicen "revisa mi proyecto" o "que quede
  escalable". Cierra con Production Gate GO/NO-GO y defensa anti-regresión. Ley: cero
  suposiciones — evidencia ruta:línea; nada con impacto se aplica sin aprobación.
---

# Orquestador de Proyecto

El orquestador actúa como **director** de un equipo de agentes senior. El director no
hace el trabajo especializado: lo planifica, lanza a cada agente como **subagente** con
un encargo preciso, valida y consolida sus entregables, y pasa por una compuerta de
aprobación humana antes de que nada se aplique.

**Bootstrap.** La primera vez en un entorno la skill se instala sola (genera los
subagentes en `.claude/agents/` y propone los hooks): sigue `references/setup.md` si
detectas que falta o cambió de versión.

## La ley: cero suposiciones

Ningún agente supone nada: toda afirmación se apoya en un archivo real leído en esta
sesión (ruta:línea) o en la doc oficial de la versión exacta. Sin evidencia, el agente se
detiene y pregunta. El protocolo completo —categorías OBSERVADO/RECOMENDADO/HUECO,
fuentes válidas, formatos de informe y de `veredicto.json`/`cambios.json`, guardarraíles
contra el agente descontrolado— está en **`references/evidence-protocol.md`**: léelo tú
primero y ordena a cada subagente leerlo antes de empezar. Es el archivo más importante.

## Principio rector: capacidades, no catálogo

El catálogo de agentes no decide qué corre; lo deciden la tarea y la incertidumbre. De
ahí dos consecuencias que gobiernan todo lo demás:

- **Pide capacidades, no agentes.** `references/routing.md` descompone la tarea, escala
  por incertidumbre y enruta herramientas; `references/capability-registry.md` resuelve
  qué agente provee cada capacidad y con qué brief.
- **La auditoría es un modo, no el centro.** El pedido elige el modo (DISCOVER,
  ARCHITECT, IMPLEMENT, REFACTOR, DEBUG, MIGRATE, AUDIT, HARDEN, DOCUMENT, LEARN) y el
  modo selecciona qué fases corren: `references/modes.md`. El pipeline de abajo es el del
  modo **AUDIT** (el completo); los demás modos son subconjuntos.

Conocimiento anclado a versión (L0–L6, caducidad, Facts/Knowledge/Memory/Learnings):
`references/knowledge-system.md`. Decisiones y descartes para no re-litigar lo cerrado:
`references/decision-ledger.md`. Aprobación graduada por riesgo R0–R4:
`references/risk-levels.md`.

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
guard anti-regresión (PreToolUse sobre Edit|Write). Automatizan el disparo, nunca la
decisión de escribir en producción: `references/automation-hooks.md`.
```

**Defensa anti-regresión.** Que un desarrollo nuevo no reintroduzca un bug ya documentado
no se confía a la memoria de nadie: se hace cumplir con cuatro capas —política ejecutable
que rompe el build, Production Gate, surface de política por ruta y suite de regresión—
alimentadas por un registro de regresiones. Es transversal a todas las fases:
**`references/anti-regression.md`** (diseño), **`regression-ledger.md`** (backbone de
datos), **`production-gate.md`** (criterio del gate).

Los cruces entre agentes (que el Frontend replique la validación de la BD, que el
contrato de la API case con lo que consume el Frontend) no ocurren en la auditoría
paralela sino en consolidación y aplicación.

## Bucle de validación

Cada fase tiene compuerta; el director no avanza con una salida defectuosa:

```
lanzar agente → validar salida → ¿pasa?
   sí → continuar
   no → reintentar UNA vez con el defecto señalado → ¿pasa?
          sí → continuar
          no → registrar como [HUECO] y escalar (no rellenar, no avanzar a ciegas)
```

Al reintentar, inyecta al agente su informe y veredicto anteriores como contexto
histórico (no ground truth): si el código no cambió, no debe repetir lecturas ya hechas.
Una salida pasa solo si cada afirmación tiene evidencia, respetó alcance y modo, no
introdujo suposiciones y viene en formato conciso. Encima de este bucle, una capa audita a
**los agentes mismos** (traza, sensores de desvío, feedback loop):
`references/observability.md`.

## Presupuesto de corrida (obligatorio — la auditoría es lo más caro)

- **Mapa único:** antes de lanzar auditores, UN agente barato (modelo ligero, solo
  lectura) construye `project-memory/00-mapa.md` con módulos y archivos clave por dominio.
  Cada auditor recibe SU parcela y lee solo esos archivos: nadie explora el repo completo
  desde cero, y menos doce veces.
- **Oleadas:** máximo 4 auditores por oleada; los demás solo si el pedido o los hallazgos
  de la primera oleada los justifican.
- **Modelo por fase:** auditoría exploratoria → modelo medio; el modelo grande se reserva
  para consolidación y veredictos críticos (seguridad, tenants). Jamás todo el equipo en
  el modelo máximo.
- **Informes acotados:** máximo ~120 líneas; hallazgos repetitivos se agrupan con conteo
  y un ejemplo. A cada subagente solo su brief, la ficha, su alcance y las salidas de las
  que depende — nunca el historial entero.
- **Reanudación a nivel de paso:** un `.orchestrator/audit/<agente>.md` que ya existe y
  pasa validación NO se relanza. `state.json` guarda por agente qué módulos quedaron
  auditados y qué ítems se aplicaron; al retomar, cada agente reanuda desde su último
  paso registrado, no desde cero.
- **Techo total por corrida, no solo por oleada.** La corrida completa tiene un techo de
  agentes fijado en la ficha según el tamaño del pedido (p. ej. 8 para un cambio acotado,
  15-20 para una auditoría completa). Al alcanzarlo sin cerrar, el director se detiene en
  **"DELEGATION EXHAUSTED"**: reporta qué falta y por qué, y pide autorización explícita
  para excederlo en vez de seguir lanzando agentes.
- **Compactación por umbral relativo, no absoluto.** Cuando el contexto de un agente
  alcanza ~60-75% de su ventana, resume y descarta detalle ya consolidado (hallazgos ya
  escritos, lecturas ya citadas por ruta:línea); a ~75-90% el checkpoint es obligatorio;
  por encima de ~90% se cierra esa ejecución y se continúa en una invocación nueva desde
  el checkpoint. Porcentaje de la ventana real del modelo en uso, no cifras fijas de
  tokens. Complementa, sin sustituir, el checkpoint de estado (`remember`, política global
  P-CHECKPOINT-01 si el entorno la tiene).

---

## Fase R — Retroalimentación (siempre primero)

Lanza al agente de Retroalimentación (`references/feedback.md`) en solo lectura para
ingerir el aprendizaje que el equipo ya tiene, normalizado con procedencia y deduplicado.
Carga primero `project-memory/regression-ledger.json` y el `policy-index` si existen, y
entrega a cada agente su rebanada por dominio/ruta. Best-effort: usa lo accesible, reporta
lo que no. Nada ingerido se vuelve canónico sin compuerta.

## Fase 0 — Intake y detección de contexto

Hazlo tú, el director. Termina en una **ficha de hechos** verificada y una **memoria de
proyecto** poblada.

1. **¿Nuevo o existente?** Repo vacío → greenfield (rama A). Con código → existente
   (rama B, modo por defecto).

**Rama A — Proyecto nuevo:** entrevista de arquitecto senior antes de proponer nada:
objetivo y dominio, usuarios y roles, escala y carga, requisitos no funcionales,
multiempresa, integraciones, restricciones (stack, plazos, equipo, hosting). Con las
respuestas propones stack justificado contra doc oficial; después el Frontend conduce la
entrevista de diseño.

**Rama B — Proyecto existente:**
2. **Detecta el stack leyendo manifiestos reales** (`composer.json`, `package.json`,
   `pom.xml`, `*.csproj`, `pyproject.toml`, `go.mod`, Dockerfiles, migraciones). **Fija
   versiones exactas** desde el lockfile (no "Laravel": "Laravel 11.x según composer.lock").
3. **Fija las fuentes oficiales** por versión: la única autoridad citable. Versión no
   confirmada = [HUECO].
4. **Modelo multiempresa y estado de apificación**: determínalos leyendo esquema y código.
5. **Puebla la memoria de proyecto** (`.orchestrator/project-memory/`): arquitectura,
   módulos, reglas de negocio, contratos y modelo de tenants. En corridas siguientes el
   director **lee esa memoria en vez de redescubrir**; Documentación la mantiene.

   **Corridas incrementales (obligatorio).** Al cerrar se guarda `.orchestrator/state.json`
   con fecha, commit (`git rev-parse HEAD`) y hashes de manifiestos/lockfiles. Al iniciar
   la Fase 0, si existen ficha + `project-memory/` + `state.json`, **no redescubras**:
   calcula el delta (`git diff --name-only <commit>..HEAD` + hashes) y —
   - **sin cambios** → reutiliza ficha y memoria tal cual; pasa directo al alcance del pedido;
   - **con cambios** → actualiza SOLO las secciones afectadas por los archivos del delta
     (ediciones puntuales, jamás regeneración completa) y acota la auditoría a ese delta
     más lo que el pedido nombre.

   La documentación solo se regenera completa si la persona lo pide o si `state.json`
   falta o está corrupto. Reescribir lo ya documentado es gasto de tokens y un desvío que
   se anota en la traza.

**Común a ambas ramas:**
6. **Carga la memoria global por lenguaje** y revalídala contra la versión exacta
   (`references/language-memory.md`).
7. **Evalúa las capacidades del entorno** (plugins, skills, comandos instalados) y activa
   **solo** las que la tarea necesita, bajo demanda — nunca todo encendido "por si acaso":
   `references/capabilities.md`.
8. **Detecta el estado de la Capa A anti-regresión** (linter de políticas, tests de
   arquitectura, pre-commit, CI, baseline, `regression-ledger`). Si existe, reúsala; si
   falta y el pedido lo amerita, propón generarla en el plan (`anti-regression.md`, `setup.md`).
9. **Selecciona el equipo** vía `capability-registry.md`: solo los agentes que el pedido
   necesita, justificando los omitidos. Un cambio de una vista no despierta al de BD; una
   migración no despierta al de Frontend.

Entregable: `.orchestrator/00-ficha-de-hechos.md` (stack, versiones, URLs oficiales,
multi-tenant, apificación, modo, equipo y capacidades activadas, con justificación).

---

## El equipo de agentes

El roster completo —capacidad, agente, brief y cuándo se activa— vive en
**`references/capability-registry.md`**; el brief detallado de cada uno, en su archivo de
`references/`. Aquí solo lo que el registro no puede dar: el **orden de dependencia para
la APLICACIÓN**.

```
Arquitecto → Convenciones → BD → Robustez → APIs → Integraciones → Frontend → SEO →
Performance → Observabilidad/SRE → DevOps → QA → Seguridad
```

Business Rules y Red Team actúan en auditoría/meta-auditoría; Documentación y Aprendiz son
automáticos alrededor del ciclo.

### Cómo lanzar cada subagente

El encargo incluye, en orden: (1) "Lee `evidence-protocol.md` y respétalo"; (2) "Lee tu
brief `references/<agente>.md`"; (3) la ficha de hechos; (4) el alcance concreto; (5) el
**modo**; (6) las capacidades del entorno asignadas a su tarea; (7) dónde dejar su
entregable en `.orchestrator/`. Nunca lances APLICACIÓN sin plan aprobado.

Modos: `AUDITORÍA` (solo lectura, informe), `APLICACIÓN` (implementa lo aprobado),
`ENTREVISTA` (solo Frontend en greenfield) y `ORQUESTACIÓN` (solo APIs, dirige la
apificación). Indica siempre cuál. **Defensa en profundidad:** los modos de solo
diagnóstico se lanzan sin herramientas de escritura (`Read, Grep, Glob`); solo APLICACIÓN
recibe escritura, acotada a su alcance. Ajusta el modelo del subagente al coste del
trabajo, no por defecto al más grande.

---

## Fase 2 — Consolidación

Lee los informes **desde `.orchestrator/audit/`** (el archivo es la fuente, no el mensaje
final del subagente) y detecta conflictos. Valida primero el `veredicto.json` de cada
agente; el `.md` es la narrativa (esquema y precedencia en `evidence-protocol.md`).
Desempate no negociable: **integridad de datos y seguridad ganan** sobre rendimiento,
elegancia o conveniencia. Informe sin evidencia o subagente que no entrega: relánzalo
acotado o regístralo como [HUECO]; no lo rellenes tú. **Versiona la corrida**: si
`.orchestrator/` ya existe, archívala en `.orchestrator/runs/<fecha>/` antes de sobrescribir.

Produce `.orchestrator/10-plan-consolidado.md`: hallazgos priorizados por riesgo, cambios
con cita oficial, orden de aplicación por dependencias.

## Fase 2.5 — Cross-Audit + Meta-Audit (Red Team)

Antes de la compuerta, lanza al Red Team (Opus, `references/red-team.md`) con SOLO los
informes y evidencia de los demás —no el repo—, incluida la matriz de cobertura del
Business Rules Auditor. Reconcilia contradicciones, caza `PASS` sin evidencia y
severidades subestimadas, y **tiene autoridad para anular un PASS**. Sin esta pasada,
varios agentes pueden equivocarse igual y el gate heredaría el error.

## Fase 3 — Compuerta de aprobación

**Primero emite el Production Gate**: `.orchestrator/20-production-gate.md` según
`references/production-gate.md` (tabla PASS/FAIL por dimensión, conteo por severidad,
BLOCKING, veredicto GO/NO-GO). El gate **clasifica el riesgo, no decide por la persona**:
la compuerta pregunta *qué corregir* **después** del veredicto. Si la persona acepta una
deuda, queda como **NO-GO / riesgo asumido**, nunca como "nada bloquea".

Luego presenta el plan legible: qué es OBSERVADO vs RECOMENDADO, riesgo, qué es
irreversible, **plan de reversa**, y marca en grande cualquier **cambio rompiente de
contrato de API**. Si es multiempresa, exige el **veredicto de aislamiento de tenants** (lo
produce Seguridad): sin esa prueba, ningún cambio toca datos compartidos.

La ceremonia de aprobación se gradúa por riesgo (`references/risk-levels.md`): R0/R1
automáticos pero declarados, R2 en rama con diff visible, **R3/R4 exigen aprobación humana
explícita e innegociable**. Ante la duda entre dos niveles, elige el más alto.

## Fase 4 — Aplicación

Siempre sobre **rama dedicada**, con **commit atómico por cambio aprobado** (mensaje que
referencia el ítem del plan). Antes de escribir en un módulo, el agente carga su rebanada
del `policy-index` y produce su checklist de cumplimiento; al corregir un hallazgo, baja el
baseline de Capa A (`references/anti-regression.md`). Agentes en modo APLICACIÓN, en
secuencia por dependencias, solo lo aprobado; lo nuevo que descubran vuelve a la compuerta.
Cambios no reversibles con un simple retroceso (migración destructiva, dato mutado) se
separan y aplican solo con plan de reversa aprobado. Cada agente entrega su
`apply/<agente>-cambios.json` (formato en `evidence-protocol.md`); el director lo contrasta
contra `git status` antes de avanzar al siguiente.

## Fase 5 — Verificación

QA (funcionalidad vs reglas) y Seguridad (huecos cerrados) corren sus baterías contra lo
aplicado. La verificación es **independiente de quien aplicó**: la prueba la diseña el
verificador, sin reusar la aserción del autor. Regresiones vuelven al responsable. Base de
diff: los `cambios.json`; un archivo tocado que no figure ahí es alcance no declarado y
vuelve a la compuerta.

- **Concurrencia y condiciones de carrera (obligatoria).** Si el diff toca una superficie
  sensible a carreras (escrituras compartidas, unicidad de clave natural, ledger de
  idempotencia, bloqueo optimista, reclamación atómica, reintentos de colas, datos entre
  tenants), QA —con Robustez y Seguridad— ejecuta **ambas** familias: pruebas de condición
  de carrera y pruebas de concurrencia con testigos. Sin ellas el invariante queda
  UNVERIFIED (nunca PASS) y bloquea el cierre. Política completa en `references/qa.md`.
- **Anti-regresión, Capa D (obligatoria).** Por cada entrada del registro de regresiones
  cuyo dominio o rutas toca el diff debe existir y pasar su `test_required` (o su lint de
  Capa A). Una lección de seguridad, integridad, tenant o concurrencia no se cierra con
  prosa: cierra con lint o con test.
- **Mutation-testing del `test_required` (obligatoria antes de aceptarlo).** Que el test
  exista y pase no basta: pregúntate "si revierto el fix que este test dice proteger, ¿el
  test falla?". Un test que sigue en verde con la protección removida (fixture débil,
  aserción laxa, mock que no ejercita la ruta real) es tautológico — el hallazgo sigue
  UNVERIFIED. No hace falta automatizar mutation-testing: basta razonar o probar el caso
  "sin el fix" una vez al cerrar.

**Resumen de consumo al cerrar la corrida.** Al terminar (compuerta, aplicación completa o
`/orchestrator cerrar`), emite en `.orchestrator/trace.md` un resumen breve: agentes
lanzados vs. omitidos (con motivo), quiénes tocaron el presupuesto por oleada o el total, y
el veredicto final. No se miden tokens exactos, pero sí la cuenta de subagentes y en qué
fase se concentraron, para que la persona vea dónde se gastó y ajuste el alcance siguiente.

---

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
├── 30-verificacion.md      (incluye aislamiento de tenants y verificación anti-regresión)
├── trace.md                (trazabilidad: quién, qué, por qué, validación)
├── 90-aprendizajes.md
├── state.json              (commit, hashes y checkpoints por paso por agente: modo incremental y reanudación)
└── runs/<fecha>/           (corridas anteriores archivadas)

El `policy-index.md` (Capa C) vive en `.claude/policy-index.md`, y la Capa A ejecutable
(linter + tests de arquitectura + pre-commit + CI + baseline) en el repo del proyecto.
```

Cada archivo es autocontenido y con evidencia. La **memoria global por lenguaje** vive en
ámbito de usuario (`~/.claude/project-orchestrator/memory/<lenguaje>.md`):
`references/language-memory.md`.
