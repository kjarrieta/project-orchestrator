---
description: Empaqueta la skill project-orchestrator instalada (con su memoria global y comandos) en ~/Downloads/project-orchestrator.skill para distribuir o respaldar — garantiza que los cambios locales no se pierdan
---

# Empaquetar la skill project-orchestrator

Empaqueta el estado actual de la skill instalada junto con sus comandos compañeros y la
memoria global hacia `~/Downloads/project-orchestrator.skill` (ZIP renombrado). Usar
después de cualquier sesión donde se hayan mejorado la skill, la memoria global o los
comandos.

La skill canónica puede vivir en `~/.claude/skills/project-orchestrator/` (global) o en
`.agents/skills/project-orchestrator/` / `.claude/skills/project-orchestrator/` de un
proyecto (si es la que se mantiene). Usa la global si existe; si no, la del proyecto
actual. Los comandos compañeros viven en `~/.claude/commands/` y en
`~/.config/opencode/commands/`.

Argumentos: $ARGUMENTS

## Pasos

1. **Sincronizar las DOS variantes de comandos compañeros en la skill.** Los comandos
   existen en dos variantes porque el procedimiento es agnóstico de proveedor pero los
   mecanismos de activación no lo son. Cada una viaja en su propia carpeta y **jamás se
   copia una encima de la otra**:

   | Origen | Destino en la skill | Backend |
   |---|---|---|
   | `~/.claude/commands/` | `<skill>/commands/` | Claude Code (plugins, `.claude/settings.json`) |
   | `~/.config/opencode/commands/` | `<skill>/commands/opencode/` | opencode (skills en `.agents/skills/`, MCP en `.opencode/opencode.json`) |

   Archivos del ecosistema en ambas: `orchestrator.md`, `setup-project.md`,
   `sync-capabilities.md`, `learn-from.md`, `policy-update.md`, `pack-skill.md`.

   ```powershell
   Copy-Item "$HOME\.claude\commands\*.md" "<skill>\commands\" -Force
   New-Item -ItemType Directory -Force "<skill>\commands\opencode" | Out-Null
   Copy-Item "$HOME\.config\opencode\commands\*.md" "<skill>\commands\opencode\" -Force
   ```

   Antes de copiar, **diff de las dos variantes** (ignorando fin de línea) y reporta si
   una quedó atrás en procedimiento —fases, compuertas, pasos nuevos—: eso es deriva real
   y hay que portarla a mano. Las diferencias de backend y de frontmatter propio del host
   (`argument-hint`, `allowed-tools`) son esperadas y no se tocan.

