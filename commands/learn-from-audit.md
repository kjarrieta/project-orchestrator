---
description: Aprende de una auditoría externa (uno o varios .md de fixes/hallazgos de otro agente) — hace ingeniería inversa del descubrimiento y lo convierte en capacidad permanente de auditoría de la skill, bajo compuerta. NO aplica los fixes.
argument-hint: "<ruta.md> [ruta2.md ...] [-- <ruta del proyecto auditado>]"
---

# Aprender de una auditoría externa

Ejecuta el meta-aprendizaje de cobertura de la skill `project-orchestrator`. Recibe uno o
varios `.md` con los hallazgos, observaciones o fixes que **un agente externo** identificó,
y los usa como **evidencia de brechas de nuestra propia metodología de auditoría** — no
como una lista de parches que aplicar.

Lee primero, y síguelo al pie de la letra:
`~/.claude/skills/project-orchestrator/references/audit-learning.md` (el método completo:
principio, taxonomía de brechas, esquema de regla generalizable, entregable y dónde
aterriza cada aprendizaje). Apóyate en `references/behavioral-journey-tracing.md` (método
de recorrido), `references/cross-layer-seams.md` (biblioteca de patrones),
`references/regression-ledger.md` (esquema `senal`) y `references/evidence-protocol.md`
(cero suposiciones).

Argumentos: $ARGUMENTS
- Uno o más `.md` de la auditoría externa (obligatorio).
- Opcional, tras `--`: la ruta del proyecto auditado, para contrastar cada hallazgo contra
  el código real (`ruta:línea`) en vez de solo contra el `.md`.

## Procedimiento

1. **Ingiere** cada `.md` (solo lectura). Inventaría qué hallazgos, flujos validados y
   fixes trae; no asumas que los fixes son completos ni que son los únicos problemas.
2. **Ejecuta el método** de `audit-learning.md` hallazgo por hallazgo: reconstruye el
   descubrimiento (entrada→hipótesis→trazabilidad→evidencia→contradicción→hallazgo→fix→
   validación), clasifica la **brecha metodológica**, aprende el **journey**, abstrae a
   **regla generalizable**, define **owner + seam** y busca **variantes no identificadas**.
   Si hay proyecto accesible, ancla cada afirmación en `ruta:línea` real; si no, en el `.md`.
3. **Produce el entregable único** (14 secciones de `audit-learning.md`), incluidas la
   matriz de cobertura y la de no-regresión, y la prueba de transferencia. Déjalo en
   `.orchestrator/90-aprendizaje-auditoria-externa.md` del proyecto activo (o, sin proyecto
   activo, donde la persona indique).
4. **Compuerta humana.** Presenta el resumen: qué se aprendió, qué brechas se cerraron, a
   qué archivo va cada pieza y qué quedó `[HUECO]`. **Nada se anexa sin visto bueno** — una
   entrada de cobertura mala se replica a todos los proyectos futuros.
5. **Aterriza tras la aprobación**, anexando (nunca sobrescribiendo — leer completo
   primero, P-NO-CLOBBER): seed patterns → `cross-layer-seams.md`; cambios de método →
   `behavioral-journey-tracing.md`; invariantes con firma → `regression-ledger` (`senal`);
   lenguaje/universal → memoria por nivel; recurrentes que merezcan norma → **propuesta**
   de política (alta solo por `/policy-update`).
6. **Recompila: `/guard-sync --all`.** Anexar no hace exigible; compilar sí.

## Reglas

- **NO es "aplica estos fixes".** Si el resultado es `Fix #N → check #N`, falló: la salida
  debe responder qué sabía hacer el agente externo que la skill no sabía, por qué, y cómo
  ese razonamiento queda incorporado, con owner y regresión.
- **Solo lectura** sobre los `.md` y sobre el proyecto auditado. El comando no modifica el
  proyecto; solo propone y, tras la compuerta, anexa a la memoria/metodología de la skill.
- **Cero suposiciones** (`evidence-protocol.md`): cada afirmación con evidencia; sin ella,
  `[HUECO]` y se pregunta.
- **No degrades la cobertura existente** al añadir reglas nuevas (sección 8 del método).
- **Tokens**: barre con Read/Grep dirigidos, resume por hallazgo (conteo + un ejemplo para
  los repetitivos), no transcribas los `.md` enteros de vuelta al contexto.
