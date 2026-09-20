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

## Contrato mínimo de entorno (la skill no asume el host)

Esta skill corre en Claude Code pero también en otros agentes. Fuera de Claude Code **no
se carga `~/.claude/CLAUDE.md`, ni los comandos de `commands/`, ni la herramienta de
subagentes**: el único artefacto que llega es este archivo. Por eso las invariantes de las
que la skill depende viven aquí abajo, no en la configuración del host.

**Precedencia:** si el host ya impone una política equivalente (p. ej. las políticas
globales `P-CHECKPOINT-01`, `P-AGENTS-01`, `P-MEMORY-01`, `P-TOKENS-01` de Claude Code),
**esa manda y esto no se duplica**. Lo de abajo es el piso cuando no hay nada.

- **I1 — Memoria antes que redescubrimiento.** Antes de explorar, se lee lo que corridas
  anteriores ya dejaron escrito (`.orchestrator/`). Redescubrir lo documentado es un
  desvío, no una precaución. La compuerta que lo hace cumplir es el paso 2 de la Fase 0.
- **I2 — Checkpoint por saturación de contexto.** Cuando el contexto llega a ~60-75% de la
  ventana se resume y se descarta detalle ya consolidado; a ~75-90% el checkpoint es
  obligatorio. El disparador es el tamaño del contexto, nunca el commit. Si el host no
  ofrece una herramienta de checkpoint, el estado se escribe en `.orchestrator/state.json`
  y `.orchestrator/trace.md`: qué se hizo, dónde quedó, qué sigue.
- **I3 — Delegación dimensionada por incertidumbre.** Regla completa en «Presupuesto de
  corrida». **Si el host no tiene subagentes**, el director ejecuta las fases él mismo, en
  secuencia, una parcela por vez y con checkpoint entre parcelas — pero **no elimina
  ninguna fase ni ninguna compuerta**. Perder el paralelismo es aceptable; perder la
  compuerta humana o la meta-auditoría, no.
- **I4 — Cero suposiciones.** Toda afirmación con evidencia `ruta:línea` o doc oficial de
  la versión exacta. Sin evidencia: `[HUECO]` y se pregunta.
- **I5 — La compuerta humana no es negociable.** Ningún cambio R3/R4 se aplica sin
  aprobación explícita de una persona, en ningún host, con o sin herramientas.
- **I6 — El cumplimiento corporativo cierra toda corrida.** La Fase 6 corre siempre, la
  última, aunque el host no tenga subagentes (entonces la ejecuta el director). Si no hay
  corpus de políticas, se declara `SIN-CORPUS` y no bloquea; lo que **no** es admisible es
  cerrar sin haberlo evaluado.

Un host que no permita cumplir I4 o I5 no puede correr los modos de aplicación: se limita
a los de diagnóstico y lo declara al abrir la corrida.

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
`references/risk-levels.md`. Copias declaradas y hechos derivados —la regresión de
artefacto que ni la auditoría ni el build miran—: `references/source-of-truth.md`.

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
Fase 6  Cumplimiento  →  OBLIGATORIA y SIEMPRE ÚLTIMA: correlaciona la corrida con las
                         políticas de la empresa; su veredicto entra al gate

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
  lectura) construye `.orchestrator/project-memory/00-mapa.md` con módulos y archivos clave por dominio.
  Cada auditor recibe SU parcela y lee solo esos archivos: nadie explora el repo completo
  desde cero, y menos doce veces.
- **Oleadas:** máximo 4 auditores por oleada; los demás solo si el pedido o los hallazgos
  de la primera oleada los justifican.
- **Modelo por incertidumbre, no por rol ni por comodidad:** dimensiona cada subagente
  por la incertidumbre que debe resolver. Trabajo mecánico (mapa, inventario, extracción,
  verificar presencia de un patrón) → modelo ligero; auditoría de una parcela ya mapeada y
  aplicación de un plan ya aprobado → modelo medio (el default); alta incertidumbre o
  consecuencia irreversible (arquitectura, seguridad, integridad de datos, tenants,
  consolidación, Red Team, compuerta) → modelo grande. Si no puedes nombrar la
  incertidumbre concreta que justifica subir de modelo, no lo subas. Jamás toda una oleada
  en el modelo máximo: el grande consolida y decide, no lee.
