---
description: Ejecuta el Orquestador de Proyecto (12 agentes senior) — flujo completo o una fase concreta
argument-hint: [auditar|aplicar|nuevo|verificar|estado|setup|cerrar] [alcance opcional]
---

# Punto de entrada del Orquestador de Proyecto

Invoca la skill `project-orchestrator` y ejecútala según el modo pedido. El mapa
completo de modos está en `~/.claude/skills/project-orchestrator/COMMANDS.md`.

Argumentos: $ARGUMENTS

## Despacho por modo (primera palabra de los argumentos)

- **(vacío)** — Flujo completo: bootstrap si falta → Fase R → 0 → 1 (auditoría
  paralela) → 2 → **detente en la Fase 3 (compuerta)** y presenta el plan. Jamás
  continúes a aplicación sin aprobación explícita.
- **auditar [alcance]** — Solo Fases R–3. Si hay alcance (p. ej. "auditar módulo de
  facturación"), acótalo en la ficha y selecciona solo los agentes que ese alcance
  justifica.
- **aplicar** — Requiere `.orchestrator/10-plan-consolidado.md` con plan aprobado en
  compuerta. Si no existe o no fue aprobado, detente y dilo. Ejecuta Fases 4–5 sobre
  rama dedicada, commits atómicos.
- **nuevo** — Proyecto greenfield: Fase R → entrevista de arquitecto senior (rama A de
  la Fase 0) → propuesta de stack → entrevista de diseño del Frontend.
- **verificar** — Solo Fase 5: QA y Seguridad contra lo último aplicado en
  `.orchestrator/apply/`.
- **estado** — No lances agentes: lee `.orchestrator/` (ficha, plan, trace, runs) y
  resume en qué fase quedó la última corrida, huecos abiertos y qué sigue.
- **setup** — Solo bootstrap (`references/setup.md`): genera subagentes, propone hooks
  y capacidades (`/setup-project`), sin iniciar corrida.
- **cerrar** — Cierre de sesión de trabajo: dispara Documentación (merge documentado)
  y Aprendiz (destilar aprendizajes a `90-aprendizajes.md` y memoria por lenguaje).

Cualquier otra primera palabra: trátala como alcance del flujo completo.

## Reglas fijas del despacho

1. Invoca SIEMPRE la skill `project-orchestrator` (herramienta Skill) antes de actuar;
   este comando solo enruta, la skill es la fuente de verdad del procedimiento.
2. Respeta las compuertas: ningún modo salta la aprobación humana de la Fase 3.
3. Si el directorio de trabajo no es un proyecto (es `~` o no hay repo/código),
   detente y pide abrir Claude Code en el proyecto.
