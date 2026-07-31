---
description: Audita plugins nuevos o cambiados y sincroniza el mapa de capacidades (plugin-profiles + orquestador) sin perder lo existente
argument-hint: [nombre de plugin concreto, opcional]
---

# Sincronizar capacidades del ecosistema

Cuando se instalan plugins nuevos, hay que auditarlos e integrarlos al esquema de
activación por proyecto y al mapa tarea→capacidad del orquestador, **sin perder lo ya
logrado con los actuales**. Este comando hace esa sincronización.

Argumentos (plugin concreto a auditar, o vacío = detectar todos): $ARGUMENTS

## Fuentes de verdad (en este orden)

1. `~/.claude/plugins/installed_plugins.json` — qué está instalado realmente.
2. `~/.claude/settings.json` → `enabledPlugins` — estado global (debe quedar `false`
   salvo security-guidance, remember y atomic-agents).
3. `~/.claude/plugin-profiles.md` — perfiles de activación por proyecto.
4. `~/.claude/skills/project-orchestrator/references/capabilities.md` — mapa
   tarea→capacidad que usan los agentes del orquestador.

## Procedimiento

1. **Detectar novedades.** Compara (1) contra (3) y (4): plugins instalados que no
   figuran en los perfiles ni en el mapa son NUEVOS; plugins documentados que ya no
   están instalados se marcan como retirados (no se borra su historia: se anota
   "retirado <fecha>").

2. **Auditar cada plugin nuevo** leyendo su contenido real en
   `~/.claude/plugins/cache/<marketplace>/<plugin>/` (manifiesto, skills, agentes,
   hooks, MCP). Produce por plugin, con evidencia de archivos leídos:
   - **Qué aporta**: capacidades concretas (skills/comandos/agentes y qué hacen).
   - **Peso en tokens**: cuántas skills/agentes inyecta al estar activo (número de
     descripciones). Alto peso = más razón para activación por proyecto.
   - **A qué tareas/agentes del orquestador sirve**: mapear contra los 12 agentes
     (BD, APIs, Frontend, QA, Seguridad, etc.). Si optimiza o mejora un trabajo que
     hoy un agente hace a mano, eso se anota como delegación recomendada.
   - **Duplicados**: si duplica algo nativo (/code-review, /verify, etc.) u otro
     plugin ya mapeado, se recomienda NO usarlo y se dice por qué.
   - **Hooks o código que ejecuta**: señálalo como implicación de seguridad.

3. **Actualizar por FUSIÓN, nunca reescritura:**
   - `~/.claude/plugin-profiles.md`: agrega el bloque `enabledPlugins` del plugin
     nuevo bajo el perfil que corresponda (o crea perfil). No toques bloques
     existentes.
   - `references/capabilities.md` del orquestador: agrega la fila al mapa
     tarea→capacidad con quién la usa y en qué modo. No modifiques filas existentes
     salvo para marcar retiros.
   - Si el plugin quedó `true` global en `~/.claude/settings.json` tras instalarse,
     proponer pasarlo a `false` global (activación por proyecto), salvo que el
     usuario diga lo contrario.

4. **Redistribuir.** Si existe `~/Downloads/project-orchestrator.skill`, reempaqueta
   la skill instalada (ZIP con carpeta raíz `project-orchestrator/`) para que la
   versión distribuible no quede atrás.

5. **Reportar**: plugins nuevos auditados (aporte, peso, mapeo), retirados, cambios
   escritos en cada archivo, y recordatorio de que los agentes del orquestador ya
   pueden llamarlos a necesidad vía `capabilities.md`.

## Reglas

- Nada de suposiciones: si un plugin no se puede leer en cache, es un hueco — dilo,
  no lo inventes.
- Preservación primero: ante conflicto entre lo documentado y lo instalado, pregunta
  antes de borrar conocimiento previo.
- Nunca sugieras reactivar plugins globalmente.