- **Informes acotados:** máximo ~120 líneas; hallazgos repetitivos se agrupan con conteo
  y un ejemplo. A cada subagente solo su brief, la ficha, su alcance y las salidas de las
  que depende — nunca el historial entero.
- **Salida callada y lectura por rango:** las salidas de herramientas son lo que más
  vuelve a entrar en contexto. Comandos con `-q`/`--quiet`/`--no-ansi` y acotados
  (`| tail -n`, `grep -c`), y dentro de una parcela se relee **por rango**, nunca el
  archivo entero: citar `ruta:línea` la primera vez evita la segunda lectura.
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

Catálogo completo de fugas de tokens, su diagnóstico y la disciplina de escritura de
los informes: **`references/token-budget.md`**. Léelo antes de dimensionar una corrida
grande o de justificar un subagente extra.

---

## Fase R — Retroalimentación (siempre primero)

Lanza al agente de Retroalimentación (`references/feedback.md`) en solo lectura para
ingerir el aprendizaje que el equipo ya tiene, normalizado con procedencia y deduplicado.
Carga primero `.orchestrator/project-memory/regression-ledger.json` y el `policy-index`
si existen, y entrega a cada agente su rebanada por dominio/ruta. Best-effort: usa lo
accesible, reporta lo que no. Nada ingerido se vuelve canónico sin compuerta.

**Rebanada normativa (si hay corpus).** Si existe
`~/.claude/project-orchestrator/memory/company-policies/`, la Fase R entrega además a cada
agente las políticas `OBLIGATORIA` de su dominio — solo esas, no el corpus entero. Prevenir
que un plan nazca violando la norma es más barato que descubrirlo en la Fase 6. La Fase 6
sigue corriendo igual: esto es prevención, no sustituye la verificación.

**Compilación del contrato de escritura (obligatoria).** Entregar la rebanada a un agente
es advisory: el modelo puede olvidarla a mitad de la Fase 4. Por eso la Fase R **también**
corre `scripts/compile-guard-rules.ps1`, que funde las cuatro fuentes de política en
`.orchestrator/guard-rules.json` — el contrato que el hook `PreToolUse` evalúa en cada
`Edit|Write` y que **bloquea** la escritura que viola un invariante ya documentado
(`automation-hooks.md`). Esto corre **antes de que ningún agente escriba**, y se repite al
cerrar si el Aprendiz añadió entradas. El compilador reporta `sin_firma[]`: las políticas
que siguen siendo prosa y por tanto **nadie puede hacer cumplir al escribir**. Ese conteo
entra a la compuerta como hueco de exigibilidad declarado.

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

**Obligatorio en esta rama, apenas el stack queda fijado y antes de que la Fase 4 escriba
código de aplicación:** corre `/distill-guard` (`commands/distill-guard.md`). Un proyecto
greenfield no tiene código previo que una auditoría pueda encontrar incumpliendo nada, así
que la vía reactiva del Aprendiz (promover tras una regresión confirmada) nunca se
dispara aquí. La única forma de que el código nazca ya cumpliendo el conocimiento fijo de
la skill (formularios, archivos, seguridad, BD…) es distilarlo en `senal` **antes** de la
primera escritura. Ver `regression-ledger.md`, «Distilación proactiva vs. reactiva».

**Rama B — Proyecto existente:**

2. **COMPUERTA INCREMENTAL — este paso va PRIMERO y puede cerrar la Fase 0 entero.** No
   detectes nada hasta haberlo ejecutado. Es una secuencia, no una advertencia:

   ```
   a. Resuelve la raíz:  ORCH_ROOT = $(git rev-parse --show-toplevel)  (si no hay git:
      el directorio del proyecto que la persona abrió). TODA ruta de esta skill se
      resuelve desde ahí: $ORCH_ROOT/.orchestrator/...  Nunca relativa al cwd.
   b. ¿Existen los tres?  .orchestrator/00-ficha-de-hechos.md
                          .orchestrator/project-memory/
                          .orchestrator/state.json
      NO (falta alguno) → hay que descubrir: sigue a los pasos 3-5.
      SÍ                → continúa en (c). NO ejecutes los pasos 3-5.
   c. Lee state.json y toma su commit. Calcula el delta:
      git diff --name-only <commit>..HEAD
      y compara los hashes de manifiestos/lockfiles que guarda state.json.
   d. Delta VACÍO y hashes iguales → reutiliza ficha y memoria tal cual. Salta a los
      pasos 6-9 con el alcance que pidió la persona; la Fase 0 termina ahí.
   e. Delta NO vacío → lee la ficha y la memoria existentes, y actualiza SOLO las
      secciones que tocan los archivos del delta (ediciones puntuales; jamás regeneración
      completa). La auditoría de la Fase 1 se acota a ese delta más lo que el pedido
      nombre. Los módulos que el delta no tocó no se releen ni se reauditan.
   f. Registra el resultado en la traza (obligatorio, ver abajo).
   ```

   **Los pasos 3, 4 y 5 corren SOLO si (b) dio NO.** Si ya hay memoria, el stack, las
   versiones, el modelo de tenants y el estado de apificación se leen de la ficha —
   relanzar un subagente a redescubrirlos es un desvío que se anota en la traza.

