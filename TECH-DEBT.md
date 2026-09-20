# Deuda técnica de la skill `project-orchestrator`

Registro de deuda técnica **de la skill misma** (su código, su distribución), separado del
`decision-ledger.md` (decisiones de los proyectos que la skill audita) y del
`regression-ledger.md` (invariantes de esos mismos proyectos). Cada entrada dice qué falta,
por qué no se resolvió en el momento en que se detectó, y qué costaría resolverla.

## DEUDA-001 — Comandos duplicados a mano por backend (Claude Code / opencode)

- **Estado:** ABIERTA
- **Detectada:** 2026-09-19
- **Síntoma:** cada comando nuevo (`distill-guard.md`, `research-file-handling.md`, y todos
  los anteriores) existe como **dos archivos casi idénticos**: `commands/<nombre>.md` y
  `commands/opencode/<nombre>.md`. La diferencia real entre ambos suele ser un párrafo (cómo
  localizar la skill: Claude Code asume `~/.claude/skills/project-orchestrator/`; opencode
  busca en `.agents/skills/`, `.claude/skills/` del proyecto, o `~/.claude/skills/`) y, a
  veces, el soporte de `argument-hint` en el frontmatter (opencode no lo usa). El resto del
  cuerpo se copia y pega — con el riesgo estructural de que diverjan con el tiempo si alguien
  edita una variante y olvida la otra.
- **Por qué no se resolvió ahora:** el pedido que lo originó (agregar `/distill-guard` y
  `/research-file-handling`) no era el momento de rediseñar el mecanismo de distribución de
  comandos; hacerlo a mitad de esa tarea habría mezclado dos cambios de naturaleza distinta
  en el mismo diff.
- **Solución propuesta (no implementada):** una sola fuente por comando — el `.md` en
  `commands/` como canónico, con un marcador (`<!-- backend:claude -->` / `<!-- backend:opencode -->`
  o un bloque de front-matter con variantes) para las pocas líneas que sí difieren — y un
  paso en `scripts/sync-commands.ps1` (o un script nuevo, `scripts/generate-commands.ps1`) que
  **genere** `commands/opencode/<nombre>.md` a partir de esa única fuente en vez de mantenerse
  como archivo editado a mano. Esto no reemplaza la sincronización hacia
  `~/.claude/commands/`/`~/.config/opencode/commands/` (ver `hooks/`, `INSTALL.md`) — es un
  paso previo, de generación, no de distribución.
- **Costo de no resolverla:** cada comando nuevo paga el trabajo doble de redactar+revisar
  dos archivos, y cada edición futura a un comando existente arriesga que una de las dos
  variantes quede desactualizada sin que ningún hook lo detecte (los hooks de `hooks/`
  sincronizan lo que hay en el repo hacia el host; no detectan que las dos variantes del
  propio repo divergieron entre sí).
- **Costo de resolverla:** diseñar el formato de marcador de variante, escribir el generador,
  migrar los ~9 comandos existentes al formato único, y decidir qué pasa con las variantes
  que ya tienen diferencias de fondo (no solo el párrafo de localización) antes de poder
  generarlas automáticamente.

## DEUDA-002 — El hook de sincronización de comandos no cubría el commit directo

- **Estado:** RESUELTA (2026-09-19)
- **Síntoma:** `hooks/` sincronizaba `commands/` hacia `~/.claude/commands/` y
  `~/.config/opencode/commands/` tras `pull`, `merge`, `checkout` o `rebase` (commit `8dec500`),
  pero **no** tras un `commit` directo en el working tree — el patrón de trabajo más común al
  desarrollar la propia skill in situ (editar y confirmar, sin pasar por `pull`). Confirmado en
  esta máquina: tras commitear `distill-guard.md` y `research-file-handling.md`, ni
  `~/.claude/commands/` ni `~/.config/opencode/commands/` los tenían.
- **Fix:** se agregó `hooks/post-commit` (mismo cuerpo compartido `_sync-commands.sh` que los
  demás hooks) y se corrió `scripts/sync-commands.ps1` manualmente para poner al día esta
  máquina. Ver `INSTALL.md`.
