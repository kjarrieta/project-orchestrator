# Instalación automática (bootstrap)

La skill no debe exigir que la persona cree a mano los subagentes ni los hooks. La
primera vez que el orquestador corre en un entorno, **se instala solo**: genera los
archivos de subagente desde sus propios briefs y propone los hooks. Esto ocurre en la
Fase de instalación, antes de la Fase 0.

## Paso 1 — Detectar si ya está instalada

Comprueba si existen los subagentes del orquestador en `.claude/agents/` (proyecto) o
`~/.claude/agents/` (usuario). Si están y coinciden con la versión de la skill, salta
la instalación. Si faltan o están desactualizados, instala/actualiza.

## Paso 1.5 — Asignar los agentes responsables por rol (agnóstico de proveedor)

El orquestador coordina **roles**, no un proveedor concreto — así el sistema funciona
con cualquier backend de agentes, **sin importar la licencia**. Al iniciar la corrida se
define qué agente cumple cada rol y se registra en `.orchestrator/agents.json`. Los tres
roles de mayor impacto se nombran explícitamente (los demás briefs siguen el mismo
esquema):

- **arquitecto** — estructura, contratos y decisiones de diseño (Fase 2).
- **aplicación / ejecución** — implementa lo aprobado y escribe en el código (Fase 4).
- **escritura / documentación** — redacta docs y memoria.

Por defecto, cada rol se mapea al subagente de Claude Code que genera el Paso 2
(**implementación concreta actual**, no un requisito). Si el entorno ofrece agentes de
otro proveedor, se asignan aquí por nombre y el flujo no cambia:

    // .orchestrator/agents.json
    {
      "architect":   "<agente-arquitecto>",
      "application":  "<agente-de-aplicación>",
      "writing":      "<agente-de-escritura/documentación>"
    }

Regla: ningún rol queda sin agente asignado antes de la Fase 1; si falta, el director lo
pregunta. La asignación es por corrida/proyecto y se puede sobreescribir. La selección de
**modelo** por defecto (Paso 2) aplica solo cuando el backend es Claude; con otro
proveedor se ignora y manda la asignación de este paso.

## Paso 2 — Generar los subagentes (automático)

Por cada brief en `references/` que sea un agente (feedback, architect,
conventions-reviewer, robustness, database, api, integrations, frontend, seo,
performance, sre, devops, business-rules, qa, security, red-team, policy-compliance,
documentation, learner), escribe un archivo en `.claude/agents/<nombre>.md` con este patrón:
frontmatter YAML + el cuerpo del brief como system prompt. Reglas al generarlos:

- **Agentes de solo diagnóstico** (feedback, architect, conventions-reviewer, robustness,
  database, api, integrations, frontend, seo, performance, sre, devops, business-rules,
  qa, security, red-team en su fase de auditoría, policy-compliance) → `tools: Read, Grep, Glob`. No reciben
  escritura hasta la fase de APLICACIÓN. El **Red Team** y el **Business Rules Auditor**
  no aplican código nunca: son solo AUDITORÍA/meta-auditoría.
- **Agentes que redactan** (documentation, learner) → añaden `Write, Edit`.
- `description` rico en señales de invocación proactiva (extraído de la primera línea
  del brief).
- **Modelo por defecto — se elige por la incertidumbre del encargo, no por el rol**
    (regla en `SKILL.md` › Presupuesto de corrida). Ajústalo si el proyecto lo pide y
    verifica los strings vigentes, pues cambian:
  - **Todos los agentes en AUDITORÍA** (incluidos architect, robustness, api,
    security, qa) → `claude-sonnet-5`. La auditoría es exploración masiva de código:
    el modelo grande aquí es el principal quemador de tokens de la skill.
  - `claude-opus-5` se reserva para el **director** (consolidación, Fase 2-3), el
    **Red Team / Audit Lead** (Fase 2.5, meta-auditoría), el **Business Rules Auditor**
    (razonamiento sobre reglas implícitas y no implementadas) y para veredictos críticos
    puntuales (aislamiento de tenants, decisión de seguridad disputada) — nunca para todo
    el equipo a la vez.
  - Ejecución y trabajo balanceado (fase de APLICACIÓN) → `claude-sonnet-5`.
  - Ligero / alto volumen (feedback, documentation de formato, ediciones simples) →
    `claude-haiku-4-5-20251001`.
  - Planeación del director → `claude-opus-5`; reserva `claude-fable-5` solo para
    decisiones de máxima complejidad.
- El cuerpo del archivo es el contenido del brief correspondiente, precedido de la
  instrucción "Lee `references/evidence-protocol.md` y respétalo".

No inventes agentes que no existan como brief. Si un brief cambia, regenera su archivo.