3. **Detecta el stack leyendo manifiestos reales** (`composer.json`, `package.json`,
   `pom.xml`, `*.csproj`, `pyproject.toml`, `go.mod`, Dockerfiles, migraciones). **Fija
   versiones exactas** desde el lockfile (no "Laravel": "Laravel 11.x según composer.lock").
4. **Fija las fuentes oficiales** por versión: la única autoridad citable. Versión no
   confirmada = [HUECO]. **Modelo multiempresa y estado de apificación**: determínalos
   leyendo esquema y código.
5. **Puebla la memoria de proyecto** (`.orchestrator/project-memory/`): arquitectura,
   módulos, reglas de negocio, contratos y modelo de tenants. Documentación la mantiene.

   Al cerrar la corrida se guarda `.orchestrator/state.json` con `schema_version`, fecha,
   commit (`git rev-parse HEAD`) y hashes de manifiestos/lockfiles — es lo que hace
   posible la compuerta (2) la próxima vez. Una corrida que no escribe `state.json`
   condena a la siguiente a redescubrir.

   La documentación solo se regenera completa si la persona lo pide explícitamente.
   `state.json` ausente o ilegible **no** autoriza a borrar ni reescribir la memoria
   existente: ver «Compatibilidad con proyectos que ya corrieron la skill».

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

### Compatibilidad con proyectos que ya corrieron la skill (obligatoria)

Un proyecto con `.orchestrator/` de una versión anterior **conserva todo su trabajo**. La
migración es por completado, nunca por regeneración:

- **`state.json` viejo no es `state.json` corrupto.** Si le faltan campos nuevos
  (`schema_version`, hashes, checkpoints por agente), trátalo como `schema_version: 1`:
  usa el `commit` que sí tiene para calcular el delta y **completa** los campos que
  falten al cerrar la corrida. Solo es corrupto si no parsea o no tiene commit; y aun
  entonces la salida es **reconstruir `state.json` desde `git rev-parse HEAD` y la memoria
  existente**, no borrar la memoria.
- **Memoria fuera de sitio.** Si no existe `.orchestrator/project-memory/` pero sí hay
  `project-memory/` en la raíz (rutas de versiones anteriores), **adóptala**: muévela bajo
  `.orchestrator/` y déjalo anotado en la traza. Jamás crear una memoria vacía al lado y
  redescubrir.
- **Sin `state.json` pero con ficha y memoria.** No es un proyecto nuevo. Reconstruye
  `state.json` con el HEAD actual, marca el delta como desconocido y acota la auditoría a
  lo que el pedido nombre — pidiendo confirmación si la persona espera cobertura completa.
  La ficha y la memoria se reutilizan y se corrigen puntualmente.
- **El backlog no se pierde.** `10-plan-consolidado.md` es acumulativo (ver Fase 2): los
  ítems heredados se re-verifican contra el código actual y solo salen cuando se comprueban
  `RESUELTO` o la persona los acepta como deuda en compuerta.
- **Corridas anteriores.** Antes de sobrescribir, `.orchestrator/` se archiva en
  `runs/<fecha>/`. La migración de formato se hace sobre la copia viva, con la archivada
  intacta como reversa.

Entregable: `.orchestrator/00-ficha-de-hechos.md` (stack, versiones, URLs oficiales,
multi-tenant, apificación, modo, equipo y capacidades activadas, con justificación).

**Traza obligatoria de la Fase 0.** La primera línea que la corrida escribe en
`.orchestrator/trace.md` declara cómo resolvió la compuerta incremental:

