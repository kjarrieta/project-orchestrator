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

Todo esto se **propone y se escribe tras el visto bueno**; sin la Capa A el sistema
funciona, pero pierde la garantía de "una regresión documentada no puede mergear", y sin
el guard de Capa C la pierde *durante el desarrollo*, que es cuando más barata sale.

## Paso 4 — Confirmar

Reporta qué se instaló (agentes creados/actualizados, hooks propuestos o escritos) y
sigue con la Fase 0. En corridas posteriores, el bootstrap se salta salvo que la skill
se haya actualizado.

## Regla

La instalación automatiza el **andamiaje** (crear archivos de agente, proponer hooks),
nunca la decisión de escribir en producción. Y respeta el guardarraíl de seguridad:
los agentes de auditoría nacen sin permiso de escritura, y los hooks pasan por
aprobación humana.