2. **Reflejar (mirror) la memoria viva en el snapshot.** La memoria viva
   `~/.claude/project-orchestrator/memory/` es la que alimentan los audits y
   `/learn-from`; el snapshot `<skill>/memory-snapshot/` es lo que viaja en el paquete.
   Hay que **reflejar**, no solo copiar, para capturar carpetas nuevas por lenguaje y
   borrados:
   ```powershell
   $live = "$HOME\.claude\project-orchestrator\memory"
   $snap = "<skill>\memory-snapshot"
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

   **Compuerta de `source-of-truth.md` (bloquea el empaquetado).** Esta es la red que
   atrapa la regresión de artefacto; si falla, no se empaqueta:

   - **INV-SOT-01 · paridad de inventario.** `commands/*.md` y `commands/opencode/*.md`
     con los mismos nombres de archivo en las dos. Un nombre presente en una y ausente en
     la otra es un comando que ese backend no tendrá: dilo, **no lo rellenes copiando la
     otra variante**. Verifica también que cada nombre existe en su destino instalado
     (`~/.claude/commands/`, `~/.config/opencode/commands/`): un comando que viaja en el
     paquete y no está instalado en ningún lado ya pasó una vez.
   - **INV-SOT-01 · paridad de procedimiento.** El diff de cada par (ignorando fin de
     línea) acotado a las diferencias declaradas en `INSTALL.md`. Divergencia en fases,
     compuertas, pasos o rutas de artefacto es deriva real y se porta a mano.
   - **INV-SOT-02 · hechos derivables.** Ninguna cifra de inventario escrita a mano en la
     prosa de la skill:
     ```bash
     grep -rnE '\b[0-9]{1,3} +(agentes|comandos|fases|capacidades|módulos|reglas|plugins|skills)\b' \
       --include='*.md' <skill> | grep -v memory-snapshot
     ```
     Cada coincidencia es un **candidato**, no un veredicto: se confirma solo si el número
     afirma cuántos elementos hay. No son violaciones una cantidad genérica en prosa, un
     anti-patrón citado, ni un conteo de diseño cerrado con sus elementos enumerados al
     lado (ver `references/source-of-truth.md`). Reporta las coincidencias con su
     ruta:línea y la clasificación que les diste.

4. **Empaquetar.** Si el argumento es `--verify`, detente aquí y reporta el estado
   sin crear el paquete. Si no, usar `.NET ZipFile` (no `Compress-Archive`: ese cmdlet
   depende de `Microsoft.PowerShell.Archive`, que falla en entornos de agentes externos):
   ```powershell
   $skill = "<skill>"
   $tmp   = "$env:TEMP\po-pack"
   $dest  = "$HOME\Downloads\project-orchestrator.skill"
   $before = if (Test-Path $dest) { (Get-Item $dest).Length } else { 0 }
   Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
   New-Item -ItemType Directory -Force "$tmp\project-orchestrator" | Out-Null
   Copy-Item "$skill\*" "$tmp\project-orchestrator\" -Recurse -Force
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $zip = "$tmp\po.zip"
   if (Test-Path $zip) { Remove-Item $zip }
   [System.IO.Compression.ZipFile]::CreateFromDirectory($tmp, $zip)
   Move-Item $zip $dest -Force
   Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
   ```
   - Verificar el paquete: abrir el ZIP y confirmar que las entradas
     `memory-snapshot/**` coinciden en tamaño con la memoria viva; reportar diferencias.

5. **Reportar.** Mostrar: tamaño del paquete (antes y después), número de archivos,
   archivos de memoria incluidos, deriva detectada entre las dos variantes de comandos, y
   el comando de instalación en otro equipo:
   ```powershell
   # En el equipo destino (no usar Expand-Archive: requiere Microsoft.PowerShell.Archive):
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   $arch = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path "project-orchestrator.skill").Path)
   foreach ($e in $arch.Entries | Where-Object { $_.Name -ne '' }) {
       $out = Join-Path "$HOME\.claude\skills" $e.FullName
       New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
       [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
   }
   $arch.Dispose()
   Copy-Item "$HOME\.claude\skills\project-orchestrator\commands\*.md" "$HOME\.claude\commands\" -Force
   Copy-Item "$HOME\.claude\skills\project-orchestrator\commands\opencode\*.md" "$HOME\.config\opencode\commands\" -Force
   Copy-Item "$HOME\.claude\skills\project-orchestrator\memory-snapshot\*" "$HOME\.claude\project-orchestrator\memory\" -Recurse -Force
   # Reiniciar la sesión
   # /orchestrator setup  (en el proyecto)
   ```

## Reglas

- Nunca incluir en el paquete: `.env`, credenciales, datos de clientes, código de
  proyectos específicos (`platform/`, `app/`, etc.), `.orchestrator/` de proyectos.
- Si `~/Downloads/project-orchestrator.skill` ya existe, sobreescribir sin preguntar
  (es el flujo normal de actualización).
- Reportar el tamaño antes y después para que el crecimiento del paquete sea visible.
- La compuerta del Paso 3 es la materialización de `references/source-of-truth.md` para
  los artefactos de la propia skill. Si falla, **no se empaqueta**: distribuir una copia
  derivada la propaga a cada equipo que instale.
- **Nunca copiar una variante de comandos sobre la otra.** `commands/` es Claude Code y
  `commands/opencode/` es opencode; sobrescribir una con la otra rompe las rutas de
  activación del backend afectado. Al mejorar el procedimiento, portar el cambio a ambas.