```
fase-0: INCREMENTAL-SIN-CAMBIOS (commit <sha>)
fase-0: INCREMENTAL-DELTA (<n> archivos desde <sha>; secciones actualizadas: ...)
fase-0: COMPLETA (motivo: falta state.json | falta ficha | la persona pidió regenerar)
fase-0: MIGRADA (schema_version 1 → 2 | memoria adoptada desde project-memory/)
```

Sin esa línea la corrida no avanza a la Fase 1. Una corrida que dice `COMPLETA` teniendo
ficha, memoria y `state.json` válidos es un desvío y se reporta como tal.

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
entregable en `.orchestrator/`; (8) la disciplina de escritura del informe. Nunca lances
APLICACIÓN sin plan aprobado.

**Disciplina de escritura (va literal en el encargo, no como puntero — el informe es lo
que vuelve al contexto del director):** sin preámbulo, sin narración de herramientas, sin
recapitular lo ya dicho, sin tablas decorativas. Hallazgo repetido = conteo + un ejemplo.
Van **verbatim**: negaciones, números, unidades, `ruta:línea`, código, comandos y cadenas
de error. **No** comprimas con abreviaturas inventadas (`cfg`, `impl`, `req`) ni flechas
como sustituto de "produce": el tokenizador las cuenta igual y se leen peor. Las
advertencias de seguridad, las acciones irreversibles y las secuencias donde el orden
importa se escriben completas: ahí la claridad manda sobre la brevedad.

Modos: `AUDITORÍA` (solo lectura, informe), `APLICACIÓN` (implementa lo aprobado),
`ENTREVISTA` (solo Frontend en greenfield) y `ORQUESTACIÓN` (solo APIs, dirige la
apificación). Indica siempre cuál. **Defensa en profundidad:** los modos de solo
diagnóstico se lanzan sin herramientas de escritura (`Read, Grep, Glob`); solo APLICACIÓN
recibe escritura, acotada a su alcance. Fija además el modelo del subagente por la
incertidumbre de su encargo (regla en «Presupuesto de corrida»), y decláralo en el brief.

---

## Fase 2 — Consolidación

Lee los informes **desde `.orchestrator/audit/`** (el archivo es la fuente, no el mensaje
final del subagente) y detecta conflictos. Valida primero el `veredicto.json` de cada
agente; el `.md` es la narrativa (esquema y precedencia en `evidence-protocol.md`).
Desempate no negociable: **integridad de datos y seguridad ganan** sobre rendimiento,
elegancia o conveniencia. Informe sin evidencia o subagente que no entrega: relánzalo
acotado o regístralo como [HUECO]; no lo rellenes tú.

**Versiona la corrida, pero nunca por encima de un plan aún sin resolver.** Antes de
tocar `10-plan-consolidado.md` del root, comprueba el estado de la compuerta del plan
que ya está ahí (`20-production-gate.md` / `state.json` de esa misma corrida):

- Si ese plan ya está **resuelto** (se aplicó en Fase 4–5, o la persona lo descartó
  explícitamente en una compuerta anterior), archívalo en `.orchestrator/runs/<run_id>/`
  como hasta ahora y produce el nuevo `10-plan-consolidado.md` en el root.
- Si ese plan sigue **pendiente de compuerta** (nadie dijo GO/aplicar ni lo descartó):
  **no lo sobrescribas ni lo archives.** Es trabajo de otra corrida todavía vivo. Escribe
  el plan de ESTA corrida en `.orchestrator/runs/<run_id>/10-plan-consolidado.md` (rama de
  planeación propia, con su propio `20-production-gate.md`) y deja el root intacto. Dos o
  más planeaciones pendientes pueden coexistir así sin pisarse: cada una vive en su
  `run_id`, cada una con su propia compuerta, hasta que la persona decide cuál aplicar (o
  pide fusionarlas explícitamente). `run_id` es la marca de tiempo de inicio de la corrida
  (`YYYY-MM-DDTHH-mm`), fijada una vez en `00-ficha-de-hechos.md`/`state.json` y reusada
  por todos los artefactos de esa misma corrida.
- El modo **estado** (ver `commands/orchestrator.md`) reporta TODOS los planes con
  compuerta pendiente que encuentre (root + cualquier `runs/<run_id>/` sin resolver), no
  solo el último — para que nunca sea una sorpresa que hay más de uno esperando decisión.