## Paso 3 — Proponer los hooks (con aprobación)

Los hooks **ejecutan código con los privilegios de la persona**, así que no se
escriben en silencio: se **proponen** y se aplican solo con su visto bueno. Genera el
bloque para `.claude/settings.json` (según `automation-hooks.md`):

- `PostToolUse` con matcher `Edit|Write` → dispara al agente de Documentación.
- `SessionEnd` → dispara al agente Aprendiz.
- `PreToolUse` con matcher `Edit|Write` → guard anti-regresión (Capa C), bloquea firmas
  duras del registro de regresiones antes de escribir. Complementa la Capa A en CI.

Muestra el bloque, explica en una línea qué hace cada hook y su implicación de
seguridad, y escríbelo solo tras el "sí". Si la persona prefiere no automatizar,
la skill funciona igual de forma manual; los hooks son una comodidad, no un requisito.

## Paso 3.5 — Capacidades del entorno

Si el proyecto aún no tiene `.claude/settings.json` con `enabledPlugins`, propón
ejecutar `/setup-project` (o el bloque equivalente) siguiendo
`references/capabilities.md`: solo los plugins que el stack y el pedido justifican,
nunca todos. Igual que los hooks, se propone y se escribe tras el visto bueno.

## Paso 3.6 — Convención de acceso a datos (por proyecto)

El patrón de capas de acceso a datos **no es global**: se decide por proyecto. En el
primer arranque, el director —con el arquitecto— **detecta** el patrón dominante del
código y **pregunta** a la persona cuál desea como estándar para nuevas funcionalidades,
actualizaciones y refactorizaciones. Opciones típicas (no exhaustivas):
`Controller/Livewire → Service → Repository → Model`; `Controller → Service → Model`;
modelos ricos / Active Record; Actions/CQRS; o "seguir lo que ya hay". Registra la
elección en `.orchestrator/conventions.md` (o el `state.json` del proyecto) para que
todos los agentes la respeten sin volver a preguntar. Si la persona no expresa
preferencia, se adopta la convención dominante detectada; **nunca se impone una nueva**.
No confundir con las políticas realmente globales (documentación de API, propagación de
obligatoriedad de la BD, manejo de datos sensibles en URL), que sí aplican a todo proyecto.

## Paso 3.6b — Convención de módulos CRUD y permisos (por proyecto)

Mismo patrón que el Paso 3.6, para un dominio distinto: **qué mecanismo de permisos usa
este proyecto** para las funcionalidades, módulos o formularios que manejan registros
(crear, consultar, editar, eliminar, activar, suspender o cambiar de estado). No es
opcional saltarlo con "ya sé cómo se hace": el mecanismo varía por proyecto y asumir uno
es exactamente la clase de suposición que la skill prohíbe (ver `security.md`, «Política
de módulos CRUD y de cambio de estado»).

1. **Detecta** el mecanismo dominante ya implementado, con evidencia `ruta:línea`: roles
   (columna en `users`, tabla de roles), paquete de permisos (Spatie `laravel-permission`,
   similar), políticas por recurso (`Policy`/`Gate` de Laravel, o su equivalente en otro
   framework), permisos por usuario directo (tabla pivote usuario↔permiso sin rol
   intermedio), ABAC (reglas por atributo del sujeto/recurso), o una combinación.
2. **Si hay un mecanismo dominante claro**, propónlo como estándar a confirmar. **Si no lo
   hay** (proyecto nuevo, o el existente es inconsistente entre módulos), **pregunta a la
   persona** cuál va a implementar — no se impone uno nuevo ni se asume el "más común"
   sin preguntar. Mismas opciones típicas del punto 1, más la combinación que el proyecto
   necesite (p. ej. roles para navegación + Policy por recurso para el detalle).
3. **Registra la elección** en `.orchestrator/conventions.md`, con: el mecanismo elegido,
   dónde vive la fuente de verdad de permisos (tabla, config, servicio), y qué acciones
   cubre (crear/consultar/editar/eliminar/activar/suspender/cambio de estado — declara
   explícitamente si alguna de estas queda fuera del alcance del mecanismo, en vez de
   dejarlo implícito).
4. **Distílalo de inmediato**, no lo dejes como convención en prosa: es el ejemplo canónico
   de invariante duro proactivo (`regression-ledger.md`, «Distilación proactiva vs.
   reactiva»). Con el mecanismo ya nombrado y el patrón de archivo real del proyecto (de
   dónde salió la evidencia del punto 1, o la forma idiomática del framework si es
   greenfield), define el `senal` (`grep_requerido`: si el método coincide con un patrón de
   acción mutante — `create`, `store`, `update`, `delete`, `destroy`, `activate`, `suspend`,
   `toggleStatus`, `changeStatus`, y equivalentes del idioma del proyecto —, debe aparecer
   también la llamada de autorización del mecanismo elegido) con `alcance_rutas` amplio
   (todo el tipo de archivo, no el módulo puntual que originó la entrevista). Corre
   `/distill-guard` o crea la entrada directo en `regression-ledger.json` y `/guard-sync`.
   El objetivo es que el **siguiente** módulo que maneje registros, no solo el actual, nazca
   protegido.

