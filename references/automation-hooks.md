# Automatización: hooks y subagentes en Claude Code

Dos agentes de esta skill —**Documentación** y **Aprendiz**— deben "correr
automáticamente". En Claude Code eso no es magia: se ancla a dos mecanismos reales,
**hooks** y **subagentes**. Este documento explica cómo cablearlos. Verifica la
sintaxis contra la doc oficial vigente (`code.claude.com/docs/en/hooks` y
`/sub-agents`) y contra tu versión instalada, porque evolucionan rápido.

## Advertencia de seguridad (léela)

Un hook es **código que autorizas a ejecutarse solo**, con tus privilegios de shell.
Un repositorio con un `.claude/settings.json` malicioso ejecutaría sus hooks en tu
máquina. Trata la configuración de hooks como código: revísala en PR, y a cada
subagente dale el mínimo de herramientas que necesita.

## Tres cosas se automatizan aquí

1. **Documentación** tras editar código (`PostToolUse`) — refresca la doc del módulo.
2. **Aprendiz** al cerrar sesión (`SessionEnd`) — destila y promueve regresiones.
3. **Guard anti-regresión** antes de escribir (`PreToolUse`) — bloquea firmas duras del
   registro de regresiones (Capa C, complementa la Capa A en CI).

## Los subagentes (dónde viven los agentes de esta skill)

Cada agente se define como un archivo Markdown con frontmatter YAML en
`.claude/agents/` (versionado con el proyecto) o `~/.claude/agents/` (tu usuario).
El **cuerpo del archivo es el system prompt** del subagente. Ejemplo con el agente
de documentación (su cuerpo sería el contenido de `references/documentation.md`):

```markdown
---
name: doc-agent
description: Documenta módulo por módulo y cierra desarrollos con un merge documentado. Úsalo proactivamente tras editar controladores, rutas o reglas de negocio.
tools: Read, Write, Edit, Glob, Grep
model: sonnet
---
(aquí va el brief del agente: el contenido de references/documentation.md)
```

Claves:
- La **invocación automática por el modelo** se dispara por el campo `description`
  (no hay un campo "trigger"): escríbelo rico en señales ("Úsalo proactivamente
  tras...", "DEBE usarse para...").
- `tools` es la palanca de seguridad. El auditor de seguridad y el aprendiz que solo
  proponen van con `Read, Grep, Glob`. Omitir `tools` hereda todas.
- Cada subagente corre en **contexto aislado**; solo su mensaje final vuelve al
  director. El único canal de entrada es el prompt con que se le invoca.

## Los hooks (qué dispara a los agentes automáticos)

Se definen en `settings.json` (proyecto: `.claude/settings.json`; usuario:
`~/.claude/settings.json`). Estructura: evento → grupo por `matcher` → manejadores.

### Documentación tras editar código → `PostToolUse`

Refresca la ficha del módulo tocado tras cada edición de código. Para no dispararse
en cada micro-edición, acota por herramienta con el `matcher` y deja que el script
decida si el archivo editado amerita doc (p. ej. solo controladores/rutas):

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/scripts/maybe-doc.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

Donde `maybe-doc.sh` lee por stdin el JSON del evento (incluye la ruta editada),
filtra por patrón (controladores, rutas, servicios de negocio) y, si aplica,
invoca al subagente de documentación. Alternativamente el manejador puede ser de
`type: "agent"` para spawnnear el subagente directamente. Nota: `PostToolUse` no
puede deshacer la edición (ya ocurrió); solo reacciona. Para bloquear algo antes de
que pase, se usa `PreToolUse`.

### Aprendiz al cerrar la sesión → `SessionEnd`

Corre una sola vez, al terminar la sesión, con todo el trabajo como material:

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/scripts/run-learner.sh",
            "timeout": 300
          }
        ]
      }
    ]
  }
}
```

Si prefieres que un modelo decida si hubo algo que valga la pena persistir antes de
gastar la corrida, usa un manejador `type: "prompt"` en el evento `Stop` que
responda si conviene lanzar al aprendiz.

### Guard anti-regresión antes de escribir → `PreToolUse`

Capa C de la defensa anti-regresión (`anti-regression.md`). A diferencia de
`PostToolUse`, `PreToolUse` corre **antes** de que la edición ocurra y **puede
bloquearla** (exit code 2 o `permissionDecision: "deny"`). Cablea un manejador sobre
`Edit|Write` que lea por stdin el JSON del evento (ruta + contenido/`new_string`
propuesto), consulte las entradas del `regression-ledger.json` cuyo `alcance_rutas` casa
con la ruta editada, y evalúe su `senal`:

**El script existe y vive en la skill**, no hay que escribirlo por proyecto:
`scripts/anti-regression-guard.ps1` (PowerShell 5.1+, funciona en Windows y con `pwsh`
en Linux/macOS). Lo que se cablea por proyecto es el hook:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh -NoProfile -File \"$HOME/.claude/skills/project-orchestrator/scripts/anti-regression-guard.ps1\"",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

El guard **no lee las políticas directamente**: lee `.orchestrator/guard-rules.json`, que
produce `scripts/compile-guard-rules.ps1` fusionando las cuatro fuentes (registro de
regresiones, corpus de empresa, memoria de lenguaje/global, `policy-index`). Si ese
archivo no existe, el guard sale en silencio: un proyecto que aún no corrió la skill no
queda bloqueado.

**Solo lo que tiene firma es exigible.** Una política en prosa no puede bloquear nada. El
corpus y las memorias de lenguaje declaran su firma en un bloque cercado ```` ```senal ````
bajo el encabezado de la política:

