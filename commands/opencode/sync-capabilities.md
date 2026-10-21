---
description: Audita skills o MCP nuevos o cambiados y sincroniza el mapa de capacidades (opencode + orquestador) sin perder lo existente
---

# Sincronizar capacidades del ecosistema

Cuando aparecen **capacidades nuevas** (agentes, skills o MCP), hay que auditarlas e
integrarlas al esquema de activación por proyecto, al mapa tarea→capacidad y a la
**asignación de roles** del orquestador (arquitecto / aplicación / escritura), **sin
perder lo ya logrado**. El mapa es capacidad→rol, **no** está atado a un proveedor: el
sistema funciona con cualquier backend de agentes, sin importar la licencia. Las fuentes
de abajo son la **implementación concreta actual (opencode)**; con otro proveedor se
sustituyen por su registro equivalente de agentes/capacidades y el procedimiento no cambia.

Argumentos (capacidad concreta a auditar, o vacío = detectar todas): $ARGUMENTS

## Fuentes de verdad (en este orden)

1. Skills instaladas: `.agents/skills/` y `.claude/skills/` del proyecto + `~/.agents/skills/` global.
2. Config de opencode: `~/.config/opencode/opencode.json` y `.opencode/opencode.json` — bloques `mcp` (servidores habilitados/deshabilitados).
3. `references/capabilities.md` de la skill `project-orchestrator` — mapa tarea→capacidad que usan los agentes del orquestador (localizar la skill en `.agents/skills/project-orchestrator/`, `.claude/skills/project-orchestrator/` o `~/.claude/skills/project-orchestrator/`).

## Procedimiento

1. **Detectar novedades.** Compara (1) y (2) contra (3): capacidades instaladas que no
   figuran en el mapa son NUEVAS; capacidades documentadas que ya no están instaladas se
   marcan como retiradas (no se borra su historia: se anota "retirado <fecha>").

2. **Auditar cada capacidad nueva** leyendo su contenido real (SKILL.md de la skill, o
   la definición del MCP en la config). Produce por capacidad, con evidencia de archivos
   leídos:
   - **Qué aporta**: capacidades concretas (skills/comandos y qué hacen, o herramientas MCP).
   - **Peso en tokens**: cuántas skills/descripciones inyecta al estar activa. Alto peso =
     más razón para activación por proyecto.
   - **A qué tareas/agentes del orquestador sirve**: mapear contra los agentes del orquestador
     (BD, APIs, Frontend, QA, Seguridad, etc.). Si optimiza o mejora un trabajo que
     hoy un agente hace a mano, eso se anota como delegación recomendada.
   - **Duplicados**: si duplica algo nativo u otra capacidad ya mapeada, se recomienda
     NO usarla y se dice por qué.
   - **Riesgo de seguridad**: si ejecuta código (hooks, scripts de setup) o abre red,
     señálalo.

3. **Actualizar por FUSIÓN, nunca reescritura:**
   - `references/capabilities.md` del orquestador: agrega la fila al mapa tarea→capacidad
     con quién la usa y en qué modo. No modifiques filas existentes salvo para marcar retiros.
   - Asignación de roles: si la capacidad nueva cambia quién debería cumplir un rol
     (arquitecto / aplicación / escritura), anótalo como sugerencia; la asignación
     efectiva vive en `.orchestrator/agents.json` por proyecto (ver `setup.md` Paso 1.5)
     y no se sobreescribe sin visto bueno.
   - Si el MCP quedó `enabled` en la config global sin justificación, proponer
     deshabilitarlo globalmente (activación por proyecto).

4. **Redistribuir.** Si existe `~/Downloads/project-orchestrator.skill`, reempaqueta la
   skill instalada (ver `/pack-skill`) para que la versión distribuible no quede atrás.

5. **Reportar**: capacidades nuevas auditadas (aporte, peso, mapeo), retiradas, cambios
   escritos en cada archivo, y recordatorio de que los agentes del orquestador ya pueden
   llamarlas a necesidad vía `capabilities.md`.

## Reglas

- Nada de suposiciones: si una capacidad no se puede leer, es un hueco — dilo, no lo inventes.
- Preservación primero: ante conflicto entre lo documentado y lo instalado, pregunta
  antes de borrar conocimiento previo.
- Nunca sugieras reactivar capacidades globalmente sin justificación.
