---
description: Regenera los .claude/agents/*.md de un proyecto contra los briefs vivos en references/, conservando el frontmatter YAML — ejecútalo cada vez que se edite un brief del orquestador para que los agentes ya desplegados vean los cambios
argument-hint: "[ruta del proyecto | --all | --revisar] [--force]"
allowed-tools: Read, Bash, PowerShell
---

# Refrescar los agentes desplegados

Pone al día los subagentes que el orquestador copió a `.claude/agents/*.md` durante el
setup. Complementa a `/guard-sync` — no lo reemplaza:

| Comando | Actualiza | Cuándo correrlo |
|---|---|---|
| `/guard-sync` | Contrato de reglas (`guard-rules.json`) + hook `PreToolUse` | cambió una política, un aprendizaje o el registro de regresiones |
| `/refresh-agents` | Cuerpo de los agentes desplegados (`.claude/agents/*.md`) | cambió un brief bajo `references/` |

Ambos son necesarios. Un brief editado en la skill queda **invisible** para los agentes
del proyecto hasta que este comando los regenera; el compilador de reglas nunca los toca.

Lee `references/setup.md` (paso 2: generación de subagentes) antes de operar.

## Cuándo ejecutarlo

| Disparador | Argumento | Por qué |
|---|---|---|
| Editaste un brief en `references/` | `--all` | Los proyectos ya instalados leen la copia vieja hasta refrescar |
| Añadiste sección nueva a un agente (ej. adenda en `architect.md`) | `--all` | Idem |
| Actualizaste la skill completa | `--all --force` | Reescribe todo, útil tras cambios masivos |
| Un proyecto puntual estaba desactualizado | `<ruta>` | Refresca solo ese |
| Solo quieres saber qué está desincronizado | `--revisar` | No escribe nada; reporta drift |

**La regla que resume todas:** *editar un brief no lo despliega. Regenerar los agentes, sí.*

## Procedimiento

### Paso 1 — Resolver el alcance

- **`--all`** o **`--revisar`**: lee `~/.claude/project-orchestrator/memory/guarded-projects.json`
  y procesa cada proyecto listado. Los que ya no tienen `.claude/agents/` se marcan `AUSENTE`.
- **Ruta explícita**: solo ese proyecto.

### Paso 2 — Regenerar los agentes

```powershell
& "$HOME/.claude/skills/project-orchestrator/scripts/refresh-agents.ps1" -All
# o
& "$HOME/.claude/skills/project-orchestrator/scripts/refresh-agents.ps1" -ProjectDir "<ruta>"
# o (dry-run)
& "$HOME/.claude/skills/project-orchestrator/scripts/refresh-agents.ps1" -Review
```

El script:

1. Lista los `.claude/agents/*.md` del proyecto.
2. Para cada agente, busca el brief homónimo en `references/`.
3. Compara el hash SHA-256 del cuerpo (ignorando frontmatter y preámbulo `evidence-protocol`).
4. Si difieren, **conserva el frontmatter YAML** (name, description, tools, model — dimensionados por el proyecto) y sustituye el cuerpo por el brief vivo.
5. Reporta cuatro cifras por proyecto:
   - **refrescados**: cuerpo actualizado
   - **sin cambio**: ya coincidía
   - **huérfanos**: agente instalado sin brief fuente (candidato a borrar tras revisión)
   - **faltantes**: brief instalable no desplegado (correr `/orchestrator setup`)

### Paso 3 — Verificar (opcional pero recomendado)

Corre `--revisar` inmediatamente después. Debe reportar `refrescados: 0` en todos los
proyectos; si no, algo falló.

## Modo `--revisar`

No escribe nada. Reporta:

- Agentes cuyo cuerpo diverge del brief fuente (drift real).
- Agentes huérfanos (instalados pero sin brief).
- Briefs instalables faltantes en cada proyecto.

Útil antes de aplicar `--all`, para saber qué va a cambiar.

## Reglas

- **Nunca toca el frontmatter YAML.** El frontmatter lleva el modelo, la descripción y las
  herramientas que el setup del proyecto dimensionó por la incertidumbre local. Cambiarlos
  sin querer degradaría al agente (ej. bajar a `haiku` un agente que necesita `sonnet`).
  Si un brief exige más tools de las que el frontmatter otorga, es un problema del setup,
  no de este comando; que salga en la próxima corrida del orquestador.
- **Nunca borra un agente huérfano.** Un agente sin brief fuente puede ser una capacidad
  antigua desactivada de la skill que el proyecto aún referencia, o un agente custom del
  proyecto. Se reporta y decide la persona, no el script.
- **Nunca instala briefs faltantes.** Instalar un brief nuevo es setup del orquestador
  (dimensiona modelo y tools por la incertidumbre del proyecto); refrescar es solo
  actualizar cuerpos. Los faltantes se listan para que se corra `/orchestrator setup`.
- **`--force` reescribe todo aunque los hashes coincidan.** Útil tras un cambio de
  encoding, línea final o formato masivo — no para saltarse compuertas.
- **`--all` es idempotente.** Correrlo dos veces seguidas debe reportar `refrescados: 0`
  la segunda vez. Si no, hay un fallo en el hash o el preámbulo.