## Paso 3.7 — Defensa anti-regresión (Capas A y C)

La pieza que hace que "lo documentado no vuelva a colarse". Ver `anti-regression.md`.

1. **Detecta si ya existe.** Busca en el repo un linter de políticas, tests de
   arquitectura, pre-commit y job de CI, y un `regression-ledger`/baseline. **Si están,
   no los reconstruyas**: reúsalos y solo bajarás el baseline al corregir hallazgos.
2. **Si faltan y el pedido lo amerita, propón generarlos** (con aprobación, igual que los
   hooks):
   - **Capa A ejecutable**, acotada a las firmas reales del proyecto: tests de
     arquitectura para reglas estructurales + un comando de lint de políticas para las
     firmas regex, cableados en la suite del stack + pre-commit + CI, con **baseline**
     que congela la deuda actual (el gate solo falla ante violaciones nuevas). No
     inventes reglas sin una política del proyecto que las respalde.
   - **`project-memory/regression-ledger.md`/`.json`** — el registro que alimenta todas
     las capas (`regression-ledger.md`).
   - **`.claude/policy-index.md`** (Capa C) — mapa `ruta/glob → reglas duras aplicables`,
     con las mismas claves que las reglas de Capa A.
3. **Guard de escritura (Capa C) — obligatorio, no opcional.** Es lo único de toda la
   skill que actúa **mientras** se escribe; sin él, cada incumplimiento se paga tres
   veces: ejecutar, corregir, auditar para volver a corregir. Se instalan las dos
   piezas, en este orden:
   - **`scripts/compile-guard-rules.ps1`** — compila las cuatro fuentes de política
     (registro de regresiones, corpus de empresa, memoria de lenguaje/global,
     `policy-index`) en `.orchestrator/guard-rules.json`. Corre en la Fase R, antes de
     que ningún agente escriba, y **se vuelve a correr al cerrar** si el Aprendiz añadió
     entradas.
   - **`scripts/anti-regression-guard.ps1`** — hook `PreToolUse` sobre `Edit|Write` que
     evalúa ese contrato y **bloquea** (exit 2) la escritura que viola un invariante ya
     documentado. Ver `automation-hooks.md`.

   La Capa A en CI sigue siendo la red final (atrapa a cualquier autor, no solo a Claude
   Code), pero ya no es la **primera**: el guard mueve la detección al momento de
   escribir, que es donde cuesta una corrección en vez de tres.

4. **Lee el inventario de huecos.** El compilador emite `sin_firma[]`: las políticas que
   **ninguna máquina puede hacer cumplir** porque siguen siendo prosa sin firma. Ese
   número es la superficie real que va a caer en auditoría humana. Preséntalo en la
   compuerta; destilar las de mayor severidad a `senal` es trabajo de la corrida, no
   deuda invisible.
5. **Corre `/distill-guard` sobre este proyecto**, con el diagnóstico de la Fase 0 ya
   fijado (stack, versiones, BD, arquitectura). No se limita a las políticas de esta
   corrida: barre las cinco capas de conocimiento aplicables (universal de la skill,
   empresa, agente-agnóstico, lenguaje/framework, librerías en cascada) e identifica,
   con evidencia real, cuáles ya están implementadas, cuáles faltan y cuáles tienen un
   patrón seguro para distilar ahora. En proyectos greenfield (Rama A de la Fase 0) esto
   es **obligatorio** antes de la primera escritura de la Fase 4, no un paso posterior —
   ver `regression-ledger.md`, «Distilación proactiva vs. reactiva».

Todo esto se **propone y se escribe tras el visto bueno**; sin la Capa A el sistema
funciona, pero pierde la garantía de "una regresión documentada no puede mergear", y sin
el guard de Capa C la pierde *durante el desarrollo*, que es cuando más barata sale.

## Paso 3.8 — Puntero al corpus de políticas de empresa (si existe)

El corpus de `/policy-update` (`~/.claude/project-orchestrator/memory/company-policies/`)
solo protege lo que pasa por la Fase 6. Una sesión de Claude Code que edita este proyecto
**sin** invocar `/orchestrator` nunca lo ve — y la mayoría de sus entradas son proceso
(Git flow, plantillas de MR, revisión) que ninguna firma de guard puede hacer cumplir
igual. La única forma barata de que esas normas lleguen a cualquier sesión, con o sin la
skill, es que el propio `AGENTS.md`/`CLAUDE.md` del proyecto las señale.

