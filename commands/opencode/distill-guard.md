---
description: Destila TODO el conocimiento aplicable al stack del proyecto (universal de la skill, empresa, agentes independientes del lenguaje, lenguaje/framework, librerías en cascada) en reglas senal del guard, en dos fases — identificar cómo está implementado hoy, definir qué se va a exigir — y recompila
---

# Distilar TODO el conocimiento aplicable al guard del proyecto

Lee `references/regression-ledger.md` («Distilación proactiva vs. reactiva») de la skill
`project-orchestrator` antes de operar (localízala en `.agents/skills/project-orchestrator/`,
`.claude/skills/project-orchestrator/` del proyecto, o `~/.claude/skills/project-orchestrator/`).
Este comando no distila una política aislada: barre **todas las capas de conocimiento que
apliquen al stack de este proyecto** y las convierte en reglas exigibles, con el mismo patrón
identificar→definir que ya usan las Fases 1 y 2 del orquestador — aquí aplicado a política, no
a hallazgos de bug.

Argumento (ruta del proyecto): $ARGUMENTS

## Requisito: diagnóstico ya hecho

Lee lo que la Fase 0 ya fijó (`00-ficha-de-hechos.md`: lenguaje/framework y versión exacta,
motor de BD, arquitectura, multi-tenant, apificación, librerías declaradas en
manifiestos/lockfiles). No audita ni descubre stack de cero. Si la ficha no existe, detente y
sugiere `/orchestrator` o `/orchestrator nuevo` primero.

## Las capas de conocimiento a barrer (todas, en este orden)

Ninguna capa se salta porque "ya se cubrió antes" sin comprobarlo — cada corrida re-verifica
qué sigue vigente y qué es nuevo desde la última vez.