- El modo **aplicar** exige que quede claro CUÁL plan se ejecuta cuando hay más de uno
  pendiente: si el root y alguna rama en `runs/` están ambos sin resolver, detente y pide
  el `run_id` explícito en vez de asumir el del root por defecto.

Produce `.orchestrator/10-plan-consolidado.md`: hallazgos priorizados por riesgo, cambios
con cita oficial, orden de aplicación por dependencias.

**`10-plan-consolidado.md` es ACUMULATIVO por diseño, nunca un snapshot de la última
corrida.** Su función es que una sola pasada de aplicación (Fase 4) pueda saldar TODO lo que
sigue abierto del proyecto, no solo lo que esta corrida auditó. Antes de escribirlo:

1. **Recupera el backlog vigente.** Si el proyecto ya tiene un documento propio de deuda
   técnica/pendientes (buscar en `docs/`, README del módulo, o donde la ficha de hechos lo
   señale — a menudo con una sección tipo "Priorización verificada" o "LEER PRIMERO"), esa
   es la fuente de verdad del backlog acumulado, no el `10-plan-consolidado.md` de la corrida
   anterior en solitario. Si no existe tal documento pero sí hay corridas previas en
   `.orchestrator/runs/`, reconstruye el backlog desde el `10-plan-consolidado.md` más
   reciente de esa carpeta.
2. **Re-verifica cada ítem heredado contra el código ACTUAL** (no asumas que sigue como se
   documentó): un hallazgo puede haberse corregido de paso en un commit que no lo mencionó.
   Márcalo `RESUELTO`/`DESACTUALIZADO` con la evidencia nueva si ya no aplica, o `VIGENTE`
   con evidencia refrescada (archivo:línea puede haber cambiado) si sigue abierto. No
   re-audites de cero lo que un agente ya confirmó abierto recientemente y el delta no tocó.
3. **Fusiona** los hallazgos re-verificados que siguen `VIGENTE` con los hallazgos NUEVOS de
   esta corrida, con IDs estables que no colisionen entre corridas (p. ej. prefijo por fecha
   de la corrida que lo originó, o numeración continua tipo P14, P15... si el proyecto ya
   usa ese patrón) — nunca reutilices un número de ID para un hallazgo distinto solo porque
   la corrida anterior ya lo usó.
4. **Solo sale del backlog** un ítem que se verificó `RESUELTO` (con evidencia) o que la
   persona marcó explícitamente como deuda aceptada/descartada en una compuerta anterior —
   nunca por quedar fuera del alcance de la corrida actual.
5. Si el proyecto mantiene su propio documento de deuda técnica, actualízalo en el mismo
   cambio (no lo dejes desincronizado de `10-plan-consolidado.md`): éste último puede
   remitir a aquel como fuente narrativa extendida, pero la lista accionable — priorizada,
   con orden de aplicación por dependencias, lista para una sola pasada de Fase 4 — vive en
   `10-plan-consolidado.md`.

`20-production-gate.md` en cambio SÍ es un snapshot de la corrida (el veredicto GO/NO-GO
corresponde al estado verificado en este momento) — no acumules gates de corridas distintas
en un solo archivo; cada corrida completa produce su propio gate, y los anteriores se
archivan en `runs/<fecha>/` como cualquier otro entregable de la corrida.

## Fase 2.5 — Cross-Audit + Meta-Audit (Red Team)

Antes de la compuerta, lanza al Red Team (Opus, `references/red-team.md`) con SOLO los
informes y evidencia de los demás —no el repo—, incluida la matriz de cobertura del
Business Rules Auditor. Reconcilia contradicciones, caza `PASS` sin evidencia y
severidades subestimadas, y **tiene autoridad para anular un PASS**. Sin esta pasada,
varios agentes pueden equivocarse igual y el gate heredaría el error.

## Fase 3 — Compuerta de aprobación

**La Fase 6 corre antes de esta compuerta**, no después: el gate no se emite sin el
veredicto de cumplimiento (`40-cumplimiento.json`). Una `OBLIGATORIA` violada es `BLOCKING`
y fuerza `NO-GO`, igual que un hallazgo crítico de seguridad. Ver la Fase 6 más abajo.

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

## Fase 6 — Cumplimiento corporativo (obligatoria, siempre la última)