1. **Si `company-policies/index.md` no existe**, omite este paso — no hay corpus que
   señalar. No es un hueco: se declara `SIN-CORPUS` igual que en la Fase 6.
2. **Si existe**, propone (nunca escribe sin aprobación, misma compuerta que los hooks)
   anexar al `AGENTS.md` del proyecto (o crearlo si no existe; si el proyecto usa
   `CLAUDE.md` como archivo primario, anexa ahí o agrega `@AGENTS.md` si aún no lo
   incluye) un bloque corto, **no el corpus completo** — cargar ~30KB en cada turno
   viola la disciplina de coste de `SKILL.md` › Presupuesto de corrida:

   ```
   Antes de crear ramas, commits, Merge Requests, endpoints de API u otro trabajo
   cubierto por norma corporativa, consulta
   `~/.claude/project-orchestrator/memory/company-policies/index.md` y lee el dominio
   aplicable (`desarrollo.md`, `apis.md`, `seguridad.md`, ...). Aplica aunque no se
   esté ejecutando la skill `project-orchestrator`.
   ```

3. **Si ya hay un puntero equivalente** (revisa antes de proponer — grep
   `company-policies` sobre `AGENTS.md`/`CLAUDE.md`), no lo dupliques.
4. Registra en `.orchestrator/state.json` que este paso corrió, para no re-proponerlo en
   cada corrida — solo se revisita si el corpus gana su primer dominio nuevo relevante a
   este proyecto (p. ej. este proyecto no tenía por qué señalar `desarrollo.md` antes de
   que existiera) o si la persona pide refrescarlo.

## Paso 3.9 — Sincronizar el conocimiento ya escrito del proyecto (equivalente a `/learn-from`)

El bootstrap hasta aquí solo empuja conocimiento hacia el proyecto (memoria global,
puntero de políticas). Un proyecto existente casi siempre ya trae aprendizaje propio
escrito antes de que el orquestador llegara — un `README`, `CONTRIBUTING`, ADRs en
`docs/`, reglas en `.cursor/` o `.github/copilot-instructions.md`, convenciones que otro
agente dejó documentadas. Ese conocimiento no debe quedarse aislado en este repositorio si
generaliza a otros proyectos del mismo lenguaje.

1. **Solo en el primer bootstrap** de este proyecto (no en corridas posteriores; si el
   proyecto ya tiene `.orchestrator/state.json` con este paso marcado, sáltalo salvo que
   la persona pida re-sincronizar).
2. Ejecuta el mismo procedimiento que `commands/learn-from.md` sobre la ruta de este
   proyecto — mismas fuentes a barrer, misma clasificación en tres niveles (proyecto /
   lenguaje+versión / universal), misma compuerta de aprobación antes de escribir en la
   memoria del orquestador. No reimplementes la lógica: invoca ese mismo rol de
   Retroalimentación con este proyecto como argumento.
3. Es **best-effort y acotado**: si el proyecto es grande, prioriza `docs/`, `README`,
   `CONTRIBUTING` y archivos de reglas de otros agentes por encima de barrer el código
   completo — el bootstrap no es una auditoría de código.
4. Presenta el resumen junto con el resto del reporte del Paso 4 (qué se extrajo, a qué
   nivel, qué quedó dudoso) y escribe en la memoria global **solo tras el visto bueno** —
   la misma regla de `learn-from.md`, sin excepción por ser parte del bootstrap.
5. Registra en `.orchestrator/state.json` que este paso corrió (con fecha), para que
   `/guard-sync` y corridas futuras sepan que este proyecto ya aportó su conocimiento
   previo y no haga falta repetirlo de cero.

## Paso 4 — Confirmar

Reporta qué se instaló (agentes creados/actualizados, hooks propuestos o escritos), si se
anexó el puntero al corpus de políticas (Paso 3.8) o por qué no (`SIN-CORPUS`, o ya
existía), y el resumen de la sincronización de conocimiento previo del proyecto (Paso 3.9):
qué se extrajo, a qué nivel de memoria fue y qué quedó pendiente de aprobación. Luego sigue
con la Fase 0. En corridas posteriores, el bootstrap se salta salvo que la skill se haya
actualizado.

## Regla

La instalación automatiza el **andamiaje** (crear archivos de agente, proponer hooks),
nunca la decisión de escribir en producción. Y respeta el guardarraíl de seguridad:
los agentes de auditoría nacen sin permiso de escritura, y los hooks pasan por
aprobación humana.