1. **Universal de la skill (agente-agnóstico de lenguaje).** Barre **los 19 briefs de agente
   de `references/*.md`** (el roster completo de `capability-registry.md`: feedback,
   architect, conventions-reviewer, robustness, database, api, integrations, frontend, seo,
   performance, sre, devops, business-rules, qa, security, red-team, policy-compliance,
   documentation, learner), no solo los que tengan el encabezado literal "Conocimiento fijo
   (no se negocia)". **La mayoría lo declara así**; los que no lo hacen igual traen
   conocimiento invariante bajo otro nombre y no se saltan por eso — verificado en campo:
   `conventions-reviewer.md` (código muerto, DRY, duplicación bajo "Regla de oro" y "Qué
   buscas") y `red-team.md` (invariantes de meta-auditoría bajo "Regla dura"). Toma el
   conocimiento fijo real del brief, siga o no ese título exacto, más `memory/global/practices.md`.
   Aplica a **todo** proyecto sin excepción de stack.
2. **Empresa.** `~/.claude/project-orchestrator/memory/company-policies/*.md`, si el corpus
   existe (`SIN-CORPUS` si no). Filtra por **Ámbito**: solo las entradas cuyo ámbito declarado
   cubre este proyecto (stack, tipo de dato, cliente) entran a evaluación.
3. **Agentes no dependientes del lenguaje, con dominio condicional.** Mismos 19 briefs, la
   parte que sí asume un dominio (formularios → frontend; archivos/proveedores →
   integrations; contratos → api; esquema/datos → database; código muerto/DRY →
   conventions-reviewer; web pública → seo…) sin atarse a un framework específico — se
   filtra por si el proyecto tiene ese dominio (no evalúes "manejo de archivos" si el
   proyecto no sube archivos, ni "SEO" si no hay web pública indexable).
4. **Lenguaje/framework propio del proyecto.** `memory/<lenguaje>/*.md`, acotado a la
   **versión exacta** de la ficha (sección `## <Framework> <versión>`, nunca la genérica si
   hay una específica de versión).
5. **Librerías usadas, en cascada de dependencias.** Lee el manifiesto/lockfile real
   (`composer.json`/`.lock`, `package.json`/`-lock.json`). Por cada librería con memoria
   conocida (grep en `memory/<lenguaje>/` por su nombre), aplica su política — empezando por
   el framework base, luego las librerías construidas sobre él (p. ej. Livewire sobre
   Laravel), luego las que esas traen a su vez — mientras exista conocimiento ya documentado.
   **No inventes política para una librería sin memoria existente**: eso es trabajo de
   `/learn-from` o de una auditoría nueva, no de este comando.
6. **Lo ya propio de este proyecto.** `regression-ledger.json`, `conventions.md`, `CLAUDE.md`
   existentes — para no proponer de nuevo lo que el proyecto ya resolvió, y para saber cómo
   este proyecto en particular nombra sus cosas (esto es lo que varía de proyecto a proyecto,
   aunque la política de origen sea la misma).

## Fase D1 — Identificar (solo lectura, con evidencia)

Por cada política candidata de las capas 1-5 que **aplique** a este stack (descarta con
motivo explícito la que no aplica — no la omitas en silencio):

- Busca en el código real **cómo está implementada hoy**, o si no está implementada en
  absoluto. Evidencia `ruta:línea` siempre — nunca una impresión.
- Esta fase es la que traduce la política genérica al **vocabulario real de este proyecto**:
  dos proyectos pueden implementar el mismo invariante ("campo identificación solo
  alfanumérico") con nombres de campo, reglas de validación y archivos completamente
  distintos. Sin esta fase no hay forma honesta de escribir un patrón que no sea ruidoso.
- Entrega un mapa: política → estado actual (implementada / parcial / ausente) → evidencia.

Es la misma disciplina que la Fase 1 del orquestador (auditoría paralela, solo lectura), pero
acotada a "¿esta política ya vive en el código, y cómo se ve?" en vez de "¿hay un bug aquí?".

## Fase D2 — Definir (con compuerta, luego se distila)

Con el mapa de D1, por cada política que sí aplica:

- **Si D1 encontró una implementación reconocible** (aunque sea parcial o incorrecta): define
  el patrón `senal` usando el vocabulario real que D1 encontró (nombres de campo, rutas,
  reglas de validación reales), con `alcance_rutas` generalizado al **tipo** de archivo
  (`app/Http/Requests/**/*.php`, no solo el archivo donde se vio), para que cubra también los
  archivos del mismo tipo que el proyecto todavía no ha escrito.
- **Si D1 no encontró nada** (política no implementada, o proyecto greenfield sin código
  aún): define el patrón contra la **forma idiomática esperada** en ese framework/versión,
  citando la doc oficial — sin inventar, con la misma evidencia que exige `evidence-protocol.md`.
- **Si ningún patrón es seguro** (alto riesgo de falso positivo, o D1 no dio vocabulario
  suficiente para diferenciarlo del resto del código): no se fuerza. Se reporta `sin_firma`
  con el motivo — sigue como conocimiento fijo para razonamiento de agente.
- Clasifica el destino de cada `senal` nueva:
  - **Regla de negocio de este proyecto** (cantidades, formatos, convenciones que no son
    universales del framework) → `.orchestrator/project-memory/regression-ledger.json`.
  - **Regla cierta para cualquier proyecto en ese lenguaje/framework+versión** (la política ya
    lo era en la skill; aquí solo se confirmó el patrón contra código real) → memoria global
    `~/.claude/project-orchestrator/memory/<lenguaje>/*.md`. **Dedupe primero**: si ya existe
    una entrada que cubre lo mismo para esa versión, no la dupliques — actualízala si el
    patrón encontrado la afina.
- **Compuerta.** Presenta el resumen completo antes de escribir: por capa, cuántas políticas
  se evaluaron, cuántas aplicaron, cuántas se distilaron (y a qué nivel), cuántas quedaron
  `sin_firma` y por qué, cuántas no aplicaban y por qué. Escribe solo tras el visto bueno —
  mismo criterio que `/policy-update` y `/learn-from`.

Es la misma disciplina que la Fase 2 del orquestador (consolidación: qué se va a tener), pero
el resultado son entradas de `senal`, no un plan de cambios de código.

## Recompilar y verificar

`/guard-sync <ruta>` (o `--all` si se escribió en memoria global — otros proyectos con el
mismo stack ganan cobertura de inmediato). Reporta reglas compiladas, bloqueantes, `sin_firma`
restante, y confirma con una prueba real (Paso 4 de `guard-sync.md`) que al menos una regla
nueva bloquea de verdad.

## Corridas siguientes: detección real de qué cambió, no una promesa en prosa

"Solo re-evalúo lo nuevo" no es honesto sin un ancla verificable. La tiene: la skill
(`~/.claude/skills/project-orchestrator`) y la memoria del orquestador
(`~/.claude/project-orchestrator/memory`) son **repos git** — su commit HEAD es la marca de
versión. El estado de cada corrida se guarda en
`.orchestrator/project-memory/distill-guard-state.json`:

```json
{
  "schema_version": 1,
  "last_run": "2026-09-19",
  "skill_commit": "ff9e75d8d16c7e53db662952f4b4d38561f9ecdf",
  "memory_commit": "cb535d43776edb2a7e9b2b3415cb09cc4a0d3431",
  "corpus_version_seen": "<fecha de company-policies/index.md en esa corrida>",
  "lockfile_hashes": { "composer.lock": "<sha256>", "package-lock.json": "<sha256>" }
}
```

Al volver a correr sobre un proyecto que ya tiene este archivo:

1. **Capas 1 y 3 (skill).** Compara `git -C ~/.claude/skills/project-orchestrator rev-parse HEAD`
   contra `skill_commit` guardado.
   - Igual → nada cambió en la skill; no re-evalúes estas capas.
   - Distinto → `git -C ~/.claude/skills/project-orchestrator diff --name-only
     <skill_commit>..HEAD -- references/` y re-evalúa **solo** los briefs que aparecen en ese
     diff (D1+D2 acotados a esos archivos). Si el diff falla (el commit guardado ya no existe
     en el historial — skill reinstalada, rebase, ZIP nuevo sin `.git`), no asumas cobertura:
     trátalo como si todo hubiera cambiado y re-evalúa el roster completo, dejando la
     advertencia explícita de por qué no se pudo acotar.
2. **Capa 2 (empresa).** Compara la fecha de `company-policies/index.md` (que ya sella su
   última actualización, ver `policy-update.md` Paso 6) contra `corpus_version_seen`. Distinta
   → re-evalúa solo las entradas nuevas/`SUPERSEDIDA` desde esa fecha.
3. **Capa 4 (lenguaje/global).** Igual que (1) pero contra `memory_commit` del repo de memoria
   (`~/.claude/project-orchestrator/memory`), acotado a `memory/<lenguaje>/` y `memory/global/`.
4. **Capa 5 (librerías).** Recalcula el hash de cada lockfile presente y compáralo contra
   `lockfile_hashes` guardado. Distinto → recalcula el árbol de dependencias y evalúa solo las
   librerías nuevas o con versión mayor cambiada.
5. **Capa 6 (proyecto).** Siempre se relee — es la más barata y la que menos cambia por fuera
   de esta misma corrida.

Si `distill-guard-state.json` **no existe** (primera corrida, o un proyecto de antes de que
este archivo existiera), no hay ancla: trátalo como corrida completa de las cinco capas, sin
excepción, y créalo al cerrar. Actualiza el archivo (los tres commits/hashes y `last_run`) al
final de cada corrida, éxito o no — si falló a medias, dejar el estado viejo haría creer a la
siguiente corrida que ya cubrió algo que no cubrió.

No reprocesa lo que ya está `senal` y sigue vigente **dentro de la capa que no cambió**; sí
reprocesa cualquier capa marcada como cambiada arriba, completa.

## Para proyectos nuevos (greenfield) — parte obligatoria de la corrida inicial

Cuando el proyecto nace por `/orchestrator nuevo`, este comando corre dentro de la misma
corrida inicial, justo después de que la Fase 0(A) fija el stack propuesto y **antes** de que
la Fase 4 escriba la primera línea de código de aplicación. Aquí la Fase D1 (identificar)
degenera trivialmente — no hay código que auditar — así que el trabajo real es D2: definir el
patrón esperado contra la doc oficial del stack elegido. Es precisamente el caso donde la vía
reactiva del Aprendiz nunca se dispararía (no hay regresión posible sobre código que no
existe): la única forma de que el proyecto nazca cumpliendo la política de la skill es
distilarla antes de la primera escritura. Ver `SKILL.md` Fase 0 (Rama A) y `setup.md` Paso 3.7.

## Reglas

- Nunca inventa un patrón sin evidencia de cómo se ve en el código real de este proyecto (D1)
  o en la doc oficial del stack propuesto (greenfield) — mismo criterio que `/policy-update`:
  sin patrón seguro conocido, `sin_firma` declarado, jamás una regex ruidosa "para cubrir".
- Ninguna capa se asume cubierta sin comprobarla en esta corrida — "ya lo vimos antes" no es
  evidencia si la política, la librería o el código cambiaron.
- Solo lectura sobre el código del proyecto en D1; las únicas escrituras son las entradas de
  `senal` nuevas o actualizadas en D2, tras compuerta.
- No dupliques lo que ya está distilado en memoria global o en el registro del proyecto —
  mismo criterio de deduplicación que `/learn-from`.
- Optimiza tokens: D1 usa Glob/Grep dirigido por lo que cada política necesita verificar, no
  un barrido completo del árbol; resume por política, no transcribas el código encontrado.
