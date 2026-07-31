---
description: Empaqueta la skill project-orchestrator instalada (con su memoria global y comandos) en ~/Downloads/project-orchestrator.skill para distribuir o respaldar — garantiza que los cambios locales no se pierdan
argument-hint: [--verify]  (--verify: solo compara sin empaquetar)
---

# Empaquetar la skill project-orchestrator

Empaqueta el estado actual de la skill instalada en
`~/.claude/skills/project-orchestrator/` junto con sus comandos compañeros y la
memoria global hacia `~/Downloads/project-orchestrator.skill` (ZIP renombrado).
Usar después de cualquier sesión donde se hayan mejorado la skill, la memoria global
o los comandos.

Argumentos: $ARGUMENTS

## Pasos

1. **Sincronizar comandos compañeros en la skill.** Copiar los archivos actuales de
   `~/.claude/commands/` que pertenecen al ecosistema hacia
   `~/.claude/skills/project-orchestrator/commands/` para que viajen en el paquete:
   - `orchestrator.md`
   - `setup-project.md`
   - `sync-capabilities.md`
   - `learn-from.md`
   - `pack-skill.md`   ← este mismo

2. **Reflejar (mirror) la memoria viva en el snapshot.** La memoria viva
   `~/.claude/project-orchestrator/memory/` es la que alimentan los audits y
   `/learn-from`; el snapshot `~/.claude/skills/project-orchestrator/memory-snapshot/`
   es lo que viaja en el paquete. Hay que **reflejar**, no solo copiar, para capturar
   carpetas nuevas por lenguaje (p. ej. `javascript/`) y borrados:
   ```powershell
   $live = "$HOME\.claude\project-orchestrator\memory"
   $snap = "$HOME\.claude\skills\project-orchestrator\memory-snapshot"
   Remove-Item -Recurse -Force $snap -ErrorAction SilentlyContinue
   New-Item -ItemType Directory -Force $snap | Out-Null
   Copy-Item "$live\*" $snap -Recurse -Force
   ```
   Regla: nunca copiar datos de proyecto específicos (`.orchestrator/` de un proyecto,
   CLAUDE.md de un cliente) — solo `memory/` (global y por lenguaje).

3. **Verificar integridad de archivos clave.** Confirmar que existen y no están
   vacíos: `SKILL.md`, `COMMANDS.md`, `references/evidence-protocol.md`,
   `references/capabilities.md`, `references/setup.md`, `references/learner.md`,
   `references/language-memory.md`. Confirmar además que el snapshot no quedó vacío
   (debe tener ≥ el nº de archivos de la memoria viva).

4. **Empaquetar.** Si el argumento es `--verify`, detente aquí y reporta el estado
   sin crear el paquete. Si no, usar `Compress-Archive` (este equipo no tiene `zip`),
   con staging para que la carpeta raíz del ZIP sea `project-orchestrator/`:
   ```powershell
   $skill = "$HOME\.claude\skills\project-orchestrator"
   $tmp   = "$env:TEMP\po-pack"
   $dest  = "$HOME\Downloads\project-orchestrator.skill"
   $before = if (Test-Path $dest) { (Get-Item $dest).Length } else { 0 }
   Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
   New-Item -ItemType Directory -Force "$tmp\project-orchestrator" | Out-Null
   Copy-Item "$skill\*" "$tmp\project-orchestrator\" -Recurse -Force
   Compress-Archive -Path "$tmp\project-orchestrator" -DestinationPath "$tmp\po.zip" -Force
   Move-Item "$tmp\po.zip" $dest -Force
   Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
   ```
   - Verificar el paquete: abrir el ZIP y confirmar que las entradas
     `memory-snapshot/**` coinciden en tamaño con la memoria viva; reportar diferencias.

5. **Reportar.** Mostrar: tamaño del paquete, número de archivos, archivos de
   memoria incluidos, y el comando de instalación en otro equipo:
   ```
   # En el equipo destino:
   Expand-Archive project-orchestrator.skill ~/.claude/skills/ -Force
   Copy-Item ~/.claude/skills/project-orchestrator/commands/* ~/.claude/commands/
   Copy-Item ~/.claude/skills/project-orchestrator/memory-snapshot/* ~/.claude/project-orchestrator/memory/ -Recurse
   # Reiniciar la sesión de Claude Code
   # /orchestrator setup  (en el proyecto)
   ```

## Reglas

- Nunca incluir en el paquete: `.env`, credenciales, datos de clientes, código de
  proyectos específicos (`platform/`, `app/`, etc.), `.orchestrator/` de proyectos.
- Si `~/Downloads/project-orchestrator.skill` ya existe, sobreescribir sin preguntar
  (es el flujo normal de actualización).
- Reportar el tamaño antes y después para que el crecimiento del paquete sea visible.
