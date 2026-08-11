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

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/scripts/anti-regression-guard.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

`anti-regression-guard.sh`:
- `grep_prohibido` que casa el patrón → **bloquea** (exit 2) con el ID de la entrada, el
  invariante y la corrección esperada.
- `grep_requerido` cuyo `patron` casa pero falta `requiere_ademas` → **bloquea**.
- Cualquier entrada del dominio/ruta tocado → **inyecta** al contexto los invariantes
  relevantes como recordatorio (aunque no bloquee).

Es **complementario, no la red final**: cubre lo que escribe Claude Code; la garantía de
que ningún autor (humano u otra herramienta) mergee una regresión la da la **Capa A**
(linter de políticas + CI, en el propio repo). El bloqueo explica el invariante y cómo
cumplirlo; la persona puede levantar el guard de forma explícita para un cambio concreto,
nunca en silencio.

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
