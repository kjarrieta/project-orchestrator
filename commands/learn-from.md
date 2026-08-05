---
description: Extrae aprendizajes de un proyecto específico (o de las memorias globales) hacia la memoria del orquestador — cualquier agente, docs y políticas, no solo .claude
argument-hint: "<ruta del proyecto | global>"
---

# Aprender de un proyecto existente

Ejecuta el rol del agente de **Retroalimentación** de la skill `project-orchestrator`
sobre una fuente concreta, para rescatar aprendizajes de proyectos viejos que aún no
tienen estándar de memoria. Lee primero
`~/.claude/skills/project-orchestrator/references/feedback.md` y
`references/language-memory.md`: definen fuentes, formato de tres niveles
(proyecto / lenguaje+versión / universal) y reglas de fusión.

Argumento (ruta del proyecto, o `global`): $ARGUMENTS

## Fuentes a barrer (TODAS las que existan, no solo .claude)

En la ruta dada, busca conocimiento escrito por cualquier agente o persona:
- `.claude/` (CLAUDE.md, reglas, memoria), `.orchestrator/` de corridas previas
- Directorios de otros agentes: `.agents/`, `.superpowers/`, `.cursor/`,
  `.github/copilot-instructions.md`, y cualquier carpeta de agente que encuentres
- **Documentación del proyecto**: `docs/` (políticas, flujos, ADRs), `README`,
  `CONTRIBUTING`, guías de estilo — las políticas y flujos documentados son
  aprendizaje aunque nadie los llame memoria
- Con `global`: `~/.claude/projects/*/memory/` (memoria global de Claude) y
  `~/.claude/project-orchestrator/memory/` (para reconciliar, no para releerse a sí
  misma como novedad)

## Procedimiento

1. **Inventaría** las fuentes presentes (lista qué encontraste y qué no — sin
   inventar). Fija el stack y las VERSIONES del proyecto desde sus lockfiles para
   poder acotar las entradas.
2. **Extrae y clasifica** cada aprendizaje en su nivel:
   - Regla de negocio / convención de ese proyecto → se queda documentada allí
     (propón consolidarla en su `CLAUDE.md` o `docs/` si está dispersa).
   - Cierto del lenguaje/framework → memoria por lenguaje, **acotado a versión**
     (`memory/<lenguaje>/<dominio>.md`, sección `## <Framework> <versión>`).
   - Cierto en cualquier stack → `memory/global/practices.md` (universal).
3. **Cada entrada lleva procedencia** (archivo de origen + fecha) y **nada sensible**
   cruza: ni secretos, ni credenciales, ni nombres de cliente, ni código propietario.
4. **Fusiona, no reescribas**: deduplica contra lo que ya existe en la memoria del
   orquestador; contradicciones se marcan como [HUECO] con ambas fuentes, no se
   resuelven en silencio.
5. **Compuerta**: presenta el resumen (qué se extrajo, a qué nivel va cada cosa, qué
   quedó dudoso) y escribe en la memoria del orquestador **solo tras el visto bueno**
   — una entrada global mala se replica a todos los proyectos futuros.

## Reglas

- Solo lectura sobre el proyecto fuente: este comando nunca modifica el proyecto del
  que aprende (salvo propuesta explícita aprobada de consolidar su propia doc).
- Memorias ajenas son claims, no verdades: márcalas dudosas si no se pueden validar.
- Optimiza tokens: barre con Glob/Grep dirigidos, no leas árboles completos; resume
  por archivo, no lo transcribas.