````markdown
### EMP-APIS-03 — Toda respuesta de error usa el envelope estándar

```senal
{
  "tipo": "grep_requerido",
  "alcance_rutas": ["app/Http/Controllers/**/*.php"],
  "patron": "response\\(\\)->json\\(",
  "requiere_ademas": "ApiResponse::|ErrorEnvelope",
  "gate": "BLOCKING",
  "correccion": "Usa ApiResponse::error(); no construyas el JSON a mano."
}
```
````

Lo que no lo declara aparece en `sin_firma[]` del `guard-rules.json`: es el inventario
explícito de lo que seguirá cayendo en auditoría humana. Ese número se presenta en la
compuerta; un hueco medido es deuda declarada, un hueco no medido es la sorpresa de la
auditoría de rama.

`anti-regression-guard.ps1`:
- `grep_prohibido` que casa el patrón → **bloquea** (exit 2) con el ID de la entrada, el
  invariante y la corrección esperada.
- `grep_requerido` cuyo `patron` casa pero falta `requiere_ademas` → **bloquea**.
- Cualquier entrada del dominio/ruta tocado → **inyecta** al contexto los invariantes
  relevantes como recordatorio (aunque no bloquee).

Es **la primera red, no la última**: atrapa la violación antes de que el archivo exista,
que es cuando corregirla cuesta una vez y no tres. La **Capa A** (linter de políticas + CI
en el propio repo) sigue siendo la garantía de que ningún autor —humano u otra
herramienta— mergee una regresión; lo que el guard elimina es el ciclo
*ejecutar → corregir → auditar → volver a corregir* dentro de una misma sesión.

El bloqueo explica el invariante y cómo cumplirlo. La persona puede levantar el guard para
IDs concretos con `ORCH_GUARD_BYPASS`, y queda registrado en
`.orchestrator/guard-bypass.log` con fecha, ruta y regla: **nunca en silencio**. El agente
que recibe un bloqueo no rodea el guard ni lo reescribe — corrige el código o escala.

### Eventos útiles (referencia rápida)

`PreToolUse` (antes de una herramienta; puede bloquear con exit code 2 o
`permissionDecision: "deny"`), `PostToolUse` (tras una herramienta, éxito),
`UserPromptSubmit`, `Stop` (fin de turno), `SessionStart`/`SessionEnd` (inicio/fin
de sesión), `PreCompact`/`PostCompact`, `SubagentStart`/`SubagentStop`. El conjunto
exacto depende de tu versión: confírmalo con `claude --help hooks`.

## Regla de diseño para lo automático

Automatiza el disparo, **no la decisión de escribir en producción**. Los agentes
automáticos (Documentación, Aprendiz) generan y **proponen**; los cambios que tocan
código o políticas siguen pasando por la compuerta humana del orquestador. Un hook
que auto-aplica cambios sin revisión es justo el antipatrón que esta skill evita
(ver los guardarraíles en `evidence-protocol.md`).
