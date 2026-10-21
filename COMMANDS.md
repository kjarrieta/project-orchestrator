# Mapa de comandos — Orquestador de Proyecto

Guía de uso para no perder nada de lo construido. El punto de entrada recomendado es
el comando global `/orchestrator` (archivo `~/.claude/commands/orchestrator.md`; si no
existe en este entorno, copia ese archivo o invoca la skill por lenguaje natural).

## Comandos

| Comando | Qué hace | Fases | Cuándo usarlo |
|---|---|---|---|
| `/orchestrator` | Flujo completo hasta la compuerta | R→0→1→2→3 | Primera corrida o corrida general: "revisa mi proyecto" |
| `/orchestrator auditar [alcance]` | Auditoría acotada, solo lectura | R→3 | Revisar un módulo o tema concreto sin tocar nada |
| `/orchestrator aplicar` | Aplica el plan ya aprobado | 4→5 | Después de aprobar la compuerta; rama dedicada + commits atómicos |
| `/orchestrator nuevo` | Entrevista greenfield + propuesta de stack | R→0(A) | Proyecto desde cero, sin código |
| `/orchestrator verificar` | Solo verificación de lo aplicado | 5 | Revalidar tras cambios manuales o regresiones |
| `/orchestrator estado` | Resume `.orchestrator/` sin lanzar agentes | — | Retomar una corrida: en qué quedó, huecos, qué sigue |
| `/orchestrator setup` | Solo bootstrap: subagentes, hooks, capacidades | instalación | Entorno nuevo o skill actualizada |
| `/orchestrator cerrar` | Documentación + Aprendiz | automáticas | Al terminar una jornada/desarrollo |

También funciona por lenguaje natural ("audita el módulo de pagos con el
orquestador"): la skill se activa sola por su descripción. El comando existe para que
el enrutamiento a fases sea determinista.

## Flujo típico

```
proyecto existente:  /orchestrator            → revisar plan → aprobar → /orchestrator aplicar → /orchestrator cerrar
proyecto nuevo:      /orchestrator nuevo      → aprobar stack → /orchestrator aplicar
retomar trabajo:     /orchestrator estado     → decidir → auditar|aplicar|verificar
solo un módulo:      /orchestrator auditar <módulo>
```

## Comandos compañeros del ecosistema

| Comando | Qué hace |
|---|---|
| `/setup-project` | Genera el `.claude/settings.json` del proyecto activando solo los plugins que su stack necesita |
| `/sync-capabilities` | Audita plugins nuevos instalados y fusiona el mapa `references/capabilities.md` sin perder lo existente |
| `/learn-from <ruta\|global>` | Extrae aprendizajes de un proyecto viejo (cualquier agente + docs/políticas) hacia la memoria del orquestador, por niveles proyecto/lenguaje+versión/universal |
| `/pack-skill [--verify]` | Vuelca la memoria viva al snapshot, sincroniza comandos y regenera `~/Downloads/project-orchestrator.skill`. Correr tras cada sesión de audits para no perder aprendizajes; `--verify` solo compara sin empaquetar |

## Reglas que ningún comando salta

- **Compuerta humana (Fase 3):** `aplicar` exige plan aprobado en
  `.orchestrator/10-plan-consolidado.md`; sin él, se detiene.
- **Cero suposiciones:** todo con evidencia ruta:línea o doc oficial de la versión
  exacta (`references/evidence-protocol.md`).
- **Capacidades por tarea:** plugins/skills del entorno se activan solo por proyecto y
  con tarea que lo justifique (`references/capabilities.md`, comando `/setup-project`).
- **Salidas en `.orchestrator/`:** cada corrida queda trazada; las anteriores se
  archivan en `runs/<fecha>/`, nada se pierde.
- **Incremental por defecto:** si `.orchestrator/state.json` existe, la documentación
  del proyecto NO se regenera — solo se actualizan las secciones afectadas por el
  delta de git desde la última corrida. Regeneración completa solo si se pide
  explícitamente.

## Instalación en un entorno nuevo

1. Descomprimir `project-orchestrator.skill` (ZIP) en `~/.claude/skills/`.
2. Copiar los archivos de `commands/` (orchestrator, setup-project,
   sync-capabilities, learn-from, pack-skill) a `~/.claude/commands/`.
3. Reiniciar la sesión de Claude Code.
4. `/orchestrator setup` en el proyecto para el bootstrap.

Nota: `/setup-project` y `/sync-capabilities` referencian `~/.claude/plugin-profiles.md`
y los plugins instalados de cada máquina; en un equipo nuevo, correr primero
`/sync-capabilities` para generar el mapa según lo que ese entorno tenga.