Lanza al agente de **Cumplimiento Corporativo** (`references/policy-compliance.md`) en solo
lectura. **Ninguna corrida cierra sin su veredicto**, en ningún modo y en ningún host: no es
condicional como los agentes del registro, es parte del cierre.

**Cuándo corre — siempre lo último de su tramo:**

```
Corrida de diagnóstico (termina en la compuerta):
   … → 2.5 Red Team → 6 Cumplimiento → 3 Compuerta (lleva el veredicto dentro)

Corrida que aplica:
   3 Compuerta → 4 Aplicación → 5 Verificación → 6 Cumplimiento (cierra la corrida)
```

En una corrida completa corre **dos veces** y no es redundancia: la primera pasada evalúa
el **plan** (evita aplicar algo que viola la norma), la segunda evalúa lo **aplicado** (el
plan aprobado y el diff real no siempre coinciden). La segunda es la que cierra.

**Qué hace.** Cruza hallazgos, plan, cambios y aprendizajes contra el corpus de políticas
de la empresa, etiquetando cada elemento como `CUMPLE`, `INCUMPLE`, `NO-CUBIERTO`,
`CONFLICTO` o `REFUERZA`. La correlación es **bidireccional**: además de verificar que la
corrida respeta la norma, detecta políticas obligatorias que aplicaban al diff y **nadie
verificó** (ese silencio es un hallazgo), y propone como **candidatas a política** los
aprendizajes recurrentes que merecerían norma. Proponer no es dar de alta: el alta solo
ocurre por `/policy-update`, con documento de la empresa detrás.

**Aprendizajes vs. norma.** Los aprendizajes del orquestador valen, pero cuando chocan con
una política de empresa **manda la política para lo que se aplica** — y el conflicto **se
escala completo a la persona**, con ambas posiciones, nunca se cierra en silencio. Si el
conflicto toca seguridad o integridad de datos, sube a `BLOCKING` aunque la política sea
`RECOMENDADA`: una norma corporativa no autoriza un hueco de seguridad sin firma humana.

**El corpus** vive en ámbito de usuario, fuera de la skill y en repositorio privado:
`~/.claude/project-orchestrator/memory/company-policies/`. Se actualiza **solo** con
`/policy-update`, que anexa con procedencia y nunca sobrescribe. **Si no existe**, el agente
emite `SIN-CORPUS`: se registra como hueco de cobertura y **no bloquea** — una empresa que
aún no entregó su documentación no se queda sin poder auditar.

Entregable: `.orchestrator/40-cumplimiento.md` y `40-cumplimiento.json`, más la línea
obligatoria en la traza:

```
fase-6: CUMPLE (corpus <versión>, N elementos correlacionados)
fase-6: INCUMPLE (obligatorias violadas: EMP-SEC-03; BLOCKING)
fase-6: OBSERVADO (N conflictos escalados, M huecos de cobertura)
fase-6: SIN-CORPUS (no existe company-policies/; no bloquea)
```

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
├── 40-cumplimiento.md / .json  (correlación con las políticas de la empresa: salida
│                           obligatoria de la Fase 6; su veredicto entra al gate)
├── trace.md                (trazabilidad: quién, qué, por qué, validación; abre con la línea `fase-0:`)
├── 90-aprendizajes.md
├── state.json              (schema_version, commit, hashes y checkpoints por paso por agente:
│                           habilita la compuerta incremental de la Fase 0 y la reanudación)
└── runs/<run_id>/          (corridas archivadas — resueltas, o planeaciones paralelas
                              aún pendientes de compuerta que no pisaron el root: ver
                              regla de versionado de la Fase 2)

El `policy-index.md` (Capa C) vive en `.claude/policy-index.md`, y la Capa A ejecutable
(linter + tests de arquitectura + pre-commit + CI + baseline) en el repo del proyecto.
El corpus de políticas de la empresa (Fase 6) vive en ámbito de usuario y privado:
`~/.claude/project-orchestrator/memory/company-policies/`. No confundirlo con el
`policy-index`: ese es política **técnica por ruta** del proyecto; aquél es norma
**corporativa** y se actualiza solo con `/policy-update`.
```

Cada archivo es autocontenido y con evidencia. La **memoria global por lenguaje** vive en
ámbito de usuario (`~/.claude/project-orchestrator/memory/<lenguaje>.md`):
`references/language-memory.md`.
