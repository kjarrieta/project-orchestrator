# Instalación automática (bootstrap)

La skill no debe exigir que la persona cree a mano los subagentes ni los hooks. La
primera vez que el orquestador corre en un entorno, **se instala solo**: genera los
archivos de subagente desde sus propios briefs y propone los hooks. Esto ocurre en la
Fase de instalación, antes de la Fase 0.

## Paso 1 — Detectar si ya está instalada

Comprueba si existen los subagentes del orquestador en `.claude/agents/` (proyecto) o
`~/.claude/agents/` (usuario). Si están y coinciden con la versión de la skill, salta
la instalación. Si faltan o están desactualizados, instala/actualiza.

## Paso 2 — Generar los subagentes (automático)

Por cada brief en `references/` que sea un agente (feedback, architect, robustness,
database, api, integrations, frontend, seo, qa, security, documentation, learner),
escribe un archivo en `.claude/agents/<nombre>.md` con este patrón: frontmatter YAML +
el cuerpo del brief como system prompt. Reglas al generarlos:

- **Agentes de solo diagnóstico** (feedback, architect, robustness, database, api,
  integrations, frontend, seo, qa, security en su fase de auditoría) → `tools: Read,
  Grep, Glob`. No reciben escritura hasta la fase de APLICACIÓN.
- **Agentes que redactan** (documentation, learner) → añaden `Write, Edit`.
- `description` rico en señales de invocación proactiva (extraído de la primera línea
  del brief).
- **Modelo por defecto** (ajústalo si el proyecto lo pide; verifica los strings
  vigentes, pues cambian):
  - **Todos los agentes en AUDITORÍA** (incluidos architect, robustness, api,
    security, qa) → `claude-sonnet-4-6`. La auditoría es exploración masiva de código:
    el modelo grande aquí es el principal quemador de tokens de la skill.
  - `claude-opus-4-8` se reserva para el **director** (consolidación, Fase 2-3) y
    para veredictos críticos puntuales (aislamiento de tenants, decisión de seguridad
    disputada) — nunca para los doce a la vez.
  - Ejecución y trabajo balanceado (fase de APLICACIÓN) → `claude-sonnet-4-6`.
  - Ligero / alto volumen (feedback, documentation de formato, ediciones simples) →
    `claude-haiku-4-5-20251001`.
  - Planeación del director → `claude-opus-4-8`; reserva `claude-fable-5` solo para
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

Muestra el bloque, explica en una línea qué hace cada hook y su implicación de
seguridad, y escríbelo solo tras el "sí". Si la persona prefiere no automatizar,
la skill funciona igual de forma manual; los hooks son una comodidad, no un requisito.

## Paso 3.5 — Capacidades del entorno

Si el proyecto aún no tiene `.claude/settings.json` con `enabledPlugins`, propón
ejecutar `/setup-project` (o el bloque equivalente) siguiendo
`references/capabilities.md`: solo los plugins que el stack y el pedido justifican,
nunca todos. Igual que los hooks, se propone y se escribe tras el visto bueno.

## Paso 4 — Confirmar

Reporta qué se instaló (agentes creados/actualizados, hooks propuestos o escritos) y
sigue con la Fase 0. En corridas posteriores, el bootstrap se salta salvo que la skill
se haya actualizado.

## Regla

La instalación automatiza el **andamiaje** (crear archivos de agente, proponer hooks),
nunca la decisión de escribir en producción. Y respeta el guardarraíl de seguridad:
los agentes de auditoría nacen sin permiso de escritura, y los hooks pasan por
aprobación humana.
